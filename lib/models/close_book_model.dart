import 'package:cloud_firestore/cloud_firestore.dart';

class CloseBook {
  final String id;
  final String owner;
  final double totalSales;
  final double totalPayment;
  final double totalDebt;
  final double debt;
  final double expenses;
  final DateTime startDate;
  final DateTime endDate;
  final double finalStock;
  final double netProfit;
  final double totalPurchase;
  final double totalDiscounts;
  final String currency;
  final String createdBy;
  final DateTime createdAt;

  // Additional fields for reserve data
  String? reserveString1;
  String? reserveString2;
  double? reserveDouble1;
  double? reserveDouble2;
  List<String>? reserveList1;
  List<String>? reserveList2;

  CloseBook({
    required this.id,
    required this.owner,
    required this.totalSales,
    required this.totalPayment,
    required this.totalDebt,
    required this.debt,
    required this.expenses,
    required this.startDate,
    required this.endDate,
    required this.finalStock,
    required this.netProfit,
    required this.totalPurchase,
    required this.totalDiscounts,
    required this.currency,
    required this.createdBy,
    required this.createdAt,
    this.reserveString1 = '',
    this.reserveString2 = '',
    this.reserveDouble1 = 0.0,
    this.reserveDouble2 = 0.0,
    this.reserveList1 = const [],
    this.reserveList2 = const [],
  });

  // Factory method to create a CloseBook from Firestore snapshot
  static CloseBook fromSnapshot(DocumentSnapshot snapshot) {
    final data = snapshot.data() as Map<String, dynamic>?; // Safely get the document data

    if (data == null) {
      throw Exception("Document data is null for snapshot with ID: ${snapshot.id}");
    }

    return CloseBook(
      id: snapshot.id,
      owner: data['owner'] ?? '',
      totalSales: (data['totalSales'] ?? 0.0) is int ? (data['totalSales'] as int).toDouble() : (data['totalSales'] ?? 0.0) as double,
      totalPayment: (data['totalPayment'] ?? 0.0) is int ? (data['totalPayment'] as int).toDouble() : (data['totalPayment'] ?? 0.0) as double,
      totalDebt: (data['totalDebt'] ?? 0.0) is int ? (data['totalDebt'] as int).toDouble() : (data['totalDebt'] ?? 0.0) as double,
      debt: (data['debt'] ?? 0.0) is int ? (data['debt'] as int).toDouble() : (data['debt'] ?? 0.0) as double,
      expenses: (data['expenses'] ?? 0.0) is int ? (data['expenses'] as int).toDouble() : (data['expenses'] ?? 0.0) as double,
      startDate: (data['startDate'] as Timestamp).toDate(),
      endDate: (data['endDate'] as Timestamp).toDate(),
      finalStock: (data['finalStock'] ?? 0.0) is int ? (data['finalStock'] as int).toDouble() : (data['finalStock'] ?? 0.0) as double,
      netProfit: (data['netProfit'] ?? 0.0) is int ? (data['netProfit'] as int).toDouble() : (data['netProfit'] ?? 0.0) as double,
      totalPurchase: (data['totalPurchase'] ?? 0.0) is int ? (data['totalPurchase'] as int).toDouble() : (data['totalPurchase'] ?? 0.0) as double,
      totalDiscounts: (data['totalDiscounts'] ?? 0.0) is int ? (data['totalDiscounts'] as int).toDouble() : (data['totalDiscounts'] ?? 0.0) as double,
      currency: data['currency'] ?? '',
      createdBy: data['createdBy'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      reserveString1: data['reserveString1'] ?? '',
      reserveString2: data['reserveString2'] ?? '',
      reserveDouble1: (data['reserveDouble1'] ?? 0.0) is int ? (data['reserveDouble1'] as int).toDouble() : (data['reserveDouble1'] ?? 0.0) as double,
      reserveDouble2: (data['reserveDouble2'] ?? 0.0) is int ? (data['reserveDouble2'] as int).toDouble() : (data['reserveDouble2'] ?? 0.0) as double,
      reserveList1: List<String>.from(data['reserveList1'] ?? []),
      reserveList2: List<String>.from(data['reserveList2'] ?? []),
    );
  }

  // Method to convert CloseBook instance to Firestore format
  Map<String, dynamic> toFirestore() {
    return {
      'owner': owner,
      'totalSales': totalSales,
      'totalPayment': totalPayment,
      'totalDebt': totalDebt,
      'debt': debt,
      'expenses': expenses,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'finalStock': finalStock,
      'netProfit': netProfit,
      'totalPurchase': totalPurchase,
      'totalDiscounts': totalDiscounts,
      'currency': currency,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'reserveString1': reserveString1,
      'reserveString2': reserveString2,
      'reserveDouble1': reserveDouble1,
      'reserveDouble2': reserveDouble2,
      'reserveList1': reserveList1,
      'reserveList2': reserveList2,
    };
  }
}
