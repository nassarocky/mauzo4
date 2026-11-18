/**
 * Shop-creation limit. Counts businesses with this ownerId, not the login list.
 * A missing or non-positive maxBusiness uses the signup default of 2.
 */
function resolvedMaxBusiness(raw) {
  const n = typeof raw === "number" ? raw : parseInt(String(raw ?? ""), 10);
  if (!Number.isFinite(n) || n <= 0) return 2;
  return Math.floor(n);
}

/**
 * @param {{ userExists: boolean, ownedCountIncludingNew: number, maxBusiness: * }} args
 * ownedCountIncludingNew includes the shop that was just created.
 * Signup writes the shop before the user profile exists, so that create is allowed.
 */
function shouldRejectNewBusiness({ userExists, ownedCountIncludingNew, maxBusiness }) {
  if (!userExists) return false;
  return ownedCountIncludingNew > resolvedMaxBusiness(maxBusiness);
}

module.exports = {
  resolvedMaxBusiness,
  shouldRejectNewBusiness,
};
