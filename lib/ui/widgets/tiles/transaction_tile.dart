import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:mauzo/controllers/profile_controller.dart';
import 'package:mauzo/models/stock_transaction.dart';
import 'package:mauzo/models/product_model.dart';
import 'package:mauzo/utils/preferences.dart';
import '../../../utils/constants.dart';

class TransactionTile extends StatelessWidget {
  const TransactionTile({
    Key? key,
    required this.transaction, required this.product
  }) : super(key: key);

  final StockTransaction transaction;
  final Product product;

  String formatTimestamp(Timestamp timestamp) {
    DateTime dateTime = timestamp.toDate();
    String formattedDate = DateFormat('yyyy-MM-dd – HH:mm').format(dateTime);
    return formattedDate;
  }

  String formatCurrency(double amount) {
    final formatCurrency = NumberFormat.currency(symbol: '', decimalDigits: 0);
    return formatCurrency.format(amount);
  }

  @override
  Widget build(BuildContext context) {
    final ProfileController profileController = Get.find();
    String formattedTimestamp = formatTimestamp(transaction.timestamp);

    double totalAmount = ((transaction.quantity - transaction.previousQuantity).abs()) * transaction.price;
    String formattedTotalAmount = formatCurrency(totalAmount);

    return GestureDetector(
      onTap: () {
        // Handle tap action
      },
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: Preferences.getTheme() ? mediumGrayColor : borderColor,
              width: 1,
            ),
          ),
        ),
        margin: const EdgeInsets.only(left: 16, right: 16),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center, // Align items to the center vertically
            children: [
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(top: 8.0, bottom: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                       '${transaction.transactionOrigin}'.tr,
                        style: bodyText(
                          Preferences.getTheme()
                              ? primaryLightColor
                              : primaryColor,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        formattedTimestamp,
                        style: bodyText(
                          Preferences.getTheme()
                              ? primaryLightColor
                              : primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Center(
                  child: Text(
                    (transaction.quantity - transaction.previousQuantity).abs().toString(),
                    style: h5(
                      warningColor,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 48.0), // Shift to the right
                    child: Text(
                      formattedTotalAmount,
                      style: h5(
                        warningColor,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
