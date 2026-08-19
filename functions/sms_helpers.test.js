const { test } = require("node:test");
const assert = require("node:assert/strict");
const {
  normalizeSmsPhone,
  countSmsSegments,
  formatDebtAmount,
  buildDebtReminderMessage,
  getSmsPackById,
  buildMobishastraUrl,
  parseMobishastraResponse,
  parseSmsCreditsValue,
  DEFAULT_SMS_PACKS,
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

test("buildDebtReminderMessage includes name debt and shop", () => {
  const msg = buildDebtReminderMessage({
    clientName: "John",
    amount: 2500.5,
    currency: "TZS",
    businessName: "Mauzo Shop",
    lang: "sw",
  });
  assert.match(msg, /John/);
  assert.match(msg, /2500.50/);
  assert.match(msg, /Mauzo Shop/);
  assert.match(msg, /deni/);
});

test("getSmsPackById resolves default packs", () => {
  const pack = getSmsPackById(DEFAULT_SMS_PACKS, "sms_100");
  assert.equal(pack.credits, 100);
  assert.equal(pack.price, 5000);
  assert.equal(getSmsPackById(DEFAULT_SMS_PACKS, "missing"), null);
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

test("formatDebtAmount drops needless decimals", () => {
  assert.equal(formatDebtAmount(15000), "15000");
  assert.equal(formatDebtAmount(15000.5), "15000.50");
});
