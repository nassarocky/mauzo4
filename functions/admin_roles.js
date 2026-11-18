"use strict";

/**
 * Admin roles stored on commission_admins/{uid}.role
 *  - missing / "admin" / "owner" / "full" / "super": full admin (existing admins keep working)
 *  - "customer_care" (and any other value): restricted. They can do everything except
 *    upgrading a customer's subscription and granting SMS. Unknown values fail closed.
 */
const FULL_ADMIN_ROLES = new Set(["admin", "owner", "full", "super", "super_admin"]);

function normalizeAdminRole(role) {
  return String(role == null ? "" : role)
    .trim()
    .toLowerCase()
    .replace(/[\s-]+/g, "_");
}

function isFullAdminRole(role) {
  const r = normalizeAdminRole(role);
  if (r === "") return true;
  return FULL_ADMIN_ROLES.has(r);
}

module.exports = { isFullAdminRole, normalizeAdminRole };
