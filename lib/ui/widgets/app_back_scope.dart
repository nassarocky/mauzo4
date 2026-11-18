import 'package:flutter/material.dart';

import '../../utils/app_navigation.dart';
import '../../utils/app_navigation_policy.dart';

/// Ensures system/AppBar back returns to [Home] instead of flashing [Login]
/// when the navigator stack was accidentally replaced (empty stack → initialRoute).
///
/// Also swallows leftover pops for one frame so a drawer `pop` issued in the
/// same gesture as `pushNamed` cannot close the destination immediately.
class AppBackScope extends StatefulWidget {
  const AppBackScope({super.key, required this.child});

  final Widget child;

  @override
  State<AppBackScope> createState() => _AppBackScopeState();
}

class _AppBackScopeState extends State<AppBackScope> {
  bool _routeSettled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _routeSettled = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final allowPop =
        _routeSettled && (ModalRoute.of(context)?.canPop ?? false);
    return PopScope(
      canPop: allowPop,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (didPop) return;
        if (AppNavigationPolicy.shouldSwallowPopUntilRouteSettled(
          routeSettled: _routeSettled,
          didPop: didPop,
        )) {
          return;
        }
        AppNavigation.popOrReturnHome(context);
      },
      child: widget.child,
    );
  }
}
