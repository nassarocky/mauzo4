import 'package:cloud_firestore/cloud_firestore.dart';

class Service {
  final String id;
  final String name;
  final String description;
  final double price;
  final String category;
  final String businessId;
  final int? duration; // in minutes, optional

  Service({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.category,
    required this.businessId,
    this.duration,
  });

  factory Service.fromMap(Map<String, dynamic> data, String id) {
    return Service(
      id: id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      price: (data['price'] ?? 0.0).toDouble(),
      category: data['category'] ?? '',
      businessId: data['businessId'] ?? '',
      duration: data['duration'],
    );
  }

  factory Service.fromSnapshot(DocumentSnapshot snapshot) {
    final data = snapshot.data() as Map<String, dynamic>;
    return Service.fromMap(data, snapshot.id);
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'price': price,
      'category': category,
      'businessId': businessId,
      'duration': duration,
    };
  }
} 