enum BulkDataResetAction {
  deleteStocks,
  zeroStocks,
  deleteSales,
  deleteExpenses,
}

class BulkCollectionTarget {
  final String collection;
  final String parentId;
  final String subcollection;

  const BulkCollectionTarget({
    required this.collection,
    required this.parentId,
    required this.subcollection,
  });

  String get path => '$collection/$parentId/$subcollection';
}

/// Owner and manager only. Legacy `employee` is treated as sales staff.
bool canPerformBulkDataReset(String? role) {
  var normalized = (role ?? '').trim().toLowerCase();
  if (normalized == 'employee') normalized = 'sales_person';
  return normalized == 'owner' || normalized == 'manager';
}

List<BulkCollectionTarget> bulkDataResetTargets({
  required BulkDataResetAction action,
  required String businessId,
  required String ownerId,
}) {
  final business = businessId.trim();
  final owner = ownerId.trim();
  switch (action) {
    case BulkDataResetAction.deleteStocks:
    case BulkDataResetAction.zeroStocks:
      return [
        if (business.isNotEmpty)
          BulkCollectionTarget(
            collection: 'products',
            parentId: business,
            subcollection: 'userProducts',
          ),
        if (owner.isNotEmpty)
          BulkCollectionTarget(
            collection: 'store',
            parentId: owner,
            subcollection: 'userStore',
          ),
      ];
    case BulkDataResetAction.deleteSales:
      return [
        if (business.isNotEmpty)
          BulkCollectionTarget(
            collection: 'sales',
            parentId: business,
            subcollection: 'userSales',
          ),
      ];
    case BulkDataResetAction.deleteExpenses:
      return [
        if (business.isNotEmpty)
          BulkCollectionTarget(
            collection: 'expenses',
            parentId: business,
            subcollection: 'userExpenses',
          ),
      ];
  }
}

bool bulkDataResetDeletesDocuments(BulkDataResetAction action) {
  return action != BulkDataResetAction.zeroStocks;
}
