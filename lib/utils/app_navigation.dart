import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'app_navigation_policy.dart';
import 'preferences.dart';

/// Central navigation helpers: debounce stack resets, debug logging, safe drawer routes.
class AppNavigation {
  AppNavigation._();

  static String? _lastOffAllKey;
  static DateTime? _lastOffAllAt;
  static const int _offAllDebounceMs = 450;

  static void _log(String message) {
    if (kDebugMode) {
      debugPrint('[Nav] $message');
    }
  }

  static bool _allowOffAll(String key) {
    final now = DateTime.now();
    if (_lastOffAllKey == key &&
        _lastOffAllAt != null &&
        now.difference(_lastOffAllAt!).inMilliseconds < _offAllDebounceMs) {
      _log('Blocked duplicate navigation: $key');
      return false;
    }
    _lastOffAllKey = key;
    _lastOffAllAt = now;
    return true;
  }

  static String currentRoute() {
    final r = Get.currentRoute;
    return r.isEmpty ? '/' : r;
  }

  static String _normalize(String route) => AppNavigationPolicy.normalize(route);

  static bool isCurrentRoute(String route) =>
      currentRoute() == _normalize(route);

  /// Replaces [Get.offAllNamed] for auth bootstrap / logout (debounced).
  static void offAllNamed(String route, {required String reason}) {
    final target = _normalize(route);
    if (!_allowOffAll('offAll:$target:$reason')) return;
    _log('Navigating (offAll) to $target — $reason');
    Get.offAllNamed(target);
  }

  /// Drawer / side menu: close the drawer without popping a page, then push
  /// on the next frame so a leftover pop cannot close the new screen.
  static void navigateFromDrawer(BuildContext context, String route) {
    final target = _normalize(route);
    if (!context.mounted) return;
    final navigator = Navigator.of(context);
    _log('Navigating from drawer to $target (push next frame)');
    final scaffold = Scaffold.maybeOf(context);
    if (scaffold != null) {
      if (scaffold.isDrawerOpen) scaffold.closeDrawer();
      if (scaffold.isEndDrawerOpen) scaffold.closeEndDrawer();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      navigator.pushNamed(target);
    });
  }

  static void pushNamed(BuildContext context, String route) {
    if (!context.mounted) return;
    final target = _normalize(route);
    _log('Push named $target');
    Navigator.of(context).pushNamed(target);
  }

  /// Dismiss dialogs/sheets only. Never pops a page route (the destination
  /// opened from home).
  static void popOpenPopups(BuildContext context) {
    if (!context.mounted) return;
    final nav = Navigator.of(context, rootNavigator: true);
    nav.popUntil(
      (route) => !AppNavigationPolicy.shouldPopRouteAsOverlay(route is PopupRoute),
    );
  }

  /// System back / AppBar back when the stack would otherwise be empty.
  static void popOrReturnHome(BuildContext context) {
    if (!context.mounted) return;
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }
    if (Preferences.isLoggedIn() && !isCurrentRoute('/home')) {
      _log('Back with empty stack — return to /home (not login)');
      navigator.pushReplacementNamed('/home');
    }
  }

  /// Safe push when already on a child screen is not desired — use replacement.
  static void pushReplacementNamed(
    BuildContext context,
    String route, {
    Object? arguments,
    required String reason,
  }) {
    if (!context.mounted) return;
    final target = _normalize(route);
    final from = currentRoute();
    _log('Navigating from $from to $target — $reason');
    Navigator.pushReplacementNamed(context, target, arguments: arguments);
  }

  static void logUnexpectedRedirect(String detail) {
    _log('Unexpected redirect detected: $detail');
  }
}
