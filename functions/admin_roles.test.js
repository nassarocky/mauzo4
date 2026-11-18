"use strict";

const test = require("node:test");
const assert = require("node:assert");
const { isFullAdminRole } = require("./admin_roles");

test("existing admins without a role stay full admins", () => {
  assert.ok(isFullAdminRole(undefined));
  assert.ok(isFullAdminRole(null));
  assert.ok(isFullAdminRole(""));
  assert.ok(isFullAdminRole("admin"));
  assert.ok(isFullAdminRole(" Super_Admin "));
});

test("customer care is restricted in any spelling", () => {
  assert.ok(!isFullAdminRole("customer_care"));
  assert.ok(!isFullAdminRole("Customer Care"));
  assert.ok(!isFullAdminRole("customer-care"));
});

test("unknown roles fail closed", () => {
  assert.ok(!isFullAdminRole("supprt"));
  assert.ok(!isFullAdminRole("viewer"));
});
