"use strict";

const test = require("node:test");
const assert = require("node:assert");
const { matchesSearch, normalizeSearchText } = require("./admin_search");

test("matches part of an email regardless of case", () => {
  assert.ok(matchesSearch("AnnaMinja92@gmail.com", "minja"));
  assert.ok(matchesSearch("annaminja92@gmail.com", "ANNAMINJA92"));
  assert.ok(matchesSearch("annaminja92@gmail.com", "92@gmail"));
});

test("business names match by any words in any order", () => {
  assert.ok(matchesSearch("Shamba la Kuku", "kuku"));
  assert.ok(matchesSearch("Shamba la Kuku", "kuku shamba"));
  assert.ok(matchesSearch("  Shamba   la Kuku ", "shamba  la"));
});

test("non matches and empty values", () => {
  assert.ok(!matchesSearch("Shamba la Kuku", "duka"));
  assert.ok(!matchesSearch("", "duka"));
  assert.ok(!matchesSearch(null, "duka"));
  assert.ok(matchesSearch("anything", "   "));
});

test("normalize trims and collapses spaces", () => {
  assert.strictEqual(normalizeSearchText("  A   B "), "a b");
});
