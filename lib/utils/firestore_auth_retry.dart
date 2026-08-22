import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Windows/desktop (and occasionally other platforms) can sign in successfully
/// while the first Firestore reads still see no auth token → permission-denied.
/// Refresh the ID token and retry with short backoff.
Future<void> ensureFirestoreAuthTokenReady([User? user]) async {
  final u = user ?? FirebaseAuth.instance.currentUser;
  if (u == null) return;
  await u.getIdToken(true);
  // Give the Firestore web channel a moment to pick up the new token.
  await Future<void>.delayed(const Duration(milliseconds: 250));
  try {
    await FirebaseAuth.instance
        .authStateChanges()
        .firstWhere((x) => x?.uid == u.uid)
        .timeout(const Duration(seconds: 3));
  } catch (_) {
    // Timeout is fine — token refresh above is the important part.
  }
  try {
    await FirebaseAuth.instance
        .idTokenChanges()
        .firstWhere((x) => x?.uid == u.uid)
        .timeout(const Duration(seconds: 3));
  } catch (_) {
    /* ignore */
  }
}

bool isFirestorePermissionDenied(Object e) {
  if (e is FirebaseException) {
    return e.code == 'permission-denied';
  }
  final text = e.toString();
  return text.contains('permission-denied') ||
      text.contains('Missing or insufficient permissions');
}

/// Delay before retry attempt [attempt] (1-based). Attempt 2 → 200ms, then 400, 800…
int firestoreAuthRetryDelayMs(int attempt) {
  if (attempt <= 1) return 0;
  final delayMs = 200 * (1 << (attempt - 2));
  return delayMs.clamp(200, 2000);
}

/// [get] with auth-token refresh retries on permission-denied.
Future<DocumentSnapshot<T>> firestoreGetWithAuthRetry<T extends Object?>(
  DocumentReference<T> ref, {
  int maxAttempts = 5,
  User? user,
}) async {
  Object? lastError;
  for (var attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      if (attempt > 1) {
        await ensureFirestoreAuthTokenReady(user ?? FirebaseAuth.instance.currentUser);
        final delayMs = firestoreAuthRetryDelayMs(attempt);
        await Future<void>.delayed(Duration(milliseconds: delayMs));
      }
      return await ref.get();
    } catch (e) {
      lastError = e;
      if (!isFirestorePermissionDenied(e) || attempt == maxAttempts) {
        rethrow;
      }
      debugPrint(
        'Firestore permission-denied on ${ref.path} (attempt $attempt/$maxAttempts); retrying…',
      );
    }
  }
  // Unreachable, but keeps the analyzer happy.
  throw lastError ?? StateError('firestoreGetWithAuthRetry failed');
}
