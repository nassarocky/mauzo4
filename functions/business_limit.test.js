const test = require("node:test");
const assert = require("node:assert/strict");
const { resolvedMaxBusiness, shouldRejectNewBusiness } = require("./business_limit");

test("missing or invalid maxBusiness defaults to 2", () => {
  assert.equal(resolvedMaxBusiness(undefined), 2);
  assert.equal(resolvedMaxBusiness(null), 2);
  assert.equal(resolvedMaxBusiness(0), 2);
  assert.equal(resolvedMaxBusiness("2"), 2);
  assert.equal(resolvedMaxBusiness(4.8), 4);
});

test("signup shop is kept when the user profile does not exist yet", () => {
  assert.equal(
    shouldRejectNewBusiness({
      userExists: false,
      ownedCountIncludingNew: 1,
      maxBusiness: 2,
    }),
    false
  );
});

test("a second owned shop is allowed when the limit is 2", () => {
  assert.equal(
    shouldRejectNewBusiness({
      userExists: true,
      ownedCountIncludingNew: 2,
      maxBusiness: 2,
    }),
    false
  );
});

test("a shop past the owned-shop limit is rejected even if the login list is short", () => {
  assert.equal(
    shouldRejectNewBusiness({
      userExists: true,
      ownedCountIncludingNew: 3,
      maxBusiness: 2,
    }),
    true
  );
});
