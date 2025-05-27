import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:get/get.dart';
import 'package:mauzo/controllers/Transaction_controller.dart';
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
  void dispose() {
    Timer.run(() {
      _transactionController.filterCategories.value = [];
      _transactionController.searchTransactions.value = _transactionController.transactions;
      _transactionController.searchText.value = '';
      _transactionController.filteredtransactions.value = _transactionController.transactions;
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
          SizedBox(height: MediaQuery.of(context).padding.top + kToolbarHeight), // Adjust for status bar and AppBar height
          Container(
            color: Colors.white, // Background color for the container
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start, // Align items to the left
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start, // Align text to the left
                  children: [
                    Text(
                      '${'Current Stock'.tr}: ${widget.product.quantity}',
                      style: bodyText(Theme.of(context).textTheme.bodyMedium!.color),
                    ),
                    SizedBox(height: 8), // Add some spacing between the text
                    Text(
                      '${'sellingPrice'.tr}: ${widget.product.price}',
                      style: bodyText(Theme.of(context).textTheme.bodyMedium!.color),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.only(left: 16.0, right: 16, top: 24.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Transaction'.tr,
                  style: bodyText(Theme.of(context).textTheme.bodyMedium!.color),
                ),
                Text(
                  'quantity'.tr,
                  style: bodyText(warningColor),
                ),
                Text(
                  'Total Amount'.tr,
                  style: bodyText(warningColor),
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
