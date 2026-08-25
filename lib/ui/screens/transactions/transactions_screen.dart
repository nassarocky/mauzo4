import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:get/get.dart';
import 'package:mauzo/controllers/transaction_controller.dart';
import 'package:mauzo/controllers/product_controller.dart';
import 'package:mauzo/controllers/business_controller.dart';
import '../../../constants/transaction_constants.dart';
import '../../../models/product_model.dart';
import '../../../models/stock_transaction.dart';
import '../../../utils/constants.dart';
import '../../widgets/tiles/transaction_tile.dart';

class TransactionsScreen extends StatefulWidget {
  final Product product;

  const TransactionsScreen({Key? key, required this.product}) : super(key: key);

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final TransactionController _transactionController = Get.find();
  final ProductController _productController = Get.find();
  final BusinessController _businessController = Get.find();
  final ScrollController _scrollController = ScrollController();
  bool showSearchBar = true;

  String selectedOrigin = 'all';

  @override
  void initState() {
    super.initState();
    // NEW: Lazy load transactions for this specific product
    _transactionController.loadProductTransactions(widget.product.id);
  }

  @override
  void dispose() {
    Timer.run(() {
      _transactionController.filterCategories.value = [];
      _transactionController.searchTransactions.value =
          _transactionController.transactions;
      _transactionController.searchText.value = '';
      _transactionController.filteredtransactions.value =
          _transactionController.transactions;

      // NEW: Unload transactions when leaving screen to free memory
      _transactionController.unloadProductTransactions(widget.product.id);
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true, // This extends the body behind the AppBar
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          '${widget.product.name}'.tr,
          style: TextStyle(color: Colors.black),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: DropdownButton<String>(
              value: selectedOrigin,
              icon: const Icon(Icons.filter_list, color: Colors.black),
              iconSize: 24,
              elevation: 16,
              style: const TextStyle(color: Colors.black),
              underline: Container(
                height: 2,
                color: Theme.of(context).primaryColor,
              ),
              dropdownColor: Colors.white,
              onChanged: (String? newValue) {
                setState(() {
                  selectedOrigin = newValue!;
                });
              },
              items:
                  <String>[
                    'all',
                    'Sale',
                    'Additions',
                    'Removals',
                    'Shop',
                    'Store',
                  ].map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value.tr),
                    );
                  }).toList(),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(height: MediaQuery.of(context).padding.top + kToolbarHeight),
          // Modern Product Info Card
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade50, Colors.white],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 2,
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                // Product Icon
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.inventory_2,
                    size: 32,
                    color: Colors.blue.shade700,
                  ),
                ),
                const SizedBox(width: 16),
                // Product Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Current Stock',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Obx(() {
                        final live = _productController.getProduct(
                          widget.product.id,
                        );
                        final quantity = live.id.isEmpty
                            ? widget.product.quantity
                            : live.quantity;
                        return Text(
                          quantity.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                // Selling Price
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Selling Price',
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.product.price.toStringAsFixed(0),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('inventory_reconciliation_alerts')
                .doc(
                  widget.product.owner.isNotEmpty
                      ? widget.product.owner
                      : _businessController.businessId.value,
                )
                .collection('alerts')
                .doc(widget.product.id)
                .snapshots(),
            builder: (context, snapshot) {
              if (!(snapshot.data?.exists ?? false)) {
                return const SizedBox.shrink();
              }
              final quantity =
                  (snapshot.data?.data()?['quantity'] as num?)?.toDouble();
              return Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.red.shade700),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        quantity == null
                            ? 'Stock reconciliation is required.'
                            : 'Synchronized stock is ${quantity.toStringAsFixed(1)}. Reconciliation is required.',
                        style: TextStyle(
                          color: Colors.red.shade800,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          // Transaction History Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(Icons.history, size: 20, color: Colors.grey[700]),
                const SizedBox(width: 8),
                Text(
                  'Transaction History',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Obx(() {
              bool isStoreMovement(StockTransaction transaction) {
                if (transaction.inventoryLocation != null) {
                  return transaction.inventoryLocation == 'store';
                }
                final origin = transaction.transactionOrigin.toLowerCase();
                return origin.contains('to store') ||
                    origin.contains('store stock') ||
                    origin.contains('store transfer');
              }

              final filteredTransactionById = _transactionController
                  .getTransactionsByProductId(widget.product.id)
                  .where((transaction) {
                    switch (selectedOrigin) {
                      case 'Sale':
                        return transaction.transactionOrigin
                            .toLowerCase()
                            .contains('sale');
                      case 'Additions':
                        return transaction.delta != null
                            ? transaction.delta! >= 0
                            : transaction.transactionType ==
                                  TransactionTypes.addition;
                      case 'Removals':
                        return transaction.delta != null
                            ? transaction.delta! < 0
                            : transaction.transactionType ==
                                  TransactionTypes.removal;
                      case 'Store':
                        return isStoreMovement(transaction);
                      case 'Shop':
                        return !isStoreMovement(transaction);
                      default:
                        return true;
                    }
                  })
                  .toList();

              return filteredTransactionById.isEmpty
                  ? Center(
                      child: Text(
                        'not_found'.tr,
                        style: bodyText(
                          Theme.of(context).textTheme.bodyMedium!.color,
                        ),
                      ),
                    )
                  : NotificationListener<ScrollNotification>(
                      onNotification: (scrollNotification) {
                        if (_scrollController.position.userScrollDirection ==
                            ScrollDirection.reverse) {
                          if (showSearchBar) {
                            setState(() {
                              showSearchBar = false;
                            });
                          }
                        } else if (_scrollController
                                .position
                                .userScrollDirection ==
                            ScrollDirection.forward) {
                          if (!showSearchBar) {
                            setState(() {
                              showSearchBar = true;
                            });
                          }
                        }
                        return true;
                      },
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.only(top: 20),
                        itemCount: filteredTransactionById.length,
                        itemBuilder: (context, index) {
                          final transaction = filteredTransactionById[index];
                          return TransactionTile(
                            transaction: transaction,
                            product: widget.product,
                          );
                        },
                      ),
                    );
            }),
          ),
        ],
      ),
    );
  }
}
