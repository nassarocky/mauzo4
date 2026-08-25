import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mauzo/ui/widgets/buttons/primary_button.dart';

void main() {
  testWidgets('loading button shows progress and blocks repeated taps', (
    tester,
  ) async {
    var presses = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PrimaryButton(
            text: 'Save',
            isLoading: true,
            onPressed: () => presses++,
          ),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();
    expect(presses, 0);
  });
}
