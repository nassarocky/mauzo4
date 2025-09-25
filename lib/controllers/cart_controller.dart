import 'package:get/get.dart';
import 'package:mauzo/controllers/profile_controller.dart';
import 'package:mauzo/models/payment_model.dart';
import 'package:mauzo/models/product_model.dart';
import 'package:mauzo/utils/preferences.dart';

import '../models/client_model.dart';
import '../models/supplier_model.dart';
import 'business_controller.dart';

class CartController extends GetxController {
  // * PRODUCTS
  final _products = <Product>[].obs;
  String origin='sale';
  String passedArgument='NOT';
  String editInvoice='NOT';
  get products => _products;
  getUniqueProducts() {
    var products = <Product>[];
    var productsId = <String>[];
    for (var product in _products) {
      if (!productsId.contains(product.id)) {
        if (product.id != '') {
          productsId.add(product.id);
          products.add(product);
        }
      }
    }
    return products;
  }

  final productsPriceMap = [].obs;

  double getPrice(String productId) {
    try {
      return productsPriceMap
          .firstWhere((element) => element['id'] == productId)['price'];
    } catch (e) {
      return 0;
    }
  }
  double getBuyingPrice(String productId) {
    try {
      return productsPriceMap
          .firstWhere((element) => element['id'] == productId)['buyingPrice'];
    } catch (e) {
      return 0;
    }
  }
  double getOriginalPrice(String productId) {
    try {
      return productsPriceMap
          .firstWhere((element) => element['id'] == productId)['originalPrice'];
    } catch (e) {
      return 0;
    }
  }


  setProducts(List<Product> products, List<dynamic> productsMap) {
    productsPriceMap.value = [];
    for (var product in productsMap) {
      productsPriceMap.add({
        'id': product['id'],
        'price': product['price'],
      });
    }
    _products.value = products;
  }

  void clearSingleProduct(Product product) {
    _products.removeWhere((p) => p.id == product.id);
  }

  void clearCart() {
    _products.clear();
  }

  void updateCart(Product product, double count, double price) {
    clearSingleProduct(product);
    for (int i = 0; i < productsPriceMap.length; i++) {
      if (productsPriceMap[i]['id'] == product.id) {
        productsPriceMap.remove(productsPriceMap[i]);
      }
    }
    productsPriceMap.add({
      'id': product.id,
      'price': price,
      'count':count,
      'originalPrice': product.price,
      'buyingPrice': product.buyingPrice
    });

    product.count=count;
    _products.add(product);


    // Preserve existing payments to avoid wiping selected methods during edits.
    // If no payments yet, initialize with a single payment equal to remaining.
    if (_payments.isEmpty) {
      addPayment(remaining, _businessController.business['mainCurrency']);
    }
  }


  double get productsPrice {
    return _products.fold(0, (sum, product) => sum + (getPrice(product.id)*product.count));
  }
  double get productsBuyingPrice {
    return _products.fold(0, (sum, product) => sum + (getBuyingPrice(product.id)*product.count));
  }
  double get productsOriginalPrice {
    return _products.fold(0, (sum, product) => sum + (getOriginalPrice(product.id)*product.count));
  }


  double singleProductQuantity(String productId) {
    final product = _products.firstWhere(
          (p) => p.id == productId,
      orElse: () => Product(
        owner: '',
        id: '',
        name: '',
        storeId:'',
        code: '',
        price: 0.0, // Default price to 0.0
      ),
    );
    return product.count;
  }




  // * CLIENT
  Client? client;
  void setClient(Client client) {
    this.client = client;
  }

  void clearClient() {
    client = null;
    update();
  }

  // * SUPPLIER
  Supplier? supplier;
  void setSupplier(Supplier supplier) {
    this.supplier = supplier;
  }

  void clearSupplier() {
    supplier = null;
    update();
  }

  // * PAYMENT
  final BusinessController _businessController = Get.find();
  final _payments = <Payment>[].obs;
  get payments => _payments;

  void addPayment(double amount, String currency, {String method = 'cash'}) {
    if (_payments.length < 4) {
      _payments.add(
        Payment(
          amount: amount,
          currency: currency,
          method: method,
        ),
      );
    }
  }

  double get payment {
    double sum = 0;
    for (var payment in _payments) {
      if (payment.currency == _businessController.business['mainCurrency']) {
        sum += payment.amount;
      } else {
        sum += payment.amount * Preferences.getExchangeRateResult();
      }
    }
    return sum;
  }

  double get remaining {
    double result = productsPrice - payment - discount.value;
    return result < 0.01 ? 0 : result;
  }

  void clearPayments() {
    _payments.clear();
  }

  // * COMMENT
  final _comment = ''.obs;
  get comment => _comment.value;
  void setComment(String comment) {
    _comment.value = comment;
  }

  void clearComment() {
    _comment.value = '';
  }

  // * DISCOUNT
  final discount = 0.0.obs;

  void setDiscount(double discount) {
    this.discount.value = discount;
  }

  void clearDiscount() {
    discount.value = 0.0;
    discount.value = 0.0;
  }
}