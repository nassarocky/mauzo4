"use strict";

const PACKAGE_KEYS = ["week", "month", "sixMonths", "year"];

function positive(n) {
  return typeof n === "number" && Number.isFinite(n) && n > 0;
}

/**
 * Per-shop increment used from the 6th shop onwards.
 * Uses pricing.extraShop[pkg] when set, otherwise the step between tier4 and
 * tier5Plus, otherwise the single-shop price.
 */
function extraShopIncrement(pricing, pkg) {
  const custom = pricing && pricing.extraShop && pricing.extraShop[pkg];
  if (positive(custom)) return custom;
  const t4 = pricing && pricing.tier4 && pricing.tier4[pkg];
  const t5 = pricing && pricing.tier5Plus && pricing.tier5Plus[pkg];
  if (positive(t4) && positive(t5) && t5 > t4) return t5 - t4;
  const t1 = pricing && pricing.tier1 && pricing.tier1[pkg];
  return positive(t1) ? t1 : 0;
}

/**
 * Prices for a given number of shops. Shops 1-5 use tier1..tier5Plus; every
 * shop beyond 5 adds extraShopIncrement, so 8 or 10 shops no longer pay the 5-shop price.
 */
function tierPricesForBusinessCount(pricing, count) {
  const n = typeof count === "number" && count > 0 ? Math.floor(count) : 1;
  if (n <= 1) return pricing.tier1;
  if (n === 2) return pricing.tier2;
  if (n === 3) return pricing.tier3;
  if (n === 4) return pricing.tier4;
  if (n === 5) return pricing.tier5Plus;

  const extraShops = n - 5;
  const out = {};
  for (const pkg of PACKAGE_KEYS) {
    const base = pricing.tier5Plus && pricing.tier5Plus[pkg];
    if (!positive(base)) continue;
    out[pkg] = base + extraShops * extraShopIncrement(pricing, pkg);
  }
  return out;
}

module.exports = { tierPricesForBusinessCount, extraShopIncrement, PACKAGE_KEYS };
