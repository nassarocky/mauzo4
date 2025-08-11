import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mauzo/controllers/employee_controller.dart';
import 'package:mauzo/controllers/profile_controller.dart';
import 'package:mauzo/controllers/sale_controller.dart';
import 'package:mauzo/models/profile_model.dart';
import 'package:mauzo/ui/widgets/dialogs/double_action_dialog.dart';
import 'package:mauzo/ui/widgets/dialogs/edit_employee_permissions_dialog.dart';
import 'package:mauzo/ui/widgets/dialogs/assign_employee_businesses_dialog.dart';

import '../../../controllers/business_controller.dart';
import '../../../controllers/employee_controller.dart';
import '../../../utils/constants.dart';
import '../buttons/primary_button.dart';
import '../buttons/secondary_button.dart';

class EmployeeInfoBottomSheet extends StatelessWidget {
  final ProfileModel employee;
  const EmployeeInfoBottomSheet({Key? key, required this.employee})
      : super(key: key);

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
                child: employee.image != null && employee.image != ''
                    ? Container(
                  decoration: const BoxDecoration(
                    color: gray200Color,
                  ),
                  width: 72,
                  height: 72,
                  child: CachedNetworkImage(
                    placeholder: (context, url) =>
                    const CircularProgressIndicator(),
                    imageUrl: employee.image!,
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
                employee.name,
                style: h5(Theme.of(context).textTheme.bodyLarge!.color),
              ),
              const SizedBox(height: 4),
              Text(
                'Role: ${(employee.role ?? 'employee').toString().capitalizeFirst!}',
                style: bodyText(Theme.of(context).textTheme.bodyMedium!.color),
              ),
              const SizedBox(height: 12),
              if(employee.role!='owner')
              Text(
                employee.password != "" ? employee.password : "no_password".tr,
                style: bodyText(
                  Theme.of(context).textTheme.bodyMedium!.color,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                  employee.email != null && employee.email != ''
                      ? employee.email!
                      : 'email'.tr,
                  style: bodyText(
                    Theme.of(context).textTheme.bodyMedium!.color,
                  )),
              
              // Display assigned businesses for multi-business employees
              if (employee.business != null && employee.business!.length > 1) ...[
                const SizedBox(height: 12),
                Text(
                  'Assigned to ${employee.business!.length} businesses',
                  style: bodyText(
                    Colors.blue[600]!,
                  ),
                ),
              ],

              const SizedBox(height: 44),
              SizedBox(
                height: 44,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if(employee.role!='owner' && canManageEmployees)
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
                                    userId: employee.id ?? '', // Use null-aware operator to avoid null errors
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
                              employee: employee,
                            ),
                          );
                        },
                      ),
                    ],
                    // Multi-business assignment button (only for owners)
                    if (profileController.user['role'] == 'owner' && employee.role != 'owner') ...[
                      const SizedBox(width: 8),
                      SecondaryButton(
                        text: 'Assign Businesses',
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) => AssignEmployeeBusinessesDialog(
                              employee: employee,
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
                          saleController.filterEmployee([employee.id]);
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
