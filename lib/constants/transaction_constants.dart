/// Transaction origin constants for standardized transaction tracking
class TransactionOrigins {
  // Stock management
  static const String openingStock = 'Opening Stock';
  static const String manualAdjustment = 'Manual Adjustment';
  
  // Sales related
  static const String sale = 'Sale';
  /// Stock restored when a sale document is deleted (distinct from [sale]).
  static const String saleDeleted = 'Sale deleted';
  static const String saleReturn = 'Sale Return';
  static const String saleEdit = 'Sale Edit';
  
  // Purchase related
  static const String purchase = 'Purchase';
  static const String purchaseReturn = 'Purchase Return';
  static const String purchaseEdit = 'Purchase Edit';
  
  // Transfer related
  static const String transferIn = 'Transfer In';
  static const String transferOut = 'Transfer Out';
  static const String batchTransferIn = 'Batch Transfer In';
  static const String batchTransferOut = 'Batch Transfer Out';
  static const String storeTransfer = 'Store Transfer';
  
  // Loss/Damage related
  static const String damaged = 'Damaged';
  static const String expired = 'Expired';
  static const String stolen = 'Stolen/Lost';
  static const String spoiled = 'Spoiled';
  
  // Other
  static const String other = 'Other';
  
  // Legacy support (for backward compatibility with old data)
  static const String edit = 'Edit';  // Old generic edit
}

/// Transaction type constants
class TransactionTypes {
  static const String addition = 'addition';
  static const String removal = 'removal';
}

/// Reference type constants for linking transactions to source documents
class TransactionReferenceTypes {
  static const String sale = 'sale';
  static const String purchase = 'purchase';
  static const String transfer = 'transfer';
  static const String manual = 'manual';
  static const String adjustment = 'adjustment';
}
