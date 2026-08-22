import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:get/get.dart';
import 'package:mauzo/models/sms_pack_model.dart';
import 'package:mauzo/utils/sms_settings.dart';

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
            .where((p) => p.id.isNotEmpty && p.credits >= 100)
            .map((p) {
              final priced = SmsPack.priceForCredits(p.credits);
              return SmsPack(
                id: p.id,
                credits: p.credits,
                price: priced > 0 ? priced : p.price,
                label: p.label,
              );
            })
            .where((p) => p.price > 0)
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

  Future<Map<String, dynamic>> sendBusinessSms({
    required String businessId,
    required String type,
    String? phone,
    String? clientId,
    String? supplierId,
    String? clientName,
    String? supplierName,
    double? amount,
    double? remaining,
    List<Map<String, dynamic>>? lines,
    String lang = 'sw',
    String? message,
  }) async {
    final result = await _functions.httpsCallable('sendBusinessSms').call({
      'businessId': businessId,
      'type': type,
      if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
      if (clientId != null && clientId.isNotEmpty) 'clientId': clientId,
      if (supplierId != null && supplierId.isNotEmpty) 'supplierId': supplierId,
      if (clientName != null) 'clientName': clientName,
      if (supplierName != null) 'supplierName': supplierName,
      if (amount != null) 'amount': amount,
      if (remaining != null) 'remaining': remaining,
      if (lines != null) 'lines': lines,
      'lang': lang,
      if (message != null && message.trim().isNotEmpty) 'message': message.trim(),
    });
    final data = result.data;
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return {'success': false};
  }

  Future<SmsSettings> saveSettings({
    required String businessId,
    required SmsSettings settings,
  }) async {
    final result = await _functions.httpsCallable('updateSmsSettings').call({
      'businessId': businessId,
      'settings': settings.toMap(),
    });
    final data = result.data;
    if (data is Map && data['settings'] is Map) {
      // Prefer values we just sent so older function builds cannot drop new flags.
      return SmsSettings.fromMap({
        ...Map<String, dynamic>.from(data['settings'] as Map),
        ...settings.toMap(),
      });
    }
    return settings;
  }

  Future<bool> tryNotify({
    required String businessId,
    required String type,
    String? phone,
    String? clientId,
    String? supplierId,
    String? clientName,
    String? supplierName,
    double? amount,
    double? remaining,
    List<Map<String, dynamic>>? lines,
    String lang = 'sw',
  }) async {
    try {
      final result = await sendBusinessSms(
        businessId: businessId,
        type: type,
        phone: phone,
        clientId: clientId,
        supplierId: supplierId,
        clientName: clientName,
        supplierName: supplierName,
        amount: amount,
        remaining: remaining,
        lines: lines,
        lang: lang,
      );
      return result['success'] == true;
    } catch (e) {
      print('SMS notify failed: $e');
      return false;
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> logs(String businessId) {
    return _firestore
        .collection('smsLogs')
        .doc(businessId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .limit(20)
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
