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
  List<dynamic>? permissions;
  /// Set at account creation from install / agent link (read-only in app).
  final String? installReferrerCode;

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
    this.permissions,
    this.installReferrerCode,
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
      maxBusiness: data['maxBusiness'] != null ? int.tryParse(data['maxBusiness'].toString()) ?? 0 : 0,
      business: data['business'] ?? const [],
      date: data['date'],
      image: data['image'] ?? '',
      email: data['email'] ?? '',
      permissions: data['permissions'],
      installReferrerCode: data['installReferrerCode']?.toString(),
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
      'permissions': permissions,
      if (installReferrerCode != null) 'installReferrerCode': installReferrerCode,
    };
  }
}
