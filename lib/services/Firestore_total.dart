import 'package:get/get.dart';
import 'package:mauzo/controllers/profile_controller.dart';
import '../controllers/business_controller.dart';
import '../models/product_model.dart';
import '../utils/constants.dart';

class FirestoreTotal {
  // * Initialize Firestore
  final BusinessController _businessController = Get.find();

  // * PRODUCT
  Stream<List<Product>> getProductTotal() {
    final String? business = _businessController.businessId.value;

    if (business == null) {
      print('Owner ID is null, returning empty stream.');
      return Stream.value([]);
    }

    return firestore
        .collection('products')
        .doc(business)
        .collection('userProducts')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map((doc) => Product.fromSnapshot(doc)).toList(),
    );
  }
}
