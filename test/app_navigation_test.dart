import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mauzo/ui/widgets/app_back_scope.dart';
import 'package:mauzo/utils/app_navigation.dart';
import 'package:mauzo/utils/app_navigation_policy.dart';

void main() {
  group('shouldResetToHomeAfterLoginBootstrap', () {
    test('resets only when still on login', () {
      expect(
        AppNavigationPolicy.shouldResetToHomeAfterLoginBootstrap('/login'),
        isTrue,
      );
    });

    test('does not reset on home', () {
      expect(
        AppNavigationPolicy.shouldResetToHomeAfterLoginBootstrap('/home'),
        isFalse,
      );
    });

    test('does not reset on stale GetX "/" after pushNamed from home', () {
      expect(
        AppNavigationPolicy.shouldResetToHomeAfterLoginBootstrap('/'),
        isFalse,
      );
    });

    test('does not reset on empty GetX currentRoute', () {
      expect(
        AppNavigationPolicy.shouldResetToHomeAfterLoginBootstrap(''),
        isFalse,
      );
    });

    test('does not reset when a child screen is already open', () {
      expect(
        AppNavigationPolicy.shouldResetToHomeAfterLoginBootstrap('/sales'),
        isFalse,
      );
    });
  });

  group('shouldSwallowPopUntilRouteSettled', () {
    test('swallows leftover pops before the first frame', () {
      expect(
        AppNavigationPolicy.shouldSwallowPopUntilRouteSettled(
          routeSettled: false,
          didPop: false,
        ),
        isTrue,
      );
    });

    test('does not swallow after the route has settled', () {
      expect(
        AppNavigationPolicy.shouldSwallowPopUntilRouteSettled(
          routeSettled: true,
          didPop: false,
        ),
        isFalse,
      );
    });

    test('does not swallow a pop that already happened', () {
      expect(
        AppNavigationPolicy.shouldSwallowPopUntilRouteSettled(
          routeSettled: false,
          didPop: true,
        ),
        isFalse,
      );
    });
  });

  group('shouldPopRouteAsOverlay', () {
    test('pops popup routes only', () {
      expect(AppNavigationPolicy.shouldPopRouteAsOverlay(true), isTrue);
      expect(AppNavigationPolicy.shouldPopRouteAsOverlay(false), isFalse);
    });
  });

  group('normalize', () {
    test('adds a leading slash and treats empty as root', () {
      expect(AppNavigationPolicy.normalize('settings'), '/settings');
      expect(AppNavigationPolicy.normalize('/sales'), '/sales');
      expect(AppNavigationPolicy.normalize(''), '/');
    });
  });

  testWidgets(
    'drawer navigation keeps the destination after the drawer closes',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          onGenerateRoute: (settings) {
            if (settings.name == '/sales') {
              return MaterialPageRoute<void>(
                settings: settings,
                builder: (_) => const AppBackScope(
                  child: Scaffold(body: Text('sales')),
                ),
              );
            }
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => Scaffold(
                appBar: AppBar(),
                drawer: Drawer(
                  child: Builder(
                    builder: (context) {
                      return ListTile(
                        title: const Text('Sales'),
                        onTap: () =>
                            AppNavigation.navigateFromDrawer(context, '/sales'),
                      );
                    },
                  ),
                ),
                body: const Text('home'),
              ),
            );
          },
        ),
      );
      await tester.pumpAndSettle();

      tester.state<ScaffoldState>(find.byType(Scaffold)).openDrawer();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sales'));
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.text('sales'), findsOneWidget);
    },
  );

  testWidgets('back still works after the destination has settled', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const AppBackScope(
                      child: Scaffold(body: Text('destination')),
                    ),
                  ),
                );
              },
              child: const Text('open'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('destination'), findsOneWidget);

    Navigator.of(tester.element(find.text('destination'))).maybePop();
    await tester.pumpAndSettle();
    expect(find.text('destination'), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });
}
