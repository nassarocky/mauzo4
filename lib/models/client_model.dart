import 'package:cloud_firestore/cloud_firestore.dart';

class Client {
  final String id;
  final String owner;
  late final String name;
  final String phone;
  final dynamic date;
  final double debt;
  final double advance;
  final List<dynamic> advanceTransactions; // New field to track transactions
  String? note;
  String? image;

  Client({
    required this.id,
    required this.owner,
    required this.name,
    required this.phone,
    required this.date,
    this.debt = 0.0,
    this.advance = 0.0,
    this.advanceTransactions = const [],
    this.note,
    this.image,
  });

  // Factory method to create a Client from Firestore snapshot
  static Client fromSnapshot(DocumentSnapshot snapshot) {
    final data = snapshot.data() as Map<String, dynamic>?;
    if (data == null) {
      throw Exception("Document data is null for snapshot with ID: ${snapshot.id}");
    }
    return Client(
      id: snapshot.id,
      owner: data['owner'] ?? '',
      name: data['name'] ?? 'Unnamed Client',
      phone: data['phone'] ?? '',
      date: data['date'],
      debt: (data['debt'] ?? 0.0) is int
          ? (data['debt'] as int).toDouble()
          : (data['debt'] ?? 0.0) as double,
      advance: (data['advance'] ?? 0.0) is int
          ? (data['advance'] as int).toDouble()
          : (data['advance'] ?? 0.0) as double,
      advanceTransactions: data['advanceTransactions'] ?? [],
      note: data['note'],
      image: data['image'],
    );
  }

  // Convert Client instance to Firestore format
  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'owner': owner,
      'name': name,
      'phone': phone,
      'date': date,
      'debt': debt,
      'advance': advance,
      'advanceTransactions': advanceTransactions,
      'note': note,
      'image': image,
    };
  }
}
