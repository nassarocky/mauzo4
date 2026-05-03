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

function functionsHttpBase() {
  const pid = firebaseConfig.projectId || "hesabumauzo";
  return `https://us-central1-${pid}.cloudfunctions.net`;
}

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
    console.info("[support-reset] Functions emulator: 127.0.0.1:5001");
  } catch (_) {
    /* already connected */
  }
}

const $ = (id) => document.getElementById(id);

/** Always-visible banner (login card is hidden after sign-in). */
function setFeedback(msg, type) {
  const el = $("feedback");
  if (!el) return;
  el.textContent = msg || "";
  if (!msg) {
    el.className = "";
    return;
  }
  const t =
    type === "error" ? "error" : type === "ok" ? "ok" : "info";
  el.className = `show ${t}`;
}

const UNAUTHORIZED = "You are not authorized.";
const NOT_COMMISSION_ADMIN = "Not authorised.";

function customerPayloadField(raw) {
  const trimmed = raw.trim();
  if (!trimmed) return null;
  if (trimmed.includes("@")) {
    return { email: trimmed };
  }
  return { phone: trimmed };
}

function updateDetectHint() {
  const el = $("targetIdentifier");
  const hint = $("detectHint");
  if (!el || !hint) return;
  const raw = el.value.trim();
  if (!raw) {
    hint.textContent = "";
    return;
  }
  hint.textContent = raw.includes("@")
    ? "Detected: email"
    : "Detected: phone number";
}

/** Which tab is visible: 'pwd' | 'data' */
let activeTab = "pwd";

function setTab(tab) {
  activeTab = tab;
  const pwd = $("panelPwd");
  const data = $("panelData");
  const tabs = document.querySelectorAll(".tabs .tab");
  tabs.forEach((btn) => {
    const on = btn.dataset.tab === tab;
    btn.classList.toggle("active", on);
    btn.setAttribute("aria-selected", on ? "true" : "false");
  });
  if (pwd) pwd.hidden = tab !== "pwd";
  if (data) data.hidden = tab !== "data";
}

function syncCollectionFieldsUI() {
  const col = $("dataCollection")?.value || "gmanusers";
  const wrapUser = $("wrapUserImage");
  const wrapMaxBiz = $("wrapUserMaxBusiness");
  const wrapBiz = $("wrapBizExtra");
  const wrapExtras = $("wrapUserDataExtras");
  if (wrapUser) wrapUser.hidden = col !== "gmanusers";
  if (wrapMaxBiz) wrapMaxBiz.hidden = col !== "gmanusers";
  if (wrapBiz) wrapBiz.hidden = col !== "businesses";
  if (wrapExtras) wrapExtras.hidden = col !== "gmanusers";
}

let dataLoadedCollection = "";
let dataLoadedDocumentId = "";
let dataLoadedOwnerId = "";

function populateBusinessSelect(businesses) {
  const sel = $("dataBusinessSelect");
  const wrap = $("wrapBusinessPicker");
  if (!sel || !wrap) return;
  sel.innerHTML = '<option value="">— Choose —</option>';
  for (const b of businesses || []) {
    if (!b?.id) continue;
    const opt = document.createElement("option");
    opt.value = b.id;
    const nm = b.name && String(b.name).trim();
    opt.textContent = nm ? `${nm} (${b.id})` : b.id;
    sel.appendChild(opt);
  }
  wrap.hidden = (businesses || []).length === 0;
}

function setResolvedUidLine(uid) {
  const line = $("dataResolvedUidLine");
  const code = $("dataResolvedUid");
  if (code) code.textContent = uid || "";
  if (line) line.hidden = !uid;
}

function clearDataForm() {
  [
    "fieldEmail",
    "fieldName",
    "fieldPhone",
    "fieldMaxBusiness",
    "fieldImage",
    "fieldSubscriptionStatus",
    "fieldPaymentStart",
    "fieldPaymentLast",
    "fieldTin",
    "fieldLogo",
  ].forEach((id) => {
    const el = $(id);
    if (el) el.value = "";
  });
  dataLoadedCollection = "";
  dataLoadedDocumentId = "";
  dataLoadedOwnerId = "";
  const save = $("dataSaveBtn");
  if (save) save.disabled = true;
  const wrapBizAct = $("wrapBizAdminActions");
  if (wrapBizAct) wrapBizAct.hidden = true;
  populateBusinessSelect([]);
  setResolvedUidLine("");
  const lookup = $("dataUserLookup");
  if (lookup) lookup.value = "";
}

document.querySelector(".tabs")?.addEventListener("click", (e) => {
  const btn = e.target.closest("button.tab");
  if (!btn?.dataset?.tab) return;
  setTab(btn.dataset.tab);
});

$("dataCollection")?.addEventListener("change", () => {
  syncCollectionFieldsUI();
  clearDataForm();
});

onAuthStateChanged(auth, async (user) => {
  const boot = $("authBootCard");
  const loginCard = $("loginCard");
  const toolCard = $("toolCard");
  const staffEmail = $("staffEmail");
  if (user) {
    if (boot) boot.hidden = false;
    loginCard.hidden = true;
    toolCard.hidden = true;
    try {
      const ping = httpsCallable(functions, "commissionAdminPing");
      await ping({});
    } catch (e) {
      console.warn("[support-reset] commissionAdminPing failed:", e?.code || e?.message || e);
      const msg = (e?.message || "").toString();
      setFeedback(msg && msg.length < 220 ? msg : NOT_COMMISSION_ADMIN, "error");
      if (boot) boot.hidden = true;
      loginCard.hidden = false;
      await signOut(auth);
      return;
    }
    if (boot) boot.hidden = true;
    toolCard.hidden = false;
    staffEmail.textContent = user.email || user.uid;
    syncCollectionFieldsUI();
    setTab(activeTab);
    setFeedback("", "");
  } else {
    if (boot) boot.hidden = true;
    loginCard.hidden = false;
    toolCard.hidden = true;
    staffEmail.textContent = "";
    clearDataForm();
  }
});

$("loginForm").addEventListener("submit", async (e) => {
  e.preventDefault();
  const email = $("supportEmail").value.trim();
  const password = $("supportPassword").value;
  setFeedback("Signing in…", "info");
  try {
    await signInWithEmailAndPassword(auth, email, password);
    setFeedback("Signed in.", "ok");
  } catch {
    setFeedback("Invalid email or password.", "error");
  }
});

$("logoutBtn").addEventListener("click", async () => {
  await signOut(auth);
  setFeedback("Signed out.", "info");
});

const targetIdentifier = $("targetIdentifier");
if (targetIdentifier) {
  targetIdentifier.addEventListener("input", updateDetectHint);
}

$("resetForm").addEventListener("submit", async (e) => {
  e.preventDefault();
  const newPassword = $("newPassword").value;
  const confirm = $("confirmPassword").value;

  if (newPassword.length < 8) {
    setFeedback("Password must be at least 8 characters.", "error");
    return;
  }
  if (newPassword !== confirm) {
    setFeedback("Passwords do not match.", "error");
    return;
  }

  const raw = $("targetIdentifier").value.trim();
  const idPayload = customerPayloadField(raw);
  if (!idPayload) {
    setFeedback("Enter the customer's phone number or email.", "error");
    return;
  }

  const payload = { newPassword, ...idPayload };

  setFeedback("Updating password…", "info");
  $("submitBtn").disabled = true;

  try {
    const adminReset = httpsCallable(functions, "adminResetUserPassword");
    const result = await adminReset(payload);
    const data = result.data;
    const uid = data?.targetUid || "—";
    setFeedback(
      `Success — password was updated.\nUser UID: ${uid}\nTell the customer the new password by phone or in person (not by unsecured chat/email).`,
      "ok"
    );
    $("resetForm").reset();
    updateDetectHint();
  } catch {
    setFeedback(UNAUTHORIZED, "error");
  } finally {
    $("submitBtn").disabled = false;
  }
});

function firestoreTsToMs(ts) {
  if (!ts || typeof ts !== "object") return null;
  const s = ts.seconds ?? ts._seconds;
  if (typeof s !== "number") return null;
  const ns = ts.nanoseconds ?? ts._nanoseconds ?? 0;
  return s * 1000 + Math.floor(ns / 1e6);
}

function formatFirestoreTs(ts) {
  const ms = firestoreTsToMs(ts);
  return ms == null ? "—" : new Date(ms).toLocaleString();
}

function fillField(id, val) {
  const el = $(id);
  if (!el) return;
  if (val === undefined || val === null) el.value = "";
  else el.value = typeof val === "string" ? val : String(val);
}

function applyLoadedRecord(col, documentId, d) {
  fillField("fieldEmail", d.email);
  fillField("fieldName", d.name);
  fillField("fieldPhone", d.phone);
  fillField("fieldMaxBusiness", d.maxBusiness);
  fillField("fieldImage", d.image);
  fillField("fieldTin", d.tin);
  fillField("fieldLogo", d.logo);
  if (col === "businesses") {
    fillField("fieldSubscriptionStatus", d.subscriptionStatus != null ? String(d.subscriptionStatus) : "");
    fillField("fieldPaymentStart", formatFirestoreTs(d.paymentStart));
    fillField("fieldPaymentLast", formatFirestoreTs(d.paymentLast));
  } else {
    fillField("fieldSubscriptionStatus", "");
    fillField("fieldPaymentStart", "");
    fillField("fieldPaymentLast", "");
  }
  dataLoadedCollection = col;
  dataLoadedDocumentId = documentId;
  dataLoadedOwnerId = col === "businesses" ? String(d.ownerId || "").trim() : "";
  const wrapBizAct = $("wrapBizAdminActions");
  if (wrapBizAct) wrapBizAct.hidden = col !== "businesses";
  $("dataSaveBtn").disabled = false;
}

$("dataLoadBtn")?.addEventListener("click", async () => {
  const col = $("dataCollection").value;
  const documentId = $("dataDocId").value.trim();
  if (!documentId) {
    setFeedback("Enter a document ID.", "error");
    return;
  }
  setFeedback("Loading…", "info");
  $("dataLoadBtn").disabled = true;
  try {
    const fn = httpsCallable(functions, "adminSupportGetRecord");
    const { data } = await fn({ collection: col, documentId });
    const d = data?.data || {};
    applyLoadedRecord(col, documentId, d);
    if (col === "gmanusers" && Array.isArray(data?.businesses)) {
      populateBusinessSelect(data.businesses);
      setResolvedUidLine(documentId);
    } else {
      populateBusinessSelect([]);
      setResolvedUidLine("");
    }
    setFeedback(col === "businesses" ? "Loaded shop record." : "Loaded user profile.", "ok");
  } catch {
    setFeedback(UNAUTHORIZED + "\nOr document not found.", "error");
    clearDataForm();
  } finally {
    $("dataLoadBtn").disabled = false;
  }
});

$("dataLoadUserBtn")?.addEventListener("click", async () => {
  const raw = $("dataUserLookup")?.value.trim() || "";
  const idPayload = customerPayloadField(raw);
  if (!idPayload) {
    setFeedback("Enter the customer's phone number or email.", "error");
    return;
  }
  setFeedback("Loading user…", "info");
  $("dataLoadUserBtn").disabled = true;
  try {
    const fn = httpsCallable(functions, "adminSupportResolveUser");
    const { data } = await fn(idPayload);
    const uid = data?.uid;
    const d = data?.data || {};
    if (!uid) {
      setFeedback("Unexpected response from server.", "error");
      return;
    }
    const colSel = $("dataCollection");
    if (colSel) colSel.value = "gmanusers";
    syncCollectionFieldsUI();
    const docInput = $("dataDocId");
    if (docInput) docInput.value = uid;
    applyLoadedRecord("gmanusers", uid, d);
    populateBusinessSelect(data?.businesses);
    setResolvedUidLine(uid);
    setFeedback("Loaded user profile.", "ok");
  } catch {
    setFeedback(
      UNAUTHORIZED + "\nOr user / profile not found (check phone, email, or Auth).",
      "error"
    );
    clearDataForm();
    syncCollectionFieldsUI();
  } finally {
    $("dataLoadUserBtn").disabled = false;
  }
});

$("dataLoadBusinessBtn")?.addEventListener("click", async () => {
  const bid = $("dataBusinessSelect")?.value?.trim() || "";
  if (!bid) {
    setFeedback("Choose a business from the list.", "error");
    return;
  }
  setFeedback("Loading business…", "info");
  $("dataLoadBusinessBtn").disabled = true;
  try {
    const fn = httpsCallable(functions, "adminSupportGetRecord");
    const { data } = await fn({ collection: "businesses", documentId: bid });
    const d = data?.data || {};
    const colSel = $("dataCollection");
    if (colSel) colSel.value = "businesses";
    syncCollectionFieldsUI();
    const docInput = $("dataDocId");
    if (docInput) docInput.value = bid;
    applyLoadedRecord("businesses", bid, d);
    setFeedback("Loaded shop record.", "ok");
  } catch {
    setFeedback(UNAUTHORIZED + "\nOr business document not found.", "error");
  } finally {
    $("dataLoadBusinessBtn").disabled = false;
  }
});

$("dataSaveBtn")?.addEventListener("click", async () => {
  if (!dataLoadedCollection || !dataLoadedDocumentId) {
    setFeedback("Load a document first.", "error");
    return;
  }
  const col = dataLoadedCollection;
  const documentId = dataLoadedDocumentId;
  const patch = {};
  const e = $("fieldEmail")?.value.trim();
  const n = $("fieldName")?.value.trim();
  const p = $("fieldPhone")?.value.trim();
  if (e) patch.email = e;
  if (n) patch.name = n;
  if (p) patch.phone = p;
  if (col === "gmanusers") {
    const img = $("fieldImage")?.value.trim();
    if (img) patch.image = img;
    const mbEl = $("fieldMaxBusiness");
    if (mbEl) {
      let mb = typeof mbEl.valueAsNumber === "number" ? mbEl.valueAsNumber : NaN;
      if (Number.isNaN(mb)) {
        const s = String(mbEl.value ?? "").trim();
        if (s !== "") mb = parseInt(s, 10);
      }
      if (!Number.isNaN(mb) && mb >= 0 && mb <= 10000) {
        patch.maxBusiness = Math.trunc(mb);
      }
    }
  }
  if (col === "businesses") {
    const tin = $("fieldTin")?.value.trim();
    const logo = $("fieldLogo")?.value.trim();
    if (tin) patch.tin = tin;
    if (logo) patch.logo = logo;
  }
  if (Object.keys(patch).length === 0) {
    setFeedback("Fill at least one field to save.", "error");
    return;
  }
  setFeedback("Saving…", "info");
  $("dataSaveBtn").disabled = true;
  try {
    const fnUpdate = httpsCallable(functions, "adminSupportUpdateRecord");
    await fnUpdate({ collection: col, documentId, patch });
    const fnGet = httpsCallable(functions, "adminSupportGetRecord");
    const { data: fresh } = await fnGet({ collection: col, documentId });
    const d = fresh?.data || {};
    applyLoadedRecord(col, documentId, d);
    if (col === "gmanusers" && Array.isArray(fresh?.businesses)) {
      populateBusinessSelect(fresh.businesses);
      setResolvedUidLine(documentId);
    }
    setFeedback(`Saved: ${Object.keys(patch).join(", ")}`, "ok");
  } catch {
    setFeedback(UNAUTHORIZED, "error");
  } finally {
    $("dataSaveBtn").disabled = false;
  }
});

$("bizPaymentExtendBtn")?.addEventListener("click", async () => {
  if (dataLoadedCollection !== "businesses" || !dataLoadedDocumentId) {
    setFeedback("Load a business document first.", "error");
    return;
  }
  const email = ($("fieldEmail")?.value || "").trim();
  const days = parseInt(String($("paymentExtendDays")?.value || "").trim(), 10);
  if (!email) {
    setFeedback("Business email is empty; load the shop or enter an email.", "error");
    return;
  }
  if (!Number.isFinite(days) || days < 1) {
    setFeedback("Enter a valid number of days (1–3650).", "error");
    return;
  }
  if (
    !confirm(
      `Update payment via legacy endpoint for ALL businesses with email:\n${email}\n\nExtend by ${days} day(s)?`
    )
  ) {
    return;
  }
  const btn = $("bizPaymentExtendBtn");
  if (btn) btn.disabled = true;
  setFeedback("Updating payment…", "info");
  try {
    const qs = new URLSearchParams({ email, numberOfDays: String(days) });
    const res = await fetch(`${functionsHttpBase()}/paymentCallbackEmail2?${qs}`, { method: "GET" });
    let bodyText = "";
    try {
      bodyText = await res.text();
    } catch (_) {
      bodyText = "";
    }
    let parsed = null;
    try {
      parsed = JSON.parse(bodyText);
    } catch (_) {
      parsed = null;
    }
    if (!res.ok) {
      const errMsg = parsed?.error || bodyText || res.statusText;
      setFeedback(`Payment update failed: ${errMsg}`, "error");
      return;
    }
    const msg = parsed?.message || bodyText || "OK";
    setFeedback(typeof msg === "string" ? msg : JSON.stringify(msg), "ok");
  } catch (e) {
    setFeedback(e?.message || String(e), "error");
  } finally {
    if (btn) btn.disabled = false;
  }
});

$("bizDeleteBtn")?.addEventListener("click", async () => {
  if (dataLoadedCollection !== "businesses" || !dataLoadedDocumentId) {
    setFeedback("Load a business document first.", "error");
    return;
  }
  const ownerId = dataLoadedOwnerId;
  if (!ownerId) {
    setFeedback("Owner id is missing on this business document (ownerId). Cannot delete safely.", "error");
    return;
  }
  const businessId = dataLoadedDocumentId;
  const nm = ($("fieldName")?.value || "").trim() || businessId;
  if (
    !confirm(
      `Permanently delete business "${nm}" (${businessId})?\n\nThis removes subcollections and cannot be undone.`
    )
  ) {
    return;
  }
  const btn = $("bizDeleteBtn");
  if (btn) btn.disabled = true;
  setFeedback("Deleting business…", "info");
  try {
    const res = await fetch(`${functionsHttpBase()}/deleteBusiness`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ businessId, ownerId }),
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
    clearDataForm();
    syncCollectionFieldsUI();
  } catch (e) {
    setFeedback(e?.message || String(e), "error");
  } finally {
    if (btn) btn.disabled = false;
  }
});

syncCollectionFieldsUI();
