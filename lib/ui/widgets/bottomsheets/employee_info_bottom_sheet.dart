import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mauzo/controllers/employee_controller.dart';
import 'package:mauzo/controllers/profile_controller.dart';
import 'package:mauzo/controllers/sale_controller.dart';
import 'package:mauzo/controllers/pay_role_controller.dart';
import 'package:mauzo/models/profile_model.dart';
import 'package:mauzo/ui/widgets/dialogs/double_action_dialog.dart';
import 'package:mauzo/ui/widgets/dialogs/edit_employee_permissions_dialog.dart';
import 'package:mauzo/ui/widgets/dialogs/assign_employee_businesses_dialog.dart';
import 'package:mauzo/ui/widgets/dialogs/manage_employee_pay_dialog.dart';
import 'package:mauzo/ui/widgets/dialogs/add_employee_loss_dialog.dart';
import 'package:mauzo/ui/widgets/dialogs/add_early_payment_dialog.dart';

import '../../../controllers/business_controller.dart';
import '../../../controllers/employee_controller.dart';
import '../../../utils/constants.dart';
import '../buttons/primary_button.dart';
import '../buttons/secondary_button.dart';

class EmployeeInfoBottomSheet extends StatefulWidget {
  final ProfileModel employee;
  const EmployeeInfoBottomSheet({Key? key, required this.employee})
      : super(key: key);

  @override
  State<EmployeeInfoBottomSheet> createState() => _EmployeeInfoBottomSheetState();
}

class _EmployeeInfoBottomSheetState extends State<EmployeeInfoBottomSheet> {
  late final PayRoleController _payRoleController;

  @override
  void initState() {
    super.initState();
    _payRoleController = Get.put(PayRoleController());
  }

  void _showCreatePayRoleDialog() {
    showDialog(
      context: context,
      builder: (context) => ManageEmployeePayDialog(
        employee: widget.employee,
      ),
    );
  }

  void _showEditPayRoleDialog(existingPayRole) {
    showDialog(
      context: context,
      builder: (context) => ManageEmployeePayDialog(
        employee: widget.employee,
        existingPayRole: existingPayRole,
      ),
    );
  }

  void _showAddLossDialog() {
    final BusinessController businessController = Get.find();
    showDialog(
      context: context,
      builder: (context) => AddEmployeeLossDialog(
        employeeId: widget.employee.id,
        employeeName: widget.employee.name,
        businessId: businessController.business['id'] ?? '',
        businessName: businessController.business['name'] ?? '',
      ),
    );
  }

  void _showAddEarlyPaymentDialog() {
    final BusinessController businessController = Get.find();
    showDialog(
      context: context,
      builder: (context) => AddEarlyPaymentDialog(
        employeeId: widget.employee.id,
        employeeName: widget.employee.name,
        businessId: businessController.business['id'] ?? '',
        businessName: businessController.business['name'] ?? '',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final EmployeeController employeeController = Get.find();
    final BusinessController businessController = Get.find();
    final ProfileController profileController = Get.find();
    final bool canManageEmployees = profileController.hasPermission('manage_employees');
    final SaleController saleController = Get.find();
    return Wrap(
      alignment: WrapAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            vertical: 25.0,
            horizontal: 20,
          ),
          child: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(100),
                child: widget.employee.image != null && widget.employee.image != ''
                    ? Container(
                  decoration: const BoxDecoration(
                    color: gray200Color,
                  ),
                  width: 72,
                  height: 72,
                  child: CachedNetworkImage(
                    placeholder: (context, url) =>
                    const CircularProgressIndicator(),
                    imageUrl: widget.employee.image!,
                    fit: BoxFit.cover,
                    errorWidget: (context, url, error) =>
                    const CircleAvatar(
                      radius: 31,
                      backgroundColor: gray200Color,
                      child: Icon(
                        Icons.person,
                        size: 40,
                        color: primaryColor,
                      ),
                    ),
                  ),
                )
                    : const CircleAvatar(
                  radius: 31,
                  backgroundColor: gray200Color,
                  child: Icon(
                    Icons.person,
                    size: 40,
                    color: primaryColor,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                widget.employee.name,
                style: h5(Theme.of(context).textTheme.bodyLarge!.color),
              ),
              const SizedBox(height: 4),
              Text(
                'Role: ${(widget.employee.role ?? 'employee').toString().capitalizeFirst!}',
                style: bodyText(Theme.of(context).textTheme.bodyMedium!.color),
              ),
              const SizedBox(height: 12),
              if(widget.employee.role!='owner')
              Text(
                widget.employee.password != "" ? widget.employee.password : "no_password".tr,
                style: bodyText(
                  Theme.of(context).textTheme.bodyMedium!.color,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                  widget.employee.email != null && widget.employee.email != ''
                      ? widget.employee.email!
                      : 'email'.tr,
                  style: bodyText(
                    Theme.of(context).textTheme.bodyMedium!.color,
                  )),
              
              // Display assigned businesses for multi-business employees
              if (widget.employee.business != null && widget.employee.business!.length > 1) ...[
                const SizedBox(height: 12),
                Text(
                  'Assigned to ${widget.employee.business!.length} businesses',
                  style: bodyText(
                    Colors.blue[600]!,
                  ),
                ),
              ],

              // Pay Management Section (Only for Owners)
              if (profileController.user['role'] == 'owner') ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.payment, color: Colors.green[600], size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Pay Management',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.green[700],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      
                      // Show current pay roles
                      Obx(() {
                        final employeePayRoles = _payRoleController.getEmployeePayRoles(widget.employee.id);
                        
                        if (employeePayRoles.isEmpty) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'No pay roles assigned',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: _showCreatePayRoleDialog,
                                  icon: const Icon(Icons.add, size: 18),
                                  label: const Text('Create Pay Role'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green[600],
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              
                              // Loss and Early Payment buttons (even without pay role)
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: _showAddLossDialog,
                                      icon: const Icon(Icons.warning, size: 16),
                                      label: const Text('Record Loss'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red[600],
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 10),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: _showAddEarlyPaymentDialog,
                                      icon: const Icon(Icons.payment, size: 16),
                                      label: const Text('Early Payment'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blue[600],
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 10),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          );
                        }
                        
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Pay Roles (${employeePayRoles.length})',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.green[700],
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 8),
                            
                            // List current pay roles
                            ...employeePayRoles.map((payRole) => Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.green[200]!),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          payRole.businessName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.blue[100],
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: Text(
                                                payRole.payType.toString().split('.').last.capitalizeFirst!,
                                                style: TextStyle(
                                                  color: Colors.blue[700],
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              payRole.getFormattedPayRate(),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () => _showEditPayRoleDialog(payRole),
                                    icon: Icon(Icons.edit, size: 18, color: Colors.green[600]),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                  ),
                                ],
                              ),
                            )).toList(),
                            
                            const SizedBox(height: 8),
                            
                            // Action buttons row
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _showCreatePayRoleDialog,
                                    icon: const Icon(Icons.add, size: 16),
                                    label: const Text('Add Pay Role'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.green[600],
                                      side: BorderSide(color: Colors.green[600]!),
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            
                            const SizedBox(height: 8),
                            
                            // Loss and Early Payment buttons
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _showAddLossDialog,
                                    icon: const Icon(Icons.warning, size: 16),
                                    label: const Text('Record Loss'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red[600],
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _showAddEarlyPaymentDialog,
                                    icon: const Icon(Icons.payment, size: 16),
                                    label: const Text('Early Payment'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue[600],
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 44),
              SizedBox(
                height: 44,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if(widget.employee.role!='owner' && canManageEmployees)
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: borderColor,
                        ),
                      ),
                      child: IconButton(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (_) {
                              return DoubleActionDialog(
                                title: 'delete_employee'.tr,
                                content: 'delete_employee_confirmation'.tr,
                                confirm: 'delete'.tr,
                                cancel: 'cancel'.tr,
                                onConfirm: () {

                                  employeeController.deleteUser(
                                    userId: widget.employee.id ?? '', // Use null-aware operator to avoid null errors
                                    businessId: businessController.business['id'] ?? '', // Ensure the key exists in the map
                                  );
                                  Navigator.pop(context);

                                },
                                onCancel: () {
                                  Navigator.pop(context);
                                },
                              );
                            },
                          );
                        },
                        icon: const Icon(
                          Icons.delete,
                          color: redColor,
                        ),
                      ),
                    ),
                    if (canManageEmployees) ...[
                      const SizedBox(width: 8),
                      SecondaryButton(
                        text: 'Edit Permissions',
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) => EditEmployeePermissionsDialog(
                              employee: widget.employee,
                            ),
                          );
                        },
                      ),
                    ],
                    // Multi-business assignment button (only for owners)
                    if (profileController.user['role'] == 'owner' && widget.employee.role != 'owner') ...[
                      const SizedBox(width: 8),
                      SecondaryButton(
                        text: 'Assign Businesses',
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) => AssignEmployeeBusinessesDialog(
                              employee: widget.employee,
                            ),
                          );
                        },
                      ),
                    ],
                    const SizedBox(width: 8),
                    Expanded(
                      child: PrimaryButton(
                        text: 'view_orders'.tr,
                        onPressed: () {
                          saleController.filterEmployee([widget.employee.id]);
                          saleController.filterSales();
                          Navigator.pushNamed(context, '/sales');
                        },
                      ),
                    ),
                  ],
                ),
              )
            ],
          ),
        ),
      ],
    );
  }
}
