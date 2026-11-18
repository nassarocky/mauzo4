"use strict";

const test = require("node:test");
const assert = require("node:assert");
const { tierPricesForBusinessCount } = require("./subscription_tiers");

const pricing = {
  tier1: { week: 5000, month: 15000, sixMonths: 75000, year: 130000 },
  tier2: { week: 10000, month: 30000, sixMonths: 150000, year: 260000 },
  tier3: { week: 15000, month: 45000, sixMonths: 225000, year: 390000 },
  tier4: { week: 20000, month: 60000, sixMonths: 300000, year: 520000 },
  tier5Plus: { week: 25000, month: 75000, sixMonths: 375000, year: 650000 },
};

test("1 to 5 shops use their tier", () => {
  assert.strictEqual(tierPricesForBusinessCount(pricing, 1).month, 15000);
  assert.strictEqual(tierPricesForBusinessCount(pricing, 4).sixMonths, 300000);
  assert.strictEqual(tierPricesForBusinessCount(pricing, 5).month, 75000);
});

test("0 or invalid counts are charged as one shop", () => {
  assert.strictEqual(tierPricesForBusinessCount(pricing, 0).month, 15000);
  assert.strictEqual(tierPricesForBusinessCount(pricing, undefined).month, 15000);
});

test("price keeps growing past six shops", () => {
  assert.strictEqual(tierPricesForBusinessCount(pricing, 6).month, 90000);
  assert.strictEqual(tierPricesForBusinessCount(pricing, 8).month, 120000);
  assert.strictEqual(tierPricesForBusinessCount(pricing, 10).sixMonths, 375000 + 5 * 75000);
  assert.ok(
    tierPricesForBusinessCount(pricing, 10).year > tierPricesForBusinessCount(pricing, 6).year
  );
});

test("extraShop override wins over the derived step", () => {
  const custom = { ...pricing, extraShop: { month: 10000 } };
  assert.strictEqual(tierPricesForBusinessCount(custom, 7).month, 75000 + 2 * 10000);
  // other packages still derive from tier4 -> tier5Plus
  assert.strictEqual(tierPricesForBusinessCount(custom, 7).week, 25000 + 2 * 5000);
});
