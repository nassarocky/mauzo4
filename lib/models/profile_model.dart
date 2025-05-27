import 'package:cloud_firestore/cloud_firestore.dart';

class ProfileModel {
  final String phone;
  int? maxBusiness;
  final String id;
  final String name;
  final String role;
  final String password;
  final dynamic date;
  String? image;
  List<dynamic> business;
  final String email;

  ProfileModel({
    required this.phone,
    required this.id,
    required this.name,
    required this.role,
    required this.password,
    required this.date,
    this.image = '',
    this.maxBusiness = 0,
    this.business = const [],
    required this.email,
  });

  // Factory method to create a ProfileModel from Firestore snapshot
  static ProfileModel fromSnapshot(DocumentSnapshot snapshot) {
    final data = snapshot.data() as Map<String, dynamic>?; // Safely get the document data

    if (data == null) {
      throw Exception("Document data is null for snapshot with ID: ${snapshot.id}");
    }

    return ProfileModel(
      phone: data['phone'] ?? '',
      id: snapshot.id,
      name: data['name'] ?? 'Unnamed Profile',
      role: data['role'] ?? '',
      password: data['password'] ?? '',
      maxBusiness: data['maxBusiness'] != null ? data['maxBusiness'].toInt() : 0,
      business: data['business'] ?? const [],
      date: data['date'],
      image: data['image'] ?? '',
      email: data['email'] ?? '',
    );
  }

  // Method to convert ProfileModel instance to Firestore format
  Map<String, dynamic> toFirestore() {
    return {
      'phone': phone,
      'id': id,
      'name': name,
      'role': role,
      'password': password,
      'date': date,
      'image': image,
      'maxBusiness': maxBusiness,
      'business': business,
      'email': email,
    };
  }
}
