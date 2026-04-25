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
    console.info("[admin-hub] Functions emulator: 127.0.0.1:5001");
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

function feedbackForPingFailure(err) {
  const code = err?.code || "";
  const msg = (err?.message || "").toString();
  if (code === "functions/not-found" || /NOT_FOUND|not found/i.test(msg)) {
    return "This site needs an updated Cloud Functions deploy (commissionAdminPing). Run: firebase deploy --only functions";
  }
  if (msg && msg.length < 200) return msg;
  return "Not authorised.";
}

onAuthStateChanged(auth, async (user) => {
  const boot = $("authBootCard");
  const loginCard = $("loginCard");
  const hubCard = $("hubCard");
  const staff = $("staffEmail");
  if (user) {
    if (boot) boot.hidden = false;
    loginCard.hidden = true;
    hubCard.hidden = true;
    try {
      const ping = httpsCallable(functions, "commissionAdminPing");
      await ping({});
    } catch (e) {
      console.warn("[admin-hub] commissionAdminPing failed:", e?.code || e?.message || e);
      setFeedback(feedbackForPingFailure(e), "error");
      if (boot) boot.hidden = true;
      loginCard.hidden = false;
      await signOut(auth);
      return;
    }
    if (boot) boot.hidden = true;
    hubCard.hidden = false;
    if (staff) staff.textContent = user.email || user.uid;
    setFeedback("", "");
  } else {
    if (boot) boot.hidden = true;
    loginCard.hidden = false;
    hubCard.hidden = true;
    if (staff) staff.textContent = "";
  }
});

$("loginForm")?.addEventListener("submit", async (e) => {
  e.preventDefault();
  const email = $("hubEmail").value.trim();
  const password = $("hubPassword").value;
  setFeedback("Signing in…", "info");
  try {
    await signInWithEmailAndPassword(auth, email, password);
    setFeedback("Signed in.", "ok");
  } catch {
    setFeedback("Invalid email or password.", "error");
  }
});

$("logoutBtn")?.addEventListener("click", async () => {
  await signOut(auth);
  setFeedback("Signed out.", "info");
});
