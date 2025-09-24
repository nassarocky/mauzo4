import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mauzo/controllers/profile_controller.dart';
import 'package:mauzo/controllers/business_list_controller.dart';
import 'package:mauzo/controllers/business_controller.dart';
import 'package:mauzo/models/profile_model.dart';
import 'package:mauzo/models/business_model.dart';
import 'package:mauzo/ui/widgets/dialogs/manage_employee_pay_dialog.dart';
import '../../utils/constants.dart';
import '../widgets/buttons/primary_button.dart';
import '../widgets/buttons/secondary_button.dart';

class SelectEmployeeForPayRoleScreen extends StatefulWidget {
  const SelectEmployeeForPayRoleScreen({Key? key}) : super(key: key);

  @override
  State<SelectEmployeeForPayRoleScreen> createState() => _SelectEmployeeForPayRoleScreenState();
}

class _SelectEmployeeForPayRoleScreenState extends State<SelectEmployeeForPayRoleScreen> {
  final ProfileController _profileController = Get.find();
  final BusinessListController _businessListController = Get.find();
  final BusinessController _businessController = Get.find();
  
  List<ProfileModel> availableEmployees = [];
  List<ProfileModel> filteredEmployees = [];
  bool isLoading = true;
  String searchQuery = '';
  
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadEmployees();
    _searchController.addListener(_filterEmployees);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadEmployees() async {
    setState(() {
      isLoading = true;
    });

    try {
      // Get all businesses owned by current user
      final userBusinesses = _profileController.user['business'] as List<dynamic>? ?? [];
      print('User businesses: $userBusinesses'); // Debug log
      
      Set<ProfileModel> employeeSet = {};
      
      // Load employees from all owned businesses using the employees collection
      for (String businessId in userBusinesses) {
        print('Loading employees from business: $businessId'); // Debug log
        
        try {
          final employeesSnapshot = await FirebaseFirestore.instance
              .collection('employees')
              .doc(businessId)
              .collection('userEmployees')
              .get();
          
          print('Found ${employeesSnapshot.docs.length} employees in business $businessId'); // Debug log
          
          for (var doc in employeesSnapshot.docs) {
            try {
              final data = doc.data();
              print('Processing employee document: ${doc.id}');
              print('Document data type: ${data.runtimeType}');
              print('Document data: $data');
              
              if (data['role'] != 'owner') { // Exclude owners
                print('Creating ProfileModel from snapshot for: ${doc.id}');
                final employee = ProfileModel.fromSnapshot(doc);
                employeeSet.add(employee);
                print('Successfully added employee: ${employee.name} from business $businessId');
              }
            } catch (e, stackTrace) {
              print('Error processing employee document ${doc.id}: $e');
              print('Stack trace: $stackTrace');
            }
          }
        } catch (e) {
          print('Error loading employees from business $businessId: $e');
        }
      }
      
      // If we have very few employees, try to load individual user documents
      // This approach respects the security rules better
      if (employeeSet.length < 5) { // Only do this if we have few employees to avoid too many queries
        for (String businessId in userBusinesses) {
          try {
            // Get employee IDs from the employees collection first
            final employeesSnapshot = await FirebaseFirestore.instance
                .collection('employees')
                .doc(businessId)
                .collection('userEmployees')
                .get();
            
            // Then fetch individual user documents from gmanusers
            for (var doc in employeesSnapshot.docs) {
              try {
                print('Fetching user document: ${doc.id}');
                final userDoc = await FirebaseFirestore.instance
                    .collection('gmanusers')
                    .doc(doc.id)
                    .get();
                
                if (userDoc.exists) {
                  final data = userDoc.data()!;
                  print('User document data type: ${data.runtimeType}');
                  print('User document data: $data');
                  
                  if (data['role'] != 'owner') { // Exclude owners
                    print('Creating ProfileModel from gmanusers snapshot for: ${doc.id}');
                    final employee = ProfileModel.fromSnapshot(userDoc);
                    employeeSet.add(employee);
                    print('Successfully added employee from gmanusers: ${employee.name}');
                  }
                }
              } catch (e, stackTrace) {
                print('Error loading user ${doc.id}: $e');
                print('Stack trace: $stackTrace');
              }
            }
          } catch (e) {
            print('Error in individual user loading for business $businessId: $e');
          }
        }
      }
      
      availableEmployees = employeeSet.toList();
      filteredEmployees = availableEmployees;
      
      print('Total unique employees loaded: ${availableEmployees.length}'); // Debug log
      
    } catch (e) {
      print('Error loading employees: $e'); // Debug log
      Get.snackbar('Error', 'Failed to load employees: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _filterEmployees() {
    setState(() {
      searchQuery = _searchController.text.toLowerCase();
      filteredEmployees = availableEmployees.where((employee) {
        final nameMatch = employee.name.toLowerCase().contains(searchQuery);
        final emailMatch = (employee.email ?? '').toLowerCase().contains(searchQuery);
        return nameMatch || emailMatch;
      }).toList();
    });
  }

  List<String> _getEmployeeBusinesses(ProfileModel employee) {
    final businesses = employee.business as List<dynamic>? ?? [];
    return businesses.cast<String>();
  }

  String _getBusinessNames(List<String> businessIds) {
    final userBusinesses = _businessListController.businesses;
    List<String> names = [];
    
    for (String businessId in businessIds) {
      final business = userBusinesses.firstWhereOrNull((b) => b.id == businessId);
      if (business != null) {
        names.add(business.name);
      } else {
        // Fallback: try to get business name from current business controller
        if (_businessController.business['id'] == businessId) {
          names.add(_businessController.business['name'] ?? 'Business $businessId');
        } else {
          names.add('Business $businessId');
        }
      }
    }
    
    return names.join(', ');
  }

  void _selectEmployee(ProfileModel employee) {
    final employeeBusinesses = _getEmployeeBusinesses(employee);
    
    if (employeeBusinesses.length == 1) {
      // Employee is in only one business, proceed directly
      _showPayRoleDialog(employee, employeeBusinesses.first);
    } else if (employeeBusinesses.length > 1) {
      // Employee is in multiple businesses, show business selection
      _showBusinessSelectionDialog(employee, employeeBusinesses);
    } else {
      Get.snackbar('Error', 'Employee is not assigned to any business');
    }
  }

  void _showBusinessSelectionDialog(ProfileModel employee, List<String> businessIds) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Business'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${employee.name} is assigned to multiple businesses. Select which business to create the pay role for:'),
            const SizedBox(height: 16),
            ...businessIds.map((businessId) {
              final business = _businessListController.businesses.firstWhereOrNull((b) => b.id == businessId);
              final businessName = business?.name ?? 'Business $businessId';
              
              return ListTile(
                title: Text(businessName),
                onTap: () {
                  Navigator.of(context).pop();
                  _showPayRoleDialog(employee, businessId, businessName);
                },
              );
            }).toList(),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showPayRoleDialog(ProfileModel employee, String businessId, [String? businessName]) {
    showDialog(
      context: context,
      builder: (context) => ManageEmployeePayDialog(
        employee: employee,
        businessId: businessId,
        businessName: businessName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Employee for Pay Role'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Search field
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search employees...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
            const SizedBox(height: 16),
            
            // Employee count
            if (!isLoading)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  children: [
                    Text(
                      '${filteredEmployees.length} employee${filteredEmployees.length != 1 ? 's' : ''} found',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            
            // Employee list
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filteredEmployees.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                searchQuery.isNotEmpty ? Icons.search_off : Icons.people_outline,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                searchQuery.isNotEmpty 
                                    ? 'No employees found matching "$searchQuery"'
                                    : 'No employees available',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 16,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              if (searchQuery.isEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'Make sure employees are added to your businesses',
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 14,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: filteredEmployees.length,
                          itemBuilder: (context, index) {
                            final employee = filteredEmployees[index];
                            final employeeBusinesses = _getEmployeeBusinesses(employee);
                            final businessNames = _getBusinessNames(employeeBusinesses);
                            
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Theme.of(context).primaryColor,
                                  backgroundImage: employee.image != null && employee.image!.isNotEmpty
                                      ? NetworkImage(employee.image!)
                                      : null,
                                  child: employee.image == null || employee.image!.isEmpty
                                      ? Text(
                                          employee.name.isNotEmpty 
                                              ? employee.name[0].toUpperCase()
                                              : '?',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        )
                                      : null,
                                ),
                                title: Text(
                                  employee.name,
                                  style: const TextStyle(fontWeight: FontWeight.w500),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Role: ${(employee.role ?? 'employee').toString().capitalizeFirst}'),
                                    if (employee.email != null && employee.email!.isNotEmpty)
                                      Text(
                                        'Email: ${employee.email}',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 12,
                                        ),
                                      ),
                                    if (businessNames.isNotEmpty)
                                      Text(
                                        'Businesses: $businessNames',
                                        style: TextStyle(
                                          color: Colors.blue[600],
                                          fontSize: 12,
                                        ),
                                      ),
                                  ],
                                ),
                                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                                onTap: () => _selectEmployee(employee),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
