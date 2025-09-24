import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:mauzo/controllers/pay_role_controller.dart';
import 'package:mauzo/controllers/profile_controller.dart';
import 'package:mauzo/models/employee_loss_model.dart';
import 'package:mauzo/models/early_payment_model.dart';
import '../../utils/constants.dart';

class EmployeeDeductionsScreen extends StatefulWidget {
  const EmployeeDeductionsScreen({Key? key}) : super(key: key);

  @override
  State<EmployeeDeductionsScreen> createState() => _EmployeeDeductionsScreenState();
}

class _EmployeeDeductionsScreenState extends State<EmployeeDeductionsScreen> with SingleTickerProviderStateMixin {
  final PayRoleController _payRoleController = Get.find<PayRoleController>();
  final ProfileController _profileController = Get.find<ProfileController>();
  late TabController _tabController;

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
          'Only business owners can access employee deductions',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      });
    }
  }

  @override
  void dispose() {
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
        title: const Text('Employee Deductions'),
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
              icon: Icon(Icons.warning),
              text: 'Employee Losses',
            ),
            Tab(
              icon: Icon(Icons.payment),
              text: 'Early Payments',
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
          _buildLossesTab(),
          _buildEarlyPaymentsTab(),
        ],
      ),
    );
  }

  Widget _buildLossesTab() {
    return Obx(() {
      final losses = _payRoleController.employeeLosses;

      if (losses.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.warning_amber,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'No employee losses recorded',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Record losses caused by employees for salary deductions',
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
        padding: const EdgeInsets.all(16),
        itemCount: losses.length,
        itemBuilder: (context, index) {
          final loss = losses[index];
          return _buildLossCard(loss);
        },
      );
    });
  }

  Widget _buildEarlyPaymentsTab() {
    return Obx(() {
      final payments = _payRoleController.earlyPayments;

      if (payments.isEmpty) {
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
                'No early payments recorded',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Early payments to employees will appear here',
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
        padding: const EdgeInsets.all(16),
        itemCount: payments.length,
        itemBuilder: (context, index) {
          final payment = payments[index];
          return _buildEarlyPaymentCard(payment);
        },
      );
    });
  }

  Widget _buildLossCard(EmployeeLossModel loss) {
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
              backgroundColor: Colors.red.shade100,
              child: Icon(
                Icons.warning,
                color: Colors.red.shade600,
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
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        loss.categoryDisplayName,
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getLossStatusColor(loss.status).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        loss.statusDisplayName,
                        style: TextStyle(
                          color: _getLossStatusColor(loss.status),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Amount: TSh ${loss.formattedAmount}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Date: ${DateFormat('dd MMM yyyy').format(loss.dateOccurred)}',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (value) => _handleLossAction(value, loss),
              itemBuilder: (context) => [
                if (loss.status == 'pending')
                  const PopupMenuItem(
                    value: 'forgive',
                    child: ListTile(
                      leading: Icon(Icons.check_circle, color: Colors.green, size: 20),
                      title: Text('Forgive Loss'),
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
          ),
          if (loss.description.isNotEmpty)
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
              backgroundColor: Colors.blue.shade100,
              child: Icon(
                Icons.payment,
                color: Colors.blue.shade600,
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
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getPaymentStatusColor(payment.status).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        payment.statusDisplayName,
                        style: TextStyle(
                          color: _getPaymentStatusColor(payment.status),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        payment.paymentMethodDisplayName,
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Amount: TSh ${payment.formattedAmount}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Requested: ${DateFormat('dd MMM yyyy').format(payment.dateRequested)}',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 12,
                  ),
                ),
                if (payment.datePaid != null)
                  Text(
                    'Paid: ${DateFormat('dd MMM yyyy').format(payment.datePaid!)}',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
            trailing: payment.status == 'approved'
                ? PopupMenuButton<String>(
                    onSelected: (value) => _handlePaymentAction(value, payment),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'mark_paid',
                        child: ListTile(
                          leading: Icon(Icons.check_circle, color: Colors.green, size: 20),
                          title: Text('Mark as Paid'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  )
                : null,
          ),
          if (payment.reason.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reason:',
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      payment.reason,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color _getLossStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'deducted':
        return Colors.green;
      case 'forgiven':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  Color _getPaymentStatusColor(String status) {
    switch (status) {
      case 'requested':
        return Colors.orange;
      case 'approved':
        return Colors.blue;
      case 'paid':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  void _handleLossAction(String action, EmployeeLossModel loss) {
    switch (action) {
      case 'forgive':
        _showForgiveLossDialog(loss);
        break;
      case 'delete':
        _showDeleteLossDialog(loss);
        break;
    }
  }

  void _handlePaymentAction(String action, EarlyPaymentModel payment) {
    switch (action) {
      case 'mark_paid':
        _showMarkPaidDialog(payment);
        break;
    }
  }

  void _showForgiveLossDialog(EmployeeLossModel loss) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Forgive Loss'),
        content: Text(
          'Are you sure you want to forgive this loss for ${loss.employeeName}?\n\nAmount: TSh ${loss.formattedAmount}\nDescription: ${loss.description}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _payRoleController.updateLossStatus(loss.lossId, 'forgiven');
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Forgive'),
          ),
        ],
      ),
    );
  }

  void _showDeleteLossDialog(EmployeeLossModel loss) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Loss'),
        content: Text(
          'Are you sure you want to permanently delete this loss record?\n\nEmployee: ${loss.employeeName}\nAmount: TSh ${loss.formattedAmount}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _payRoleController.deleteEmployeeLoss(loss.lossId);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showMarkPaidDialog(EarlyPaymentModel payment) {
    String selectedMethod = payment.paymentMethod;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark as Paid'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Employee: ${payment.employeeName}'),
            Text('Amount: TSh ${payment.formattedAmount}'),
            const SizedBox(height: 16),
            const Text('Payment Method:'),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: selectedMethod,
              items: EarlyPaymentModel.paymentMethods.map((method) {
                return DropdownMenuItem(
                  value: method,
                  child: Text(method == 'cash' ? 'Cash' :
                            method == 'bank_transfer' ? 'Bank Transfer' :
                            method == 'mobile_money' ? 'Mobile Money' : 'Check'),
                );
              }).toList(),
              onChanged: (value) {
                selectedMethod = value!;
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
              await _payRoleController.markEarlyPaymentAsPaid(payment.paymentId, selectedMethod);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Mark Paid'),
          ),
        ],
      ),
    );
  }
}
