import 'package:flutter/material.dart';

class TestDialog extends StatelessWidget {
  const TestDialog({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Test Dialog'),
      content: const Text('This is a test to check if buttons work'),
      actions: [
        TextButton(
          onPressed: () {
            print('=== TEST BUTTON WORKS ===');
            Navigator.of(context).pop();
          },
          child: const Text('Test Button'),
        ),
      ],
    );
  }
}
