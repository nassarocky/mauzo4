import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mauzo/controllers/profile_controller.dart';
import 'package:mauzo/controllers/business_list_controller.dart';
import 'package:mauzo/models/profile_model.dart';
import 'package:mauzo/models/business_model.dart';
import 'package:mauzo/ui/widgets/dialogs/manage_employee_pay_dialog.dart';
import '../../../utils/constants.dart';
import '../buttons/primary_button.dart';
import '../buttons/secondary_button.dart';

class SelectEmployeeForPayRoleDialog extends StatefulWidget {
  const SelectEmployeeForPayRoleDialog({Key? key}) : super(key: key);

  @override
  State<SelectEmployeeForPayRoleDialog> createState() => _SelectEmployeeForPayRoleDialogState();
}

class _SelectEmployeeForPayRoleDialogState extends State<SelectEmployeeForPayRoleDialog> {
  final ProfileController _profileController = Get.find();
  final BusinessListController _businessController = Get.find();
  
  List<ProfileModel> availableEmployees = [];
  List<ProfileModel> filteredEmployees = [];
  bool isLoading = true;
  String searchQuery = '';
  String? selectedBusinessId;
  String? selectedBusinessName;
  
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
      
      Map<String, ProfileModel> employeeMap = {};
      
      // Load employees from all owned businesses
      for (String businessId in userBusinesses) {
        final employeesSnapshot = await FirebaseFirestore.instance
            .collection('employees')
            .doc(businessId)
            .collection('userEmployees')
            .get();
        
        for (var doc in employeesSnapshot.docs) {
          final data = doc.data();
          print('[DEBUG] Employee ${doc.id} in business $businessId: role=${data['role']}, name=${data['name']}');
          
          if (data['role'] != 'owner') { // Exclude owners
            final employeeId = doc.id;
            
            // Check if we already have this employee
            if (employeeMap.containsKey(employeeId)) {
              print('[DEBUG] Employee $employeeId already exists with role ${employeeMap[employeeId]!.role}, found again with role ${data['role']}');
              print('[DEBUG] Skipping duplicate employee record');
              // Skip this duplicate record
            } else {
              // First time seeing this employee
              employeeMap[employeeId] = ProfileModel(
                id: employeeId,
                phone: data['phone'] ?? '',
                name: data['name'] ?? 'Unnamed Employee',
                role: data['role'] ?? 'employee',
                password: data['password'] ?? '',
                date: data['date'],
                image: data['image'] ?? '',
                business: data['business'] ?? [],
                email: data['email'] ?? '',
                permissions: data['permissions'],
                maxBusiness: data['maxBusiness'],
              );
            }
          }
        }
      }
      
      availableEmployees = employeeMap.values.toList();
      filteredEmployees = availableEmployees;
      
    } catch (e) {
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
    final userBusinesses = _businessController.businesses;
    List<String> names = [];
    
    for (String businessId in businessIds) {
      final business = userBusinesses.firstWhereOrNull((b) => b.id == businessId);
      if (business != null) {
        names.add(business.name);
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
        title: Text('Select Business'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${employee.name} is assigned to multiple businesses. Select which business to create the pay role for:'),
            const SizedBox(height: 16),
            ...businessIds.map((businessId) {
              final business = _businessController.businesses.firstWhereOrNull((b) => b.id == businessId);
              final businessName = business?.name ?? 'Unknown Business';
              
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
    Navigator.of(context).pop(); // Close employee selection dialog
    
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
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Select Employee for Pay Role',
                    style: h5(Theme.of(context).textTheme.bodyLarge!.color),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
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
                                  child: Text(
                                    employee.name.isNotEmpty 
                                        ? employee.name[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  employee.name,
                                  style: const TextStyle(fontWeight: FontWeight.w500),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Role: ${(employee.role ?? 'employee').toString().capitalizeFirst}'),
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
            
            // Footer
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                SecondaryButton(
                  text: 'Cancel',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
