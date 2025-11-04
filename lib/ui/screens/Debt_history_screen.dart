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

  void _showEditDebtDialog(BuildContext context, DebtHistory debt) {
    if (!_profileController.hasPermission('manage_debt')) {
      Get.snackbar('Access Denied', 'You do not have permission to manage debt payments', backgroundColor: Colors.red, colorText: Colors.white);
      return;
    }

    final TextEditingController remainingCtrl = TextEditingController(text: debt.remainingDebtAmount.toStringAsFixed(2));
    final TextEditingController commentCtrl = TextEditingController(text: debt.comment);
    DateTime selectedDate = debt.dateIncurred.toDate();

    showDialog(
      context: context,
      builder: (context) {
        return Obx(() => AlertDialog(
          title: Text('Edit Debt'.tr),
          content: _debtHistoryController.isLoading.value
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: remainingCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(labelText: 'Remaining Debt Amount'.tr),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: commentCtrl,
                        decoration: InputDecoration(labelText: 'Comment'.tr),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 18),
                          const SizedBox(width: 8),
                          Text(DateFormat('yyyy-MM-dd – HH:mm').format(selectedDate)),
                          const Spacer(),
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
                            icon: const Icon(Icons.edit_calendar),
                            label: Text('Change Date'.tr),
                          ),
                        ],
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
                onPressed: () async {
                  final newRemaining = double.tryParse(remainingCtrl.text.trim());
                  if (newRemaining == null || newRemaining < 0) {
                    Get.snackbar('Invalid amount', 'Remaining debt must be a non-negative number', backgroundColor: Colors.red, colorText: Colors.white);
                    return;
                  }
                  await _updateDebtTransaction(context, debt, newRemaining, commentCtrl.text.trim(), Timestamp.fromDate(selectedDate));
                },
                child: Text('Save'.tr),
              ),
          ],
        ));
      },
    );
  }

  Future<void> _updateDebtTransaction(BuildContext context, DebtHistory debt, double newRemaining, String newComment, Timestamp newDate) async {
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
        title: Text('Delete Debt'.tr),
        content: Text('This will clear the remaining debt for this sale, add the remaining amount to the Paid value of the sale, and remove the debt record.\n\nClient: ${debt.name}\nRemaining: ${debt.remainingDebtAmount.toStringAsFixed(2)}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'.tr),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
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

  /// Build a row of filter buttons: All, Pending, Paid.
  Widget buildFilterButtons() {
    return Obx(() {
      final filter = _debtHistoryController.filterStatus;
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ElevatedButton(
            onPressed: () => _debtHistoryController.setFilterStatus([]),
            style: ElevatedButton.styleFrom(
              backgroundColor: filter.isEmpty ? Colors.blueAccent : Colors.grey,
            ),
            child: Text('All'.tr),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () =>
                _debtHistoryController.setFilterStatus(["PENDING"]),
            style: ElevatedButton.styleFrom(
              backgroundColor: filter.contains("PENDING")
                  ? Colors.blueAccent
                  : Colors.grey,
            ),
            child: Text('Pending'.tr),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () => _debtHistoryController.setFilterStatus(["PAID"]),
            style: ElevatedButton.styleFrom(
              backgroundColor: filter.contains("PAID") ? Colors.blueAccent : Colors.grey,
            ),
            child: Text('Paid'.tr),
          ),
        ],
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white, // AppBar background white
        title: Obx(() {
          // Calculate total remaining debt from the currently filtered list
          final totalDebt = _debtHistoryController.filteredDebtHistories.fold<double>(
            0.0,
                (sum, debt) => sum + debt.remainingDebtAmount,
          );
          return Text(
            '${'Debt Records'.tr} (${totalDebt.toStringAsFixed(2)})',
            style: const TextStyle(color: Colors.black),
          );
        }),
        iconTheme: const IconThemeData(color: Colors.black),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search by name...'.tr,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                prefixIcon: const Icon(Icons.search, color: Colors.black),
                filled: true,
                fillColor: Colors.white,
              ),
              onChanged: (query) {
                _debtHistoryController.searchByClientName(query);
              },
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          const SizedBox(height: 10),
          // Display filter toggle buttons
          buildFilterButtons(),
          const SizedBox(height: 10),
          // List of Debt Histories wrapped in Obx for reactive updates
          Expanded(
            child: Obx(() {
              if (_debtHistoryController.filteredDebtHistories.isEmpty) {
                return Center(child: Text('No debt history found'.tr));
              }
              return ListView.builder(
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

    Color getStatusColor() {
      if (debt.status == 'PAID') {
        return Colors.greenAccent;
      } else if (debt.status == 'PENDING') {
        return Colors.orangeAccent;
      }
      return Colors.grey;
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
      elevation: 5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.person, color: Colors.blueAccent),
                    const SizedBox(width: 10),
                    Text(
                      '${'Client:'.tr} ${client.name}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'view_orders') {
                      saleController.selectedDateRange = null;
                      saleController.filterSalesById(debt.id);
                      Navigator.pushNamed(context, '/sales');
                    } else if (value == 'edit_debt') {
                      onEditDebt(debt);
                    } else if (value == 'delete_debt') {
                      onDeleteDebt(debt);
                    }
                  },
                  itemBuilder: (BuildContext context) {
                    final items = <PopupMenuEntry<String>>[
                      PopupMenuItem<String>(
                        value: 'view_orders',
                        child: Text('View Orders'.tr),
                      ),
                    ];
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
                  icon: const Icon(Icons.more_vert),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.money, color: Colors.greenAccent),
                const SizedBox(width: 10),
                Text(
                  '${'Initial Debt:'.tr} ${debt.initialDebtAmount.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.monetization_on, color: Colors.redAccent),
                const SizedBox(width: 10),
                Text(
                  '${'Remaining Debt:'.tr} ${debt.remainingDebtAmount.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.timer, color: getStatusColor()),
                const SizedBox(width: 10),
                Text(
                  'Status: ${debt.status}'.tr,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: getStatusColor(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.calendar_today, color: Colors.grey),
                const SizedBox(width: 10),
                Text(
                  'Date: $formattedDate',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ],
            ),
            const SizedBox(height: 15),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  backgroundColor: Colors.blueAccent,
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
                ),
                onPressed: () {
                  _showPaymentRecords(context, debt);
                },
                icon: const Icon(Icons.payment, color: Colors.white),
                label: Text('View Payments'.tr, style: const TextStyle(color: Colors.white)),
              ),
            ),
            const SizedBox(height: 10),
            if (debt.remainingDebtAmount > 0)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  debt.comment,
                  style: const TextStyle(
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                    color: Colors.redAccent,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showPaymentRecords(BuildContext context, DebtHistory debt) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        final List<dynamic> paymentRecords = debt.paymentRecords;
        return Container(
          padding: const EdgeInsets.all(15),
          height: MediaQuery.of(context).size.height * 0.8,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Payment Records'.tr,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Divider(),
              Expanded(
                child: paymentRecords.isNotEmpty
                    ? ListView.builder(
                  itemCount: paymentRecords.length,
                  itemBuilder: (context, index) {
                    final record = paymentRecords[index];
                    final DateTime paymentDate = (record['date'] as Timestamp).toDate();
                    final String formattedPaymentDate =
                    DateFormat('yyyy-MM-dd – HH:mm').format(paymentDate);
                    return ListTile(
                      title: Text('${'Payment:'.tr} ${record['amount']}'),
                      subtitle: Text('${'Date:'.tr} $formattedPaymentDate'),
                      trailing: const Icon(Icons.check_circle, color: Colors.green),
                    );
                  },
                )
                    : Center(child: Text('No payment records available'.tr)),
              ),
              Align(
                alignment: Alignment.bottomRight,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _showDebtPaymentDialog(context, debt);
                  },
                  icon: const Icon(Icons.payment),
                  label: Text('Make Debt Payment'.tr),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                    backgroundColor: Colors.blueAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
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
    // CRITICAL SECURITY CHECK: Verify user has permission to manage debt
    if (!_profileController.hasPermission('manage_debt')) {
      Get.snackbar(
        'Access Denied',
        'You do not have permission to manage debt payments',
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
              title: Text('Enter Payment Amount'.tr),
              content: _debtHistoryController.isLoading.value
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: paymentController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(hintText: 'Amount'.tr),
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          value: paymentMethod,
                          decoration: InputDecoration(
                            labelText: 'Payment Method',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'cash', child: Text('Cash')),
                            DropdownMenuItem(value: 'bank', child: Text('Bank')),
                            DropdownMenuItem(value: 'mobile', child: Text('Lipa Namba (Mobile)')),
                          ],
                          onChanged: (v) => setStateLocal(() => paymentMethod = v ?? 'cash'),
                        ),
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
                    onPressed: () {
                      final double paymentAmount =
                          double.tryParse(paymentController.text) ?? 0.0;
                      if (paymentAmount > 0 &&
                          paymentAmount <= debt.remainingDebtAmount) {
                        _processDebtPayment(context, debt, paymentAmount, paymentMethod);
                      } else {
                        Get.snackbar('Invalid Payment',
                            'Please enter a valid payment amount.');
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
        throw Exception("Payment amount exceeds the remaining debt.");
      }

      final newSaleData = {
        ...oldSaleData,
        'id': salesCollection.doc().id,
        'payment': paymentAmount,
        'date': DateTime.now(),
        'debt': 0.00,
        'products': [],
        'price': 0.00,
        'buyingPrice': 0.00,
      };

      final newSaleRef = salesCollection.doc(newSaleData['id']);
      transaction.set(newSaleRef, newSaleData);
      transaction.update(oldSaleRef, {
        'debt': newRemainingDebt,
        'date': Timestamp.now(),
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
