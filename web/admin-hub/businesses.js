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
    console.info("[admin-hub/businesses] Functions emulator: 127.0.0.1:5001");
  } catch (_) {
    /* already connected */
  }
}

function functionsHttpBase() {
  const pid = firebaseConfig.projectId || "hesabumauzo";
  return `https://us-central1-${pid}.cloudfunctions.net`;
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
  if (!ts || typeof ts._seconds !== "number") return "Unknown";
  return new Date(ts._seconds * 1000).toLocaleString();
}

function formatDateOnly(ts) {
  if (!ts || typeof ts._seconds !== "number") return "Unknown";
  return new Date(ts._seconds * 1000).toLocaleDateString();
}

function statusBadgeClass(status) {
  if (status === "subscription_ok") return "ok";
  if (status === "subscription_ended") return "ended";
  if (status === "subscription_ontrial") return "trial";
  return "";
}

/** Cursor stack: index 0 = first page (null cursor). */
let cursorStack = [null];
let pageIndex = 0;
let hasMore = false;
let loading = false;

function currentFilters() {
  return {
    pageSize: parseInt($("pageSize")?.value || "20", 10) || 20,
    sortBy: ($("sortBy")?.value || "date").trim(),
    subscriptionStatus: ($("subscriptionStatus")?.value || "").trim(),
    dateFrom: ($("dateFrom")?.value || "").trim(),
    dateTo: ($("dateTo")?.value || "").trim(),
    email: ($("emailExact")?.value || "").trim(),
    name: ($("nameExact")?.value || "").trim(),
  };
}

function syncStatusSortHint() {
  const status = ($("subscriptionStatus")?.value || "").trim();
  const sortEl = $("sortBy");
  if (!sortEl) return;
  if (status === "subscription_ok") {
    sortEl.value = "paymentStart";
  }
}

function renderBusinesses(list) {
  const grid = $("bizGrid");
  if (!grid) return;
  grid.innerHTML = "";
  if (!list.length) {
    grid.innerHTML = `<p style="color:var(--muted);margin:0">No businesses on this page.</p>`;
    return;
  }
  for (const b of list) {
    const card = document.createElement("article");
    card.className = "biz";
    const st = b.subscriptionStatus || "";
    card.innerHTML = `
      <h2></h2>
      <p><span class="k">Email:</span> <span class="email"></span></p>
      <p><span class="k">Phone:</span> <span class="phone"></span></p>
      <p><span class="k">Id:</span> <span class="id"></span></p>
      <p><span class="k">Owner:</span> <span class="owner"></span></p>
      <p><span class="k">Hesabu ya mwisho:</span> <span class="reset"></span></p>
      <p><span class="k">Allow debt:</span> <span class="debt"></span></p>
      <p><span class="k">Registered:</span> <span class="reg"></span></p>
      <p><span class="k">Payment start:</span> <span class="pstart"></span></p>
      <p><span class="k">Payment last:</span> <span class="plast"></span></p>
      <p><span class="k">SMS remaining:</span> <span class="sms-left"></span></p>
      <p><span class="k">SMS used / purchased:</span> <span class="sms-usage"></span></p>
      <span class="badge ${statusBadgeClass(st)}"></span>
      <div class="biz-actions">
        <button type="button" class="ghost tiny pay-btn">Update payment</button>
        <button type="button" class="ghost tiny sms-btn">Grant SMS</button>
        <button type="button" class="danger tiny del-btn">Delete</button>
        <a class="ghost tiny" style="display:inline-block;text-decoration:none;padding:6px 10px;border:1px solid var(--border);border-radius:8px;color:var(--muted);font-weight:600;font-size:0.8rem"
           href="/support-reset/">Open in Support</a>
      </div>
    `;
    card.querySelector("h2").textContent = b.name || "(no name)";
    card.querySelector(".email").textContent = b.email || "—";
    card.querySelector(".phone").textContent = b.phone || "—";
    card.querySelector(".id").textContent = b.id || "—";
    card.querySelector(".owner").textContent = b.ownerId || "—";
    card.querySelector(".reset").textContent = formatTs(b.reset_time);
    card.querySelector(".debt").textContent = String(b.debtEnabled ?? "—");
    card.querySelector(".reg").textContent = formatDateOnly(b.date);
    card.querySelector(".pstart").textContent = formatTs(b.paymentStart);
    card.querySelector(".plast").textContent = formatTs(b.paymentLast);
    card.querySelector(".sms-left").textContent = String(b.smsCredits ?? 0);
    card.querySelector(".sms-usage").textContent =
      `${b.smsCreditsUsed ?? 0} / ${b.smsCreditsTotalPurchased ?? 0}`;
    card.querySelector(".badge").textContent = st || "no status";
    card.querySelector(".pay-btn")?.addEventListener("click", () => openPaymentUpdate(b));
    card.querySelector(".sms-btn")?.addEventListener("click", () => grantSmsCredits(b));
    card.querySelector(".del-btn")?.addEventListener("click", () => confirmDelete(b));
    grid.appendChild(card);
  }
}

function updatePager() {
  if ($("pageMeta")) $("pageMeta").textContent = `Page ${pageIndex + 1}`;
  if ($("prevBtn")) $("prevBtn").disabled = loading || pageIndex <= 0;
  if ($("nextBtn")) $("nextBtn").disabled = loading || !hasMore;
  if ($("loadBtn")) $("loadBtn").disabled = loading;
}

async function loadPage({ reset } = { reset: false }) {
  if (loading) return;
  loading = true;
  updatePager();
  if (reset) {
    cursorStack = [null];
    pageIndex = 0;
  }
  const filters = currentFilters();
  const cursor = cursorStack[pageIndex] || null;
  setFeedback("Loading businesses…", "info");
  try {
    const listFn = httpsCallable(functions, "adminListBusinesses");
    const payload = {
      pageSize: filters.pageSize,
      sortBy: filters.sortBy,
      subscriptionStatus: filters.subscriptionStatus || undefined,
      dateFrom: filters.dateFrom || undefined,
      dateTo: filters.dateTo || undefined,
      email: filters.email || undefined,
      name: filters.name || undefined,
      cursor: cursor || undefined,
    };
    const res = await listFn(payload);
    const data = res.data || {};
    const businesses = Array.isArray(data.businesses) ? data.businesses : [];
    hasMore = Boolean(data.hasMore);
    if (hasMore && data.nextCursor) {
      cursorStack[pageIndex + 1] = data.nextCursor;
    } else {
      cursorStack = cursorStack.slice(0, pageIndex + 1);
    }
    renderBusinesses(businesses);
    if ($("sortMeta")) {
      $("sortMeta").textContent = `Sorted by ${data.sortBy || filters.sortBy} (newest first) · ${businesses.length} on page`;
    }
    setFeedback(
      businesses.length
        ? `Loaded ${businesses.length} business(es).`
        : "No businesses matched these filters.",
      businesses.length ? "ok" : "info"
    );
  } catch (e) {
    console.error(e);
    const msg = e?.message || String(e);
    setFeedback(msg.replace(/^Firebase:\s*/i, ""), "error");
    renderBusinesses([]);
    hasMore = false;
  } finally {
    loading = false;
    updatePager();
  }
}

async function openPaymentUpdate(b) {
  const email = (b.email || "").trim();
  if (!email) {
    setFeedback("This business has no email for payment update.", "error");
    return;
  }
  const raw = prompt(`Enter number of days to extend payment for ${email}:`);
  if (raw == null) return;
  const days = parseInt(String(raw).trim(), 10);
  if (!Number.isFinite(days) || days < 1) {
    setFeedback("Enter a valid number of days.", "error");
    return;
  }
  setFeedback("Updating payment…", "info");
  try {
    const qs = new URLSearchParams({ email, numberOfDays: String(days) });
    const res = await fetch(`${functionsHttpBase()}/paymentCallbackEmail2?${qs}`, {
      method: "GET",
    });
    const bodyText = await res.text();
    if (!res.ok) {
      setFeedback(`Payment update failed: ${bodyText || res.statusText}`, "error");
      return;
    }
    setFeedback(bodyText || "Payment updated.", "ok");
    await loadPage({ reset: false });
  } catch (e) {
    setFeedback(e?.message || String(e), "error");
  }
}

async function grantSmsCredits(b) {
  const remaining = b.smsCredits ?? 0;
  const used = b.smsCreditsUsed ?? 0;
  const purchased = b.smsCreditsTotalPurchased ?? 0;
  const raw = prompt(
    `Grant SMS to "${b.name || b.id}"\nRemaining: ${remaining}\nUsed: ${used}\nPurchased: ${purchased}\n\nEnter number of SMS to add:`
  );
  if (raw == null) return;
  const credits = parseInt(String(raw).trim(), 10);
  if (!Number.isFinite(credits) || credits < 1 || credits > 100000) {
    setFeedback("Enter a number of SMS between 1 and 100000.", "error");
    return;
  }
  setFeedback("Granting SMS credits…", "info");
  try {
    const grantFn = httpsCallable(functions, "grantSmsCredits");
    const res = await grantFn({
      businessId: b.id,
      credits,
      packId: "admin_grant",
      note: "admin hub",
    });
    const granted = res.data?.credits ?? credits;
    setFeedback(`Added ${granted} SMS. Remaining will refresh shortly.`, "ok");
    await loadPage({ reset: false });
  } catch (e) {
    setFeedback(e?.message || String(e), "error");
  }
}

async function confirmDelete(b) {
  const ownerId = b.ownerId || "";
  if (!ownerId) {
    setFeedback("Missing ownerId — cannot delete safely. Use Support tools.", "error");
    return;
  }
  if (
    !confirm(
      `Delete business "${b.name || b.id}"?\n\nThis cannot be undone.`
    )
  ) {
    return;
  }
  setFeedback("Deleting business…", "info");
  try {
    const res = await fetch(`${functionsHttpBase()}/deleteBusiness`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ businessId: b.id, ownerId }),
    });
    let data = null;
    try {
      data = await res.json();
    } catch (_) {
      data = null;
    }
    if (!res.ok) {
      setFeedback(data?.error || data?.message || `HTTP ${res.status}`, "error");
      return;
    }
    setFeedback(data?.message || "Business deleted.", "ok");
    await loadPage({ reset: false });
  } catch (e) {
    setFeedback(e?.message || String(e), "error");
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
    await loadPage({ reset: true });
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

$("loadBtn")?.addEventListener("click", () => loadPage({ reset: true }));
$("resetFiltersBtn")?.addEventListener("click", () => {
  if ($("sortBy")) $("sortBy").value = "date";
  if ($("subscriptionStatus")) $("subscriptionStatus").value = "";
  if ($("dateFrom")) $("dateFrom").value = "";
  if ($("dateTo")) $("dateTo").value = "";
  if ($("emailExact")) $("emailExact").value = "";
  if ($("nameExact")) $("nameExact").value = "";
  if ($("pageSize")) $("pageSize").value = "20";
  loadPage({ reset: true });
});

$("subscriptionStatus")?.addEventListener("change", syncStatusSortHint);

$("nextBtn")?.addEventListener("click", async () => {
  if (!hasMore || loading) return;
  pageIndex += 1;
  await loadPage({ reset: false });
});

$("prevBtn")?.addEventListener("click", async () => {
  if (pageIndex <= 0 || loading) return;
  pageIndex -= 1;
  await loadPage({ reset: false });
});
