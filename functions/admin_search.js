"use strict";

function normalizeSearchText(value) {
  return String(value == null ? "" : value)
    .toLowerCase()
    .replace(/\s+/g, " ")
    .trim();
}

/**
 * Case-insensitive partial match. Every space-separated word of [query] must
 * appear somewhere in [value], in any order ("kuku shamba" finds "Shamba la Kuku").
 * An empty query matches everything.
 */
function matchesSearch(value, query) {
  const q = normalizeSearchText(query);
  if (!q) return true;
  const haystack = normalizeSearchText(value);
  return q.split(" ").every((token) => haystack.includes(token));
}

module.exports = { normalizeSearchText, matchesSearch };
