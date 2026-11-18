/// Pure navigation rules used to stop intermittent "screen opens then closes".
///
/// GetX [Get.currentRoute] often stays `/` or empty when screens are opened with
/// [Navigator.pushNamed], so bootstrap must not treat that as "still on login".
class AppNavigationPolicy {
  AppNavigationPolicy._();

  static String normalize(String route) {
    final trimmed = route.trim();
    if (trimmed.isEmpty) return '/';
    return trimmed.startsWith('/') ? trimmed : '/$trimmed';
  }

  /// After a logged-in auth bootstrap, replace the stack with `/home` only when
  /// the user is still on the login screen. `/` and empty are *not* login — they
  /// are the usual stale GetX values after a [Navigator.pushNamed] from home.
  static bool shouldResetToHomeAfterLoginBootstrap(String currentRoute) {
    return normalize(currentRoute) == '/login';
  }

  /// A leftover [Navigator.pop] from closing the drawer must not be handled by
  /// the newly pushed page. Swallow system/pop callbacks until that page has
  /// finished its first frame.
  static bool shouldSwallowPopUntilRouteSettled({
    required bool routeSettled,
    required bool didPop,
  }) {
    if (didPop) return false;
    return !routeSettled;
  }

  /// Overlay dismissals (subscription dialog, etc.) may only pop [PopupRoute]s.
  /// Page routes must stay, otherwise a child screen opened from home is closed.
  static bool shouldPopRouteAsOverlay(bool isPopupRoute) => isPopupRoute;
}
