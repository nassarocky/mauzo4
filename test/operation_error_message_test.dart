import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mauzo/utils/operation_error_message.dart';

void main() {
  test('shows internet guidance for unavailable Firebase operations', () {
    final error = FirebaseException(
      plugin: 'cloud_firestore',
      code: 'unavailable',
      message: 'The service is unavailable.',
    );

    expect(operationErrorMessage(error), internetRequiredMessage);
  });

  test('preserves non-network operation errors', () {
    expect(
      operationErrorMessage(Exception('Insufficient stock')),
      contains('Insufficient stock'),
    );
  });

  test('shows internet guidance when server connectivity check times out', () {
    expect(
      operationErrorMessage(TimeoutException('server check')),
      internetRequiredMessage,
    );
  });
}
