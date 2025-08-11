import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:mauzo/models/profile_model.dart';
import '../utils/constants.dart';

class ProfileController extends GetxController {
  /// Centralized permission check
  bool hasPermission(String permission) {
    final user = this.user;
    String role = user['role'] ?? '';
    
    // Legacy support: treat 'employee' as 'sales_person'
    if (role == 'employee') role = 'sales_person';
    
    // Custom permissions override
    final List perms = user['permissions'] ?? [];
    if (perms.contains(permission)) return true;
    final Map<String, List<String>> rolePermissions = {
      'owner': ['all'],
      'manager': [
        'view_products', 'edit_products', 'make_sales', 'view_sales', 'view_sales_own',
        'manage_clients', 'manage_suppliers', 'edit_invoices', 'manage_expenses',
        'view_reports', 'edit_business', 'edit_home', 'create_invoices', 'transfer_products',
        'manage_transfers', 'view_statistics', 'manage_categories', 'view_transactions',
        'manage_debt', 'print_invoices', 'share_invoices', 'buy_products'
      ],
      'cashier': [
        'view_products', 'make_sales', 'view_sales_own', 'manage_clients', 'create_invoices',
        'print_invoices', 'share_invoices'
      ],
      'sales_person': [
        'view_products', 'make_sales', 'view_sales_own', 'manage_clients', 'create_invoices',
        'print_invoices', 'share_invoices', 'buy_products'
      ],
      'agent': [
        'view_products', 'view_sales', 'view_reports', 'view_statistics'
      ]
    };
    // Owner can do everything
    if (role == 'owner' || (rolePermissions[role]?.contains('all') ?? false)) {
      return true;
    }
    
    // Check role-based permissions
    return rolePermissions[role]?.contains(permission) ?? false;
  }

  final Rx<Map<String, dynamic>> _user = Rx<Map<String, dynamic>>({});
  Map<String, dynamic> get user => _user.value;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Rx<String> emailId = "".obs;
  final Rx<String> role = "".obs;
  updateUserEmail(String emailIdd) async {
    emailId.value = emailIdd;
    await updateUserData(); // Calling updatebusinessData to fetch business info and set selectedBusinessId
  }
  void clearUser() {
    _user.value.clear(); // Clear the contents of the reactive map
    emailId.value = '';
    role.value='';// Reset the reactive businessId
  }
  
  /// Refresh user data from Firestore (useful after admin updates)
  Future<void> refreshUserData() async {
    await updateUserData();
  }
  

  updateUserData() async {
    try {
      String uid = _auth.currentUser?.uid ?? '';

      if (uid.isNotEmpty) {
        var snapshot = await firestore
            .collection('gmanusers')
            .doc(uid) // ✅ correct document reference
            .get();

        if (snapshot.exists) {
          var user = ProfileModel.fromSnapshot(snapshot);

          _user.value = {
            'name': user.name,
            'business': user.business,
            'image': user.image,
            'phone': user.phone,
            'maxBusiness': user.maxBusiness,
            'role': user.role,
            'password': user.password,
            'id': user.id,
            'date': user.date,
            'email': user.email, // you can store the email here
            'permissions': user.permissions, // Include permissions in user data
          };

          role.value = user.role;
        } else {
          errorSnackbar('No user found with the provided uid: $uid');
        }
      } else {
        errorSnackbar('User is not authenticated.');
      }
    } catch (e) {
      errorSnackbar('Error: $e');
    }

    update();
  }

}
