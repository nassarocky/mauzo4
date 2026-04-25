import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mauzo/controllers/payment_controller.dart';
import 'package:mauzo/controllers/pay_role_controller.dart';
import 'package:mauzo/controllers/profile_controller.dart';
import 'package:mauzo/models/payment_record_model.dart';
import 'package:mauzo/models/early_payment_model.dart';
import 'package:mauzo/models/employee_loss_model.dart';
// Removed dialog imports - no longer needed
import '../widgets/dialogs/create_payment_dialog.dart';
import '../../utils/constants.dart';

class PaymentManagementScreen extends StatefulWidget {
  const PaymentManagementScreen({Key? key}) : super(key: key);

  @override
  State<PaymentManagementScreen> createState() => _PaymentManagementScreenState();
}

class _PaymentManagementScreenState extends State<PaymentManagementScreen> {
  final PaymentController _paymentController = Get.put(PaymentController());
  final PayRoleController _payRoleController = Get.put(PayRoleController());
  final ProfileController _profileController = Get.find();
  final TextEditingController _searchController = TextEditingController();
  
  String? employeeFilter;
  String? employeeName;

  EarlyPaymentModel? _getEarlyPaymentById(String id) {
    try {
      return _payRoleController.earlyPayments.firstWhere((e) => e.paymentId == id);
    } catch (_) {
      return null;
    }
  }

  EmployeeLossModel? _getEmployeeLossById(String id) {
    try {
      return _payRoleController.employeeLosses.firstWhere((l) => l.lossId == id);
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    // Check if user is owner
    if (!_isOwner()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Get.back();
        Get.snackbar(
          'Access Denied'.tr,
          'Only business owners can access payment management'.tr,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      });
    }
  }

  @override
  void dispose() {
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
        title: Text(employeeName != null 
            ? '${'Payments - '.tr}$employeeName' 
            : 'Payment Management'.tr),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _paymentController.refreshPayments(),
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
                  final stats = _paymentController.getPaymentStatistics();
                  
                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              'Total Pending',
                              'TZS ${stats['pendingAmount'].toStringAsFixed(0)}',
                              Icons.pending_actions,
                              Colors.orange,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatCard(
                              'Total Paid',
                              'TZS ${stats['paidAmount'].toStringAsFixed(0)}',
                              Icons.check_circle,
                              Colors.green,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              'Overdue',
                              '${stats['overduePayments']} payments',
                              Icons.warning,
                              Colors.red,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatCard(
                              'Total Payments',
                              '${stats['totalPayments']}',
                              Icons.receipt,
                              Colors.blue,
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

          // Search and Filters
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Search Bar
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search employees or reference numbers...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              _paymentController.setSearchQuery('');
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
                  onChanged: (value) => _paymentController.setSearchQuery(value),
                ),
                const SizedBox(height: 12),

                // Filter Row
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      // Status Filters
                      _buildFilterChip(
                        'All',
                        _paymentController.selectedStatusFilter.value.isEmpty,
                        () => _paymentController.setStatusFilter(''),
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        'Pending',
                        _paymentController.selectedStatusFilter.value == 'pending',
                        () => _paymentController.selectedStatusFilter.value == 'pending'
                            ? _paymentController.setStatusFilter('')
                            : _paymentController.setStatusFilter('pending'),
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        'Paid',
                        _paymentController.selectedStatusFilter.value == 'paid',
                        () => _paymentController.selectedStatusFilter.value == 'paid'
                            ? _paymentController.setStatusFilter('')
                            : _paymentController.setStatusFilter('paid'),
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        'Overdue',
                        _paymentController.selectedStatusFilter.value == 'overdue',
                        () => _paymentController.selectedStatusFilter.value == 'overdue'
                            ? _paymentController.setStatusFilter('')
                            : _paymentController.setStatusFilter('overdue'),
                      ),

                      // Clear Filters
                      Obx(() {
                        final hasFilters = _paymentController.selectedBusinessFilter.value.isNotEmpty ||
                            _paymentController.selectedStatusFilter.value.isNotEmpty ||
                            _paymentController.searchQuery.value.isNotEmpty;
                        
                        if (!hasFilters) return const SizedBox.shrink();
                        
                        return Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: TextButton.icon(
                            onPressed: () {
                              _searchController.clear();
                              _paymentController.clearFilters();
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

          // Payment Records List
          Expanded(
            child: Obx(() {
              if (_paymentController.isLoading.value) {
                return const Center(child: CircularProgressIndicator());
              }

              final payments = _paymentController.filteredPaymentRecords;

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
                        'No payment records found',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Create payment records to track salary payments',
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

              // Filter by employee if specified
              final displayPayments = employeeFilter != null
                  ? payments.where((p) => p.employeeId == employeeFilter).toList()
                  : payments;
              
              if (employeeFilter != null && displayPayments.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.payment_outlined, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No payments found for $employeeName',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Payments will appear here once generated',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                );
              }

              return Column(
                children: [
                  // Employee summary if filtered
                  if (employeeFilter != null && displayPayments.isNotEmpty)
                    _buildEmployeeSummary(displayPayments),
                  
                  Expanded(
                    child: ListView.builder(
                      itemCount: displayPayments.length,
                      itemBuilder: (context, index) {
                        final payment = displayPayments[index];
                        return _buildPaymentCard(payment);
                      },
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _paymentController.generateAutomaticPayments(),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.refresh),
        label: const Text('Generate Payments'),
      ),
    );
  }

  void _confirmDelete(PaymentRecord payment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Payment'),
        content: Text(
          'Are you sure you want to delete this payment for ${payment.employeeName}?\n\n'
          "Amount: ${payment.getFormattedAmount('TZS')}\n"
          'Period: ${payment.getFormattedPayPeriod()}\n\n'
          'If an expense was created for this payment, it will also be deleted.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await _paymentController.deletePayment(payment.id);
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
              fontSize: 16,
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

  bool _paymentHasSalaryBreakdown(PaymentRecord p) {
    if ((p.grossSalary ?? 0) > 0) return true;
    if ((p.advanceDeductions ?? 0) > 0) return true;
    if ((p.lossDeductions ?? 0) > 0) return true;
    if (p.appliedEarlyPaymentDetails != null && p.appliedEarlyPaymentDetails!.isNotEmpty) return true;
    if (p.appliedLossDetails != null && p.appliedLossDetails!.isNotEmpty) return true;
    if (p.deductedEarlyPaymentIds != null && p.deductedEarlyPaymentIds!.isNotEmpty) return true;
    if (p.deductedLossIds != null && p.deductedLossIds!.isNotEmpty) return true;
    return false;
  }

  Widget _buildPendingDeductionHint(PaymentRecord payment) {
    if (payment.status == PaymentStatus.paid || payment.status == PaymentStatus.cancelled) {
      return const SizedBox.shrink();
    }
    if (!_paymentHasSalaryBreakdown(payment)) return const SizedBox.shrink();
    final adv = payment.advanceDeductions ?? 0;
    final loss = payment.lossDeductions ?? 0;
    if (adv <= 0 && loss <= 0) {
      final hasDetail = (payment.appliedEarlyPaymentDetails?.isNotEmpty ?? false) ||
          (payment.appliedLossDetails?.isNotEmpty ?? false) ||
          (payment.deductedEarlyPaymentIds?.isNotEmpty ?? false) ||
          (payment.deductedLossIds?.isNotEmpty ?? false);
      if (!hasDetail) return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 14, color: Colors.deepOrange.shade700),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Deductions apply hint'.tr,
              style: TextStyle(
                fontSize: 11,
                color: Colors.deepOrange.shade800,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Shared breakdown: gross, advances, losses, net, carryover, itemized lines with reasons.
  Widget _buildSalaryDeductionBreakdown(PaymentRecord payment) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Salary breakdown'.tr,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 6),
        if ((payment.grossSalary ?? 0) > 0)
          _buildDetailRow('Salary (Gross)', 'TZS ${(payment.grossSalary!).toStringAsFixed(0)}'),
        if ((payment.advanceDeductions ?? 0) > 0)
          _buildDetailRow('Early Payments', '- TZS ${(payment.advanceDeductions ?? 0).toStringAsFixed(0)}'),
        if ((payment.lossDeductions ?? 0) > 0)
          _buildDetailRow('Employee Losses', '- TZS ${(payment.lossDeductions ?? 0).toStringAsFixed(0)}'),
        _buildDetailRow('Net to Pay', 'TZS ${payment.amount.toStringAsFixed(0)}', isTotal: true),
        if ((payment.carryoverDeductions ?? 0) > 0)
          _buildDetailRow('Carryover to Next Period', 'TZS ${(payment.carryoverDeductions ?? 0).toStringAsFixed(0)}'),
        const SizedBox(height: 8),
        if ((payment.appliedEarlyPaymentDetails ?? []).isNotEmpty) ...[
          Text(
            'Applied Early Payments (this period):',
            style: TextStyle(fontSize: 11, color: Colors.grey[700], fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          ...((payment.appliedEarlyPaymentDetails ?? []).map((m) {
            final id = (m['id'] ?? '').toString();
            final amount = (m['amount'] ?? 0).toDouble();
            final ep = id.isEmpty ? null : _getEarlyPaymentById(id);
            final reason = ep?.reason ?? 'Early payment';
            final date = ep?.dateRequested;
            final dateStr = date != null ? '${date.day}/${date.month}/${date.year}' : '';
            return Text(
              '- TZS ${amount.toStringAsFixed(0)} • $reason ${dateStr.isNotEmpty ? '• $dateStr' : ''}',
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            );
          })),
        ] else if ((payment.deductedEarlyPaymentIds ?? []).isNotEmpty) ...[
          Text(
            'Applied Early Payments:',
            style: TextStyle(fontSize: 11, color: Colors.grey[700], fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          ...((payment.deductedEarlyPaymentIds ?? []).map((id) {
            final ep = _getEarlyPaymentById(id);
            if (ep == null) return Text('- $id', style: TextStyle(fontSize: 11, color: Colors.grey[600]));
            return Text(
              '- TZS ${ep.amount.toStringAsFixed(0)} • ${ep.reason} • ${ep.dateRequested.day}/${ep.dateRequested.month}/${ep.dateRequested.year}',
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            );
          })),
        ],
        if ((payment.appliedLossDetails ?? []).isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            'Applied Losses (this period):',
            style: TextStyle(fontSize: 11, color: Colors.grey[700], fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          ...((payment.appliedLossDetails ?? []).map((m) {
            final id = (m['id'] ?? '').toString();
            final amount = (m['amount'] ?? 0).toDouble();
            final loss = id.isEmpty ? null : _getEmployeeLossById(id);
            final cat = loss?.categoryDisplayName ?? 'Loss';
            final date = loss?.dateOccurred;
            final dateStr = date != null ? '${date.day}/${date.month}/${date.year}' : '';
            final desc = (loss?.description ?? '').trim();
            final descShort = desc.length > 72 ? '${desc.substring(0, 72)}…' : desc;
            final reasonPart = descShort.isNotEmpty ? ' • ${'Loss reason'.tr}: $descShort' : '';
            return Text(
              '- TZS ${amount.toStringAsFixed(0)} • $cat $reasonPart ${dateStr.isNotEmpty ? '• $dateStr' : ''}',
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            );
          })),
        ] else if ((payment.deductedLossIds ?? []).isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            'Applied Losses:',
            style: TextStyle(fontSize: 11, color: Colors.grey[700], fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          ...((payment.deductedLossIds ?? []).map((id) {
            final loss = _getEmployeeLossById(id);
            if (loss == null) return Text('- $id', style: TextStyle(fontSize: 11, color: Colors.grey[600]));
            final desc = loss.description.trim();
            final descShort = desc.length > 72 ? '${desc.substring(0, 72)}…' : desc;
            final reasonPart = descShort.isNotEmpty ? ' • ${'Loss reason'.tr}: $descShort' : '';
            return Text(
              '- TZS ${loss.amount.toStringAsFixed(0)} • ${loss.categoryDisplayName}$reasonPart • ${loss.dateOccurred.day}/${loss.dateOccurred.month}/${loss.dateOccurred.year}',
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            );
          })),
        ],
      ],
    );
  }

  void _confirmMarkPaid(PaymentRecord payment) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Confirm payment'.tr),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(payment.employeeName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text(payment.businessName, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
              const SizedBox(height: 8),
              Text(
                '${'Period'.tr}: ${payment.getFormattedPayPeriod()}',
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 6),
              Text(
                'Confirm payment subtitle'.tr,
                style: TextStyle(fontSize: 13, color: Colors.grey[700]),
              ),
              const SizedBox(height: 12),
              if (_paymentHasSalaryBreakdown(payment))
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _buildSalaryDeductionBreakdown(payment),
                )
              else ...[
                _buildDetailRow('Net to Pay', 'TZS ${payment.amount.toStringAsFixed(0)}', isTotal: true),
              ],
              const SizedBox(height: 12),
              Text(
                'Mark paid updates advances losses'.tr,
                style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade700, fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('cancel'.tr),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _paymentController.markPaymentAsPaidDirect(payment.id);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: Text('Mark Paid'.tr),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentCard(PaymentRecord payment) {
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
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getPaymentStatusColor(payment.status).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        payment.status.toString().split('.').last.toUpperCase(),
                        style: TextStyle(
                          color: _getPaymentStatusColor(payment.status),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                payment.getFormattedAmount('TZS'),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              if ((payment.grossSalary ?? 0) > 0 &&
                                  ((payment.advanceDeductions ?? 0) > 0 || (payment.lossDeductions ?? 0) > 0)) ...[
                                const SizedBox(width: 6),
                                Text(
                                  "(${'Net pay to disburse'.tr})",
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          _buildPendingDeductionHint(payment),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Due: ${payment.formatDate(payment.dueDate)}',
                  style: TextStyle(
                    color: payment.isOverdue ? Colors.red : Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Period: ${payment.getFormattedPayPeriod()}',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 11,
                  ),
                ),
                if (payment.payPeriod != null)
                  Text(
                    _getPayScheduleDescription(payment),
                    style: TextStyle(
                      color: Colors.blue[600],
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                if (_paymentHasSalaryBreakdown(payment)) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: _buildSalaryDeductionBreakdown(payment),
                  ),
                ],
                if (payment.paidDate != null)
                  Text(
                    'Paid: ${payment.formatDate(payment.paidDate!)}',
                    style: TextStyle(color: Colors.green[600], fontSize: 12),
                  )
                else
                  Text(
                    payment.getOverdueStatusText(),
                    style: TextStyle(
                      color: payment.isOverdue ? Colors.red[600] : Colors.orange[600],
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (payment.status == PaymentStatus.pending || payment.status == PaymentStatus.overdue)
                  _buildPaymentActions(payment)
                else if (payment.status == PaymentStatus.paid)
                  const Icon(Icons.check_circle, color: Colors.green, size: 24),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Delete Payment',
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _confirmDelete(payment),
                ),
              ],
            ),
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

  Widget _buildPaymentActions(PaymentRecord payment) {
    // Check if this is a commission payment
    final isCommission = payment.payType?.toLowerCase() == 'commission';
    
    if (isCommission) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ElevatedButton(
            onPressed: () => _showCommissionCalculation(payment),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            ),
            child: const Text('Calculate', style: TextStyle(fontSize: 12)),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () => _confirmMarkPaid(payment),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            ),
            child: const Text('Mark Paid', style: TextStyle(fontSize: 12)),
          ),
        ],
      );
    } else {
      return ElevatedButton(
        onPressed: () => _confirmMarkPaid(payment),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
        child: const Text('Mark Paid'),
      );
    }
  }

  void _showCommissionCalculation(PaymentRecord payment) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    final result = await _paymentController.calculateCommissionPreview(payment.id);
    
    if (!mounted) return;
    Navigator.of(context).pop(); // Close loading dialog

    if (result == null) {
      Get.snackbar('Error', 'Payment not found', backgroundColor: Colors.red, colorText: Colors.white);
      return;
    }

    if (result['error'] != null) {
      Get.snackbar('Error', result['error'], backgroundColor: Colors.red, colorText: Colors.white);
      return;
    }

    if (result['isCommission'] == false) {
      Get.snackbar('Info', result['message'], backgroundColor: Colors.blue, colorText: Colors.white);
      return;
    }

    _showCommissionDetailsDialog(result, payment);
  }

  void _showCommissionDetailsDialog(Map<String, dynamic> details, PaymentRecord payment) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Commission Calculation'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Employee: ${details['employeeName']}', style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('Business: ${details['businessName']}'),
              const SizedBox(height: 16),
              Text('Period: ${_formatDate(details['periodStart'])} - ${_formatDate(details['periodEnd'])}'),
              const SizedBox(height: 16),
              const Text('Commission Breakdown:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _buildDetailRow('Sales Count', '${details['salesCount']} sales'),
              _buildDetailRow('Total Sales', '${details['currency']} ${details['totalSales'].toStringAsFixed(2)}'),
              _buildDetailRow('Commission Rate', '${details['commissionRate']}%'),
              _buildDetailRow('Commission Earned', '${details['currency']} ${details['commission'].toStringAsFixed(2)}'),
              const Divider(),
              _buildDetailRow('Base Pay', '${details['currency']} ${details['basePayRate'].toStringAsFixed(2)}'),
              _buildDetailRow('Commission', '${details['currency']} ${details['commission'].toStringAsFixed(2)}'),
              _buildDetailRow('Total Amount', '${details['currency']} ${details['newAmount'].toStringAsFixed(2)}', isTotal: true),
              const SizedBox(height: 8),
              if (details['currentAmount'] != details['newAmount'])
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange[200]!),
                  ),
                  child: Text(
                    'Current amount: ${details['currency']} ${details['currentAmount'].toStringAsFixed(2)}\nWill be updated to: ${details['currency']} ${details['newAmount'].toStringAsFixed(2)}',
                    style: TextStyle(color: Colors.orange[800], fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _confirmMarkPaid(payment);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Mark as Paid'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              fontSize: isTotal ? 16 : 14,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              fontSize: isTotal ? 16 : 14,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Color _getPaymentStatusColor(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.pending:
        return Colors.orange;
      case PaymentStatus.paid:
        return Colors.green;
      case PaymentStatus.overdue:
        return Colors.red;
      case PaymentStatus.cancelled:
        return Colors.grey;
    }
  }

  String _getPayScheduleDescription(PaymentRecord payment) {
    if (payment.payPeriod == null) return '';
    
    if (payment.payPeriod == 'weekly') {
      final weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
      final dayIndex = (payment.notes?.contains('payDay:') == true) 
          ? int.tryParse(payment.notes!.split('payDay:')[1].split(' ')[0]) ?? 1
          : 1;
      final weekday = weekdays[(dayIndex - 1).clamp(0, 6)];
      return 'Weekly payments on $weekday';
    } else if (payment.payPeriod == 'monthly') {
      final dayIndex = (payment.notes?.contains('payDay:') == true) 
          ? int.tryParse(payment.notes!.split('payDay:')[1].split(' ')[0]) ?? 1
          : 1;
      String suffix = 'th';
      if (dayIndex % 10 == 1 && dayIndex != 11) suffix = 'st';
      else if (dayIndex % 10 == 2 && dayIndex != 12) suffix = 'nd';
      else if (dayIndex % 10 == 3 && dayIndex != 13) suffix = 'rd';
      return 'Monthly payments on $dayIndex$suffix';
    }
    
    return payment.payPeriod?.capitalizeFirst ?? '';
  }

  IconData _getPaymentStatusIcon(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.pending:
        return Icons.pending;
      case PaymentStatus.paid:
        return Icons.check;
      case PaymentStatus.overdue:
        return Icons.warning;
      case PaymentStatus.cancelled:
        return Icons.cancel;
    }
  }

  Widget _buildEmployeeSummary(List<PaymentRecord> employeePayments) {
    final totalOwed = employeePayments
        .where((p) => p.status != PaymentStatus.paid)
        .fold<double>(0, (sum, payment) => sum + payment.amount);
    
    final overduePayments = employeePayments.where((p) => p.isOverdue).toList();
    final totalOverdue = overduePayments.fold<double>(0, (sum, payment) => sum + payment.amount);
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Payment Summary for $employeeName',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildSummaryItem(
                  'Total Owed',
                  'TZS ${totalOwed.toStringAsFixed(0)}',
                  totalOwed > 0 ? Colors.orange : Colors.green,
                ),
              ),
              Expanded(
                child: _buildSummaryItem(
                  'Overdue',
                  'TZS ${totalOverdue.toStringAsFixed(0)}',
                  totalOverdue > 0 ? Colors.red : Colors.green,
                ),
              ),
            ],
          ),
          if (overduePayments.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '${overduePayments.length} overdue payment${overduePayments.length > 1 ? 's' : ''}',
              style: TextStyle(
                color: Colors.red[600],
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  void _showCreatePaymentDialog() {
    showDialog(
      context: context,
      builder: (context) => const CreatePaymentDialog(),
    );
  }
}
