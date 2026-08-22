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
    console.info("[admin-hub/sms] Functions emulator: 127.0.0.1:5001");
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

function formatTs(ts) {
  if (!ts || typeof ts._seconds !== "number") return "—";
  return new Date(ts._seconds * 1000).toLocaleString();
}

function formatMoney(n) {
  const v = Number(n) || 0;
  return `TZS ${v.toLocaleString()}`;
}

function emptyTable(message) {
  return `<p style="color:var(--muted);margin:0">${message}</p>`;
}

function renderPurchases(list) {
  const el = $("purchaseTable");
  if (!el) return;
  if (!list.length) {
    el.innerHTML = emptyTable("No recorded purchases yet. New paid packs and admin grants will appear here.");
    return;
  }
  const rows = list.map((p) => `
    <tr>
      <td>${formatTs(p.createdAt)}</td>
      <td>${p.source === "admin_grant" ? "Grant" : "Purchase"}</td>
      <td>${p.credits}</td>
      <td>${p.amountTzs ? formatMoney(p.amountTzs) : "—"}</td>
      <td>${p.packId || "—"}</td>
      <td style="font-family:monospace;font-size:0.75rem">${p.businessId || "—"}</td>
    </tr>
  `).join("");
  el.innerHTML = `
    <table>
      <thead>
        <tr>
          <th>When</th>
          <th>Type</th>
          <th>SMS</th>
          <th>Paid</th>
          <th>Pack</th>
          <th>Business</th>
        </tr>
      </thead>
      <tbody>${rows}</tbody>
    </table>
  `;
}

function renderShops(list) {
  const el = $("shopTable");
  if (!el) return;
  if (!list.length) {
    el.innerHTML = emptyTable("No shops currently hold or have used SMS credits.");
    return;
  }
  const rows = list.map((b) => `
    <tr>
      <td>${b.name || "(no name)"}</td>
      <td>${b.email || "—"}</td>
      <td>${b.smsCredits ?? 0}</td>
      <td>${b.smsCreditsUsed ?? 0}</td>
      <td>${b.smsCreditsTotalPurchased ?? 0}</td>
    </tr>
  `).join("");
  el.innerHTML = `
    <table>
      <thead>
        <tr>
          <th>Shop</th>
          <th>Email</th>
          <th>Remaining</th>
          <th>Used</th>
          <th>Purchased</th>
        </tr>
      </thead>
      <tbody>${rows}</tbody>
    </table>
  `;
}

async function loadOverview() {
  setFeedback("Loading SMS overview…", "info");
  if ($("reloadBtn")) $("reloadBtn").disabled = true;
  try {
    const fn = httpsCallable(functions, "adminGetSmsOverview");
    const res = await fn({});
    const data = res.data || {};
    const gateway = data.gateway || {};
    const shops = data.shops || {};
    const revenue = data.revenue || {};

    $("gatewayRemaining").textContent =
      gateway.success && gateway.remaining != null ? String(gateway.remaining) : "—";
    $("gatewayHint").textContent = gateway.success
      ? "SMS left on the Mobishastra account you top up manually."
      : (gateway.error || "Could not read Mobishastra balance.");

    $("shopsRemaining").textContent = String(shops.remaining ?? 0);
    $("shopsHint").textContent =
      `Used ${shops.used ?? 0} · purchased ${shops.purchased ?? 0} · ${shops.count ?? 0} shops scanned.`;

    $("revenueTzs").textContent = formatMoney(revenue.tzs);
    $("revenueHint").textContent =
      `${revenue.purchaseCount ?? 0} paid pack(s), ${revenue.creditsSold ?? 0} SMS sold. Grants: ${revenue.creditsGranted ?? 0}. Older sales before this page may be missing.`;

    renderPurchases(Array.isArray(data.purchases) ? data.purchases : []);
    renderShops(Array.isArray(data.topShops) ? data.topShops : []);
    setFeedback("SMS overview loaded.", "ok");
  } catch (e) {
    console.error(e);
    setFeedback((e?.message || String(e)).replace(/^Firebase:\s*/i, ""), "error");
  } finally {
    if ($("reloadBtn")) $("reloadBtn").disabled = false;
  }
}

onAuthStateChanged(auth, async (user) => {
  const boot = $("authBootCard");
  const loginCard = $("loginCard");
  const mainCard = $("mainCard");
  if (user) {
    if (boot) boot.hidden = false;
    loginCard.hidden = true;
    mainCard.hidden = true;
    try {
      const ping = httpsCallable(functions, "commissionAdminPing");
      await ping({});
    } catch (e) {
      setFeedback(e?.message || "Not authorised.", "error");
      if (boot) boot.hidden = true;
      loginCard.hidden = false;
      await signOut(auth);
      return;
    }
    if (boot) boot.hidden = true;
    mainCard.hidden = false;
    if ($("staffEmail")) $("staffEmail").textContent = user.email || user.uid;
    setFeedback("", "");
    await loadOverview();
  } else {
    if (boot) boot.hidden = true;
    loginCard.hidden = false;
    mainCard.hidden = true;
  }
});

$("loginForm")?.addEventListener("submit", async (e) => {
  e.preventDefault();
  setFeedback("Signing in…", "info");
  try {
    await signInWithEmailAndPassword(
      auth,
      $("hubEmail").value.trim(),
      $("hubPassword").value
    );
  } catch {
    setFeedback("Invalid email or password.", "error");
  }
});

$("logoutBtn")?.addEventListener("click", async () => {
  await signOut(auth);
  setFeedback("Signed out.", "info");
});

$("reloadBtn")?.addEventListener("click", () => loadOverview());
