import 'package:cloud_firestore/cloud_firestore.dart';


class Sale {
  final String id;
  final String owner;
  final bool frominvoice;
  final String client;
  final String clientname;
  final String? supplier;
  final String? suppliername;
  final String employeeId;
  final String employeeName;
  final Timestamp date;
  final List<dynamic> products;
  final double price;
  final double buyingPrice;
  final double payment;
  final double debt;
  final double discount;
  final String comment;
  // Sale type: 'original' for regular sales, 'debt_repayment' for debt payments
  final String? saleType;
  // Optional detailed payments breakdown (each item: {amount,currency,method})
  final List<Map<String, dynamic>> payments;
  // Optional purchase fund source (e.g., cash, bank, mobile, other)
  final String? fundSource;
  // Optional note/description when fundSource is 'other'
  final String? fundSourceNote;

  Sale({
    required this.id,
    required this.client,
    required this.clientname,
    this.supplier,
    this.suppliername,
    required this.employeeId,
    required this.employeeName,
    required this.owner,
    required this.frominvoice,
    required this.date,
    required this.products,
    required this.price,
    required this.buyingPrice,
    required this.payment,
    required this.debt,
    required this.discount,
    required this.comment,
    this.saleType,
    this.payments = const [],
    this.fundSource,
    this.fundSourceNote,
  });
  static Sale fromSnapshot(DocumentSnapshot snapshot) {
    var data = snapshot.data() as Map<String, dynamic>?;

    return Sale(
      id: snapshot.id,
      owner: data?['owner'] ?? '',
      frominvoice: data?['frominvoice'] ?? false,
      client: data?['client'] ?? '',
      clientname: data?['clientname'] ?? 'Unnamed Client',
      supplier: data?['supplier'],
      suppliername: data?['suppliername'],
      employeeId: data?['employeeId'] ?? '',
      employeeName: data?['employeeName'] ?? '',
      products: data?['products'] ?? [],
      date: data?['date'] ?? Timestamp.now(),
      price: (data?['price'] ?? 0.0).toDouble(),          // Converts to double
      buyingPrice: (data?['buyingPrice'] ?? 0.0).toDouble(), // Converts to double
      payment: (data?['payment'] ?? 0.0).toDouble(),      // Converts to double
      debt: (data?['debt'] ?? 0.0).toDouble(),            // Converts to double
      discount: (data?['discount'] ?? 0.0).toDouble(),    // Converts to double
      comment: data?['comment'] ?? '',
      saleType: data?['saleType'],
      payments: List<Map<String, dynamic>>.from(data?['payments'] ?? const []),
      fundSource: data?['fundSource'],
      fundSourceNote: data?['fundSourceNote'],
    );
  }


}
