import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:get/get.dart';
import 'package:mauzo/models/sms_pack_model.dart';

class SmsReminderService {
  SmsReminderService({
    FirebaseFunctions? functions,
    FirebaseFirestore? firestore,
  })  : _functions = functions ??
            FirebaseFunctions.instanceFor(region: 'us-central1'),
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFunctions _functions;
  final FirebaseFirestore _firestore;

  Future<List<SmsPack>> loadPacks() async {
    try {
      final doc = await _firestore.collection('smsPricing').doc('config').get();
      final packs = doc.data()?['packs'];
      if (packs is List && packs.isNotEmpty) {
        return packs
            .whereType<Map>()
            .map((e) => SmsPack.fromMap(Map<String, dynamic>.from(e)))
            .where((p) => p.id.isNotEmpty && p.credits > 0 && p.price > 0)
            .toList();
      }
    } catch (_) {
      // Fall back to built-in packs sold by Hesabu Mauzo.
    }
    return SmsPack.defaults;
  }

  Future<Map<String, dynamic>> sendReminders({
    required String businessId,
    required List<String> clientIds,
    String lang = 'sw',
  }) async {
    final result = await _functions.httpsCallable('sendDebtReminderSms').call({
      'businessId': businessId,
      'clientIds': clientIds,
      'lang': lang,
    });
    final data = result.data;
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return {'success': false};
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> logs(String businessId) {
    return _firestore
        .collection('smsLogs')
        .doc(businessId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots();
  }
}

String smsFunctionErrorMessage(Object error) {
  if (error is FirebaseFunctionsException) {
    return error.message?.trim().isNotEmpty == true
        ? error.message!
        : (error.code);
  }
  return error.toString();
}
