import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mauzo/models/profile_model.dart';
import 'package:mauzo/controllers/business_controller.dart';
import 'package:mauzo/controllers/profile_controller.dart';
import 'package:mauzo/utils/constants.dart';

class AssignEmployeeBusinessesDialog extends StatefulWidget {
  final ProfileModel employee;

  const AssignEmployeeBusinessesDialog({
    Key? key,
    required this.employee,
  }) : super(key: key);

  @override
  State<AssignEmployeeBusinessesDialog> createState() => _AssignEmployeeBusinessesDialogState();
}

class _AssignEmployeeBusinessesDialogState extends State<AssignEmployeeBusinessesDialog> {
  final BusinessController _businessController = Get.find();
  final ProfileController _profileController = Get.find();
  
  bool isLoading = false;
  List<Map<String, dynamic>> ownerBusinesses = [];
  List<String> employeeCurrentBusinesses = [];
  List<String> selectedBusinesses = [];

  @override
  void initState() {
    super.initState();
    _loadOwnerBusinesses();
    _loadEmployeeCurrentBusinesses();
  }

  Future<void> _loadOwnerBusinesses() async {
    setState(() {
      isLoading = true;
    });

    try {
      // Get current user's businesses (owner's businesses)
      final currentUserBusinesses = _profileController.user['business'] as List<dynamic>? ?? [];
      
      // Fetch business details for each business the owner has
      for (String businessId in currentUserBusinesses) {
        final businessDoc = await FirebaseFirestore.instance
            .collection('businesses')
            .doc(businessId)
            .get();
            
        if (businessDoc.exists) {
          final businessData = businessDoc.data() as Map<String, dynamic>;
          ownerBusinesses.add({
            'id': businessId,
            'name': businessData['name'] ?? 'Unknown Business',
            'description': businessData['description'] ?? '',
          });
        }
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to load businesses: ${e.toString()}',
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

  Future<void> _loadEmployeeCurrentBusinesses() async {
    try {
      // Get employee's current business assignments
      final employeeDoc = await FirebaseFirestore.instance
          .collection('gmanusers')
          .doc(widget.employee.id)
          .get();
          
      if (employeeDoc.exists) {
        final employeeData = employeeDoc.data() as Map<String, dynamic>;
        employeeCurrentBusinesses = List<String>.from(employeeData['business'] ?? []);
        selectedBusinesses = List<String>.from(employeeCurrentBusinesses);
      }
    } catch (e) {
      print('Error loading employee businesses: $e');
    }
  }

  Future<void> _saveBusinessAssignments() async {
    setState(() {
      isLoading = true;
    });

    try {
      final String employeeId = widget.employee.id ?? '';
      
      if (employeeId.isEmpty) {
        throw Exception('Employee ID is missing');
      }

      // Update employee's business list in gmanusers collection
      await FirebaseFirestore.instance
          .collection('gmanusers')
          .doc(employeeId)
          .update({
        'business': selectedBusinesses,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Add employee to each selected business's employees subcollection
      for (String businessId in selectedBusinesses) {
        await FirebaseFirestore.instance
            .collection('employees')
            .doc(businessId)
            .collection('userEmployees')
            .doc(employeeId)
            .set({
          'id': employeeId,
          'name': widget.employee.name,
          'email': widget.employee.email ?? '',
          'role': widget.employee.role ?? 'employee',
          'permissions': widget.employee.permissions ?? [],
          'business': selectedBusinesses,
          'assignedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      // Remove employee from businesses they're no longer assigned to
      final businessesToRemove = employeeCurrentBusinesses
          .where((businessId) => !selectedBusinesses.contains(businessId))
          .toList();
          
      for (String businessId in businessesToRemove) {
        await FirebaseFirestore.instance
            .collection('employees')
            .doc(businessId)
            .collection('userEmployees')
            .doc(employeeId)
            .delete();
      }

      // Refresh ProfileController cache if we updated the current user
      final String currentUserId = _profileController.user['id'] ?? '';
      if (employeeId == currentUserId) {
        await _profileController.refreshUserData();
      }

      Get.snackbar(
        'Success',
        'Employee business assignments updated successfully',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: const Duration(seconds: 4),
      );

      Navigator.of(context).pop();

    } catch (e) {
      Get.snackbar(
        'Update Failed',
        'Failed to update business assignments: ${e.toString()}',
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
    return AlertDialog(
      title: Text(
        'Assign ${widget.employee.name} to Businesses',
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      content: isLoading
          ? const SizedBox(
              height: 200,
              child: Center(child: CircularProgressIndicator()),
            )
          : SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select businesses to assign this employee to:',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (ownerBusinesses.isEmpty)
                    const Text(
                      'No businesses available for assignment.',
                      style: TextStyle(color: Colors.grey),
                    )
                  else
                    ...ownerBusinesses.map((business) {
                      final businessId = business['id'] as String;
                      final businessName = business['name'] as String;
                      final isSelected = selectedBusinesses.contains(businessId);
                      
                      return CheckboxListTile(
                        title: Text(businessName),
                        subtitle: business['description'].toString().isNotEmpty
                            ? Text(
                                business['description'],
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              )
                            : null,
                        value: isSelected,
                        onChanged: (bool? value) {
                          setState(() {
                            if (value == true) {
                              selectedBusinesses.add(businessId);
                            } else {
                              selectedBusinesses.remove(businessId);
                            }
                          });
                        },
                        controlAffinity: ListTileControlAffinity.leading,
                      );
                    }).toList(),
                  const SizedBox(height: 16),
                  if (selectedBusinesses.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Selected Businesses (${selectedBusinesses.length}):',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...selectedBusinesses.map((businessId) {
                            final business = ownerBusinesses.firstWhere(
                              (b) => b['id'] == businessId,
                              orElse: () => {'name': 'Unknown Business'},
                            );
                            return Text(
                              '• ${business['name']}',
                              style: const TextStyle(fontSize: 13),
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                ],
              ),
            ),
      actions: [
        TextButton(
          onPressed: isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: isLoading || selectedBusinesses.isEmpty
              ? null
              : _saveBusinessAssignments,
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
          ),
          child: isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text('Save Assignments'),
        ),
      ],
    );
  }
}
