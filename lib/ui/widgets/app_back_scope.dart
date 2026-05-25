import 'package:flutter/material.dart';

import '../../utils/app_navigation.dart';

/// Ensures system/AppBar back returns to [Home] instead of flashing [Login]
/// when the navigator stack was accidentally replaced (empty stack → initialRoute).
class AppBackScope extends StatelessWidget {
  const AppBackScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: Navigator.of(context).canPop(),
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (didPop) return;
        AppNavigation.popOrReturnHome(context);
      },
      child: child,
    );
  }
}
