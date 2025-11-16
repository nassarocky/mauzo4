import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:get/get.dart';
import 'package:mauzo/controllers/transaction_controller.dart';
import '../../../controllers/profile_controller.dart';
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
  final ProfileController _profileController = Get.find();
  final TransactionController _transactionController = Get.find();
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
      _transactionController.searchTransactions.value = _transactionController.transactions;
      _transactionController.searchText.value = '';
      _transactionController.filteredtransactions.value = _transactionController.transactions;
      
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
        title: Text('${widget.product.name}'.tr, style: TextStyle(color: Colors.black)),
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
              items: <String>['all', 'Sale', 'Stock Added', 'Stock Reduced']
                  .map<DropdownMenuItem<String>>((String value) {
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
                      Text(
                        widget.product.quantity.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                // Selling Price
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                        ),
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
              List<StockTransaction> filteredTransactionById = _transactionController
                  .getTransactionsByProductId(widget.product.id)
                  .where((transaction) =>
              selectedOrigin == 'all' ||
                  transaction.transactionOrigin == selectedOrigin ||
                  (selectedOrigin == 'Stock Added' && transaction.transactionOrigin == 'Opening Stock'))
                  .toList();

              return filteredTransactionById.isEmpty
                  ? Center(
                child: Text(
                  'not_found'.tr,
                  style: bodyText(Theme.of(context).textTheme.bodyMedium!.color),
                ),
              )
                  : NotificationListener<ScrollNotification>(
                onNotification: (scrollNotification) {
                  if (_scrollController.position.userScrollDirection == ScrollDirection.reverse) {
                    if (showSearchBar) {
                      setState(() {
                        showSearchBar = false;
                      });
                    }
                  } else if (_scrollController.position.userScrollDirection == ScrollDirection.forward) {
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
