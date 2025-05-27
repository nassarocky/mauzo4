import 'dart:async';
import 'dart:convert';
import 'package:get/get.dart';
import 'package:mauzo/controllers/business_controller.dart';
import 'package:mauzo/models/profile_model.dart';
import '../services/firestore_db.dart';
import '../utils/constants.dart';
import 'package:http/http.dart' as http;

class EmployeeController extends GetxController {
  final BusinessController _businessController = Get.find();

  final employees = <ProfileModel>[].obs;
  final searchEmployees = <ProfileModel>[].obs;
  final sortCategory = 'name'.obs;

  StreamSubscription<List<ProfileModel>>? _employeeSubscription;

  @override
  void onInit() {
    super.onInit();
    try {
      _employeeSubscription = FirestoreDb().getEmployee().listen((data) {
        employees.value = data;
        searchEmployees.value = data;
      });
    } catch (e) {
      print("Error initializing EmployeeController: $e");
    }
  }

  @override
  void onClose() {
    _employeeSubscription?.cancel();
    super.onClose();
  }



  ProfileModel getEmployee(String clientId) {
    return employees.firstWhere((client) => client.id == clientId,
        orElse: () => ProfileModel(
          role: '',
          id: '',
          password: '',
          email: '',
          name: '',
          phone: '',
          date: DateTime.now(),
        ));
  }

// Function to call the Cloud Function for deleting a user
  Future<void> deleteUser({
    required String userId,
    required String businessId,
  }) async {
    final Uri url = Uri.parse(
        'https://us-central1-hesabumauzo.cloudfunctions.net/deleteUser');
    try {

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
          'businessId': businessId,

        }),
      );
      // Handle successful response
      if (response.statusCode == 200) {
        successSnackbar('User successfully deleted!');
      }
      // Handle error cases
      else if (response.statusCode == 400) {
        final error = jsonDecode(response.body)['error'];
        errorSnackbar('Error400: $error');
      } else {
        errorSnackbar('Failed to delete user. Please try again later.');
      }
    } catch (e) {
      // Handle network or server errors
      errorSnackbar('Error: ${e.toString()}');
    }
  }


  void search(String searchText) {
    searchEmployees.value = employees
        .where((employee) =>
        employee.name.toLowerCase().contains(searchText.toLowerCase()))
        .toList();
  }

  void clearEmployee(){
    employees.value.clear();
    searchEmployees.value.clear();
  }

}
