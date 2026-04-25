import { initializeApp } from "https://www.gstatic.com/firebasejs/10.14.1/firebase-app.js";
import {
  getAuth,
  signInWithEmailAndPassword,
  signOut,
  onAuthStateChanged,
} from "https://www.gstatic.com/firebasejs/10.14.1/firebase-auth.js";
import {
  getFunctions,
  httpsCallable,
  connectFunctionsEmulator,
} from "https://www.gstatic.com/firebasejs/10.14.1/firebase-functions.js";
import { firebaseConfig } from "./firebase-config.js";

const app = initializeApp(firebaseConfig);
const auth = getAuth(app);
const functions = getFunctions(app, "us-central1");

/** Only use the Functions emulator when explicitly enabled (avoids "Not authorised" when emulators are off). */
function shouldUseFunctionsEmulator() {
  try {
    if (new URLSearchParams(location.search).get("functionsEmulator") === "1") return true;
  } catch (_) {
    /* ignore */
  }
  try {
    return localStorage.getItem("hesabu_functions_emulator") === "1";
  } catch (_) {
    return false;
  }
}

if (
  shouldUseFunctionsEmulator() &&
  (location.hostname === "localhost" || location.hostname === "127.0.0.1")
) {
  try {
    connectFunctionsEmulator(functions, "127.0.0.1", 5001);
    console.info("[agent-portal] Functions emulator: 127.0.0.1:5001");
  } catch (_) {
    /* already connected */
  }
}

const $ = (id) => document.getElementById(id);

function setFeedback(msg, type) {
  const el = $("feedback");
  if (!el) return;
  el.textContent = msg || "";
  if (!msg) {
    el.className = "";
    return;
  }
  const t = type === "error" ? "error" : type === "ok" ? "ok" : "info";
  el.className = `show ${t}`;
}

let portalRole = null; // 'admin' | 'agent'

async function detectPortalRole() {
  try {
    const fn = httpsCallable(functions, "commissionAdminListAgents");
    await fn({});
    return "admin";
  } catch (_) {
    /* not admin */
  }
  try {
    const fn = httpsCallable(functions, "commissionAgentPing");
    await fn({});
    return "agent";
  } catch (e) {
    console.warn("[agent-portal] commissionAgentPing failed:", e?.code || e?.message || e);
    return null;
  }
}

function currentYearMonth() {
  const d = new Date();
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}`;
}

function esc(s) {
  const t = document.createElement("div");
  t.textContent = s == null ? "" : String(s);
  return t.innerHTML;
}

function renderCommissionStatsDashboard(box, data, agentHeader) {
  if (!box) return;
  const rows = (data.referrals || [])
    .map(
      (r) =>
        `<tr><td>${esc(r.businessName)}</td><td><code>${esc(r.businessId)}</code></td><td>${esc(
          r.installReferrerCode
        )}</td><td>${esc(r.subscriptionStatus)}</td><td>${esc(
          r.paymentStart?.seconds ? new Date(r.paymentStart.seconds * 1000).toISOString().slice(0, 10) : "—"
        )}</td></tr>`
    )
    .join("");
  const adminLine =
    agentHeader && agentHeader.uid
      ? `<p class="stats">Viewing agent: <strong>${esc(agentHeader.displayName || "—")}</strong> · ${esc(
          agentHeader.email || "—"
        )} · <code>${esc(agentHeader.uid)}</code>${agentHeader.active === false ? " · <em>inactive</em>" : ""}</p>`
      : "";
  box.innerHTML = `
    ${adminLine}
    <p class="stats">
      <strong>${esc(data.yearMonth)}</strong> · Commission rate <strong>${esc(data.commissionPercent)}%</strong> ·
      Promo codes: <strong>${(data.promoCodes || []).map(esc).join(", ") || "—"}</strong>
    </p>
    <p class="stats">
      Shops with this install promo (businesses): <strong>${(data.referrals || []).length}</strong> ·
      Paid this month (distinct shops): <strong>${esc(data.paidInMonthBusinessCount)}</strong> ·
      Subscription payment events: <strong>${esc(data.paidInMonthEventCount)}</strong> ·
      Est. commission this month (TZS): <strong>${Number(data.estimatedCommissionTzs || 0).toLocaleString()}</strong>
    </p>
    <p class="hint">${esc(data.commissionNote || "")}</p>
    <div class="table-wrap">
      <table>
        <thead><tr><th>Business</th><th>ID</th><th>Promo</th><th>Subscription</th><th>Last payment start</th></tr></thead>
        <tbody>${rows || '<tr><td colspan="5">No shops with this promo yet.</td></tr>'}</tbody>
      </table>
    </div>
    <details class="events">
      <summary>Payment events this month (${(data.paymentEvents || []).length})</summary>
      <div class="table-wrap">
        <table>
          <thead><tr><th>Business</th><th>Code</th><th>Days</th><th>Basis TZS</th></tr></thead>
          <tbody>
            ${(data.paymentEvents || [])
              .map(
                (e) =>
                  `<tr><td><code>${esc(e.businessId)}</code></td><td>${esc(
                    e.installReferrerCode
                  )}</td><td>${esc(e.periodDays)}</td><td>${Number(
                    e.commissionBasisTzs || 0
                  ).toLocaleString()}</td></tr>`
              )
              .join("") || "<tr><td colspan='4'>None</td></tr>"}
          </tbody>
        </table>
      </div>
    </details>
  `;
}

function renderAgentDashboard(data) {
  renderCommissionStatsDashboard($("agentDashboard"), data, null);
}

async function loadAgentDashboard() {
  const ym = ($("agentMonth")?.value || "").trim() || currentYearMonth();
  setFeedback("Loading…", "info");
  try {
    const fn = httpsCallable(functions, "commissionAgentGetDashboard");
    const { data } = await fn({ yearMonth: ym });
    setFeedback("", "");
    renderAgentDashboard(data);
  } catch (e) {
    setFeedback(e.message || String(e), "error");
  }
}

async function loadAdminAgents() {
  setFeedback("Loading agents…", "info");
  try {
    const fn = httpsCallable(functions, "commissionAdminListAgents");
    const { data } = await fn({});
    const agents = data.agents || [];
    const tbody = $("adminAgentsBody");
    if (tbody) {
      tbody.innerHTML = agents
        .map(
          (a) =>
            `<tr data-uid="${esc(a.uid)}">
            <td><code>${esc(a.uid)}</code></td>
            <td>${esc(a.email)}</td>
            <td>${esc(a.displayName)}</td>
            <td>${(a.promoCodes || []).map(esc).join(", ")}</td>
            <td>${a.commissionPercent != null ? esc(a.commissionPercent) : "20"}%</td>
            <td>${a.active === false ? "inactive" : "active"}</td>
          </tr>`
        )
        .join("") || '<tr><td colspan="6">No agents yet.</td></tr>';
    }
    const sm = $("adminStatsMonth");
    if (sm && !String(sm.value || "").trim()) sm.value = currentYearMonth();
    setFeedback("", "");
  } catch (e) {
    setFeedback(e.message || String(e), "error");
  }
}

async function loadAdminAgentStats() {
  const agentUid = ($("editAgentUid")?.value || "").trim() || selectedAdminAgentUid();
  if (!agentUid) {
    setFeedback("Select an agent row or enter UID before loading stats.", "error");
    return;
  }
  const ym = ($("adminStatsMonth")?.value || "").trim() || currentYearMonth();
  setFeedback("Loading agent stats…", "info");
  try {
    const fn = httpsCallable(functions, "commissionAdminGetAgentDashboard");
    const { data } = await fn({ agentUid, yearMonth: ym });
    setFeedback("", "");
    renderCommissionStatsDashboard($("adminAgentDashboard"), data, {
      uid: data.agentUid || agentUid,
      email: data.agentEmail,
      displayName: data.agentDisplayName,
      active: data.agentActive,
    });
  } catch (e) {
    setFeedback(e.message || String(e), "error");
    const box = $("adminAgentDashboard");
    if (box) box.innerHTML = "";
  }
}

function selectedAdminAgentUid() {
  const tr = document.querySelector("#adminAgentsTable tbody tr[data-uid].selected");
  return tr?.dataset?.uid || "";
}

document.addEventListener("DOMContentLoaded", () => {
  $("adminAgentsTable")?.addEventListener("click", (e) => {
    const tr = e.target.closest("tr[data-uid]");
    if (!tr) return;
    document.querySelectorAll("#adminAgentsTable tbody tr").forEach((r) => r.classList.remove("selected"));
    tr.classList.add("selected");
    const uid = tr.dataset.uid;
    if ($("editAgentUid")) $("editAgentUid").value = uid;
  });

  $("loginForm")?.addEventListener("submit", async (e) => {
    e.preventDefault();
    const email = $("loginEmail").value.trim();
    const password = $("loginPassword").value;
    setFeedback("Signing in…", "info");
    try {
      await signInWithEmailAndPassword(auth, email, password);
      setFeedback("Signed in.", "ok");
    } catch {
      setFeedback("Invalid email or password.", "error");
    }
  });

  const doLogout = async () => {
    await signOut(auth);
    portalRole = null;
    setFeedback("Signed out.", "info");
  };
  $("logoutBtn")?.addEventListener("click", doLogout);
  $("logoutBtnAgent")?.addEventListener("click", doLogout);

  $("agentRefreshBtn")?.addEventListener("click", () => loadAgentDashboard());

  $("adminRefreshBtn")?.addEventListener("click", () => loadAdminAgents());

  $("adminAgentStatsBtn")?.addEventListener("click", () => loadAdminAgentStats());

  $("adminCreateForm")?.addEventListener("submit", async (e) => {
    e.preventDefault();
    setFeedback("Creating agent…", "info");
    try {
      const promoCodes = $("newPromoCodes")
        .value.split(/[\s,]+/)
        .map((s) => s.trim())
        .filter(Boolean);
      const fn = httpsCallable(functions, "commissionAdminCreateAgent");
      await fn({
        email: $("newAgentEmail").value.trim(),
        password: $("newAgentPassword").value,
        displayName: $("newAgentName").value.trim(),
        promoCodes,
        commissionPercent: parseFloat($("newAgentPercent").value) || 20,
      });
      setFeedback("Agent created. They can sign in here with that email and password.", "ok");
      $("adminCreateForm").reset();
      if ($("newAgentPercent")) $("newAgentPercent").value = "20";
      await loadAdminAgents();
    } catch (err) {
      setFeedback(err.message || String(err), "error");
    }
  });

  $("adminUpdateForm")?.addEventListener("submit", async (e) => {
    e.preventDefault();
    const agentUid = ($("editAgentUid")?.value || "").trim() || selectedAdminAgentUid();
    if (!agentUid) {
      setFeedback("Select an agent row or paste UID.", "error");
      return;
    }
    setFeedback("Saving…", "info");
    try {
      const payload = { agentUid };
      const pct = $("editPercent").value.trim();
      if (pct !== "") payload.commissionPercent = parseFloat(pct);
      const codesRaw = $("editPromoCodes").value.trim();
      if (codesRaw !== "") {
        payload.promoCodes = codesRaw.split(/[\s,]+/).map((s) => s.trim()).filter(Boolean);
      }
      const fn = httpsCallable(functions, "commissionAdminUpdateAgent");
      await fn(payload);
      setFeedback("Agent updated.", "ok");
      await loadAdminAgents();
    } catch (err) {
      setFeedback(err.message || String(err), "error");
    }
  });

  $("adminDeactivateBtn")?.addEventListener("click", async () => {
    const agentUid = ($("editAgentUid")?.value || "").trim() || selectedAdminAgentUid();
    if (!agentUid || !confirm("Deactivate this agent? They will no longer see the dashboard.")) return;
    try {
      const fn = httpsCallable(functions, "commissionAdminUpdateAgent");
      await fn({ agentUid, active: false });
      setFeedback("Agent deactivated.", "ok");
      await loadAdminAgents();
    } catch (err) {
      setFeedback(err.message || String(err), "error");
    }
  });

  $("adminDeleteAgentBtn")?.addEventListener("click", async () => {
    const agentUid = ($("editAgentUid")?.value || "").trim() || selectedAdminAgentUid();
    if (!agentUid) {
      setFeedback("Select an agent row or paste UID.", "error");
      return;
    }
    if (
      !confirm(
        "Permanently delete this agent? Their portal login (Firebase Auth) and commission_agents record will be removed. This cannot be undone."
      )
    ) {
      return;
    }
    setFeedback("Deleting agent…", "info");
    try {
      const fn = httpsCallable(functions, "commissionAdminDeleteAgent");
      const { data } = await fn({ agentUid });
      const warn = data?.authDeleteError ? ` Auth warning: ${data.authDeleteError}` : "";
      setFeedback(`Agent deleted.${warn}`, data?.authDeleteError ? "info" : "ok");
      if ($("editAgentUid")) $("editAgentUid").value = "";
      if ($("editPercent")) $("editPercent").value = "";
      if ($("editPromoCodes")) $("editPromoCodes").value = "";
      document.querySelectorAll("#adminAgentsTable tbody tr").forEach((r) => r.classList.remove("selected"));
      const dash = $("adminAgentDashboard");
      if (dash) dash.innerHTML = "";
      await loadAdminAgents();
    } catch (err) {
      setFeedback(err.message || String(err), "error");
    }
  });
});

onAuthStateChanged(auth, async (user) => {
  const boot = $("authBootCard");
  const loginCard = $("loginCard");
  const adminCard = $("adminCard");
  const agentCard = $("agentCard");
  const who = $("signedInAs");
  const whoAgent = $("signedInAsAgent");
  const topNav = $("adminTopNav");
  const label = user?.email || user?.uid || "";
  if (who) who.textContent = label;
  if (whoAgent) whoAgent.textContent = label;
  if (user) {
    if (boot) boot.hidden = false;
    loginCard.hidden = true;
    adminCard.hidden = true;
    agentCard.hidden = true;
    if (topNav) topNav.hidden = true;
    portalRole = await detectPortalRole();
    if (portalRole === "admin") {
      if (topNav) topNav.hidden = false;
      adminCard.hidden = false;
      agentCard.hidden = true;
      await loadAdminAgents();
    } else if (portalRole === "agent") {
      if (topNav) topNav.hidden = true;
      adminCard.hidden = true;
      agentCard.hidden = false;
      if ($("agentMonth") && !$("agentMonth").value) $("agentMonth").value = currentYearMonth();
      await loadAgentDashboard();
    } else {
      if (topNav) topNav.hidden = true;
      adminCard.hidden = true;
      agentCard.hidden = true;
      setFeedback("Not authorised.", "error");
      if (boot) boot.hidden = true;
      loginCard.hidden = false;
      await signOut(auth);
      portalRole = null;
      return;
    }
    if (boot) boot.hidden = true;
  } else {
    if (boot) boot.hidden = true;
    if (topNav) topNav.hidden = true;
    loginCard.hidden = false;
    adminCard.hidden = true;
    agentCard.hidden = true;
    if (who) who.textContent = "";
    if (whoAgent) whoAgent.textContent = "";
    portalRole = null;
  }
});
