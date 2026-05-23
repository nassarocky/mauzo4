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

/** Matches Flutter [normalizePhoneToE164] (default TZ 255). */
function normalizePhoneToE164(input, defaultCountryCode = "255") {
  let digits = String(input || "").replace(/[^0-9]/g, "");
  if (digits.startsWith("0") && digits.length === 10) {
    digits = `${defaultCountryCode}${digits.slice(1)}`;
  }
  return `+${digits}`;
}

/** Same heuristic as Flutter [LoginScreen] (spaces only stripped for the digit-length test). */
function looksLikePhoneForLogin(credential) {
  const t = String(credential || "").trim();
  const digitsOnly = t.replace(/[^0-9]/g, "");
  const forPhoneTest = t.replace(/\s/g, "");
  return /^\+?[0-9]{9,15}$/.test(forPhoneTest) && digitsOnly.length > 0;
}

/**
 * Resolves the Firebase Auth email/username — mirrors Flutter login_screen.dart
 * (normalizePhoneToE164 then digits@hesabumauzo.app when it looks like a phone).
 */
function resolveLoginCredentialForAuth(credential) {
  const t = String(credential || "").trim();
  if (!t) return "";
  if (looksLikePhoneForLogin(t)) {
    const e164 = normalizePhoneToE164(t);
    const normalized = e164.replace(/[^0-9]/g, "");
    return `${normalized}@hesabumauzo.app`;
  }
  return t;
}

/**
 * Legacy agents created before server phone normalization matched Flutter:
 * Auth email was built from digits after stripping only + / spaces / hyphens (e.g. 0712…@… not 255712…@…).
 */
function legacyPhoneOnlyAuthEmailFromRaw(raw) {
  let s = String(raw ?? "")
    .trim()
    .replace(/[\s-]/g, "");
  if (!s) return "";
  s = s.replace(/^\+/, "");
  if (!/^[0-9]{8,20}$/.test(s)) return "";
  return `${s}@hesabumauzo.app`;
}

function syncCreateAgentFormMode() {
  const mode = document.querySelector('input[name="agentRegMode"]:checked')?.value || "email";
  const emailBlock = $("createAgentEmailBlock");
  const phoneBlock = $("createAgentPhoneBlock");
  const contactWrap = $("newAgentContactPhoneWrap");
  const em = $("newAgentEmail");
  const lp = $("newAgentLoginPhone");
  const cp = $("newAgentPhone");
  if (mode === "phone") {
    if (emailBlock) emailBlock.hidden = true;
    if (phoneBlock) phoneBlock.hidden = false;
    if (contactWrap) contactWrap.hidden = true;
    if (em) em.removeAttribute("required");
    if (lp) lp.setAttribute("required", "required");
    if (cp) cp.removeAttribute("required");
  } else {
    if (emailBlock) emailBlock.hidden = false;
    if (phoneBlock) phoneBlock.hidden = true;
    if (contactWrap) contactWrap.hidden = false;
    if (em) em.setAttribute("required", "required");
    if (lp) lp.removeAttribute("required");
    if (cp) cp.setAttribute("required", "required");
  }
}

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
/** Full agent list from commissionAdminListAgents (for search + row edit). */
let allAgents = [];

function adminAgentSearchQuery() {
  return ($("adminAgentSearch")?.value || "").trim().toLowerCase();
}

function agentMatchesSearch(a, q) {
  if (!q) return true;
  const email = (a.email || "").toLowerCase();
  const phone = String(a.phone || "")
    .toLowerCase()
    .replace(/\s/g, "");
  const codes = (a.promoCodes || []).join(" ").toLowerCase();
  const name = (a.displayName || "").toLowerCase();
  const qCompact = q.replace(/\s/g, "");
  if (email.includes(q)) return true;
  const emailLocal = (a.email || "").split("@")[0] || "";
  const qDigits = q.replace(/\D/g, "");
  if (emailLocal && /^[0-9]+$/.test(emailLocal) && qDigits && emailLocal.includes(qDigits)) return true;
  if (name.includes(q)) return true;
  if (phone && (phone.includes(qCompact) || qCompact.includes(phone.replace(/^\+/, "")))) return true;
  for (const c of a.promoCodes || []) {
    if (String(c).toLowerCase().includes(q)) return true;
  }
  if (codes.includes(q)) return true;
  return false;
}

function formatAgentPromoCodesCell(a) {
  const counts = a.promoCodeCounts && typeof a.promoCodeCounts === "object" ? a.promoCodeCounts : {};
  return (a.promoCodes || [])
    .map((c) => {
      const key = String(c).trim().toUpperCase();
      const n = counts[c] ?? counts[key] ?? 0;
      return `${esc(c)} (${Number(n).toLocaleString()})`;
    })
    .join(", ");
}

function renderAdminAgentsTableBody() {
  const tbody = $("adminAgentsBody");
  if (!tbody) return;
  if (allAgents.length === 0) {
    tbody.innerHTML = '<tr><td colspan="7">No agents yet.</td></tr>';
    return;
  }
  const q = adminAgentSearchQuery();
  const agents = allAgents.filter((a) => agentMatchesSearch(a, q));
  const keepUid = ($("editAgentUid")?.value || "").trim();
  tbody.innerHTML = agents
    .map(
      (a) =>
        `<tr data-uid="${esc(a.uid)}">
            <td>${esc(a.displayName || "—")}</td>
            <td>${esc(a.email)}</td>
            <td>${esc(a.phone || "—")}</td>
            <td>${formatAgentPromoCodesCell(a) || "—"}</td>
            <td>${Number(a.registrationCount || 0).toLocaleString()}</td>
            <td>${a.commissionPercent != null ? esc(a.commissionPercent) : "20"}%</td>
            <td>${a.active === false ? "inactive" : "active"}</td>
          </tr>`
    )
    .join("") || '<tr><td colspan="7">No agents match this search.</td></tr>';
  if (keepUid) {
    const row = Array.from(tbody.querySelectorAll("tr[data-uid]")).find((r) => r.dataset.uid === keepUid);
    if (row) {
      document.querySelectorAll("#adminAgentsTable tbody tr").forEach((r) => r.classList.remove("selected"));
      row.classList.add("selected");
      updateSelectedAgentSummaryFromRow(row);
    } else {
      document.querySelectorAll("#adminAgentsTable tbody tr").forEach((r) => r.classList.remove("selected"));
    }
  }
}

function fillEditAgentForm(agent) {
  const ph = $("editPhone");
  const ban = $("editBankAccountName");
  const bnum = $("editBankAccountNumber");
  const btype = $("editBankType");
  if (!ph) return;
  if (!agent) {
    ph.value = "";
    if (ban) ban.value = "";
    if (bnum) bnum.value = "";
    if (btype) btype.value = "";
    return;
  }
  ph.value = agent.phone != null ? String(agent.phone) : "";
  if (ban) ban.value = agent.bankAccountName != null ? String(agent.bankAccountName) : "";
  if (bnum) bnum.value = agent.bankAccountNumber != null ? String(agent.bankAccountNumber) : "";
  if (btype) {
    const v = agent.bankType != null ? String(agent.bankType).trim() : "";
    btype.querySelectorAll("option[data-legacy-extra]").forEach((o) => o.remove());
    if (v && ![...btype.options].some((o) => o.value === v)) {
      const o = document.createElement("option");
      o.value = v;
      o.textContent = `${v} (legacy)`;
      o.setAttribute("data-legacy-extra", "1");
      btype.appendChild(o);
    }
    btype.value = v;
  }
}

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

function businessDisplayName(entry) {
  const nm = entry && entry.businessName != null ? String(entry.businessName).trim() : "";
  if (nm) return nm;
  const id = entry && entry.businessId != null ? String(entry.businessId).trim() : "";
  return id || "—";
}

function renderCommissionStatsDashboard(box, data, agentHeader) {
  if (!box) return;
  const rows = (data.referrals || [])
    .map(
      (r) =>
        `<tr><td>${esc(businessDisplayName(r))}</td><td>${esc(
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
        )} · ${esc(agentHeader.phone || "—")}${agentHeader.active === false ? " · <em>inactive</em>" : ""}</p>`
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
        <thead><tr><th>Business</th><th>Promo</th><th>Subscription</th><th>Last payment start</th></tr></thead>
        <tbody>${rows || '<tr><td colspan="4">No shops with this promo yet.</td></tr>'}</tbody>
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
                  `<tr><td>${esc(businessDisplayName(e))}</td><td>${esc(
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

const SELECT_AGENT_HINT = "Select a row in the Agents table above.";

function updateSelectedAgentSummaryFromRow(tr) {
  const sum = $("selectedAgentSummary");
  if (!sum) return;
  if (!tr) {
    sum.textContent = SELECT_AGENT_HINT;
    fillEditAgentForm(null);
    return;
  }
  const cells = tr.querySelectorAll("td");
  const name = cells[0]?.textContent?.trim() || "—";
  const email = cells[1]?.textContent?.trim() || "—";
  const phone = cells[2]?.textContent?.trim() || "—";
  sum.textContent = `${name} · ${email} · ${phone}`;
  const uid = tr.dataset.uid;
  const agent = allAgents.find((a) => a.uid === uid);
  fillEditAgentForm(agent || null);
}

async function loadAdminAgents() {
  setFeedback("Loading agents…", "info");
  try {
    const fn = httpsCallable(functions, "commissionAdminListAgents");
    const { data } = await fn({});
    allAgents = data.agents || [];
    const tbody = $("adminAgentsBody");
    if (tbody) {
      renderAdminAgentsTableBody();
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
    setFeedback("Select an agent in the table below before loading stats.", "error");
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
      phone: data.agentPhone,
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
    updateSelectedAgentSummaryFromRow(tr);
  });

  $("loginForm")?.addEventListener("submit", async (e) => {
    e.preventDefault();
    const raw = ($("loginCredential")?.value || "").trim();
    const password = $("loginPassword").value;
    if (!raw) {
      setFeedback("Email or phone cannot be empty.", "error");
      return;
    }
    if (!password) {
      setFeedback("Password cannot be empty.", "error");
      return;
    }
    let email = resolveLoginCredentialForAuth(raw);
    setFeedback("Signing in…", "info");
    try {
      await signInWithEmailAndPassword(auth, email, password);
      setFeedback("Signed in.", "ok");
    } catch {
      let legacy = "";
      if (looksLikePhoneForLogin(raw)) {
        const leg = legacyPhoneOnlyAuthEmailFromRaw(raw);
        if (leg && leg !== email) legacy = leg;
      }
      if (legacy) {
        try {
          await signInWithEmailAndPassword(auth, legacy, password);
          setFeedback("Signed in.", "ok");
          return;
        } catch {
          /* fall through */
        }
      }
      setFeedback("Invalid credentials.", "error");
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

  $("adminRefreshBtn")?.addEventListener("click", () => {
    document.querySelectorAll("#adminAgentsTable tbody tr").forEach((r) => r.classList.remove("selected"));
    if ($("editAgentUid")) $("editAgentUid").value = "";
    updateSelectedAgentSummaryFromRow(null);
    if ($("adminAgentSearch")) $("adminAgentSearch").value = "";
    loadAdminAgents();
  });

  $("adminAgentSearch")?.addEventListener("input", () => {
    renderAdminAgentsTableBody();
  });

  $("adminAgentStatsBtn")?.addEventListener("click", () => loadAdminAgentStats());

  $("adminCreateForm")?.addEventListener("submit", async (e) => {
    e.preventDefault();
    const mode = document.querySelector('input[name="agentRegMode"]:checked')?.value || "email";
    setFeedback("Creating agent…", "info");
    try {
      const promoCodes = $("newPromoCodes")
        .value.split(/[\s,]+/)
        .map((s) => s.trim())
        .filter(Boolean);
      const payload = {
        registrationMode: mode,
        password: $("newAgentPassword").value,
        displayName: $("newAgentName").value.trim(),
        bankAccountName: $("newBankAccountName").value.trim(),
        bankAccountNumber: $("newBankAccountNumber").value.trim(),
        bankType: $("newBankType").value.trim(),
        promoCodes,
        commissionPercent: parseFloat($("newAgentPercent").value) || 20,
      };
      if (mode === "email") {
        const em = $("newAgentEmail").value.trim();
        const ph = $("newAgentPhone").value.trim();
        if (!em) {
          setFeedback("Agent email is required.", "error");
          return;
        }
        if (!ph) {
          setFeedback("Contact phone is required.", "error");
          return;
        }
        payload.email = em;
        payload.phone = ph;
      } else {
        const lp = ($("newAgentLoginPhone")?.value || "").trim();
        if (!lp) {
          setFeedback("Agent phone (login) is required.", "error");
          return;
        }
        payload.loginPhone = lp;
      }
      const fn = httpsCallable(functions, "commissionAdminCreateAgent");
      await fn(payload);
      setFeedback(
        mode === "phone"
          ? "Agent created. They sign in with Phone + password (same as the app; Auth email is digits@hesabumauzo.app)."
          : "Agent created. They can sign in with email and password.",
        "ok"
      );
      $("adminCreateForm").reset();
      const emailRadio = document.querySelector('input[name="agentRegMode"][value="email"]');
      if (emailRadio) emailRadio.checked = true;
      syncCreateAgentFormMode();
      if ($("newAgentPercent")) $("newAgentPercent").value = "20";
      if ($("newBankType")) $("newBankType").value = "";
      await loadAdminAgents();
    } catch (err) {
      setFeedback(err.message || String(err), "error");
    }
  });

  $("adminUpdateForm")?.addEventListener("submit", async (e) => {
    e.preventDefault();
    const agentUid = ($("editAgentUid")?.value || "").trim() || selectedAdminAgentUid();
    if (!agentUid) {
      setFeedback("Select an agent in the table below.", "error");
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
      const phoneRaw = ($("editPhone")?.value || "").trim();
      if (!phoneRaw) {
        setFeedback("Agent phone is required.", "error");
        return;
      }
      payload.phone = phoneRaw;
      payload.bankAccountName = ($("editBankAccountName")?.value || "").trim();
      payload.bankAccountNumber = ($("editBankAccountNumber")?.value || "").trim();
      payload.bankType = ($("editBankType")?.value || "").trim();
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
      if ($("editAgentUid")) $("editAgentUid").value = "";
      updateSelectedAgentSummaryFromRow(null);
      document.querySelectorAll("#adminAgentsTable tbody tr").forEach((r) => r.classList.remove("selected"));
      await loadAdminAgents();
    } catch (err) {
      setFeedback(err.message || String(err), "error");
    }
  });

  $("adminDeleteAgentBtn")?.addEventListener("click", async () => {
    const agentUid = ($("editAgentUid")?.value || "").trim() || selectedAdminAgentUid();
    if (!agentUid) {
      setFeedback("Select an agent in the table below.", "error");
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
      updateSelectedAgentSummaryFromRow(null);
      if ($("editPercent")) $("editPercent").value = "";
      if ($("editPromoCodes")) $("editPromoCodes").value = "";
      if ($("editPhone")) $("editPhone").value = "";
      if ($("editBankAccountName")) $("editBankAccountName").value = "";
      if ($("editBankAccountNumber")) $("editBankAccountNumber").value = "";
      if ($("editBankType")) $("editBankType").value = "";
      document.querySelectorAll("#adminAgentsTable tbody tr").forEach((r) => r.classList.remove("selected"));
      const dash = $("adminAgentDashboard");
      if (dash) dash.innerHTML = "";
      await loadAdminAgents();
    } catch (err) {
      setFeedback(err.message || String(err), "error");
    }
  });

  document.querySelectorAll('input[name="agentRegMode"]').forEach((r) => {
    r.addEventListener("change", syncCreateAgentFormMode);
  });
  syncCreateAgentFormMode();
});

onAuthStateChanged(auth, async (user) => {
  const boot = $("authBootCard");
  const loginCard = $("loginCard");
  const adminCard = $("adminCard");
  const agentCard = $("agentCard");
  const who = $("signedInAs");
  const whoAgent = $("signedInAsAgent");
  const topNav = $("adminTopNav");
  const label = user?.email || "Signed in";
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
