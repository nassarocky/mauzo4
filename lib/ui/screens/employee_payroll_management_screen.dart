import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:mauzo/controllers/pay_role_controller.dart';
import 'package:mauzo/controllers/profile_controller.dart';
import 'package:mauzo/models/early_payment_model.dart';
import 'package:mauzo/models/employee_loss_model.dart';
import 'package:mauzo/ui/widgets/dialogs/add_early_payment_dialog.dart';
import 'package:mauzo/ui/widgets/dialogs/add_employee_loss_dialog.dart';
import '../../utils/constants.dart';
import 'package:mauzo/controllers/business_controller.dart';

class EmployeePayrollManagementScreen extends StatefulWidget {
  final String? employeeFilter;
  final String? employeeName;

  const EmployeePayrollManagementScreen({
    Key? key,
    this.employeeFilter,
    this.employeeName,
  }) : super(key: key);

  @override
  State<EmployeePayrollManagementScreen> createState() => _EmployeePayrollManagementScreenState();
}

class _EmployeePayrollManagementScreenState extends State<EmployeePayrollManagementScreen>
    with SingleTickerProviderStateMixin {
  final PayRoleController _payRoleController = Get.find();
  final ProfileController _profileController = Get.find();
  final BusinessController _businessController = Get.find();
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    // Check if user is owner
    if (!_isOwner()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Get.back();
        Get.snackbar(
          'Access Denied',
          'Only business owners can access payroll management',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
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
        title: Text(widget.employeeName != null 
            ? '${widget.employeeName} - Payroll'
            : 'Employee Payroll Management'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(
              icon: Icon(Icons.payment),
              text: 'Early Payments',
            ),
            Tab(
              icon: Icon(Icons.warning),
              text: 'Employee Losses',
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _payRoleController.refreshPayRoles(),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildEarlyPaymentsTab(),
          _buildEmployeeLossesTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDialog,
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        icon: Icon(_tabController.index == 0 ? Icons.payment : Icons.warning),
        label: Text(_tabController.index == 0 ? 'Add Payment' : 'Add Loss'),
      ),
    );
  }

  Widget _buildEarlyPaymentsTab() {
    return Column(
      children: [
        // Search and filters
        Container(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search early payments...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
        ),
        
        // Early payments list
        Expanded(
          child: Obx(() {
            final earlyPayments = _payRoleController.earlyPayments
                .where((payment) => widget.employeeFilter == null || 
                    payment.employeeId == widget.employeeFilter)
                .toList();

            if (earlyPayments.isEmpty) {
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
                      'No early payments found',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: earlyPayments.length,
              itemBuilder: (context, index) {
                final payment = earlyPayments[index];
                return _buildEarlyPaymentCard(payment);
              },
            );
          }),
        ),
      ],
    );
  }

  Widget _buildEmployeeLossesTab() {
    return Column(
      children: [
        // Search and filters
        Container(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search employee losses...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
        ),
        
        // Employee losses list
        Expanded(
          child: Obx(() {
            final employeeLosses = _payRoleController.employeeLosses
                .where((loss) => widget.employeeFilter == null || 
                    loss.employeeId == widget.employeeFilter)
                .toList();

            if (employeeLosses.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.warning,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No employee losses found',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: employeeLosses.length,
              itemBuilder: (context, index) {
                final loss = employeeLosses[index];
                return _buildEmployeeLossCard(loss);
              },
            );
          }),
        ),
      ],
    );
  }

  Widget _buildEarlyPaymentCard(EarlyPaymentModel payment) {
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
              backgroundColor: _getPaymentStatusColor(payment.status),
              child: Icon(
                _getPaymentStatusIcon(payment.status),
                color: Colors.white,
                size: 20,
              ),
            ),
            title: Text(
              payment.employeeName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  payment.businessName,
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  'Amount: TZS ${payment.amount.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Reason: ${payment.reason}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getPaymentStatusColor(payment.status).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        payment.status.toUpperCase(),
                        style: TextStyle(
                          color: _getPaymentStatusColor(payment.status),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Requested: ${DateFormat('dd MMM yyyy').format(payment.dateRequested)}',
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
            trailing: _buildPaymentActions(payment),
          ),
          if (payment.notes != null && payment.notes!.isNotEmpty)
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
                  payment.notes!,
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

  Widget _buildEmployeeLossCard(EmployeeLossModel loss) {
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
              backgroundColor: _getLossStatusColor(loss.status),
              child: Icon(
                _getLossStatusIcon(loss.status),
                color: Colors.white,
                size: 20,
              ),
            ),
            title: Text(
              loss.employeeName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  loss.businessName,
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  'Amount: TZS ${loss.amount.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Category: ${_getCategoryDisplayName(loss.category)}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getLossStatusColor(loss.status).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        loss.status.toUpperCase(),
                        style: TextStyle(
                          color: _getLossStatusColor(loss.status),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Occurred: ${DateFormat('dd MMM yyyy').format(loss.dateOccurred)}',
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
            trailing: _buildLossActions(loss),
          ),
          // Description
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
                loss.description,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentActions(EarlyPaymentModel payment) {
    if (payment.status == 'approved') {
      return ElevatedButton(
        onPressed: () => _showMarkAsPaidDialog(payment),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        child: const Text('Mark as Paid', style: TextStyle(fontSize: 12)),
      );
    } else if (payment.status == 'paid' && !payment.isDeductedFromSalary) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          'Pending Deduction',
          style: TextStyle(
            color: Colors.orange,
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    } else {
      return const SizedBox.shrink();
    }
  }

  Widget _buildLossActions(EmployeeLossModel loss) {
    if (loss.status == 'pending') {
      return ElevatedButton(
        onPressed: () => _showMarkLossAsDeductedDialog(loss),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        child: const Text('Mark as Deducted', style: TextStyle(fontSize: 12)),
      );
    } else {
      return const SizedBox.shrink();
    }
  }

  Color _getPaymentStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Colors.blue;
      case 'paid':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData _getPaymentStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Icons.check_circle;
      case 'paid':
        return Icons.payment;
      default:
        return Icons.pending;
    }
  }

  Color _getLossStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'deducted':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getLossStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Icons.pending;
      case 'deducted':
        return Icons.remove_circle;
      default:
        return Icons.warning;
    }
  }

  String _getCategoryDisplayName(String category) {
    switch (category) {
      case 'damage':
        return 'Property Damage';
      case 'theft':
        return 'Theft/Loss';
      case 'shortage':
        return 'Cash Shortage';
      case 'mistake':
        return 'Costly Mistake';
      case 'other':
        return 'Other Loss';
      default:
        return category;
    }
  }

  void _showAddDialog() {
    if (_tabController.index == 0) {
      _showAddEarlyPaymentDialog();
    } else {
      _showAddEmployeeLossDialog();
    }
  }

  void _showAddEarlyPaymentDialog() {
    // You would need to implement employee selection first
    Get.snackbar(
      'Feature Coming Soon',
      'Employee selection for early payments will be available soon',
      backgroundColor: Colors.blue,
      colorText: Colors.white,
    );
  }

  void _showAddEmployeeLossDialog() {
    // You would need to implement employee selection first
    Get.snackbar(
      'Feature Coming Soon',
      'Employee selection for losses will be available soon',
      backgroundColor: Colors.blue,
      colorText: Colors.white,
    );
  }

  void _showMarkAsPaidDialog(EarlyPaymentModel payment) {
    final paymentMethods = ['Cash', 'Bank Transfer', 'Mobile Money', 'Check'];
    String selectedMethod = paymentMethods.first;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Mark as Paid'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Employee: ${payment.employeeName}'),
              Text('Amount: TZS ${payment.amount.toStringAsFixed(0)}'),
              const SizedBox(height: 16),
              const Text('Payment Method:'),
              const SizedBox(height: 8),
              if (((_businessController.business['multiFundEnabled'] ?? false) == true))
                DropdownButtonFormField<String>(
                  value: selectedMethod,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: paymentMethods.map((method) {
                    return DropdownMenuItem(
                      value: method,
                      child: Text(method),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedMethod = value!;
                    });
                  },
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _payRoleController.markEarlyPaymentAsPaid(
                  payment.paymentId,
                  selectedMethod,
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('Mark as Paid'),
            ),
          ],
        ),
      ),
    );
  }

  void _showMarkLossAsDeductedDialog(EmployeeLossModel loss) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark Loss as Deducted'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Employee: ${loss.employeeName}'),
            Text('Amount: TZS ${loss.amount.toStringAsFixed(0)}'),
            Text('Category: ${_getCategoryDisplayName(loss.category)}'),
            const SizedBox(height: 8),
            const Text(
              'This will mark the loss as deducted from the employee\'s salary.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _payRoleController.updateLossStatus(loss.lossId, 'deducted');
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Mark as Deducted'),
          ),
        ],
      ),
    );
  }
}
