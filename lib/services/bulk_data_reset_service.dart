import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:mauzo/controllers/auth_controller.dart';
import 'package:mauzo/utils/bulk_data_reset.dart';

class BulkDataResetService {
  BulkDataResetService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  static const int _pageSize = 400;
  static const String _verifyAppName = 'owner-password-verify';

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  Future<void> verifyOwnerPassword({
    required String ownerId,
    required String password,
  }) async {
    final trimmed = password.trim();
    if (trimmed.isEmpty) {
      throw FirebaseAuthException(
        code: 'wrong-password',
        message: 'Password is required.',
      );
    }
    if (ownerId.trim().isEmpty) {
      throw StateError('Owner ID is missing.');
    }

    final ownerSnap =
        await _firestore.collection('gmanusers').doc(ownerId.trim()).get();
    if (!ownerSnap.exists) {
      throw StateError('Owner profile was not found.');
    }
    final data = ownerSnap.data() ?? {};
    var email = (data['email'] ?? '').toString().trim();
    if (email.isEmpty) {
      final phone = (data['phone'] ?? '').toString();
      if (phone.isNotEmpty) {
        email = emailDerivedFromPhoneE164(phone);
      }
    }
    if (email.isEmpty) {
      throw StateError('Owner email was not found.');
    }

    final currentUid = _auth.currentUser?.uid;
    if (currentUid == ownerId.trim()) {
      final user = _auth.currentUser;
      if (user == null) {
        throw FirebaseAuthException(
          code: 'user-not-found',
          message: 'Not signed in.',
        );
      }
      final cred = EmailAuthProvider.credential(
        email: email,
        password: trimmed,
      );
      await user.reauthenticateWithCredential(cred);
      return;
    }

    final app = await _ownerVerifyApp();
    final secondaryAuth = FirebaseAuth.instanceFor(app: app);
    try {
      await secondaryAuth.signInWithEmailAndPassword(
        email: email,
        password: trimmed,
      );
    } finally {
      if (secondaryAuth.currentUser != null) {
        await secondaryAuth.signOut();
      }
    }
  }

  Future<int> run({
    required BulkDataResetAction action,
    required String businessId,
    required String ownerId,
  }) async {
    final targets = bulkDataResetTargets(
      action: action,
      businessId: businessId,
      ownerId: ownerId,
    );
    if (targets.isEmpty) {
      throw StateError('Business ID is missing.');
    }

    final deleteDocs = bulkDataResetDeletesDocuments(action);
    var changed = 0;
    for (final target in targets) {
      changed += await _processCollection(
        target: target,
        deleteDocs: deleteDocs,
      );
    }
    return changed;
  }

  Future<FirebaseApp> _ownerVerifyApp() async {
    for (final app in Firebase.apps) {
      if (app.name == _verifyAppName) return app;
    }
    return Firebase.initializeApp(
      name: _verifyAppName,
      options: Firebase.app().options,
    );
  }

  Future<int> _processCollection({
    required BulkCollectionTarget target,
    required bool deleteDocs,
  }) async {
    final col = _firestore
        .collection(target.collection)
        .doc(target.parentId)
        .collection(target.subcollection);

    QueryDocumentSnapshot<Map<String, dynamic>>? cursor;
    var changed = 0;
    while (true) {
      Query<Map<String, dynamic>> query = col.limit(_pageSize);
      if (!deleteDocs && cursor != null) {
        query = query.startAfterDocument(cursor);
      }
      final snap = await query.get();
      if (snap.docs.isEmpty) break;

      final batch = _firestore.batch();
      for (final doc in snap.docs) {
        if (deleteDocs) {
          batch.delete(doc.reference);
        } else {
          batch.update(doc.reference, {'quantity': 0});
        }
      }
      await batch.commit();
      changed += snap.docs.length;
      if (snap.docs.length < _pageSize) break;
      if (!deleteDocs) {
        cursor = snap.docs.last;
      }
    }
    return changed;
  }
}
