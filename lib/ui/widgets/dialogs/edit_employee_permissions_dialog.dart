import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mauzo/controllers/business_controller.dart';
import 'package:mauzo/controllers/employee_controller.dart';
import 'package:mauzo/controllers/profile_controller.dart';
import 'package:mauzo/models/profile_model.dart';
import '../../../utils/constants.dart';
import '../buttons/primary_button.dart';
import '../buttons/secondary_button.dart';
import 'role_permissions_guide_dialog.dart';

class EditEmployeePermissionsDialog extends StatefulWidget {
  final ProfileModel employee;
  
  const EditEmployeePermissionsDialog({
    Key? key,
    required this.employee,
  }) : super(key: key);

  @override
  State<EditEmployeePermissionsDialog> createState() => _EditEmployeePermissionsDialogState();
}

class _EditEmployeePermissionsDialogState extends State<EditEmployeePermissionsDialog> {
  final BusinessController _businessController = Get.find();
  final EmployeeController _employeeController = Get.find();
  final ProfileController _profileController = Get.find();
  
  String? selectedRole;
  List<String> selectedPermissions = [];
  bool isLoading = false;
  bool showCustomPermissions = false; // Toggle for custom permissions visibility
  
  // Available roles
  final List<String> availableRoles = [
    'owner',
    'manager', 
    'cashier',
    'sales_person',
    'agent',
    'employee'
  ];
  
  // Available permissions
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
    'buy_products'
  ];

  @override
  void initState() {
    super.initState();
    selectedRole = widget.employee.role ?? 'employee';
    
    // Initialize permissions from employee data
    if (widget.employee.permissions != null) {
      selectedPermissions = List<String>.from(widget.employee.permissions!);
    }
  }

  Future<void> _saveChanges() async {
    setState(() {
      isLoading = true;
    });

    try {
      final String businessId = _businessController.business['id'] ?? '';
      final String employeeId = widget.employee.id ?? '';
      
      if (businessId.isEmpty || employeeId.isEmpty) {
        throw Exception('Missing business ID or employee ID');
      }

      // Data to update (custom permissions temporarily disabled)
      final Map<String, dynamic> updateData = {
        'role': selectedRole,
        // TODO: Re-enable when custom permissions are needed
        // 'permissions': selectedPermissions,
        'permissions': [], // Clear custom permissions, rely on role-based permissions only
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Update in gmanusers collection using set with merge to handle missing docs
      await FirebaseFirestore.instance
          .collection('gmanusers')
          .doc(employeeId)
          .set(updateData, SetOptions(merge: true));

      // Update in employees subcollection using set with merge
      await FirebaseFirestore.instance
          .collection('employees')
          .doc(businessId)
          .collection('userEmployees')
          .doc(employeeId)
          .set(updateData, SetOptions(merge: true));

      // Employee data will refresh automatically via stream subscription
      
      // CRITICAL: Refresh ProfileController cache if we updated the current user
      final String currentUserId = _profileController.user['id'] ?? '';
      if (employeeId == currentUserId) {
        await _profileController.refreshUserData();
      }

      // Show success message
      Get.snackbar(
        'success'.tr,
        '${'employee_permissions_updated'.tr}\n${'role_colon'.tr} $selectedRole',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );

      // Close dialog
      Navigator.of(context).pop();

    } catch (e, stackTrace) {
      // Show error message
      Get.snackbar(
        'error'.tr,
        '${'something_went_wrong'.tr}: ${e.toString()}',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 5),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Text(
                    'edit_employee_permissions'.tr,
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
            
            // Employee info
            Text(
              'Employee: ${widget.employee.name}',
              style: bodyText(Theme.of(context).textTheme.bodyMedium!.color),
            ),
            const SizedBox(height: 16),
            
            // Role selection
            Row(
              children: [
                Text(
                  'role'.tr,
                  style: bodyText(Theme.of(context).textTheme.bodyLarge!.color),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => const RolePermissionsGuideDialog(),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.help_outline,
                          size: 16,
                          color: Colors.blue[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'view_role_guide'.tr,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: borderColor),
                borderRadius: BorderRadius.circular(4),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: selectedRole,
                  isExpanded: true,
                  items: availableRoles.map((role) {
                    return DropdownMenuItem<String>(
                      value: role,
                      child: Text(
                        role.replaceAll('_', ' ').capitalizeFirst!,
                        style: bodyText(Theme.of(context).textTheme.bodyMedium!.color),
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedRole = value;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),
            
            // TODO: Re-enable custom permissions feature later
            // Custom Permissions Toggle Section
            // InkWell(
            //   onTap: () {
            //     setState(() {
            //       showCustomPermissions = !showCustomPermissions;
            //     });
            //   },
            //   child: Container(
            //     padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            //     decoration: BoxDecoration(
            //       border: Border.all(color: borderColor),
            //       borderRadius: BorderRadius.circular(8),
            //       color: showCustomPermissions ? primaryColor.withOpacity(0.05) : Colors.transparent,
            //     ),
            //     child: Row(
            //       children: [
            //         Icon(
            //           showCustomPermissions ? Icons.expand_less : Icons.expand_more,
            //           color: primaryColor,
            //         ),
            //         const SizedBox(width: 8),
            //         Expanded(
            //           child: Column(
            //             crossAxisAlignment: CrossAxisAlignment.start,
            //             children: [
            //               Text(
            //                 'custom_permissions'.tr,
            //                 style: bodyText(Theme.of(context).textTheme.bodyLarge!.color),
            //               ),
            //               if (selectedPermissions.isNotEmpty)
            //                 Text(
            //                   '${selectedPermissions.length} ${'permission_selected'.tr}',
            //                   style: bodyText(primaryColor),
            //                 ),
            //             ],
            //           ),
            //         ),
            //         if (selectedPermissions.isNotEmpty)
            //           Container(
            //             padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            //             decoration: BoxDecoration(
            //               color: primaryColor,
            //               borderRadius: BorderRadius.circular(12),
            //             ),
            //             child: Text(
            //               '${selectedPermissions.length}',
            //               style: const TextStyle(
            //                 color: Colors.white,
            //                 fontSize: 12,
            //                 fontWeight: FontWeight.bold,
            //               ),
            //             ),
            //           ),
            //       ],
            //     ),
            //   ),
            // ),
            // 
            // // Collapsible Permissions Section
            // if (showCustomPermissions) ...[
            //   const SizedBox(height: 12),
            //   Text(
            //     'permissions_override_note'.tr,
            //     style: bodyText(textPlaceholderColor),
            //   ),
            //   const SizedBox(height: 12),
            //   
            //   // Permissions list
            //   Expanded(
            //     child: Container(
            //       decoration: BoxDecoration(
            //         border: Border.all(color: borderColor),
            //         borderRadius: BorderRadius.circular(4),
            //       ),
            //       child: ListView.builder(
            //         shrinkWrap: true,
            //         itemCount: availablePermissions.length,
            //         itemBuilder: (context, index) {
            //           final permission = availablePermissions[index];
            //           final isSelected = selectedPermissions.contains(permission);
            //           
            //           return CheckboxListTile(
            //             title: Text(
            //               permission.tr,
            //               style: bodyText(Theme.of(context).textTheme.bodyMedium!.color),
            //             ),
            //             value: isSelected,
            //             onChanged: (checked) {
            //               setState(() {
            //                 if (checked == true) {
            //                   selectedPermissions.add(permission);
            //                 } else {
            //                   selectedPermissions.remove(permission);
            //                 }
            //               });
            //             },
            //             controlAffinity: ListTileControlAffinity.leading,
            //             dense: true,
            //           );
            //         },
            //       ),
            //     ),
            //   ),
            // ] else ...[
            //   // When collapsed, show a more compact view
            //   const Spacer(),
            // ],
            const SizedBox(height: 16),
            
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: SecondaryButton(
                    text: 'cancel'.tr,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: PrimaryButton(
                    text: isLoading ? 'saving'.tr : 'save_changes'.tr,
                    onPressed: isLoading ? () {} : () => _saveChanges(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
