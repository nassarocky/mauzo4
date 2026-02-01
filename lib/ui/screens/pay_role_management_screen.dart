import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mauzo/controllers/pay_role_controller.dart';
import 'package:mauzo/controllers/profile_controller.dart';
import 'package:mauzo/models/pay_role_model.dart';
import 'package:mauzo/models/profile_model.dart';
import 'package:mauzo/models/employee_loss_model.dart';
import 'package:mauzo/models/early_payment_model.dart';
import 'package:mauzo/ui/widgets/dialogs/manage_employee_pay_dialog.dart';
import 'package:mauzo/ui/widgets/dialogs/add_employee_loss_dialog.dart';
import 'package:mauzo/ui/widgets/dialogs/add_early_payment_dialog.dart';
import '../widgets/dialogs/select_employee_for_pay_role_dialog.dart';
import 'employee_payroll_management_screen.dart';
import '../../utils/constants.dart';
import 'package:intl/intl.dart';

class PayRoleManagementScreen extends StatefulWidget {
  const PayRoleManagementScreen({Key? key}) : super(key: key);

  @override
  State<PayRoleManagementScreen> createState() => _PayRoleManagementScreenState();
}

class _PayRoleManagementScreenState extends State<PayRoleManagementScreen> with SingleTickerProviderStateMixin {
  final PayRoleController _payRoleController = Get.put(PayRoleController());
  final ProfileController _profileController = Get.find();
  final TextEditingController _searchController = TextEditingController();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // Check if user is owner
    if (!_isOwner()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Get.back();
        Get.snackbar(
          'Access Denied',
          'Only business owners can access pay role management',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  bool _isOwner() {
    return _profileController.user['role'] == 'owner';
  }

  @override
  Widget build(BuildContext context) {
    if (!_isOwner()) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Pay Role Management'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _payRoleController.refreshPayRoles(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Header with statistics
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: primaryColor,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                // Statistics Cards
                Obx(() {
                  final totalPayroll = _payRoleController.getTotalMonthlyPayrollAllBusinesses();
                  final payTypeStats = _payRoleController.getPayTypeStatistics();
                  final totalEmployees = _payRoleController.payRoles.length;

                  return Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Total Monthly Payroll',
                          'TZS ${totalPayroll.toStringAsFixed(0)}',
                          Icons.account_balance_wallet,
                          Colors.green,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          'Employees with Pay',
                          '$totalEmployees',
                          Icons.people,
                          Colors.blue,
                        ),
                      ),
                    ],
                  );
                }),
              ],
            ),
          ),

          // Search and Filters
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Search Bar
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search employees or businesses...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              _payRoleController.setSearchQuery('');
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  onChanged: (value) => _payRoleController.setSearchQuery(value),
                ),
                const SizedBox(height: 12),

                // Filter Row
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      // Business Filter
                      Obx(() => _buildFilterChip(
                        'All Businesses',
                        _payRoleController.selectedBusinessFilter.value.isEmpty,
                        () => _payRoleController.setBusinessFilter(''),
                      )),
                      const SizedBox(width: 8),

                      // Pay Type Filters
                      ...PayType.values.map((payType) =>
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Obx(() => _buildFilterChip(
                            payType.toString().split('.').last.capitalizeFirst!,
                            _payRoleController.selectedPayTypeFilter.value == payType.toString().split('.').last,
                            () => _payRoleController.selectedPayTypeFilter.value == payType.toString().split('.').last
                                ? _payRoleController.setPayTypeFilter('')
                                : _payRoleController.setPayTypeFilter(payType.toString().split('.').last),
                          )),
                        ),
                      ),

                      // Clear Filters
                      Obx(() {
                        final hasFilters = _payRoleController.selectedBusinessFilter.value.isNotEmpty ||
                            _payRoleController.selectedPayTypeFilter.value.isNotEmpty ||
                            _payRoleController.searchQuery.value.isNotEmpty;
                        
                        if (!hasFilters) return const SizedBox.shrink();
                        
                        return Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: TextButton.icon(
                            onPressed: () {
                              _searchController.clear();
                              _payRoleController.clearFilters();
                            },
                            icon: const Icon(Icons.clear_all, size: 16),
                            label: const Text('Clear All'),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Pay Roles List
          Expanded(
            child: Obx(() {
              if (_payRoleController.isLoading.value) {
                return const Center(child: CircularProgressIndicator());
              }

              final payRoles = _payRoleController.filteredPayRoles;

              if (payRoles.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.payment,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No pay roles found'.tr,
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Create pay roles for your employees to get started'.tr,
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: payRoles.length,
                itemBuilder: (context, index) {
                  final payRole = payRoles[index];
                  return _buildPayRoleCard(payRole);
                },
              );
            }),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreatePayRoleDialog(),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Pay Role'),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? primaryColor : Colors.grey[300]!,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[700],
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildPayRoleCard(PayRoleModel payRole) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: CircleAvatar(
              backgroundColor: _getPayTypeColor(payRole.payType),
              child: Text(
                payRole.employeeName.isNotEmpty
                    ? payRole.employeeName[0].toUpperCase()
                    : 'E',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            title: Text(
              payRole.employeeName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  payRole.businessName,
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getPayTypeColor(payRole.payType).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        payRole.payType.toString().split('.').last.capitalizeFirst!,
                        style: TextStyle(
                          color: _getPayTypeColor(payRole.payType),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      payRole.getFormattedPayRate(),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Payment count info
                Text(
                  payRole.getPaymentCountDuration(),
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 12,
                  ),
                ),
                Text(
                  payRole.getPaymentFrequencyInfo(),
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Payment navigation button
                IconButton(
                  onPressed: () => _navigateToPayments(payRole),
                  icon: const Icon(Icons.payment),
                  tooltip: 'View Payments',
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.blue.withOpacity(0.1),
                    foregroundColor: Colors.blue,
                  ),
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  onSelected: (value) => _handlePayRoleAction(value, payRole),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: ListTile(
                        leading: Icon(Icons.edit, size: 20),
                        title: Text('Edit'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'deactivate',
                      child: ListTile(
                        leading: Icon(Icons.pause_circle, size: 20),
                        title: Text('Deactivate'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        leading: Icon(Icons.delete, color: Colors.red, size: 20),
                        title: Text('Delete', style: TextStyle(color: Colors.red)),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (payRole.notes != null && payRole.notes!.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  payRole.notes!,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color _getPayTypeColor(PayType payType) {
    switch (payType) {
      case PayType.salary:
        return Colors.green;
      case PayType.commission:
        return Colors.orange;
    }
  }

  void _handlePayRoleAction(String action, PayRoleModel payRole) {
    switch (action) {
      case 'edit':
        _showEditPayRoleDialog(payRole);
        break;
      case 'deactivate':
        _showDeactivateConfirmation(payRole);
        break;
      case 'delete':
        _showDeleteConfirmation(payRole);
        break;
    }
  }

  void _showCreatePayRoleDialog() {
    Navigator.pushNamed(context, '/select-employee-pay-role');
  }

  void _showEditPayRoleDialog(PayRoleModel payRole) async {
    Get.dialog(const Center(child: CircularProgressIndicator()), barrierDismissible: false);

    try {
      final employeeDoc = await FirebaseFirestore.instance
          .collection('gmanusers')
          .doc(payRole.employeeId)
          .get();

      Get.back(); // Dismiss loading indicator

      if (employeeDoc.exists) {
        final employeeProfile = ProfileModel.fromSnapshot(employeeDoc);
        showDialog(
          context: context,
          builder: (context) => ManageEmployeePayDialog(
            employee: employeeProfile,
            businessId: payRole.businessId,
            businessName: payRole.businessName,
            existingPayRole: payRole,
          ),
        );
      } else {
        Get.snackbar(
          'Error',
          'Could not find employee details for ${payRole.employeeName}.',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      Get.back(); // Dismiss loading indicator
      Get.snackbar(
        'Error',
        'Failed to fetch employee details: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  void _showDeactivateConfirmation(PayRoleModel payRole) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Deactivate Pay Role'),
        content: Text(
          'Are you sure you want to deactivate the pay role for ${payRole.employeeName}?\n\nThis will stop all pay calculations but preserve the data.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _payRoleController.deactivatePayRole(payRole.id);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(PayRoleModel payRole) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Pay Role'),
        content: Text(
          'Are you sure you want to permanently delete the pay role for ${payRole.employeeName}?\n\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _payRoleController.deletePayRole(payRole.id);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _navigateToPayments(PayRoleModel payRole) {
    Get.to(() => EmployeePayrollManagementScreen(
      employeeFilter: payRole.employeeId,
      employeeName: payRole.employeeName,
    ));
  }
}
