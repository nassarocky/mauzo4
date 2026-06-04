import '../models/product_model.dart';

/// Helpers for paired (twin) products — e.g. filled cylinder ↔ empty cylinder.
class PairedProductService {
  PairedProductService._();

  static const String typeNormal = 'normal';
  static const String typePaired = 'paired';

  /// Main paired product (sells/consumes twin on linked stock moves).
  static bool isPairedMain(Product p) =>
      p.productType == typePaired &&
      p.twinProductId != null &&
      p.twinProductId!.isNotEmpty;

  static bool isTwin(Product p) => p.isTwinProduct;

  /// Sort: services first, then each main immediately followed by its twin.
  static List<Product> sortForDisplay(List<Product> products) {
    final list = List<Product>.from(products);
    list.sort((a, b) {
      if (a.itemType == 'service' && b.itemType != 'service') return -1;
      if (a.itemType != 'service' && b.itemType == 'service') return 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    final byId = {for (final p in list) p.id: p};
    final result = <Product>[];
    final added = <String>{};

    for (final p in list) {
      if (isTwin(p) || added.contains(p.id)) continue;
      result.add(p);
      added.add(p.id);
      final twinId = p.twinProductId;
      if (isPairedMain(p) && twinId != null && twinId.isNotEmpty) {
        final twin = byId[twinId];
        if (twin != null && !added.contains(twin.id)) {
          result.add(twin);
          added.add(twin.id);
        }
      }
    }

    for (final p in list) {
      if (!added.contains(p.id)) {
        result.add(p);
        added.add(p.id);
      }
    }
    return result;
  }

  /// Twin stock delta when main stock moves (sale: +delta on twin, purchase: -delta).
  static double? twinDeltaForMainMovement({
    required Product main,
    required double mainQuantityChange,
  }) {
    if (!isPairedMain(main) || mainQuantityChange == 0) return null;
    // Main decreased → twin increases (sale). Main increased → twin decreases (purchase).
    return -mainQuantityChange;
  }
}
