import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:mauzo/controllers/sale_controller.dart';
import '../../controllers/business_controller.dart';
import '../../controllers/client_controller.dart';
import '../../controllers/debt_history_controller.dart'; // Import the DebtHistoryController
import '../../models/client_model.dart';
import '../../models/debtHistory_model.dart';

class DebtHistoryScreen extends StatefulWidget {
  const DebtHistoryScreen({Key? key}) : super(key: key);

  @override
  State<DebtHistoryScreen> createState() => _DebtHistoryScreenState();
}

class _DebtHistoryScreenState extends State<DebtHistoryScreen> {
  final DebtHistoryController _debtHistoryController = Get.find();

  @override
  void initState() {
    super.initState();
    // Set default filter to Pending
    _debtHistoryController.setFilterStatus(["PENDING"]);
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
                  return DebtCard(debt: debt);
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
  static final ClientController _clientController = Get.find();
  final BusinessController _businessController = Get.find();
  final DebtHistoryController _debtHistoryController = Get.find();
  final SaleController saleController = Get.find();

  DebtCard({required this.debt});

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
                    }
                  },
                  itemBuilder: (BuildContext context) {
                    return [
                      PopupMenuItem<String>(
                        value: 'view_orders',
                        child: Text('View Orders'.tr),
                      ),
                    ];
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
    final TextEditingController paymentController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return Obx(() => AlertDialog(
          title: Text('Enter Payment Amount'.tr),
          content: _debtHistoryController.isLoading.value
              ? Center(child: CircularProgressIndicator())
              : TextField(
            controller: paymentController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(hintText: 'Amount'.tr),
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
                    _processDebtPayment(context, debt, paymentAmount);
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
  }

  void _processDebtPayment(BuildContext context, DebtHistory debt, double paymentAmount) async {
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

      final double oldDebt = oldSaleData['debt'] ?? 0.0;
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
      transaction.update(oldSaleRef, {'debt': newRemainingDebt});

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

      final double currentClientDebt = clientSnapshot.get('debt') ?? 0.0;
      final double newClientDebt = currentClientDebt - paymentAmount;
      transaction.update(clientRef, {'debt': newClientDebt});
    }).then((_) {
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
