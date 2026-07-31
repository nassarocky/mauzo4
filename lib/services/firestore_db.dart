import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart' show DateUtils;
import 'package:get/get.dart';
import 'package:mauzo/controllers/profile_controller.dart';
import 'package:mauzo/models/business_model.dart';
import 'package:mauzo/models/client_model.dart';
import 'package:mauzo/models/supplier_model.dart';
import 'package:mauzo/models/profile_model.dart';
import 'package:mauzo/models/sale_model.dart';
import '../controllers/business_controller.dart';
import '../models/close_book_model.dart';
import '../models/aggregates.dart';
import '../models/debtHistory_model.dart';
import '../models/expences.dart';
import '../models/product_model.dart';
import '../models/product_transfer_request.dart';
import '../models/stock_transaction.dart';
import '../utils/constants.dart';

class FirestoreDb {
  // * Initialize Firestore
  final ProfileController _profileController = Get.find();
  final BusinessController _businessController = Get.find();



  
  /// NEW: Get transactions for a specific product only (Lazy Loading)
  /// This reduces database reads by only loading what's needed
  Stream<List<StockTransaction>> getTransactionsByProduct(String productId) {
    final String? business = _businessController.businessId.value;

    if (business == null || business.isEmpty) {
      print('❌ Business ID is null, returning empty transactions.');
      return Stream.value([]);
    }
    
    print('🔍 Fetching transactions for product: $productId in business: $business');

    return firestore
        .collection('transactions')
        .doc(business)
        .collection('usersTransactions')
        .where('productId', isEqualTo: productId)  // ✅ Filter by product
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      print('✅ Received ${snapshot.docs.length} transactions for product $productId');
      return snapshot.docs.map((doc) {
        return StockTransaction.fromSnapshot(doc);
      }).toList();
    }).handleError((error) {
      print('❌ Error fetching transactions for product $productId: $error');
    });
  }

// * BUSINESS
  Stream<List<BusinessModel>> getBusiness() {
    print('Fetching BUSINESS for owner:${_profileController.user['id']}');
    if (_profileController.user['business'].isEmpty) {
      print('Business ID list is empty, returning empty Business.');
      return Stream.value([]);
    }

    return firestore
        .collection('businesses')
        .where(FieldPath.documentId, whereIn: _profileController.user['business'])
        .snapshots()
        .map((snapshot) {
      print('Received Business with ${snapshot.docs.length} documents');
      return snapshot.docs.map((doc) {
        print('Processing Business with ID: ${doc.id}');
        return BusinessModel.fromSnapshot(doc); // Assuming you have a method to convert doc to BusinessModel
      }).toList();
    }).handleError((error) {
      print('Error fetching businesses: $error');
    });
  }
  Stream<List<Product>> getReport() {
    final String? business = _businessController.businessId.value;


    if (business!.isEmpty) {
      print('Owner ID is null, returning empty productos.');
      return Stream.value([]);
    }

    print('Fetching productos for owner: $business');

    return firestore
        .collection('productReports')
        .doc(business)
        .collection('userReports')
        .snapshots()
        .map((snapshot) {
      final products = snapshot.docs
          .map((doc) => Product.fromSnapshot(doc))
          .toList();
      products.sort((a, b) => a.name.compareTo(b.name));
      return products;
    }).handleError((error) {
      Get.snackbar(
        'Error',
        'Error: $error',
        snackPosition: SnackPosition.BOTTOM,
        duration: Duration(seconds: 10),
      );
      print('Error fetching products: $error');
    });
  }

  Stream<List<Product>> getProducts() {
    final String? business = _businessController.businessId.value;


    if (business!.isEmpty) {
      print('Owner ID is null, returning empty productos.');
      return Stream.value([]);
    }

    return firestore
        .collection('products')
        .doc(business)
        .collection('userProducts')
        .snapshots()
        .map((snapshot) {
      final products = snapshot.docs
          .map((doc) => Product.fromSnapshot(doc))
          .toList();
      products.sort((a, b) => a.name.compareTo(b.name));
      return products;
    }).handleError((error) {
      Get.snackbar(
        'Error',
        'Error: $error',
        snackPosition: SnackPosition.BOTTOM,
        duration: Duration(seconds: 10),
      );
      print('Error fetching products: $error');
    });
  }
  Stream<List<Product>> getProductInStore() {
    final String? storeId = _businessController.business['owner'];

    if (storeId!.isEmpty) {
      print('Owner ID is null, returning empty productos.');
      return Stream.value([]);
    }

    return firestore
        .collection('store')
        .doc(storeId)
        .collection('userStore')
        .snapshots()
        .map((snapshot) {
      final products = snapshot.docs
          .map((doc) => Product.fromSnapshot(doc))
          .toList();
      products.sort((a, b) => a.name.compareTo(b.name));
      return products;
    }).handleError((error) {
      Get.snackbar(
        'Error',
        'Error: $error',
        snackPosition: SnackPosition.BOTTOM,
        duration: Duration(seconds: 10),
      );
      print('Error fetching products: $error');
    });
  }
  Stream<List<CloseBook>> getClosedBooks() {
    final String? business = _businessController.businessId.value;

    if (business!.isEmpty) {
      print('Business ID is null, returning empty ClosedBooks.');
      return Stream.value([]);
    }

    print('Fetching closed books for ClosedBooks: $business');

    return firestore
        .collection('closedbooks')
        .doc(business)
        .collection('userClosedBooks')
        .orderBy('createdAt', descending: true)  // Sorting by createdDate in descending order
        .snapshots()
        .map((snapshot) {
      print('Received ClosedBooks with ${snapshot.docs.length} documents');
      List<CloseBook> books = snapshot.docs.map((doc) {
        print('Processing ClosedBooks with ID: ${doc.id}');
        return CloseBook.fromSnapshot(doc);  // Convert Firestore document to Book model
      }).toList();

      return books;
    }).handleError((error) {
      Get.snackbar(
        'Error',
        'Error: $error',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 10),
      );
      print('Error fetching closed books: $error');
    });
  }

  /// Period start for default sales/purchases lists.
  /// Uses business [reset_time], or start of today if missing — never "all history".
  Timestamp defaultListPeriodStart() {
    final dynamic raw = _businessController.business['reset_time'];
    if (raw is Timestamp) return raw;
    if (raw is DateTime) return Timestamp.fromDate(raw);
    return Timestamp.fromDate(DateUtils.dateOnly(DateTime.now()));
  }

  // * SALE
  Stream<List<Sale>> getSales() {

    final String? business = _businessController.businessId.value;
    if (business!.isEmpty) {
      print('Owner ID is null, returning empty Sales.');
      return Stream.value([]);
    }

    final Timestamp resetTime = defaultListPeriodStart();
    print('Fetching sales from reset time: ${resetTime.toDate()} for owner: $business');

    // Query sales where date >= resetTime (optimized to reduce reads)
    return firestore
        .collection('sales')
        .doc(business)
        .collection('userSales')
        .where('date', isGreaterThanOrEqualTo: resetTime)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
      print('Received Sales with ${snapshot.docs.length} documents (from reset time)');
      return snapshot.docs.map((doc) {
        return Sale.fromSnapshot(doc);
      }).toList();
    })
        .handleError((error) {
      print('Error fetching sales: $error');
    });
  }

  // Query sales by specific date range (for filtering)
  Stream<List<Sale>> getSalesByDateRange(DateTime startDate, DateTime endDate) {
    final String? business = _businessController.businessId.value;
    if (business!.isEmpty) {
      print('Owner ID is null, returning empty Sales.');
      return Stream.value([]);
    }

    final Timestamp startTimestamp = Timestamp.fromDate(startDate);
    final Timestamp endTimestamp = Timestamp.fromDate(endDate.add(const Duration(days: 1)));

    print('Fetching sales from $startDate to $endDate for owner: $business');

    return firestore
        .collection('sales')
        .doc(business)
        .collection('userSales')
        .where('date', isGreaterThanOrEqualTo: startTimestamp)
        .where('date', isLessThan: endTimestamp)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
      print('Received ${snapshot.docs.length} sales in date range');
      return snapshot.docs.map((doc) {
        return Sale.fromSnapshot(doc);
      }).toList();
    })
        .handleError((error) {
      print('Error fetching sales by date range: $error');
    });
  }

  // Get ALL sales without reset_time filter (for statistics)
  Stream<List<Sale>> getAllSalesForStatistics() {
    final String? business = _businessController.businessId.value;
    if (business!.isEmpty) {
      print('Business ID is null, returning empty Sales.');
      return Stream.value([]);
    }

    print('Fetching ALL sales for statistics (no reset_time filter) for business: $business');

    return firestore
        .collection('sales')
        .doc(business)
        .collection('userSales')
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
      print('Received ${snapshot.docs.length} total sales for statistics');
      return snapshot.docs.map((doc) {
        return Sale.fromSnapshot(doc);
      }).toList();
    })
        .handleError((error) {
      print('Error fetching all sales for statistics: $error');
    });
  }

  Stream<List<Sale>> getBought() {

    final String? business = _businessController.businessId.value;
    if (business!.isEmpty) {
      print('Owner ID is null, returning empty Recovered.');
      return Stream.value([]);
    }

    final Timestamp resetTime = defaultListPeriodStart();
    print('Fetching purchases from reset time: ${resetTime.toDate()} for owner: $business');

    // Query purchases where date >= resetTime (optimized to reduce reads)
    return firestore
        .collection('recovered')
        .doc(business)
        .collection('userRecovered')
        .where('date', isGreaterThanOrEqualTo: resetTime)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
      print('Received ${snapshot.docs.length} purchases (from reset time)');
      return snapshot.docs.map((doc) {
        return Sale.fromSnapshot(doc);
      }).toList();
    })
        .handleError((error) {
      print('Error fetching Recovered: $error');
    });
  }

  // Query purchases by specific date range (for filtering)
  Stream<List<Sale>> getBoughtByDateRange(DateTime startDate, DateTime endDate) {
    final String? business = _businessController.businessId.value;
    if (business!.isEmpty) {
      print('Owner ID is null, returning empty purchases.');
      return Stream.value([]);
    }

    final Timestamp startTimestamp = Timestamp.fromDate(startDate);
    final Timestamp endTimestamp = Timestamp.fromDate(endDate.add(const Duration(days: 1)));

    print('Fetching purchases from $startDate to $endDate for owner: $business');

    return firestore
        .collection('recovered')
        .doc(business)
        .collection('userRecovered')
        .where('date', isGreaterThanOrEqualTo: startTimestamp)
        .where('date', isLessThan: endTimestamp)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
      print('Received ${snapshot.docs.length} purchases in date range');
      return snapshot.docs.map((doc) {
        return Sale.fromSnapshot(doc);
      }).toList();
    })
        .handleError((error) {
      print('Error fetching purchases by date range: $error');
    });
  }


  // Load debts by status only (PENDING or PAID) - optimized to reduce reads
  // PENDING: Debts with remaining balance > 0 (new credit extended)
  // PAID: Debts fully paid (remaining balance = 0)
  // Note: Debt payments are recorded as new sales, so only PENDING debts count as actual debt
  Stream<List<DebtHistory>> getDebtHistory({String status = 'PENDING'}) {
    final String? business = _businessController.businessId.value;

    if (business!.isEmpty) {
      print('Business ID is null, returning empty DebtHistory');
      return Stream.value([]);
    }

    print('Fetching debt history with status: $status for business: $business');

    return firestore
        .collection('debtHistory')
        .doc(business)
        .collection('clientDebtHistory')
        .where('status', isEqualTo: status)
        .orderBy('dateIncurred', descending: true)
        .snapshots()
        .map((snapshot) {
      print('Received ${snapshot.docs.length} debt records with status: $status');
      List<DebtHistory> debtHistories = snapshot.docs.map((doc) {
        return DebtHistory.fromSnapshot(doc);
      }).toList();

      return debtHistories;
    }).handleError((error) {
      Get.snackbar(
        'Error',
        'Error: $error',
        snackPosition: SnackPosition.BOTTOM,
        duration: Duration(seconds: 10),
      );
      print('Error fetching debt history: $error');
    });
  }




  Stream<List<Expense>> getExpenses() {
    final String? business = _businessController.businessId.value;

    if (business!.isEmpty) {
      print('business ID is null, returning empty stream.');
      return Stream.value([]);
    }

    // Get reset time from business data
    final Timestamp? resetTime = _businessController.business['reset_time'];
    
    if (resetTime == null) {
      print('Reset time is null, fetching all expenses for business: $business');
      // Fallback to all expenses if no reset time
      return firestore
          .collection('expenses')
          .doc(business)
          .collection('userExpenses')
          .snapshots()
          .map((snapshot) {
        return snapshot.docs
            .map((doc) => Expense.fromMap(doc.data(), doc.id))
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));
      });
    }

    print('Fetching expenses from reset time: ${resetTime.toDate()} for business: $business');

    // Query expenses where date >= resetTime (optimized to reduce reads)
    return firestore
        .collection('expenses')
        .doc(business)
        .collection('userExpenses')
        .where('date', isGreaterThanOrEqualTo: resetTime)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
      print('Received ${snapshot.docs.length} expenses (from reset time)');
      return snapshot.docs
          .map((doc) => Expense.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  // Query expenses by specific date range (for filtering)
  Stream<List<Expense>> getExpensesByDateRange(DateTime startDate, DateTime endDate) {
    final String? business = _businessController.businessId.value;
    if (business!.isEmpty) {
      print('business ID is null, returning empty stream.');
      return Stream.value([]);
    }

    final Timestamp startTimestamp = Timestamp.fromDate(startDate);
    final Timestamp endTimestamp = Timestamp.fromDate(endDate.add(const Duration(days: 1)));

    print('Fetching expenses from $startDate to $endDate for business: $business');

    return firestore
        .collection('expenses')
        .doc(business)
        .collection('userExpenses')
        .where('date', isGreaterThanOrEqualTo: startTimestamp)
        .where('date', isLessThan: endTimestamp)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
      print('Received ${snapshot.docs.length} expenses in date range');
      return snapshot.docs
          .map((doc) => Expense.fromMap(doc.data(), doc.id))
          .toList();
    });
  }
  // * INVOICE
  Stream<List<Sale>> getInvoices() {
    final String? business = _businessController.businessId.value;
    if (business!.isEmpty) {
      print('Owner ID is null, returning empty sInvoices.');
      return Stream.value([]);
    }

    // Get reset time from business data
    final Timestamp? resetTime = _businessController.business['reset_time'];
    
    if (resetTime == null) {
      print('Reset time is null, fetching all invoices for owner: $business');
      // Fallback to all invoices if no reset time
      return firestore
          .collection('invoices')
          .doc(business)
          .collection('userInvoices')
          .snapshots()
          .map((snapshot) {
        print('Received Invoices with ${snapshot.docs.length} documents');
        return snapshot.docs.map((doc) {
          return Sale.fromSnapshot(doc);
        }).toList();
      })
          .handleError((error) {
        print('Error fetching invoices: $error');
      });
    }

    print('Fetching invoices from reset time: ${resetTime.toDate()} for owner: $business');

    // Query invoices where date >= resetTime (optimized to reduce reads)
    return firestore
        .collection('invoices')
        .doc(business)
        .collection('userInvoices')
        .where('date', isGreaterThanOrEqualTo: resetTime)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
      print('Received ${snapshot.docs.length} invoices (from reset time)');
      return snapshot.docs.map((doc) {
        return Sale.fromSnapshot(doc);
      }).toList();
    })
        .handleError((error) {
      print('Error fetching invoices: $error');
    });
  }

  // Query invoices by specific date range (for filtering)
  Stream<List<Sale>> getInvoicesByDateRange(DateTime startDate, DateTime endDate) {
    final String? business = _businessController.businessId.value;
    if (business!.isEmpty) {
      print('Owner ID is null, returning empty invoices.');
      return Stream.value([]);
    }

    final Timestamp startTimestamp = Timestamp.fromDate(startDate);
    final Timestamp endTimestamp = Timestamp.fromDate(endDate.add(const Duration(days: 1)));

    print('Fetching invoices from $startDate to $endDate for owner: $business');

    return firestore
        .collection('invoices')
        .doc(business)
        .collection('userInvoices')
        .where('date', isGreaterThanOrEqualTo: startTimestamp)
        .where('date', isLessThan: endTimestamp)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
      print('Received ${snapshot.docs.length} invoices in date range');
      return snapshot.docs.map((doc) {
        return Sale.fromSnapshot(doc);
      }).toList();
    })
        .handleError((error) {
      print('Error fetching invoices by date range: $error');
    });
  }

  // * CLIENT
  Stream<List<Client>> getClients() {
    final String? business = _businessController.businessId.value;
    if (business!.isEmpty) {
      print('Owner ID is null, returning empty Clients');
      return Stream.value([]);
    }

    print('Fetching clients for owner: $business');

    return firestore
        .collection('clients')
        .doc(business)
        .collection('userClients')
        .snapshots()
        .map((snapshot) {
      print('Received Clients with ${snapshot.docs.length} documents');
      return snapshot.docs.map((doc) {
        print('Processing Clients with ID: ${doc.id}');
        return Client.fromSnapshot(doc);
      }).toList();
    })
        .handleError((error) {
      print('Error fetching clients: $error');
    });
  }

  Stream<List<ProfileModel>> getEmployee() {
    final String? business = _businessController.businessId.value;
    if (business!.isEmpty) {
      print('Owner ID is null, returning empty Employee.');
      return Stream.value([]);
    }

    print('Fetching Employeefor owner: $business');

    return firestore
        .collection('employees')
        .doc(business)
        .collection('userEmployees')
        .snapshots()
        .map((snapshot) {
      print('Received Employee with ${snapshot.docs.length} documents');
      return snapshot.docs.map((doc) {
        print('Processing Employee with ID: ${doc.id}');
        return ProfileModel.fromSnapshot(doc);
      }).toList();
    })
        .handleError((error) {
      print('Error fetching Employee: $error');
    });
  }

  Stream<List<Supplier>> getSuppliers() {
    final String? business = _businessController.businessId.value;
    if (business!.isEmpty) {
      print('Business ID is null, returning empty suppliers.');
      return Stream.value([]);
    }

    print('Fetching suppliers for business: $business');

    return firestore
        .collection('suppliers')
        .doc(business)
        .collection('userSuppliers')
        .snapshots()
        .map((snapshot) {
      print('Received suppliers with ${snapshot.docs.length} documents');
      return snapshot.docs.map((doc) {
        print('Processing supplier with ID: ${doc.id}');
        return Supplier.fromSnapshot(doc);
      }).toList();
    })
        .handleError((error) {
      print('Error fetching suppliers: $error');
    });
  }

  // * TRANSFER REQUESTS
  Stream<List<ProductTransferRequest>> getIncomingTransferRequests() {
    final String? business = _businessController.businessId.value;
    if (business!.isEmpty) {
      print('Business ID is empty, returning empty incoming transfer requests.');
      return Stream.value([]);
    }

    print('Fetching incoming transfer requests for business: $business');

    return firestore
        .collection('product_transfer_requests')
        .doc(business)
        .collection('userTransferRequests')
        .where('toBusinessId', isEqualTo: business)
        .orderBy('requestedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      print('Received incoming transfer requests with ${snapshot.docs.length} documents');
      return snapshot.docs.map((doc) {
        print('Processing incoming transfer request with ID: ${doc.id}');
        return ProductTransferRequest.fromSnapshot(doc);
      }).toList();
    }).handleError((error) {
      print('Error fetching incoming transfer requests: $error');
    });
  }

  Stream<List<ProductTransferRequest>> getOutgoingTransferRequests() {
    final String? business = _businessController.businessId.value;
    if (business!.isEmpty) {
      print('Business ID is empty, returning empty outgoing transfer requests.');
      return Stream.value([]);
    }

    print('Fetching outgoing transfer requests for business: $business');

    return firestore
        .collection('product_transfer_requests')
        .doc(business)
        .collection('userTransferRequests')
        .where('fromBusinessId', isEqualTo: business)
        .orderBy('requestedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      print('Received outgoing transfer requests with ${snapshot.docs.length} documents');
      return snapshot.docs.map((doc) {
        print('Processing outgoing transfer request with ID: ${doc.id}');
        return ProductTransferRequest.fromSnapshot(doc);
      }).toList();
    }).handleError((error) {
      print('Error fetching outgoing transfer requests: $error');
    });
  }

  Stream<List<ProductTransferRequest>> getAllTransferRequests() {
    final String? business = _businessController.businessId.value;
    if (business!.isEmpty) {
      print('Business ID is empty, returning empty transfer requests.');
      return Stream.value([]);
    }

    print('Fetching all transfer requests for business: $business');

    return firestore
        .collection('product_transfer_requests')
        .doc(business)
        .collection('userTransferRequests')
        .orderBy('requestedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      print('Received all transfer requests with ${snapshot.docs.length} documents');
      return snapshot.docs.map((doc) {
        print('Processing transfer request with ID: ${doc.id}');
        return ProductTransferRequest.fromSnapshot(doc);
      }).toList();
    }).handleError((error) {
      print('Error fetching all transfer requests: $error');
    });
  }

  Stream<PeriodAggregate?> getCurrentPeriodAggregate() {
    final String? business = _businessController.businessId.value;
    if (business == null || business.isEmpty) {
      return Stream.value(null);
    }
    return firestore
        .collection('aggregates')
        .doc(business)
        .collection('periods')
        .doc('current')
        .snapshots()
        .map((doc) => doc.exists ? PeriodAggregate.fromMap(doc.data() as Map<String, dynamic>) : null);
  }

  Stream<AggregatesMetaTotals?> getAggregatesMetaTotals() {
    final String? business = _businessController.businessId.value;
    if (business == null || business.isEmpty) {
      return Stream.value(null);
    }
    return firestore
        .collection('aggregates')
        .doc(business)
        .collection('meta')
        .doc('totals')
        .snapshots()
        .map((doc) => doc.exists ? AggregatesMetaTotals.fromMap(doc.data() as Map<String, dynamic>) : null);
  }
}
