import 'package:get/get.dart';

import '../controllers/business_controller.dart';
import '../controllers/profile_controller.dart';
import 'constants.dart';

/// Allow Purchases (business setting) + role gate (Sales Person / Agent never).
class PurchasesAccess {
  static const Set<String> guardedRoutes = {
    '/supplier-debt',
    '/bought',
    '/buy',
    '/buycart',
    '/suppliers',
    '/supplier/select',
    '/supplier/add',
    '/supplier/edit',
  };

  static BusinessController get _business => Get.find<BusinessController>();

  static ProfileController? get _profile =>
      Get.isRegistered<ProfileController>()
          ? Get.find<ProfileController>()
          : null;

  /// Firestore Allow Purchases toggle only (no role check).
  static bool get isBusinessPurchasesEnabled => _business.isPurchasesEnabled;

  static bool get isRoleAllowed =>
      _profile == null ? true : !_profile!.isPurchaseExcludedRole;

  /// Full access: business setting ON and user is not Sales Person / Agent.
  static bool get isEnabled =>
      isBusinessPurchasesEnabled && isRoleAllowed;

  static bool isGuardedRoute(String? routeName) =>
      routeName != null && guardedRoutes.contains(routeName);

  static void notifyDisabled() {
    if (!isRoleAllowed) {
      errorSnackbar('purchases_role_not_allowed'.tr);
      return;
    }
    errorSnackbar('purchases_disabled_by_admin'.tr);
  }

  /// Returns true when purchases are allowed; otherwise shows the appropriate message.
  static bool requireEnabled({bool notify = true}) {
    if (isEnabled) return true;
    if (notify) notifyDisabled();
    return false;
  }
}
