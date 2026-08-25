/**
 * Pure helpers for SMS billing, messages, and scheduled debt reminders.
 */

const SMS_MIN_PACK = 100;
const SMS_UNIT_PRICE = 30;
const SMS_BULK_MIN = 1000;
const SMS_BULK_UNIT_PRICE = 25;

function priceForCredits(credits) {
  const n = Math.trunc(Number(credits) || 0);
  if (n < SMS_MIN_PACK) return 0;
  if (n >= SMS_BULK_MIN) return n * SMS_BULK_UNIT_PRICE;
  return n * SMS_UNIT_PRICE;
}

const DEFAULT_SMS_PACKS = [
  { id: "sms_100", credits: 100, price: priceForCredits(100), label: "SMS 100" },
  { id: "sms_200", credits: 200, price: priceForCredits(200), label: "SMS 200" },
  { id: "sms_500", credits: 500, price: priceForCredits(500), label: "SMS 500" },
  { id: "sms_1000", credits: 1000, price: priceForCredits(1000), label: "SMS 1000" },
  { id: "sms_2000", credits: 2000, price: priceForCredits(2000), label: "SMS 2000" },
];

const DEFAULT_SMS_SETTINGS = {
  defaultCreditDays: 7,
  reminderDaysBefore: [3, 1, 0],
  reminderDaysAfter: [],
  reminderAfterMode: "off",
  reminderMaxCount: 5,
  debtReminderTemplate: "",
  dailyDigestEnabled: false,
  expiryAlertEnabled: false,
  lowStockAlertEnabled: false,
  advanceSmsEnabled: true,
  debtPaymentSmsEnabled: true,
};

const GSM_BASIC =
  "@£$¥èéùìòÇ\nØø\rÅåΔ_ΦΓΛΩΠΨΣΘΞÆæßÉ !\"#¤%&'()*+,-./0123456789:;<=>?" +
  "¡ABCDEFGHIJKLMNOPQRSTUVWXYZÄÖÑÜ§¿abcdefghijklmnopqrstuvwxyzäöñüà";

const MOBISHASTRA_SEND_URL = "https://mshastra.com/sendurl.aspx";
const MOBISHASTRA_BALANCE_URL = "https://mshastra.com/balance.aspx";

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

function formatSmsMoney(amount, currency) {
  const cur = String(currency || "TZS").trim() || "TZS";
  return `${cur} ${formatDebtAmount(amount)}`;
}

function parseSmsNumber(raw) {
  if (typeof raw === "number" && Number.isFinite(raw)) return raw;
  const s = String(raw ?? "").replace(/,/g, "").trim();
  const n = Number(s);
  return Number.isFinite(n) ? n : 0;
}

function normalizeSmsLines(raw) {
  let list = raw;
  if (list && !Array.isArray(list) && typeof list === "object") {
    list = Object.keys(list)
      .sort((a, b) => Number(a) - Number(b))
      .map((k) => list[k]);
  }
  if (!Array.isArray(list)) return [];
  return list
    .map((l) => ({
      name: String(l?.name || "").trim(),
      qty: parseSmsNumber(l?.qty ?? l?.quantity ?? l?.count ?? 1),
      price: parseSmsNumber(l?.price ?? l?.unitPrice ?? 0),
    }))
    .filter((l) => l.name);
}

function formatInvoiceSmsLine(line, currency) {
  const qtyRaw = parseSmsNumber(line?.qty ?? line?.quantity ?? 1);
  const qty = qtyRaw > 0 ? qtyRaw : 1;
  const price = parseSmsNumber(line?.price);
  const name = String(line?.name || "").trim();
  if (!(price > 0)) return `${name} x${qty}`;
  const unit = formatSmsMoney(price, currency);
  if (qty > 1) {
    return `${name} x${qty} ${unit} (${formatSmsMoney(price * qty, currency)})`;
  }
  return `${name} x${qty} ${unit}`;
}

function startOfDay(date) {
  const d = new Date(date);
  d.setHours(0, 0, 0, 0);
  return d;
}

function nairobiDateParts(date = new Date()) {
  const parts = new Intl.DateTimeFormat("en-CA", {
    timeZone: "Africa/Nairobi",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).formatToParts(date);
  const get = (type) => parts.find((p) => p.type === type)?.value;
  return {
    year: get("year"),
    month: get("month"),
    day: get("day"),
  };
}

function startOfDayNairobi(date = new Date()) {
  const { year, month, day } = nairobiDateParts(date);
  return new Date(`${year}-${month}-${day}T00:00:00+03:00`);
}

function endOfDayNairobi(date = new Date()) {
  const { year, month, day } = nairobiDateParts(date);
  return new Date(`${year}-${month}-${day}T23:59:59.999+03:00`);
}

function nairobiMonthKey(date = new Date()) {
  const { year, month } = nairobiDateParts(date);
  return `${year}-${month}`;
}

function formatDueDateLabel(date) {
  if (!date) return "";
  const d = date instanceof Date ? date : new Date(date);
  if (Number.isNaN(d.getTime())) return "";
  const { year, month, day } = nairobiDateParts(d);
  return `${day}/${month}/${year}`;
}

function firestoreToDate(value) {
  if (!value) return null;
  if (typeof value.toDate === "function") return value.toDate();
  if (value instanceof Date) return value;
  if (typeof value.seconds === "number") return new Date(value.seconds * 1000);
  const d = new Date(value);
  return Number.isNaN(d.getTime()) ? null : d;
}

function dueDateFrom(start, creditDays) {
  const days = Math.max(0, Math.trunc(Number(creditDays) || 0));
  const { year, month, day } = nairobiDateParts(start);
  return new Date(
    new Date(`${year}-${month}-${day}T00:00:00+03:00`).getTime() + days * 86400000
  );
}

function daysUntilDue(dueDate, today) {
  const due = startOfDayNairobi(dueDate).getTime();
  const now = startOfDayNairobi(today).getTime();
  return Math.round((due - now) / 86400000);
}

function sameCalendarDay(a, b) {
  if (!a || !b) return false;
  const left = nairobiDateParts(a);
  const right = nairobiDateParts(b);
  return left.year === right.year && left.month === right.month && left.day === right.day;
}

/**
 * Send if remaining debt, under max count, not already sent today,
 * and days-until-due matches owner-chosen before/after rules.
 * daysUntilDue > 0 = before due, 0 = due day, < 0 = after due.
 * reminderAfterMode: off | days | daily | weekly
 */
function shouldSendScheduledReminder({
  remainingDebt,
  dueDate,
  today,
  reminderDaysBefore,
  reminderDaysAfter,
  reminderAfterMode,
  reminderCount,
  reminderMaxCount,
  lastReminderAt,
}) {
  if (!(Number(remainingDebt) > 0) || !dueDate) return false;
  const max = Math.max(1, Math.trunc(Number(reminderMaxCount) || 5));
  if ((Number(reminderCount) || 0) >= max) return false;
  if (lastReminderAt && sameCalendarDay(lastReminderAt, today)) return false;
  const days = daysUntilDue(dueDate, today);
  const beforeList = Array.isArray(reminderDaysBefore) && reminderDaysBefore.length
    ? reminderDaysBefore.map((n) => Math.trunc(Number(n))).filter((n) => Number.isFinite(n) && n >= 0)
    : DEFAULT_SMS_SETTINGS.reminderDaysBefore;
  if (days >= 0) return beforeList.includes(days);

  const overdue = -days;
  const mode = normalizeReminderAfterMode(reminderAfterMode, reminderDaysAfter);
  if (mode === "daily") return overdue > 0;
  if (mode === "weekly") return overdue > 0 && overdue % 7 === 0;
  if (mode !== "days") return false;
  const afterList = Array.isArray(reminderDaysAfter)
    ? reminderDaysAfter.map((n) => Math.trunc(Number(n))).filter((n) => Number.isFinite(n) && n > 0)
    : DEFAULT_SMS_SETTINGS.reminderDaysAfter;
  return afterList.includes(overdue);
}

function normalizeReminderAfterMode(rawMode, reminderDaysAfter) {
  const mode = String(rawMode || "").toLowerCase();
  if (mode === "daily" || mode === "weekly" || mode === "days" || mode === "off") {
    if (mode === "days") {
      const hasDays = Array.isArray(reminderDaysAfter) && reminderDaysAfter.some((n) => Number(n) > 0);
      return hasDays ? "days" : "off";
    }
    return mode;
  }
  const hasDays = Array.isArray(reminderDaysAfter) && reminderDaysAfter.some((n) => Number(n) > 0);
  return hasDays ? "days" : "off";
}

function defaultDebtReminderTemplate(lang = "sw") {
  if (lang === "en") {
    return "Hello {name}, you owe {currency} {amount} to {business}.{due} Please pay. Thank you.";
  }
  return "Habari {name}, una deni la {currency} {amount} kwa {business}.{due} Tafadhali lipa. Asante.";
}

function applyDebtReminderTemplate(template, {
  clientName,
  amount,
  currency,
  businessName,
  dueDateLabel,
}) {
  const name = String(clientName || "Mteja").trim() || "Mteja";
  const biz = String(businessName || "duka").trim() || "duka";
  const cur = String(currency || "TZS").trim() || "TZS";
  const amt = formatDebtAmount(amount);
  const dueRaw = dueDateLabel ? String(dueDateLabel).trim() : "";
  return String(template || "")
    .replace(/\{amount\}\s*\{currency\}/gi, "{currency} {amount}")
    .replace(/\{name\}/gi, name)
    .replace(/\{client\}/gi, name)
    .replace(/\{amount\}/gi, amt)
    .replace(/\{currency\}/gi, cur)
    .replace(/\{business\}/gi, biz)
    .replace(/\{shop\}/gi, biz)
    .replace(/\{due\}/gi, dueRaw)
    .replace(/\s{2,}/g, " ")
    .trim();
}

function buildDebtReminderMessage({
  clientName,
  amount,
  currency,
  businessName,
  dueDateLabel,
  lang = "sw",
  template,
}) {
  const custom = String(template || "").trim();
  if (custom) {
    return applyDebtReminderTemplate(custom, {
      clientName,
      amount,
      currency,
      businessName,
      dueDateLabel,
    });
  }
  const name = String(clientName || "Mteja").trim() || "Mteja";
  const biz = String(businessName || "duka").trim() || "duka";
  const due = dueDateLabel ? String(dueDateLabel) : "";
  const money = formatSmsMoney(amount, currency);
  if (lang === "en") {
    const extra = due ? ` Due ${due}.` : "";
    return `Hello ${name}, you owe ${money} to ${biz}.${extra} Please pay. Thank you.`;
  }
  const extra = due ? ` Tarehe ya malipo ${due}.` : "";
  return `Habari ${name}, una deni la ${money} kwa ${biz}.${extra} Tafadhali lipa. Asante.`;
}

function buildInvoiceSms({ clientName, amount, currency, businessName, lines, lang = "sw" }) {
  const name = String(clientName || "Mteja").trim() || "Mteja";
  const biz = String(businessName || "duka").trim() || "duka";
  const items = normalizeSmsLines(lines)
    .slice(0, 8)
    .map((l) => formatInvoiceSmsLine(l, currency))
    .join(", ");
  if (lang === "en") {
    return `Invoice from ${biz} for ${name}: ${items || "items"}. Total ${formatSmsMoney(amount, currency)}.`;
  }
  return `Ankara kutoka ${biz} kwa ${name}: ${items || "bidhaa"}. Jumla ${formatSmsMoney(amount, currency)}.`;
}

function buildPurchaseListSms({ supplierName, businessName, lines, lang = "sw" }) {
  const sup = String(supplierName || "Msambazaji").trim() || "Msambazaji";
  const biz = String(businessName || "duka").trim() || "duka";
  const items = (Array.isArray(lines) ? lines : [])
    .slice(0, 10)
    .map((l) => `${l.name} x${l.qty}`)
    .join(", ");
  if (lang === "en") {
    return `${biz} purchase list for ${sup}: ${items || "items"}.`;
  }
  return `Orodha ya manunuzi ya ${biz} kwa ${sup}: ${items || "bidhaa"}.`;
}

function buildAdvanceSms({ clientName, amount, currency, businessName, lang = "sw" }) {
  const name = String(clientName || "Mteja").trim() || "Mteja";
  const biz = String(businessName || "duka").trim() || "duka";
  const money = formatSmsMoney(amount, currency);
  if (lang === "en") {
    return `Hello ${name}, ${biz} recorded your advance of ${money}. Thank you.`;
  }
  return `Habari ${name}, ${biz} imepokea advance yako ya ${money}. Asante.`;
}

function buildDebtPaymentSms({ clientName, amount, remaining, currency, businessName, lang = "sw" }) {
  const name = String(clientName || "Mteja").trim() || "Mteja";
  const biz = String(businessName || "duka").trim() || "duka";
  if (lang === "en") {
    return `Hello ${name}, ${biz} received your debt payment of ${formatSmsMoney(amount, currency)}. Remaining ${formatSmsMoney(remaining, currency)}.`;
  }
  return `Habari ${name}, ${biz} imepokea malipo ya deni ${formatSmsMoney(amount, currency)}. Deni lililobaki ${formatSmsMoney(remaining, currency)}.`;
}

function buildDailyDigestSms({ businessName, sales, profit, expenses, currency, lang = "sw" }) {
  const biz = String(businessName || "duka").trim() || "duka";
  if (lang === "en") {
    return `${biz} today: sales ${formatSmsMoney(sales, currency)}, profit ${formatSmsMoney(profit, currency)}, expenses ${formatSmsMoney(expenses, currency)}.`;
  }
  return `${biz} leo: mauzo ${formatSmsMoney(sales, currency)}, faida ${formatSmsMoney(profit, currency)}, matumizi ${formatSmsMoney(expenses, currency)}.`;
}

function buildExpiryAlertSms({ businessName, products, lang = "sw" }) {
  const biz = String(businessName || "duka").trim() || "duka";
  const names = (Array.isArray(products) ? products : []).slice(0, 6).join(", ");
  if (lang === "en") {
    return `${biz}: products nearing expiry: ${names || "items"}.`;
  }
  return `${biz}: bidhaa zinakaribia kuisha muda: ${names || "bidhaa"}.`;
}

/** Same rule as the app understock filter: quantity < understock. */
function isLowStockProduct(product) {
  if (!product || typeof product !== "object") return false;
  if (String(product.itemType || "product").toLowerCase() === "service") return false;
  const understock = Number(product.understock);
  if (!Number.isFinite(understock) || understock <= 0) return false;
  const quantity = Number(product.quantity);
  if (!Number.isFinite(quantity)) return false;
  return quantity < understock;
}

function formatLowStockLabel(product) {
  const name = String(product?.name || "bidhaa").trim() || "bidhaa";
  const qty = Number(product?.quantity);
  const qtyLabel = Number.isFinite(qty) ? formatDebtAmount(qty) : "?";
  return `${name}(${qtyLabel})`;
}

function buildLowStockAlertSms({ businessName, products, lang = "sw" }) {
  const biz = String(businessName || "duka").trim() || "duka";
  const labels = (Array.isArray(products) ? products : [])
    .filter(isLowStockProduct)
    .slice(0, 6)
    .map(formatLowStockLabel);
  if (lang === "en") {
    return `${biz}: low stock: ${labels.join(", ") || "items"}.`;
  }
  return `${biz}: stock chini: ${labels.join(", ") || "bidhaa"}.`;
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

function buildMobishastraBalanceUrl({ user, pwd }) {
  const params = new URLSearchParams({
    user: String(user || ""),
    pwd: String(pwd || ""),
  });
  return `${MOBISHASTRA_BALANCE_URL}?${params.toString()}`;
}

const MOBISHASTRA_COUNTRY_CODES = new Set([
  1, 44, 91, 250, 254, 255, 256, 257, 258, 260, 966, 971,
]);

function parseMobishastraBalance(body) {
  const raw = String(body || "").trim();
  if (!raw) return { success: false, credits: null, raw: "" };
  try {
    const parsed = JSON.parse(raw);
    const credits = Number(
      parsed.credits ?? parsed.Credits ?? parsed.balance ?? parsed.Balance
    );
    if (Number.isFinite(credits)) {
      return { success: true, credits: Math.trunc(credits), raw };
    }
  } catch (_) {
    // Plain-text gateway replies are expected.
  }
  if (/invalid|blocked|password|profile id|no more credits/i.test(raw) &&
      !/\d{2,}/.test(raw)) {
    return { success: false, credits: null, raw };
  }
  // Dashboard/API style: "Tanzania (+255) = 9999" or "255=9999"
  const afterEq = raw.match(/=\s*(-?\d+(?:\.\d+)?)/);
  if (afterEq) {
    const credits = Math.trunc(Number(afterEq[1]));
    if (Number.isFinite(credits)) return { success: true, credits, raw };
  }
  const nums = [...raw.matchAll(/(-?\d+(?:\.\d+)?)/g)]
    .map((m) => Math.trunc(Number(m[1])))
    .filter((n) => Number.isFinite(n));
  if (!nums.length) return { success: false, credits: null, raw };
  const withoutCountry = nums.filter((n) => !MOBISHASTRA_COUNTRY_CODES.has(n));
  const credits = (withoutCountry.length ? withoutCountry : nums).at(-1);
  return { success: true, credits, raw };
}

function parseSmsCreditsValue(raw) {
  const n = typeof raw === "number" ? raw : parseInt(String(raw || "0"), 10);
  if (!Number.isFinite(n) || n < 1 || n > 100000) return 0;
  return Math.trunc(n);
}

function normalizeSmsSettings(raw) {
  const s = raw && typeof raw === "object" ? raw : {};
  const days = Array.isArray(s.reminderDaysBefore)
    ? s.reminderDaysBefore.map((n) => Math.trunc(Number(n))).filter((n) => Number.isFinite(n) && n >= 0 && n <= 60)
    : DEFAULT_SMS_SETTINGS.reminderDaysBefore;
  const afterDays = Array.isArray(s.reminderDaysAfter)
    ? [...new Set(
        s.reminderDaysAfter
          .map((n) => Math.trunc(Number(n)))
          .filter((n) => Number.isFinite(n) && n > 0 && n <= 60)
      )].sort((a, b) => a - b)
    : DEFAULT_SMS_SETTINGS.reminderDaysAfter;
  const reminderAfterMode = normalizeReminderAfterMode(s.reminderAfterMode, afterDays);
  return {
    defaultCreditDays: Math.max(
      0,
      Math.min(365, Math.trunc(Number(s.defaultCreditDays) || DEFAULT_SMS_SETTINGS.defaultCreditDays))
    ),
    reminderDaysBefore: days.length ? [...new Set(days)].sort((a, b) => b - a) : DEFAULT_SMS_SETTINGS.reminderDaysBefore,
    reminderDaysAfter: afterDays,
    reminderAfterMode,
    reminderMaxCount: Math.max(1, Math.min(30, Math.trunc(Number(s.reminderMaxCount) || DEFAULT_SMS_SETTINGS.reminderMaxCount))),
    debtReminderTemplate: String(s.debtReminderTemplate || "").trim().slice(0, 600),
    dailyDigestEnabled: Boolean(s.dailyDigestEnabled),
    expiryAlertEnabled: Boolean(s.expiryAlertEnabled),
    lowStockAlertEnabled: Boolean(s.lowStockAlertEnabled),
    advanceSmsEnabled: s.advanceSmsEnabled !== false,
    debtPaymentSmsEnabled: s.debtPaymentSmsEnabled !== false,
  };
}

module.exports = {
  SMS_MIN_PACK,
  SMS_UNIT_PRICE,
  SMS_BULK_MIN,
  SMS_BULK_UNIT_PRICE,
  DEFAULT_SMS_PACKS,
  DEFAULT_SMS_SETTINGS,
  MOBISHASTRA_SEND_URL,
  MOBISHASTRA_BALANCE_URL,
  priceForCredits,
  normalizeSmsPhone,
  isGsmText,
  countSmsSegments,
  formatDebtAmount,
  formatSmsMoney,
  parseSmsNumber,
  normalizeSmsLines,
  formatInvoiceSmsLine,
  dueDateFrom,
  daysUntilDue,
  shouldSendScheduledReminder,
  normalizeReminderAfterMode,
  startOfDayNairobi,
  endOfDayNairobi,
  nairobiMonthKey,
  formatDueDateLabel,
  firestoreToDate,
  sameCalendarDay,
  buildDebtReminderMessage,
  defaultDebtReminderTemplate,
  applyDebtReminderTemplate,
  buildInvoiceSms,
  buildPurchaseListSms,
  buildAdvanceSms,
  buildDebtPaymentSms,
  buildDailyDigestSms,
  buildExpiryAlertSms,
  isLowStockProduct,
  formatLowStockLabel,
  buildLowStockAlertSms,
  getSmsPackById,
  buildMobishastraUrl,
  buildMobishastraBalanceUrl,
  parseMobishastraResponse,
  parseMobishastraBalance,
  parseSmsCreditsValue,
  normalizeSmsSettings,
};
