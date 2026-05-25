import 'package:get/get.dart';
import 'package:mauzo/models/payment_model.dart';
import 'package:mauzo/models/product_model.dart';
import 'package:mauzo/utils/preferences.dart';

import '../models/client_model.dart';
import '../models/supplier_model.dart';
import 'business_controller.dart';

class CartController extends GetxController {
  final BusinessController _businessController = Get.find();

  // * PRODUCTS
  final _products = <Product>[].obs;
  String origin = 'sale';
  String passedArgument = 'NOT';
  String editInvoice = 'NOT';
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

  /// When true, new lines and re-applied cart lines use wholesale catalog price; retail is the default.
  final useWholesalePricing = false.obs;

  /// Sum of line quantities for distinct products in the cart.
  double get totalCartItemQuantity {
    double sum = 0;
    for (final p in getUniqueProducts()) {
      sum += singleProductQuantity(p.id);
    }
    return sum;
  }

  /// True when every line quantity ≥ that product's wholesale minimum.
  bool get wholesaleThresholdMet {
    final lines = getUniqueProducts();
    if (lines.isEmpty) return false;
    for (final p in lines) {
      final base = singleProductQuantity(p.id);
      final minQ = p.effectiveWholesaleMinQuantity.toDouble();
      if (base + 1e-9 < minQ) return false;
    }
    return true;
  }

  /// User may turn wholesale on when each product meets its own minimum quantity.
  bool get canEnableWholesalePricing => wholesaleThresholdMet;

  /// Short summary for UI: "Name: 2 / 6, ..." for lines below their minimum.
  String wholesalePricingShortfallDescription() {
    final parts = <String>[];
    for (final p in getUniqueProducts()) {
      final minQ = p.effectiveWholesaleMinQuantity.toDouble();
      final base = singleProductQuantity(p.id);
      if (base + 1e-9 < minQ) {
        final cs = base == base.roundToDouble()
            ? base.toInt().toString()
            : base.toStringAsFixed(2);
        parts.add('$cs / ${minQ.toInt()} · ${p.name}');
      }
    }
    return parts.join('\n');
  }

  /// Persisted on each sale/invoice for audit.
  Map<String, dynamic> buildWholesalePricingAuditMap() {
    final lineAudits = getUniqueProducts().map((p) {
      final minQ = p.effectiveWholesaleMinQuantity;
      final cq = p.count;
      return {
        'productId': p.id,
        'productName': p.name,
        'lineQuantity': cq,
        'wholesaleMinQuantity': minQ,
        'meetsMin': cq >= minQ,
      };
    }).toList();
    return {
      'usedWholesalePricing': useWholesalePricing.value,
      'cartTotalQuantity': totalCartItemQuantity,
      'perProductThresholdMet': wholesaleThresholdMet,
      'lines': lineAudits,
    };
  }

  void setUseWholesalePricing(bool value) {
    if (value && !canEnableWholesalePricing) return;
    if (useWholesalePricing.value == value) return;
    useWholesalePricing.value = value;
    _reapplyPricingModeToCartLines();
  }

  /// If quantity drops below threshold, force retail pricing.
  void enforceWholesaleThreshold() {
    if (useWholesalePricing.value && !canEnableWholesalePricing) {
      useWholesalePricing.value = false;
      _reapplyPricingModeToCartLines();
    }
  }

  double defaultUnitSellingPrice(Product product) {
    return useWholesalePricing.value
        ? product.effectiveWholesalePrice
        : product.effectiveRetailPrice;
  }

  /// Net amount due after discount (what Imelipwa targets when changing selling total).
  double get netSaleTotal {
    final n = productsPrice - discount.value;
    return n < 0 ? 0 : n;
  }

  /// Label for net total row: markup (Imelipwa above catalog) → BEI MPYA; reduction → discounted price.
  String get netSaleSummaryLabelKey =>
      discount.value < -0.01 ? 'new_sale_price' : 'discounted_price';

  /// Imelipwa edits the sale total: above catalog uses negative discount; below catalog is partial pay.
  void applySellingTotalFromImelipwa(double amountMainCurrency) {
    if (!amountMainCurrency.isFinite || amountMainCurrency < 0) return;
    final double catalog = productsPrice;
    if (amountMainCurrency + 1e-9 >= catalog) {
      setDiscount(catalog - amountMainCurrency);
    } else {
      setDiscount(0);
    }
  }

  bool _isCustomUnitPrice(
    double enteredPrice,
    double retailBase,
    double wholesaleBase,
  ) {
    return (enteredPrice - retailBase).abs() > 1e-9 &&
        (enteredPrice - wholesaleBase).abs() > 1e-9;
  }

  double _asDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  double getPrice(String productId) {
    try {
      return _asDouble(productsPriceMap
          .firstWhere((element) => element['id'] == productId)['price']);
    } catch (e) {
      return 0;
    }
  }

  double getBuyingPrice(String productId) {
    try {
      return _asDouble(productsPriceMap
          .firstWhere((element) => element['id'] == productId)['buyingPrice']);
    } catch (e) {
      return 0;
    }
  }

  double getOriginalPrice(String productId) {
    try {
      return _asDouble(productsPriceMap
          .firstWhere((element) => element['id'] == productId)['originalPrice']);
    } catch (e) {
      return 0;
    }
  }

  void setProducts(List<Product> products, List<dynamic> productsMap) {
    productsPriceMap.value = [];
    for (var i = 0; i < products.length; i++) {
      final prod = products[i];
      Map<String, dynamic> raw = {};
      if (i < productsMap.length) {
        raw = Map<String, dynamic>.from(productsMap[i] as Map);
      }
      if (raw['id'] != null && raw['id'] != prod.id) {
        raw = {};
        for (final entry in productsMap) {
          final m = Map<String, dynamic>.from(entry as Map);
          if (m['id'] == prod.id) {
            raw = m;
            break;
          }
        }
      }
      final linePrice = (raw['price'] as num?)?.toDouble() ?? prod.price;
      final retail = (raw['retailPrice'] as num?)?.toDouble() ?? linePrice;
      final wholesale = (raw['wholesalePrice'] as num?)?.toDouble() ?? linePrice;
      productsPriceMap.add({
        'id': prod.id,
        'price': linePrice,
        'retailPrice': retail,
        'wholesalePrice': wholesale,
        'buyingPrice': raw['buyingPrice'] ?? prod.buyingPrice,
        'originalPrice': raw['originalPrice'] ?? retail,
        'customUnitPrice': raw['customUnitPrice'] == true ||
            _isCustomUnitPrice(linePrice, retail, wholesale),
      });
      // Cart line totals use [Product.count] (display qty), not shop [quantity].
      if (raw['quantity'] != null) {
        prod.count = (raw['quantity'] as num).toDouble();
      }
    }
    _products.value = products;
    enforceWholesaleThreshold();
    _products.refresh();
    productsPriceMap.refresh();
  }

  void clearSingleProduct(Product product) {
    _products.removeWhere((p) => p.id == product.id);
    productsPriceMap.removeWhere((e) => e['id'] == product.id);
    enforceWholesaleThreshold();
    _products.refresh();
    productsPriceMap.refresh();
  }

  void clearCart() {
    _products.clear();
    productsPriceMap.clear();
    useWholesalePricing.value = false;
  }

  void updateCart(
    Product product,
    double count,
    double price,
  ) {
    clearSingleProduct(product);
    productsPriceMap.removeWhere((e) => e['id'] == product.id);

    final retail = product.effectiveRetailPrice;
    final wholesale = product.effectiveWholesalePrice;

    productsPriceMap.add({
      'id': product.id,
      'price': price,
      'count': count,
      'retailPrice': retail,
      'wholesalePrice': wholesale,
      'originalPrice': retail,
      'buyingPrice': product.buyingPrice,
      'customUnitPrice': _isCustomUnitPrice(price, retail, wholesale),
    });

    product.count = count;
    _products.add(product);
    enforceWholesaleThreshold();
    _products.refresh();
    productsPriceMap.refresh();
  }

  /// When there is net amount due and no payment rows yet, add one full payment in main currency.
  /// Call after [updateCart] only when the cart subtotal was ~zero before the add (e.g. first line), so [scalePaymentsAfterLineTotalChange] is not applied on top of a freshly inserted full payment.
  void ensureDefaultPaymentWhenEmpty() {
    final double net = productsPrice - discount.value;
    if (net < 0.01) return;
    if (_payments.isNotEmpty) return;
    final String cur =
        (_businessController.business['mainCurrency'] ?? 'USD').toString();
    addPayment(net, cur, method: 'cash');
    _payments.refresh();
  }

  void _reapplyPricingModeToCartLines() {
    for (var i = 0; i < productsPriceMap.length; i++) {
      final e = Map<String, dynamic>.from(productsPriceMap[i] as Map);
      if (e['customUnitPrice'] == true) {
        productsPriceMap[i] = e;
        continue;
      }
      final retailBase = (e['retailPrice'] as num?)?.toDouble() ??
          (e['originalPrice'] as num?)?.toDouble() ??
          0.0;
      final wholesaleBase =
          (e['wholesalePrice'] as num?)?.toDouble() ?? retailBase;

      e['price'] =
          useWholesalePricing.value ? wholesaleBase : retailBase;
      productsPriceMap[i] = e;
    }
    productsPriceMap.refresh();
  }

  double get productsPrice {
    return _products.fold(
        0, (sum, product) => sum + (getPrice(product.id) * product.count));
  }

  double get productsBuyingPrice {
    double total = 0;
    for (var product in _products) {
      total += getBuyingPrice(product.id) * product.count;
    }
    return total;
  }

  double get productsOriginalPrice {
    return _products.fold(
        0, (sum, product) => sum + (getOriginalPrice(product.id) * product.count));
  }

  double singleProductQuantity(String productId) {
    final product = _products.firstWhere(
      (p) => p.id == productId,
      orElse: () => Product(
        owner: '',
        id: '',
        name: '',
        storeId: '',
        code: '',
        price: 0.0,
        wholesaleMinQuantity: Product.defaultWholesaleMinQuantity,
      ),
    );
    return product.count;
  }

  /// Same as [singleProductQuantity]; kept for call sites that referred to "base" stock units.
  double singleProductBaseQuantity(String productId) {
    return singleProductQuantity(productId);
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

  /// Replaces [method] on every payment row (amount/currency unchanged). Used when the user
  /// picks a fund source on the sale cart so rows created as `cash` still persist correctly.
  void applyFundSourceToAllPayments(String method) {
    final String m = method.trim().isEmpty ? 'cash' : method.trim();
    if (_payments.isEmpty) return;
    _payments.assignAll(
      _payments
          .map(
            (p) => Payment(
              amount: p.amount,
              currency: p.currency,
              method: m,
            ),
          )
          .toList(),
    );
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

  /// Amount still owed (debt). Never negative — overpayment / higher Imelipwa shows as 0 in Inayobaki.
  double get remaining {
    final double result = productsPrice - payment - discount.value;
    if (result < 0.01) return 0;
    return result;
  }

  void clearPayments() {
    _payments.clear();
  }

  /// After line qty/price changes, scale recorded payments so "paid" matches the new
  /// cart net (same ratio as old net). Call immediately after [updateCart].
  void scalePaymentsAfterLineTotalChange({required double previousProductsPrice}) {
    final d = discount.value;
    final oldNet = previousProductsPrice - d;
    final newNet = productsPrice - d;
    if (_payments.isEmpty || oldNet <= 1e-9) return;
    final ratio = newNet / oldNet;
    if (!ratio.isFinite || ratio < 0) return;
    final scaled = <Payment>[];
    for (final p in _payments) {
      final a = p.amount * ratio;
      scaled.add(Payment(
        amount: a < 0 ? 0 : a,
        currency: p.currency,
        method: p.method,
      ));
    }
    _payments.assignAll(scaled);
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
