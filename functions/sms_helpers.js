/**
 * Pure helpers for debt-reminder SMS (Mobishastra).
 * Kept free of Firebase so Node's built-in test runner can cover them.
 */

const DEFAULT_SMS_PACKS = [
  { id: "sms_50", credits: 50, price: 3000, label: "SMS 50" },
  { id: "sms_100", credits: 100, price: 5000, label: "SMS 100" },
  { id: "sms_500", credits: 500, price: 20000, label: "SMS 500" },
  { id: "sms_1000", credits: 1000, price: 35000, label: "SMS 1000" },
];

const GSM_BASIC =
  "@£$¥èéùìòÇ\nØø\rÅåΔ_ΦΓΛΩΠΨΣΘΞÆæßÉ !\"#¤%&'()*+,-./0123456789:;<=>?" +
  "¡ABCDEFGHIJKLMNOPQRSTUVWXYZÄÖÑÜ§¿abcdefghijklmnopqrstuvwxyzäöñüà";

const MOBISHASTRA_SEND_URL = "https://mshastra.com/sendurl.aspx";

function normalizeSmsPhone(raw, defaultCountry = "255") {
  const digits = String(raw || "").replace(/\D/g, "");
  if (!digits) return "";
  if (digits.startsWith("0") && digits.length === 10) {
    return defaultCountry + digits.slice(1);
  }
  if (digits.length === 9 && !digits.startsWith(defaultCountry)) {
    return defaultCountry + digits;
  }
  return digits;
}

function isGsmText(text) {
  const s = String(text || "");
  for (const ch of s) {
    if (!GSM_BASIC.includes(ch)) return false;
  }
  return true;
}

function countSmsSegments(text) {
  const msg = String(text || "");
  if (!msg) return 0;
  const gsm = isGsmText(msg);
  const singleLimit = gsm ? 160 : 70;
  const concatLimit = gsm ? 153 : 67;
  if (msg.length <= singleLimit) return 1;
  return Math.ceil(msg.length / concatLimit);
}

function formatDebtAmount(amount) {
  const n = Number(amount);
  if (!Number.isFinite(n)) return "0";
  if (Math.abs(n - Math.round(n)) < 0.005) return String(Math.round(n));
  return n.toFixed(2);
}

function buildDebtReminderMessage({
  clientName,
  amount,
  currency,
  businessName,
  lang = "sw",
}) {
  const name = String(clientName || "Mteja").trim() || "Mteja";
  const biz = String(businessName || "duka").trim() || "duka";
  const cur = String(currency || "TZS").trim() || "TZS";
  const amt = formatDebtAmount(amount);
  if (lang === "en") {
    return `Hello ${name}, you owe ${amt} ${cur} to ${biz}. Please pay. Thank you.`;
  }
  return `Habari ${name}, una deni la ${amt} ${cur} kwa ${biz}. Tafadhali lipa. Asante.`;
}

function getSmsPackById(packs, packId) {
  const list = Array.isArray(packs) && packs.length ? packs : DEFAULT_SMS_PACKS;
  return list.find((p) => p && p.id === packId) || null;
}

function buildMobishastraUrl({
  user,
  pwd,
  senderId,
  mobileNo,
  msgText,
}) {
  const params = new URLSearchParams({
    user: String(user || ""),
    pwd: String(pwd || ""),
    senderid: String(senderId || "HesabuMz"),
    mobileno: String(mobileNo || ""),
    msgtext: String(msgText || ""),
    priority: "High",
    CountryCode: "ALL",
    ShowError: "C",
  });
  return `${MOBISHASTRA_SEND_URL}?${params.toString()}`;
}

function parseMobishastraResponse(body) {
  const text = String(body || "").trim();
  const codeMatch = text.match(/\b(\d{3})\b/);
  const code = codeMatch ? codeMatch[1] : "";
  const success =
    code === "000" ||
    /send successful/i.test(text) ||
    /^sent/i.test(text);
  return { success, code, raw: text };
}

function parseSmsCreditsValue(raw) {
  const n = typeof raw === "number" ? raw : parseInt(String(raw || "0"), 10);
  if (!Number.isFinite(n) || n < 1 || n > 100000) return 0;
  return Math.trunc(n);
}

module.exports = {
  DEFAULT_SMS_PACKS,
  MOBISHASTRA_SEND_URL,
  normalizeSmsPhone,
  isGsmText,
  countSmsSegments,
  formatDebtAmount,
  buildDebtReminderMessage,
  getSmsPackById,
  buildMobishastraUrl,
  parseMobishastraResponse,
  parseSmsCreditsValue,
};
