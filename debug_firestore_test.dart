// TEMPORARY DEBUG TEST - Run this to check Firestore directly
import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> debugFirestorePermissions() async {
  final String userId = 'rSh419KqjBbA7197VNDwiFziqa52'; // ROLE user ID
  
  print('=== FIRESTORE DEBUG TEST ===');
  
  try {
    // Check gmanusers collection
    print('1. Checking gmanusers collection...');
    DocumentSnapshot userDoc = await FirebaseFirestore.instance
        .collection('gmanusers')
        .doc(userId)
        .get();
    
    if (userDoc.exists) {
      Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
      print('✅ User document exists in gmanusers');
      print('Role: ${userData['role']}');
      print('Permissions: ${userData['permissions']}');
      print('Full data: $userData');
    } else {
      print('❌ User document NOT found in gmanusers');
    }
    
    // Check employees subcollection
    print('\n2. Checking employees subcollection...');
    String businessId = 'I8zta2CuYb3LjDeeDIsi'; // From your logs
    
    DocumentSnapshot empDoc = await FirebaseFirestore.instance
        .collection('employees')
        .doc(businessId)
        .collection('userEmployees')
        .doc(userId)
        .get();
    
    if (empDoc.exists) {
      Map<String, dynamic> empData = empDoc.data() as Map<String, dynamic>;
      print('✅ Employee document exists in subcollection');
      print('Role: ${empData['role']}');
      print('Permissions: ${empData['permissions']}');
      print('Full data: $empData');
    } else {
      print('❌ Employee document NOT found in subcollection');
    }
    
    // Test manual update
    print('\n3. Testing manual permission update...');
    await FirebaseFirestore.instance
        .collection('gmanusers')
        .doc(userId)
        .set({
      'permissions': ['edit_business', 'make_sales', 'test_permission'],
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    
    print('✅ Manual update completed - check if this works');
    
  } catch (e) {
    print('❌ Error in debug test: $e');
  }
  
  print('=== DEBUG TEST COMPLETED ===');
}

// Call this function from somewhere in your app to test
