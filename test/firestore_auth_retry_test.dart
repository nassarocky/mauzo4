import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mauzo/utils/firestore_auth_retry.dart';

void main() {
  group('isFirestorePermissionDenied', () {
    test('detects FirebaseException permission-denied', () {
      final e = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
        message: 'Missing or insufficient permissions.',
      );
      expect(isFirestorePermissionDenied(e), isTrue);
    });

    test('detects message text', () {
      expect(
        isFirestorePermissionDenied(
          Exception('Missing or insufficient permissions'),
        ),
        isTrue,
      );
    });

    test('ignores other errors', () {
      final e = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unavailable',
      );
      expect(isFirestorePermissionDenied(e), isFalse);
    });
  });

  group('firestoreAuthRetryDelayMs', () {
    test('first attempt has no delay', () {
      expect(firestoreAuthRetryDelayMs(1), 0);
    });

    test('backoff grows then clamps', () {
      expect(firestoreAuthRetryDelayMs(2), 200);
      expect(firestoreAuthRetryDelayMs(3), 400);
      expect(firestoreAuthRetryDelayMs(4), 800);
      expect(firestoreAuthRetryDelayMs(5), 1600);
      expect(firestoreAuthRetryDelayMs(6), 2000);
    });
  });
}
