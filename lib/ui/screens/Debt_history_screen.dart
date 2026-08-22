import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:mauzo/controllers/sale_controller.dart';
import '../../controllers/business_controller.dart';
import '../../controllers/client_controller.dart';
import '../../controllers/debt_history_controller.dart'; // Import the DebtHistoryController
import '../../controllers/profile_controller.dart';
import '../../models/client_model.dart';
import '../../models/debtHistory_model.dart';
import 'package:mauzo/services/ledger_service.dart';
import 'package:mauzo/services/sms_reminder_service.dart';
import 'package:mauzo/ui/widgets/dialogs/debt_sms_dialog.dart';
import 'package:mauzo/utils/constants.dart';
import 'package:mauzo/utils/preferences.dart';
import 'package:mauzo/utils/sale_debt_due_date.dart';
import 'package:mauzo/utils/sms_phone.dart';
import 'package:mauzo/utils/sms_settings.dart';

ShapeBorder get _debtDialogShape =>
    RoundedRectangleBorder(borderRadius: BorderRadius.circular(16));

InputDecoration _debtFieldDecoration(
  BuildContext context, {
  String? labelText,
  String? hintText,
}) {
  final isDark = Preferences.getTheme();
  final side = BorderSide(
    color: isDark ? lightGrayColor.withOpacity(0.4) : borderColor,
  );
  return InputDecoration(
    labelText: labelText,
    hintText: hintText,
    filled: true,
    fillColor: isDark ? darkGrayColor : gray100Color,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: side,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: side,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: primaryColor, width: 1.4),
    ),
  );
}

ButtonStyle get _debtPrimaryButtonStyle => ElevatedButton.styleFrom(
      elevation: 0,
      backgroundColor: primaryColor,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );

class DebtHistoryScreen extends StatefulWidget {
  const DebtHistoryScreen({Key? key}) : super(key: key);

  @override
  State<DebtHistoryScreen> createState() => _DebtHistoryScreenState();
}

class _DebtHistoryScreenState extends State<DebtHistoryScreen> {
  final DebtHistoryController _debtHistoryController = Get.find();
  final ProfileController _profileController = Get.find();
  final BusinessController _businessController = Get.find();

  @override
  void initState() {
    super.initState();
    // Set default filter to Pending
    _debtHistoryController.setFilterStatus(["PENDING"]);
  }

  Future<void> _showDefaultLoanPeriodDialog(BuildContext context) async {
    var days = _businessController.smsSettings.defaultCreditDays;
    var saving = false;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: _debtDialogShape,
              title: Text('sms_credit_days'.tr),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'sms_credit_days_hint'.tr,
                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: primaryUltraLightColor,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          onPressed: days <= 0 || saving
                              ? null
                              : () => setDialogState(() => days -= 1),
                          icon: const Icon(Icons.remove_circle_outline),
                          color: primaryColor,
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            '$days',
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: primaryColor,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: days >= 365 || saving
                              ? null
                              : () => setDialogState(() => days += 1),
                          icon: const Icon(Icons.add_circle_outline),
                          color: primaryColor,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('days'.tr, style: TextStyle(color: Colors.grey[600])),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(dialogContext),
                  child: Text('cancel'.tr),
                ),
                ElevatedButton(
                  style: _debtPrimaryButtonStyle,
                  onPressed: saving
                      ? null
                      : () async {
                          setDialogState(() => saving = true);
                          try {
                            final current = _businessController.smsSettings;
                            final next = current.copyWith(defaultCreditDays: days);
                            final saved = await SmsReminderService().saveSettings(
                              businessId: _businessController.businessId.value,
                              settings: next,
                            );
                            _businessController.business['smsSettings'] =
                                saved.toMap();
                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                            }
                            Get.snackbar(
                              'success'.tr,
                              'sms_settings_saved'.tr,
                              backgroundColor: Colors.green,
                              colorText: Colors.white,
                            );
                          } catch (e) {
                            setDialogState(() => saving = false);
                            Get.snackbar(
                              'error'.tr,
                              e.toString(),
                              backgroundColor: Colors.red,
                              colorText: Colors.white,
                            );
                          }
                        },
                  child: saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text('save'.tr),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditDebtDialog(BuildContext context, DebtHistory debt) {
    if (!_profileController.hasPermission('manage_debt')) {
      Get.snackbar('Access Denied', 'You do not have permission to manage debt payments', backgroundColor: Colors.red, colorText: Colors.white);
      return;
    }

    final TextEditingController remainingCtrl = TextEditingController(text: debt.remainingDebtAmount.toStringAsFixed(2));
    final TextEditingController commentCtrl = TextEditingController(text: debt.comment);
    DateTime selectedDate = debt.dateIncurred.toDate();
    DateTime selectedDueDate = debt.dueDate?.toDate() ??
        SaleDebtDueDate.defaultDueDate(
          saleDate: selectedDate,
          defaultCreditDays: _businessController.smsSettings.defaultCreditDays,
        );

    showDialog(
      context: context,
      builder: (context) {
        return Obx(() => AlertDialog(
          shape: _debtDialogShape,
          title: Text('Edit Debt'.tr),
          content: _debtHistoryController.isLoading.value
              ? const SizedBox(
                  height: 72,
                  child: Center(
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(strokeWidth: 2.6),
                    ),
                  ),
                )
              : SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: remainingCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: _debtFieldDecoration(
                          context,
                          labelText: 'Remaining Debt Amount'.tr,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: commentCtrl,
                        decoration: _debtFieldDecoration(
                          context,
                          labelText: 'Comment'.tr,
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: borderColor),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today, size: 18, color: primaryColor),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                DateFormat('yyyy-MM-dd – HH:mm').format(selectedDate),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () async {
                                final date = await showDatePicker(
                                  context: context,
                                  initialDate: selectedDate,
                                  firstDate: DateTime(2015),
                                  lastDate: DateTime(2101),
                                );
                                if (date != null) {
                                  // Preserve time
                                  selectedDate = DateTime(date.year, date.month, date.day, selectedDate.hour, selectedDate.minute);
                                  (context as Element).markNeedsBuild();
                                }
                              },
                              icon: const Icon(Icons.edit_calendar, size: 18),
                              label: Text('Change Date'.tr),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: borderColor),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.event, size: 18, color: primaryColor),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${'sale_debt_due_date'.tr}: ${DateFormat('yyyy-MM-dd').format(selectedDueDate)}',
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () async {
                                final saleDay =
                                    SaleDebtDueDate.startOfDay(selectedDate);
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: selectedDueDate.isBefore(saleDay)
                                      ? saleDay
                                      : selectedDueDate,
                                  firstDate: saleDay,
                                  lastDate:
                                      SaleDebtDueDate.lastSelectableDueDate(
                                    selectedDate,
                                  ),
                                );
                                if (picked != null) {
                                  selectedDueDate =
                                      SaleDebtDueDate.startOfDay(picked);
                                  (context as Element).markNeedsBuild();
                                }
                              },
                              icon: const Icon(Icons.edit_calendar, size: 18),
                              label: Text('sale_debt_due_date'.tr),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
          actions: [
            if (!_debtHistoryController.isLoading.value)
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel'.tr),
              ),
            if (!_debtHistoryController.isLoading.value)
              ElevatedButton(
                style: _debtPrimaryButtonStyle,
                onPressed: () async {
                  final newRemaining = double.tryParse(remainingCtrl.text.trim());
                  if (newRemaining == null || newRemaining < 0) {
                    Get.snackbar('Invalid amount', 'Remaining debt must be a non-negative number', backgroundColor: Colors.red, colorText: Colors.white);
                    return;
                  }
                  await _updateDebtTransaction(context, debt, newRemaining, commentCtrl.text.trim(), Timestamp.fromDate(selectedDate), Timestamp.fromDate(selectedDueDate));
                },
                child: Text('Save'.tr),
              ),
          ],
        ));
      },
    );
  }

  Future<void> _updateDebtTransaction(BuildContext context, DebtHistory debt, double newRemaining, String newComment, Timestamp newDate, Timestamp newDueDate) async {
    final salesCollection = FirebaseFirestore.instance
        .collection('sales')
        .doc(_businessController.business['id'])
        .collection('userSales');

    final debtHistoryCollection = FirebaseFirestore.instance
        .collection('debtHistory')
        .doc(_businessController.business['id'])
        .collection('clientDebtHistory');

    final clientCollection = FirebaseFirestore.instance
        .collection('clients')
        .doc(_businessController.business['id'])
        .collection('userClients');

    _debtHistoryController.isLoading.value = true;

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final saleRef = salesCollection.doc(debt.id);
      final debtRef = debtHistoryCollection.doc(debt.id);
      final clientRef = clientCollection.doc(debt.client);

      final saleSnap = await transaction.get(saleRef);
      final debtSnap = await transaction.get(debtRef);
      final clientSnap = await transaction.get(clientRef);

      if (!saleSnap.exists) {
        throw Exception("Sale with ID ${debt.id} does not exist.");
      }
      if (!debtSnap.exists) {
        throw Exception("Debt history with ID ${debt.id} does not exist.");
      }
      if (!clientSnap.exists) {
        throw Exception("Client with ID ${debt.client} does not exist.");
      }

      final oldRemaining = (debtSnap.get('remainingDebtAmount') ?? 0.0).toDouble();
      final delta = newRemaining - oldRemaining;

      final Map<String, dynamic> saleUpdates = {'debt': newRemaining};
      if (newRemaining <= 0) {
        saleUpdates['date'] = Timestamp.now();
      }
      transaction.update(saleRef, saleUpdates);

      final debtUpdates = <String, dynamic>{
        'remainingDebtAmount': newRemaining,
        'comment': newComment,
        'dateIncurred': newDate,
        'dueDate': newDueDate,
        'creditDays': SaleDebtDueDate.creditDaysFrom(
          saleDate: newDate.toDate(),
          dueDate: newDueDate.toDate(),
        ),
        'status': newRemaining <= 0 ? 'PAID' : 'PENDING',
      };
      transaction.update(debtRef, debtUpdates);

      if (delta != 0) {
        final currentClientDebt = (clientSnap.get('debt') ?? 0.0).toDouble();
        final newClientDebt = currentClientDebt + delta; // delta can be +/-
        transaction.update(clientRef, {'debt': newClientDebt});
      }
    }).then((_) {
      _debtHistoryController.isLoading.value = false;
      Navigator.pop(context);
      Get.snackbar('Success', 'Debt updated successfully', backgroundColor: Colors.green, colorText: Colors.white);
    }).catchError((error) {
      _debtHistoryController.isLoading.value = false;
      Get.snackbar('Error', 'Failed to update debt: $error', backgroundColor: Colors.red, colorText: Colors.white);
    });
  }

  void _confirmDeleteDebt(BuildContext context, DebtHistory debt) {
    if (!_profileController.hasPermission('manage_debt')) {
      Get.snackbar('Access Denied', 'You do not have permission to delete debts', backgroundColor: Colors.red, colorText: Colors.white);
      return;
    }
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: _debtDialogShape,
        title: Text('Delete Debt'.tr),
        content: Text('This will clear the remaining debt for this sale, add the remaining amount to the Paid value of the sale, and remove the debt record.\n\nClient: ${debt.name}\nRemaining: ${debt.remainingDebtAmount.toStringAsFixed(2)}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'.tr),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              elevation: 0,
              backgroundColor: redColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              Navigator.pop(context);
              _deleteDebtTransaction(context, debt);
            },
            child: Text('Delete'.tr),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteDebtTransaction(BuildContext context, DebtHistory debt) async {
    final salesCollection = FirebaseFirestore.instance
        .collection('sales')
        .doc(_businessController.business['id'])
        .collection('userSales');

    final debtHistoryCollection = FirebaseFirestore.instance
        .collection('debtHistory')
        .doc(_businessController.business['id'])
        .collection('clientDebtHistory');

    final clientCollection = FirebaseFirestore.instance
        .collection('clients')
        .doc(_businessController.business['id'])
        .collection('userClients');

    _debtHistoryController.isLoading.value = true;

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final saleRef = salesCollection.doc(debt.id);
      final debtRef = debtHistoryCollection.doc(debt.id);
      final clientRef = clientCollection.doc(debt.client);

      final saleSnap = await transaction.get(saleRef);
      final debtSnap = await transaction.get(debtRef);
      final clientSnap = await transaction.get(clientRef);

      if (!saleSnap.exists) {
        throw Exception("Sale with ID ${debt.id} does not exist.");
      }
      if (!debtSnap.exists) {
        throw Exception("Debt history with ID ${debt.id} does not exist.");
      }
      if (!clientSnap.exists) {
        throw Exception("Client with ID ${debt.client} does not exist.");
      }

      final remaining = (debtSnap.get('remainingDebtAmount') ?? 0.0).toDouble();

      // Clear sale debt, add remaining to paid value, and record adjustment
      transaction.update(saleRef, {
        'debt': 0.0,
        'payment': FieldValue.increment(remaining),
        'date': Timestamp.now(),
        'debtAdjustments': FieldValue.arrayUnion([
          {
            'amount': remaining,
            'date': Timestamp.now(),
            'by': _profileController.user['name'] ?? _profileController.user['id'] ?? '',
            'type': 'debt_delete_adjustment',
          }
        ]),
      });

      // Remove debt history
      transaction.delete(debtRef);

      // Adjust client aggregate debt
      final currentClientDebt = (clientSnap.get('debt') ?? 0.0).toDouble();
      final newClientDebt = currentClientDebt - remaining;
      transaction.update(clientRef, {'debt': newClientDebt});
    }).then((_) {
      _debtHistoryController.isLoading.value = false;
      Get.snackbar('Deleted', 'Debt record deleted; amount added to sale payment and client debt updated', backgroundColor: Colors.green, colorText: Colors.white);
    }).catchError((error) {
      _debtHistoryController.isLoading.value = false;
      Get.snackbar('Error', 'Failed to delete debt: $error', backgroundColor: Colors.red, colorText: Colors.white);
    });
  }

  @override
  void dispose() {
    super.dispose();
    Timer.run(() {
      _debtHistoryController.filteredDebtHistories.value =
          _debtHistoryController.debtHistories;
    });
  }

  bool get _isDark => Preferences.getTheme();

  Color get _pageBg => _isDark ? darkGrayColor : const Color(0xFFF7F8FA);

  Color get _cardBg => _isDark ? mediumGrayColor : whiteColor;

  Color get _muted =>
      Theme.of(context).textTheme.bodyMedium?.color ?? textMutedColor;

  /// Build a row of filter buttons: All, Pending, Paid.
  Widget buildFilterButtons() {
    return Obx(() {
      final filter = _debtHistoryController.filterStatus;
      Widget chip({
        required String label,
        required bool selected,
        required VoidCallback onTap,
      }) {
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(
            label: Text(label),
            selected: selected,
            selectedColor: primaryUltraLightColor,
            labelStyle: TextStyle(
              color: selected ? primaryColor : _muted,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            ),
            side: BorderSide(
              color: selected
                  ? primaryColor.withOpacity(0.35)
                  : (_isDark ? lightGrayColor.withOpacity(0.3) : borderColor),
            ),
            backgroundColor: _cardBg,
            showCheckmark: false,
            onSelected: (_) => onTap(),
          ),
        );
      }

      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            chip(
              label: 'All'.tr,
              selected: filter.isEmpty,
              onTap: () => _debtHistoryController.setFilterStatus([]),
            ),
            chip(
              label: 'Pending'.tr,
              selected: filter.contains("PENDING"),
              onTap: () =>
                  _debtHistoryController.setFilterStatus(["PENDING"]),
            ),
            chip(
              label: 'Paid'.tr,
              selected: filter.contains("PAID"),
              onTap: () => _debtHistoryController.setFilterStatus(["PAID"]),
            ),
          ],
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBg,
      appBar: AppBar(
        title: Obx(() {
          // Calculate total remaining debt from the currently filtered list
          final totalDebt = _debtHistoryController.filteredDebtHistories.fold<double>(
            0.0,
                (sum, debt) => sum + debt.remainingDebtAmount,
          );
          return Text(
            '${'Debt Records'.tr} (${totalDebt.toStringAsFixed(2)})',
          );
        }),
        elevation: 0,
        actions: [
          if ((_profileController.user['role'] ?? '') == 'owner')
            IconButton(
              tooltip: 'sms_credit_days'.tr,
              icon: const Icon(Icons.event_available_outlined),
              onPressed: () => _showDefaultLoanPeriodDialog(context),
            ),
          IconButton(
            tooltip: 'export_debtors_excel'.tr,
            icon: Image.asset(
              'assets/images/excel.png',
              width: 24,
              height: 24,
            ),
            onPressed: () {
              Get.find<ClientController>().generateExcelFromDebtors();
            },
          ),
          PopupMenuButton<String>(
            tooltip: 'export_debtors_pdf'.tr,
            icon: const Icon(Icons.picture_as_pdf_outlined),
            onSelected: (value) {
              final clients = Get.find<ClientController>();
              if (value == 'print') {
                clients.generatePdfFromDebtors(share: false);
              } else if (value == 'share') {
                clients.generatePdfFromDebtors(share: true);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'print',
                child: Text('print_pdf'.tr),
              ),
              PopupMenuItem(
                value: 'share',
                child: Text('share_pdf'.tr),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              onChanged: (query) {
                _debtHistoryController.searchByClientName(query);
              },
              decoration: InputDecoration(
                hintText: 'Search by name...'.tr,
                prefixIcon: Icon(Icons.search, color: _muted),
                filled: true,
                fillColor: _cardBg,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: _isDark ? lightGrayColor.withOpacity(0.25) : borderColor,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: _isDark ? lightGrayColor.withOpacity(0.25) : borderColor,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: primaryColor, width: 1.4),
                ),
              ),
            ),
          ),
          buildFilterButtons(),
          const SizedBox(height: 8),
          Expanded(
            child: Obx(() {
              if (_debtHistoryController.filteredDebtHistories.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.receipt_long_outlined, size: 44, color: _muted),
                        const SizedBox(height: 10),
                        Text(
                          'No debt history found'.tr,
                          style: TextStyle(color: _muted, fontSize: 15),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                itemCount: _debtHistoryController.filteredDebtHistories.length,
                itemBuilder: (context, index) {
                  final debt = _debtHistoryController.filteredDebtHistories[index];
                  return DebtCard(
                    debt: debt,
                    onEditDebt: (d) => _showEditDebtDialog(context, d),
                    onDeleteDebt: (d) => _confirmDeleteDebt(context, d),
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }
}

class DebtCard extends StatelessWidget {
  final DebtHistory debt;
  final void Function(DebtHistory debt) onEditDebt;
  final void Function(DebtHistory debt) onDeleteDebt;
  final BusinessController _businessController = Get.find();
  final DebtHistoryController _debtHistoryController = Get.find();
  final ProfileController _profileController = Get.find();
  final ClientController _clientController = Get.find();
  final SaleController saleController = Get.find();

  DebtCard({required this.debt, required this.onEditDebt, required this.onDeleteDebt});

  @override
  Widget build(BuildContext context) {
    final DateTime dateIncurred = debt.dateIncurred.toDate();
    final String formattedDate = DateFormat('yyyy-MM-dd – HH:mm').format(dateIncurred);
    Client client = _clientController.getClient(debt.client);
    final isDark = Preferences.getTheme();
    final cardBg = isDark ? mediumGrayColor : whiteColor;
    final muted = Theme.of(context).textTheme.bodyMedium?.color ?? textMutedColor;
    final titleColor = Theme.of(context).textTheme.bodyLarge?.color ?? textDarkColor;

    Color getStatusColor() {
      if (debt.status == 'PAID') {
        return greenColor;
      } else if (debt.status == 'PENDING') {
        return warningColor;
      }
      return textMutedColor;
    }

    final initial = client.name.trim().isNotEmpty
        ? client.name.trim()[0].toUpperCase()
        : '?';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? lightGrayColor.withOpacity(0.25) : borderColor,
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: primaryUltraLightColor,
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: primaryColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${'Client:'.tr} ${client.name}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: titleColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: getStatusColor().withOpacity(0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'Status: ${debt.status}'.tr,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: getStatusColor(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                  onSelected: (value) async {
                    if (value == 'view_orders') {
                      saleController.selectedDateRange = null;
                      saleController.filterSalesById(debt.id);
                      Navigator.pushNamed(context, '/sales');
                    } else if (value == 'edit_debt') {
                      onEditDebt(debt);
                    } else if (value == 'delete_debt') {
                      onDeleteDebt(debt);
                    } else if (value == 'send_sms') {
                      final dueLabel = debt.dueDate != null
                          ? DateFormat('dd/MM/yyyy')
                              .format(debt.dueDate!.toDate())
                          : null;
                      await showDebtSmsDialog(
                        context: context,
                        clientName: client.name.isNotEmpty
                            ? client.name
                            : debt.name,
                        phone: client.phone,
                        amount: debt.remainingDebtAmount,
                        clientId: debt.client,
                        dueDateLabel: dueLabel,
                      );
                    }
                  },
                  itemBuilder: (BuildContext context) {
                    final items = <PopupMenuEntry<String>>[
                      PopupMenuItem<String>(
                        value: 'view_orders',
                        child: Text('View Orders'.tr),
                      ),
                    ];
                    if (debt.remainingDebtAmount > 0 &&
                        isValidSmsPhone(client.phone) &&
                        (_profileController.hasPermission('send_debt_sms') ||
                            _profileController.hasPermission('manage_debt') ||
                            (_profileController.user['role'] ?? '') ==
                                'owner')) {
                      items.add(
                        PopupMenuItem<String>(
                          value: 'send_sms',
                          child: Text('send_debt_sms'.tr),
                        ),
                      );
                    }
                    if (_profileController.hasPermission('manage_debt')) {
                      items.addAll([
                        PopupMenuItem<String>(
                          value: 'edit_debt',
                          child: Text('Edit Debt'.tr),
                        ),
                        PopupMenuItem<String>(
                          value: 'delete_debt',
                          child: Text('Delete Debt'.tr),
                        ),
                      ]);
                    }
                    return items;
                  },
                  icon: Icon(Icons.more_vert, color: muted),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _amountTile(
                  context,
                  label: 'Initial Debt:'.tr,
                  value: debt.initialDebtAmount.toStringAsFixed(2),
                  color: greenColor,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _amountTile(
                  context,
                  label: 'Remaining Debt:'.tr,
                  value: debt.remainingDebtAmount.toStringAsFixed(2),
                  color: debt.remainingDebtAmount > 0 ? redColor : greenColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.calendar_today_outlined, size: 14, color: muted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Date: $formattedDate',
                  style: TextStyle(fontSize: 13, color: muted),
                ),
              ),
            ],
          ),
          if (debt.dueDate != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.event_outlined, size: 14, color: muted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${'sale_debt_due_date'.tr}: ${DateFormat('yyyy-MM-dd').format(debt.dueDate!.toDate())}',
                    style: TextStyle(fontSize: 13, color: muted),
                  ),
                ),
              ],
            ),
          ],
          if (debt.remainingDebtAmount > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                debt.comment,
                style: const TextStyle(
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  color: redColor,
                ),
              ),
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                _showPaymentRecords(context, debt);
              },
              icon: const Icon(Icons.payments_outlined, size: 18),
              label: Text('View Payments'.tr),
            ),
          ),
        ],
      ),
    );
  }

  Widget _amountTile(
    BuildContext context, {
    required String label,
    required String value,
    required Color color,
  }) {
    final isDark = Preferences.getTheme();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.16 : 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
        ],
      ),
    );
  }

  void _showPaymentRecords(BuildContext context, DebtHistory debt) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final List<dynamic> paymentRecords = debt.paymentRecords;
        return Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          height: MediaQuery.of(context).size.height * 0.8,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: borderColor,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              Text(
                'Payment Records'.tr,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: paymentRecords.isNotEmpty
                    ? ListView.builder(
                  itemCount: paymentRecords.length,
                  itemBuilder: (context, index) {
                    final record = paymentRecords[index];
                    final DateTime paymentDate = (record['date'] as Timestamp).toDate();
                    final String formattedPaymentDate =
                    DateFormat('yyyy-MM-dd – HH:mm').format(paymentDate);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: borderColor),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFFE8F5E9),
                          child: Icon(Icons.check, color: greenColor, size: 20),
                        ),
                        title: Text('${'Payment:'.tr} ${record['amount']}'),
                        subtitle: Text('${'Date:'.tr} $formattedPaymentDate'),
                      ),
                    );
                  },
                )
                    : Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.payments_outlined,
                              size: 40,
                              color: textMutedColor,
                            ),
                            const SizedBox(height: 10),
                            Text('No payment records available'.tr),
                          ],
                        ),
                      ),
              ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _showDebtPaymentDialog(context, debt);
                  },
                  icon: const Icon(Icons.payment),
                  label: Text('Make Debt Payment'.tr),
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showDebtPaymentDialog(BuildContext context, DebtHistory debt) {
    // CRITICAL SECURITY CHECK: Verify user has permission to record debt payments
    if (!_profileController.hasPermission('record_debt_payment')) {
      Get.snackbar(
        'Access Denied',
        'You do not have permission to record debt payments',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
      return;
    }
    
    final TextEditingController paymentController = TextEditingController();
    String paymentMethod = 'cash';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateLocal) {
            return Obx(() => AlertDialog(
              shape: _debtDialogShape,
              title: Text('Enter Payment Amount'.tr),
              content: _debtHistoryController.isLoading.value
                  ? const SizedBox(
                      height: 72,
                      child: Center(
                        child: SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(strokeWidth: 2.6),
                        ),
                      ),
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: paymentController,
                          keyboardType: TextInputType.number,
                          decoration: _debtFieldDecoration(
                            context,
                            hintText: 'Amount'.tr,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (((_businessController.business['multiFundEnabled'] ?? false) == true))
                          Obx(() {
                            final methods = _businessController
                                .paymentMethodsForDropdown(
                                    currentValue: paymentMethod);
                            if (methods.isEmpty) {
                              return const SizedBox.shrink();
                            }
                            final values = methods
                                .map((m) => m['value']?.toString() ?? '')
                                .where((v) => v.isNotEmpty)
                                .toList();
                            if (values.isEmpty) {
                              return const SizedBox.shrink();
                            }
                            final safe = values.contains(paymentMethod)
                                ? paymentMethod
                                : values.first;
                            if (safe != paymentMethod) {
                              WidgetsBinding.instance
                                  .addPostFrameCallback((_) {
                                setStateLocal(() => paymentMethod = safe);
                              });
                            }
                            return DropdownButtonFormField<String>(
                              value: safe,
                              decoration: _debtFieldDecoration(
                                context,
                                labelText: 'Payment Method'.tr,
                              ),
                              items: methods
                                  .map((m) {
                                    final v = m['value']?.toString() ?? '';
                                    if (v.isEmpty) return null;
                                    return DropdownMenuItem<String>(
                                      value: v,
                                      child: Text(m['label']?.toString() ?? v),
                                    );
                                  })
                                  .whereType<DropdownMenuItem<String>>()
                                  .toList(),
                              onChanged: (v) => setStateLocal(
                                  () => paymentMethod = v ?? values.first),
                            );
                          }),
                      ],
                    ),
              actions: [
                if (!_debtHistoryController.isLoading.value)
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Cancel'.tr),
                  ),
                if (!_debtHistoryController.isLoading.value)
                  ElevatedButton(
                    style: _debtPrimaryButtonStyle,
                    onPressed: () {
                      final double paymentAmount =
                          double.tryParse(paymentController.text) ?? 0.0;
                      if (paymentAmount > 0 &&
                          paymentAmount <= debt.remainingDebtAmount) {
                        _processDebtPayment(context, debt, paymentAmount, paymentMethod);
                      } else {
                        Get.snackbar('Invalid Payment'.tr,
                            'Please enter a valid payment amount'.tr);
                      }
                    },
                    child: Text('Save'.tr),
                  ),
              ],
            ));
          },
        );
      },
    );
  }

  void _processDebtPayment(BuildContext context, DebtHistory debt, double paymentAmount, String paymentMethod) async {
    final salesCollection = FirebaseFirestore.instance
        .collection('sales')
        .doc(_businessController.business['id'])
        .collection('userSales');

    final debtHistoryCollection = FirebaseFirestore.instance
        .collection('debtHistory')
        .doc(_businessController.business['id'])
        .collection('clientDebtHistory');

    final clientCollection = FirebaseFirestore.instance
        .collection('clients')
        .doc(_businessController.business['id'])
        .collection('userClients');

    _debtHistoryController.isLoading.value = true;

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final oldSaleRef = salesCollection.doc(debt.id);
      final debtHistoryRef = debtHistoryCollection.doc(debt.id);
      final clientRef = clientCollection.doc(debt.client);

      final oldSaleSnapshot = await transaction.get(oldSaleRef);
      final debtHistorySnapshot = await transaction.get(debtHistoryRef);
      final clientSnapshot = await transaction.get(clientRef);

      if (!oldSaleSnapshot.exists) {
        throw Exception("Sale with ID ${debt.id} does not exist.");
      }
      final oldSaleData = oldSaleSnapshot.data();
      if (oldSaleData == null) {
        throw Exception("Failed to retrieve sale data.");
      }
      if (!debtHistorySnapshot.exists) {
        throw Exception("Debt history with ID ${debt.id} does not exist.");
      }
      if (!clientSnapshot.exists) {
        throw Exception("Client with ID ${debt.client} does not exist.");
      }

      final double oldDebt = (oldSaleData['debt'] ?? 0.0).toDouble();
      final double newRemainingDebt = oldDebt - paymentAmount;

      if (newRemainingDebt < 0) {
        throw Exception('Payment amount exceeds the remaining debt.'.tr);
      }

      final newSaleData = {
        ...oldSaleData,
        'id': salesCollection.doc().id,
        'saleType': 'debt_repayment',
        'payment': paymentAmount,
        'date': Timestamp.now(),
        'debt': 0.00,
        'products': [],
        'price': 0.00,
        'buyingPrice': 0.00,
        'payments': [
          {
            'amount': paymentAmount,
            'currency': _businessController.business['mainCurrency'] ?? 'TZS',
            'method': paymentMethod,
          }
        ],
        'fundSource': paymentMethod,
      };

      final newSaleRef = salesCollection.doc(newSaleData['id']);
      transaction.set(newSaleRef, newSaleData);
      // ✅ FIXED: Only update debt, DO NOT change the original sale's date
      // Changing the date causes the sale to appear in wrong date range queries
      transaction.update(oldSaleRef, {
        'debt': newRemainingDebt,
        // 'date': Timestamp.now(),  ← REMOVED: Don't change original sale date
      });

      final newPaymentRecord = {
        'amount': paymentAmount,
        'date': Timestamp.now(),
      };
      final Map<String, dynamic> debtHistoryUpdates = {
        'remainingDebtAmount': newRemainingDebt,
        'paymentRecords': FieldValue.arrayUnion([newPaymentRecord]),
        'status': newRemainingDebt <= 0 ? 'PAID' : 'PENDING',
      };
      transaction.update(debtHistoryRef, debtHistoryUpdates);

      final double currentClientDebt = (clientSnapshot.get('debt') ?? 0.0).toDouble();
      final double newClientDebt = currentClientDebt - paymentAmount;
      transaction.update(clientRef, {'debt': newClientDebt});
    }).then((_) async {
      _debtHistoryController.isLoading.value = false;
      // Refresh the filtered list and switch to the Paid tab
      _debtHistoryController.filteredDebtHistoriesList();
      _debtHistoryController.setFilterStatus(["PAID"]);
      Navigator.pop(context);
      Get.snackbar(
        'Success',
        'Debt payment processed successfully.',
        backgroundColor: Colors.greenAccent,
        colorText: Colors.white,
        duration: Duration(seconds: 5),
      );
      if (_businessController.smsSettings.debtPaymentSmsEnabled) {
        final client = Get.find<ClientController>().getClient(debt.client);
        final phone = client.phone.isNotEmpty ? client.phone : '';
        if (isValidSmsPhone(phone)) {
          unawaited(
            SmsReminderService().tryNotify(
              businessId: _businessController.businessId.value,
              type: 'debt_payment',
              phone: phone,
              clientId: debt.client,
              clientName: debt.name,
              amount: paymentAmount,
              remaining: (debt.remainingDebtAmount - paymentAmount)
                  .clamp(0, double.infinity)
                  .toDouble(),
              lang: Get.locale?.languageCode == 'en' ? 'en' : 'sw',
            ),
          );
        }
      }
      // Post ledger IN for client debt repayment
      try {
        await LedgerService().postSaleIn(
          saleId: debt.id,
          payments: [
            {
              'amount': paymentAmount,
              'method': paymentMethod,
            }
          ],
          postedAt: Timestamp.now(),
          clientId: debt.client,
          clientName: debt.name,
        );
      } catch (e) {
        print('⚠️ Ledger postSaleIn (client debt payment) failed for sale ${debt.id}: $e');
      }
    }).catchError((error) {
      Get.snackbar(
        'Error',
        'Failed to process payment: $error',
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        duration: Duration(seconds: 15),
        margin: const EdgeInsets.all(10),
      );
    });
  }
}
