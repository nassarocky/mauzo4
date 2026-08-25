const { test } = require("node:test");
const assert = require("node:assert/strict");
const {
  normalizeSmsPhone,
  countSmsSegments,
  formatDebtAmount,
  buildDebtReminderMessage,
  priceForCredits,
  getSmsPackById,
  buildMobishastraUrl,
  buildMobishastraBalanceUrl,
  parseMobishastraResponse,
  parseMobishastraBalance,
  parseSmsCreditsValue,
  DEFAULT_SMS_PACKS,
  shouldSendScheduledReminder,
  dueDateFrom,
  daysUntilDue,
  isLowStockProduct,
  buildLowStockAlertSms,
  buildInvoiceSms,
  buildPurchaseListSms,
} = require("./sms_helpers");

test("normalizeSmsPhone converts TZ local formats", () => {
  assert.equal(normalizeSmsPhone("0765908208"), "255765908208");
  assert.equal(normalizeSmsPhone("+255765908208"), "255765908208");
  assert.equal(normalizeSmsPhone("765908208"), "255765908208");
  assert.equal(normalizeSmsPhone(""), "");
});

test("countSmsSegments uses GSM 160 for Swahili Latin", () => {
  const short = buildDebtReminderMessage({
    clientName: "Asha",
    amount: 15000,
    currency: "TZS",
    businessName: "Duka",
    lang: "sw",
  });
  assert.equal(countSmsSegments(short), 1);
  assert.ok(short.length < 160);
  assert.equal(countSmsSegments("a".repeat(161)), 2);
});

test("buildDebtReminderMessage uses custom template placeholders", () => {
  const msg = buildDebtReminderMessage({
    clientName: "Asha",
    amount: 12000,
    currency: "TZS",
    businessName: "Duka",
    dueDateLabel: "28/08/2026",
    template: "{name} deni {amount} {currency} {business} {due}",
  });
  assert.equal(msg, "Asha deni TZS 12000 Duka 28/08/2026");
});

test("buildInvoiceSms puts currency first and includes item prices", () => {
  const msg = buildInvoiceSms({
    clientName: "Asha",
    amount: 3000,
    currency: "TZS",
    businessName: "Duka",
    lines: [{ name: "Sugar", qty: 2, price: 1500 }],
    lang: "en",
  });
  assert.ok(msg.includes("Sugar x2 TZS 1500 (TZS 3000)"));
  assert.ok(!msg.includes("@"));
  assert.ok(msg.includes("Total TZS 3000"));
  assert.ok(!msg.includes(" = "));
  assert.ok(!msg.includes("3000 TZS"));
  const multi = buildInvoiceSms({
    clientName: "Asha",
    amount: 4500,
    currency: "TZS",
    businessName: "Duka",
    lines: [
      { name: "Sugar", qty: 2, price: 1500 },
      { name: "Rice", qty: 1, price: 1500 },
    ],
    lang: "en",
  });
  assert.ok(multi.includes("Sugar x2 TZS 1500 (TZS 3000)"));
  assert.ok(multi.includes("Rice x1 TZS 1500"));
  assert.ok(multi.includes("Total TZS 4500"));
});

test("buildPurchaseListSms includes every selected name and quantity", () => {
  const message = buildPurchaseListSms({
    supplierName: "Mtoa Bidhaa",
    businessName: "Duka",
    lines: [
      { name: "Sugar", qty: 4 },
      { name: "Rice", qty: 2 },
    ],
    lang: "en",
  });
  assert.ok(message.includes("Sugar x4"));
  assert.ok(message.includes("Rice x2"));
  assert.ok(!message.includes("@"));
});

test("getSmsPackById resolves default packs", () => {
  const pack = getSmsPackById(DEFAULT_SMS_PACKS, "sms_100");
  assert.equal(pack.credits, 100);
  assert.equal(pack.price, 3000);
  assert.equal(getSmsPackById(DEFAULT_SMS_PACKS, "missing"), null);
});

test("priceForCredits is 30 until 1000 then 25", () => {
  assert.equal(priceForCredits(99), 0);
  assert.equal(priceForCredits(100), 3000);
  assert.equal(priceForCredits(200), 6000);
  assert.equal(priceForCredits(500), 15000);
  assert.equal(priceForCredits(1000), 25000);
  assert.equal(priceForCredits(2000), 50000);
});

test("shouldSendScheduledReminder respects due days and max count", () => {
  const today = new Date("2026-08-20T10:00:00+03:00");
  const due = new Date("2026-08-23T00:00:00+03:00");
  assert.equal(
    shouldSendScheduledReminder({
      remainingDebt: 1000,
      dueDate: due,
      today,
      reminderDaysBefore: [3, 1, 0],
      reminderCount: 0,
      reminderMaxCount: 5,
      lastReminderAt: null,
    }),
    true
  );
  assert.equal(
    shouldSendScheduledReminder({
      remainingDebt: 1000,
      dueDate: due,
      today,
      reminderDaysBefore: [3, 1, 0],
      reminderCount: 5,
      reminderMaxCount: 5,
      lastReminderAt: null,
    }),
    false
  );
  assert.equal(daysUntilDue(due, today), 3);
  assert.equal(
    dueDateFrom(today, 7).toISOString(),
    new Date("2026-08-27T00:00:00+03:00").toISOString()
  );
});

test("shouldSendScheduledReminder can send after due date when configured", () => {
  const due = new Date("2026-08-20T00:00:00+03:00");
  const threeDaysAfter = new Date("2026-08-23T10:00:00+03:00");
  assert.equal(daysUntilDue(due, threeDaysAfter), -3);
  assert.equal(
    shouldSendScheduledReminder({
      remainingDebt: 5000,
      dueDate: due,
      today: threeDaysAfter,
      reminderDaysBefore: [3, 1, 0],
      reminderDaysAfter: [],
      reminderAfterMode: "off",
      reminderCount: 0,
      reminderMaxCount: 5,
      lastReminderAt: null,
    }),
    false
  );
  assert.equal(
    shouldSendScheduledReminder({
      remainingDebt: 5000,
      dueDate: due,
      today: threeDaysAfter,
      reminderDaysBefore: [3, 1, 0],
      reminderDaysAfter: [1, 3, 7],
      reminderAfterMode: "days",
      reminderCount: 1,
      reminderMaxCount: 5,
      lastReminderAt: null,
    }),
    true
  );
  assert.equal(
    shouldSendScheduledReminder({
      remainingDebt: 5000,
      dueDate: due,
      today: threeDaysAfter,
      reminderDaysBefore: [3, 1, 0],
      reminderDaysAfter: [1, 7],
      reminderAfterMode: "days",
      reminderCount: 1,
      reminderMaxCount: 5,
      lastReminderAt: null,
    }),
    false
  );
});

test("shouldSendScheduledReminder daily and weekly after due", () => {
  const due = new Date("2026-08-20T00:00:00+03:00");
  const day2 = new Date("2026-08-22T10:00:00+03:00");
  const day7 = new Date("2026-08-27T10:00:00+03:00");
  const day8 = new Date("2026-08-28T10:00:00+03:00");

  assert.equal(
    shouldSendScheduledReminder({
      remainingDebt: 1000,
      dueDate: due,
      today: day2,
      reminderDaysBefore: [0],
      reminderAfterMode: "daily",
      reminderCount: 0,
      reminderMaxCount: 30,
      lastReminderAt: null,
    }),
    true
  );
  assert.equal(
    shouldSendScheduledReminder({
      remainingDebt: 1000,
      dueDate: due,
      today: day7,
      reminderDaysBefore: [0],
      reminderAfterMode: "weekly",
      reminderCount: 0,
      reminderMaxCount: 30,
      lastReminderAt: null,
    }),
    true
  );
  assert.equal(
    shouldSendScheduledReminder({
      remainingDebt: 1000,
      dueDate: due,
      today: day8,
      reminderDaysBefore: [0],
      reminderAfterMode: "weekly",
      reminderCount: 0,
      reminderMaxCount: 30,
      lastReminderAt: null,
    }),
    false
  );
});

test("buildMobishastraUrl encodes message and phone", () => {
  const url = buildMobishastraUrl({
    user: "20000000",
    pwd: "secret",
    senderId: "HesabuMz",
    mobileNo: "255765908208",
    msgText: "Habari Asha, una deni",
  });
  assert.ok(url.startsWith("https://mshastra.com/sendurl.aspx?"));
  assert.ok(url.includes("mobileno=255765908208"));
  assert.ok(url.includes("CountryCode=ALL"));
  assert.ok(url.includes("ShowError=C"));
  assert.ok(!url.includes(" "));
});

test("parseMobishastraResponse treats 000 as success", () => {
  assert.equal(parseMobishastraResponse("000 - Send Successful").success, true);
  assert.equal(parseMobishastraResponse("Send Successful").success, true);
  assert.equal(parseMobishastraResponse("005").success, false);
  assert.equal(parseMobishastraResponse("No More Credits").success, false);
});

test("parseSmsCreditsValue rejects invalid packs", () => {
  assert.equal(parseSmsCreditsValue(100), 100);
  assert.equal(parseSmsCreditsValue("50"), 50);
  assert.equal(parseSmsCreditsValue(0), 0);
  assert.equal(parseSmsCreditsValue(-1), 0);
});

test("buildMobishastraBalanceUrl uses balance endpoint", () => {
  const url = buildMobishastraBalanceUrl({ user: "20000000", pwd: "secret" });
  assert.ok(url.startsWith("https://mshastra.com/balance.aspx?"));
  assert.ok(url.includes("user=20000000"));
});

test("parseMobishastraBalance reads remaining credits", () => {
  assert.equal(parseMobishastraBalance("1250").credits, 1250);
  assert.equal(parseMobishastraBalance("Balance: 80.0").credits, 80);
  assert.equal(parseMobishastraBalance(JSON.stringify({ credits: 42 })).credits, 42);
  assert.equal(parseMobishastraBalance("Invalid Password").success, false);
  assert.equal(parseMobishastraBalance("Tanzania (+255) = 9999").credits, 9999);
  assert.equal(parseMobishastraBalance("255=9999").credits, 9999);
  assert.equal(parseMobishastraBalance("255").credits, 255);
});

test("formatDebtAmount drops needless decimals", () => {
  assert.equal(formatDebtAmount(15000), "15000");
  assert.equal(formatDebtAmount(15000.5), "15000.50");
});

test("isLowStockProduct uses understock minimum like the app", () => {
  assert.equal(
    isLowStockProduct({ name: "Sugar", quantity: 4, understock: 10 }),
    true
  );
  assert.equal(
    isLowStockProduct({ name: "Sugar", quantity: 10, understock: 10 }),
    false
  );
  assert.equal(
    isLowStockProduct({ name: "Sugar", quantity: 0, understock: 0 }),
    false
  );
  assert.equal(
    isLowStockProduct({
      name: "Cleaning",
      quantity: 0,
      understock: 5,
      itemType: "service",
    }),
    false
  );
});

test("buildLowStockAlertSms lists product quantities", () => {
  const msg = buildLowStockAlertSms({
    businessName: "Duka",
    products: [
      { name: "Sugar", quantity: 2, understock: 10 },
      { name: "Flour", quantity: 0, understock: 5 },
      { name: "Rice", quantity: 20, understock: 5 },
    ],
    lang: "sw",
  });
  assert.match(msg, /Duka/);
  assert.match(msg, /stock chini/);
  assert.match(msg, /Sugar\(2\)/);
  assert.match(msg, /Flour\(0\)/);
  assert.equal(msg.includes("Rice"), false);
  assert.equal(require("./sms_helpers").countSmsSegments(msg), 1);
});
