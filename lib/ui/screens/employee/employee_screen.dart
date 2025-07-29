import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mauzo/utils/preferences.dart';
import '../../../controllers/employee_controller.dart';
import '../../../controllers/profile_controller.dart';
import '../../widgets/bottomsheets/employee_info_bottom_sheet.dart';
import '../../../utils/constants.dart';


class EmployeesScreen extends StatefulWidget {
  const EmployeesScreen({Key? key}) : super(key: key);

  @override
  State<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends State<EmployeesScreen> {
  final EmployeeController _employeeController = Get.find();
  final ProfileController _profileController = Get.find();


  @override
  void dispose() {
    Timer.run(() {
      _employeeController.searchEmployees.value = _employeeController.employees;
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool canManageEmployees = _profileController.hasPermission('manage_employees');
    
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: Text('Employees'.tr),
      ),
      floatingActionButton: canManageEmployees ? FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(
            context,
            '/employee/add',
          );
        },
        child: const Icon(Icons.add),
      ) : null,
      body: Obx(
            () => Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              SizedBox(
                height: 44,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: TextField(
                        onChanged: (value) {
                          setState(() {
                            _employeeController.search(value);
                          });
                        },
                        decoration: InputDecoration(
                          contentPadding: inputPadding,
                          prefixIcon: const Icon(Icons.search),
                          prefixIconColor: iconGrayColor,
                          filled: true,
                          fillColor: Preferences.getTheme()
                              ? darkGrayColor
                              : gray100Color,
                          hintText: 'search'.tr,
                          hintStyle: bodyText(textPlaceholderColor),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4),
                            borderSide: BorderSide(
                              color: Preferences.getTheme()
                                  ? mediumGrayColor
                                  : const Color(0xFFE0E0E0),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4),
                            borderSide: BorderSide(
                              color: Preferences.getTheme()
                                  ? mediumGrayColor
                                  : const Color(0xFFE0E0E0),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _employeeController.employees.isEmpty
                    ? Center(
                  child: Text(
                    'not_found'.tr,
                    style: bodyText(
                      Theme.of(context).textTheme.bodyMedium!.color,
                    ),
                  ),
                )
                    : ListView.builder(
                  shrinkWrap: true,
                  itemCount: _employeeController.searchEmployees.length,
                  itemBuilder: (context, index) {
                    final employee = _employeeController.searchEmployees[index];
                    return ListTile(
                      onTap: () {
                        showModalBottomSheet(
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(4),
                              topRight: Radius.circular(4),
                            ),
                          ),
                          isScrollControlled: true,
                          context: context,
                          builder: (_) {
                            return EmployeeInfoBottomSheet(
                              employee: employee,
                            );
                          },
                        );
                      },
                      contentPadding: const EdgeInsets.all(0),
                      leading: SizedBox(
                        height: 36,
                        width: 36,
                        child: employee.image != ''
                            ? ClipRRect(
                          borderRadius: BorderRadius.circular(100),
                          child: CachedNetworkImage(
                            imageUrl: employee.image!,
                            fit: BoxFit.cover,
                            placeholder: (context, url) =>
                            const CircularProgressIndicator(),
                            errorWidget: (context, url, error) =>
                                Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(
                                        color: gray200Color,
                                        borderRadius:
                                        BorderRadius.circular(100),
                                      ),
                                    ),
                                    const Icon(
                                      Icons.person,
                                      color: iconGrayColor,
                                    ),
                                  ],
                                ),
                          ),
                        )
                            : Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: gray200Color,
                                borderRadius:
                                BorderRadius.circular(100),
                              ),
                            ),
                            const Icon(
                              Icons.person,
                              color: iconGrayColor,
                            ),
                          ],
                        ),
                      ),
                      title: Text(
                        employee.name,
                        style: bodyText(
                            Theme.of(context).textTheme.bodyLarge!.color),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
