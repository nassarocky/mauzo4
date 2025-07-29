import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/profile_controller.dart';
import '../../controllers/business_controller.dart';

class EditEmployeePermissionsDialogCloudFunction extends StatefulWidget {
  final Map<String, dynamic> employee;
  final VoidCallback onUpdated;

  const EditEmployeePermissionsDialogCloudFunction({
    Key? key,
    required this.employee,
    required this.onUpdated,
  }) : super(key: key);

  @override
  _EditEmployeePermissionsDialogCloudFunctionState createState() =>
      _EditEmployeePermissionsDialogCloudFunctionState();
}

class _EditEmployeePermissionsDialogCloudFunctionState
    extends State<EditEmployeePermissionsDialogCloudFunction> {
  final ProfileController _profileController = Get.find();
  final BusinessController _businessController = Get.find();
  
  late String selectedRole;
  late List<String> selectedPermissions;
  bool isLoading = false;

  final List<String> availableRoles = [
    'owner',
    'manager', 
    'cashier',
    'sales_person',
    'agent',
    'employee'
  ];

  final List<String> availablePermissions = [
    'view_products',
    'edit_products',
    'make_sales',
    'view_sales',
    'view_sales_own',
    'view_reports',
    'manage_employees',
    'manage_clients',
    'manage_expenses',
    'transfer_products',
    'create_invoices',
    'manage_transfers',
    'view_statistics',
    'manage_categories',
    'view_transactions',
    'manage_debt',
    'print_invoices',
    'share_invoices',
  ];

  @override
  void initState() {
    super.initState();
    selectedRole = widget.employee['role'] ?? 'employee';
    selectedPermissions = List<String>.from(widget.employee['permissions'] ?? []);
  }

  Future<void> _saveChanges() async {
    if (!_profileController.hasPermission('manage_employees')) {
      Get.snackbar('Access Denied', 'You do not have permission to manage employees');
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      // Call Cloud Function to update user role and permissions
      final HttpsCallable callable = FirebaseFunctions.instance
          .httpsCallable('updateUserRolePermissions');
      
      final result = await callable.call({
        'targetUserId': widget.employee['id'],
        'newRole': selectedRole,
        'newPermissions': selectedPermissions,
        'businessId': _businessController.business['id'],
      });

      if (result.data['success'] == true) {
        Get.snackbar(
          'Success',
          'Employee role and permissions updated successfully',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
        
        widget.onUpdated();
        Navigator.of(context).pop();
      } else {
        throw Exception(result.data['message'] ?? 'Update failed');
      }
    } catch (e) {
      print('Error updating employee: $e');
      Get.snackbar(
        'Error',
        'Failed to update employee: ${e.toString()}',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Edit Employee Permissions'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Employee: ${widget.employee['name']}'),
            SizedBox(height: 16),
            
            // Role Dropdown
            Text('Role:', style: TextStyle(fontWeight: FontWeight.bold)),
            DropdownButton<String>(
              value: selectedRole,
              isExpanded: true,
              items: availableRoles.map((role) {
                return DropdownMenuItem(
                  value: role,
                  child: Text(role.replaceAll('_', ' ').toUpperCase()),
                );
              }).toList(),
              onChanged: isLoading ? null : (value) {
                setState(() {
                  selectedRole = value!;
                });
              },
            ),
            SizedBox(height: 16),
            
            // Custom Permissions
            Text('Custom Permissions:', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            ...availablePermissions.map((permission) {
              return CheckboxListTile(
                title: Text(permission.replaceAll('_', ' ').toUpperCase()),
                value: selectedPermissions.contains(permission),
                onChanged: isLoading ? null : (bool? value) {
                  setState(() {
                    if (value == true) {
                      selectedPermissions.add(permission);
                    } else {
                      selectedPermissions.remove(permission);
                    }
                  });
                },
                dense: true,
                contentPadding: EdgeInsets.zero,
              );
            }).toList(),
            
            SizedBox(height: 16),
            Text('Current Permissions Array:', 
                 style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            Text(selectedPermissions.toString(), 
                 style: TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: isLoading ? null : () => Navigator.of(context).pop(),
          child: Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: isLoading ? null : _saveChanges,
          child: isLoading 
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text('Save'),
        ),
      ],
    );
  }
}
