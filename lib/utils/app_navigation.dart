import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'preferences.dart';

/// Central navigation helpers: debounce duplicates, debug logging, safe drawer routes.
class AppNavigation {
  AppNavigation._();

  static String? _lastNavKey;
  static DateTime? _lastNavAt;
  static const int _debounceMs = 450;

  static void _log(String message) {
    if (kDebugMode) {
      debugPrint('[Nav] $message');
    }
  }

  static bool _allow(String key) {
    final now = DateTime.now();
    if (_lastNavKey == key &&
        _lastNavAt != null &&
        now.difference(_lastNavAt!).inMilliseconds < _debounceMs) {
      _log('Blocked duplicate navigation: $key');
      return false;
    }
    _lastNavKey = key;
    _lastNavAt = now;
    return true;
  }

  static String currentRoute() {
    final r = Get.currentRoute;
    return r.isEmpty ? '/' : r;
  }

  static String _normalize(String route) =>
      route.startsWith('/') ? route : '/$route';

  static bool isCurrentRoute(String route) =>
      currentRoute() == _normalize(route);

  /// Replaces [Get.offAllNamed] for auth bootstrap / logout (debounced).
  static void offAllNamed(String route, {required String reason}) {
    final target = _normalize(route);
    if (!_allow('offAll:$target:$reason')) return;
    _log('Navigating (offAll) to $target — $reason');
    Get.offAllNamed(target);
  }

  /// Drawer / side menu: push on top of [Home] so Back returns to home (not login).
  static void navigateFromDrawer(BuildContext context, String route) {
    final target = _normalize(route);
    final from = currentRoute();
    if (!_allow('drawer:$from->$target')) return;
    _log('Navigating from $from to $target (push)');
    final navigator = Navigator.of(context);
    navigator.pop(); // close drawer
    if (from == target) return;
    navigator.pushNamed(target);
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
    if (!_allow('replace:$from->$target:$reason')) return;
    _log('Navigating from $from to $target — $reason');
    Navigator.pushReplacementNamed(context, target, arguments: arguments);
  }

  static void logUnexpectedRedirect(String detail) {
    _log('Unexpected redirect detected: $detail');
  }
}
