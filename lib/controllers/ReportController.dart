import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'business_controller.dart';

class ReportController extends GetxController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final BusinessController _businessController = Get.find();
  var isLoading = false.obs;
  var reports = [].obs;
  var selectedDate = DateTime.now().obs;

  @override
  void onInit() {
    super.onInit();
    fetchReports(selectedDate.value);
  }

  Future<void> fetchReports(DateTime date) async {
    isLoading.value = true;
    try {
      String dateStr = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
      final String? businessId = _businessController.business['id'];
      QuerySnapshot snapshot = await _firestore
          .collection('productReports')
          .doc(businessId) // Replace with actual businessId
          .collection('userReports')
          .where('reportDate', isEqualTo: dateStr)
          .get();

      reports.value = snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      print("Error fetching reports: $e");
    } finally {
      isLoading.value = false;
    }
  }

  void selectDate(BuildContext context) async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: selectedDate.value,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (pickedDate != null) {
      selectedDate.value = pickedDate;
      fetchReports(pickedDate);
    }
  }
}
