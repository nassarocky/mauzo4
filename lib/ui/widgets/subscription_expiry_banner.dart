import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/business_controller.dart';

class SubscriptionExpiryBanner extends StatelessWidget {
  final BusinessController _businessController = Get.find();

  SubscriptionExpiryBanner({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!_businessController.shouldShowSubscriptionWarning()) {
      return SizedBox.shrink();
    }

    final daysLeft = _businessController.getDaysUntilSubscriptionExpiry()!;
    final expiryDate = _businessController.getFormattedExpiryDate()!;
    final subscriptionType = _businessController.getSubscriptionType();

    Color bgColor;
    Color textColor;
    IconData icon;
    String message;

    if (daysLeft <= 2) {
      bgColor = Colors.red[50]!;
      textColor = Colors.red[900]!;
      icon = Icons.error_outline;
      message = subscriptionType == 'Trial'
          ? daysLeft == 0
              ? 'Trial expires today!'.tr
              : daysLeft == 1
                  ? 'Trial expires tomorrow!'.tr
                  : '${'Trial expires in'.tr} $daysLeft ${'days!'.tr}'
          : daysLeft == 0
              ? 'Subscription expires today!'.tr
              : daysLeft == 1
                  ? 'Subscription expires tomorrow!'.tr
                  : '${'Subscription expires in'.tr} $daysLeft ${'days!'.tr}';
    } else if (daysLeft <= 6) {
      bgColor = Colors.orange[50]!;
      textColor = Colors.orange[900]!;
      icon = Icons.warning_amber;
      message = subscriptionType == 'Trial'
          ? '${'Trial expires in'.tr} $daysLeft ${'days'.tr}'
          : '${'Subscription expires in'.tr} $daysLeft ${'days'.tr}';
    } else {
      bgColor = Colors.yellow[50]!;
      textColor = Colors.yellow[900]!;
      icon = Icons.info_outline;
      message = subscriptionType == 'Trial'
          ? '${'Trial expires in'.tr} $daysLeft ${'days'.tr}'
          : '${'Subscription expires in'.tr} $daysLeft ${'days'.tr}';
    }

    return Container(
      padding: EdgeInsets.all(12),
      margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: textColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: textColor, size: 24),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  message,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '${'Expiry:'.tr} $expiryDate',
                  style: TextStyle(color: textColor, fontSize: 12),
                ),
                if (subscriptionType == 'Trial')
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'Subscribe to continue after trial'.tr,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(width: 8),
          ElevatedButton(
            onPressed: () {
              // Navigate to subscription screen
              Get.toNamed('/subscription');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: textColor,
              foregroundColor: bgColor,
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: Text(
              subscriptionType == 'Trial' ? 'Subscribe'.tr : 'Renew'.tr,
              style: TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
