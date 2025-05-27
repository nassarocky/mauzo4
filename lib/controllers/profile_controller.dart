import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:mauzo/models/profile_model.dart';
import '../utils/constants.dart';

class ProfileController extends GetxController {
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
  updateUserData() async {
    try {
      String uid = _auth.currentUser?.uid ?? '';

      if (uid.isNotEmpty) {
        print('Authenticated profile user id: $uid'); // Debugging line

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
          };

          role.value = user.role;
        } else {
          print('No user found with the provided uid: $uid');
        }
      } else {
        errorSnackbar('User is not authenticated.');
        print('User is not authenticated.');
      }
    } catch (e) {
      errorSnackbar('Error: $e');
      print('Error: $e');
    }

    update();
  }

}
