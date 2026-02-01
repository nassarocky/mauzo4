import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../controllers/business_controller.dart';
import '../../utils/constants.dart';
import '../widgets/dialogs/payment_dialog.dart';

class SubscriptionScreen extends StatefulWidget {
  SubscriptionScreen({Key? key}) : super(key: key);

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  final BusinessController _businessController = Get.find();

  @override
  void initState() {
    super.initState();
    // Refresh business data when screen opens
    _businessController.updateBusinessData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: Text('Subscription'),
      ),
      body: Obx(
        () {
          if (_businessController.business.isEmpty) {
            return Center(child: CircularProgressIndicator());
          }
          
          return SingleChildScrollView(
            child: Column(
              children: [
                _buildHeaderSection(),
                SizedBox(height: 16),
                _buildSubscriptionCard(),
                SizedBox(height: 16),
                _buildDetailsCard(),
                SizedBox(height: 16),
                _buildPaymentButton(context),
                SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeaderSection() {
    final daysLeft = _businessController.getDaysUntilSubscriptionExpiry();
    final subscriptionType = _businessController.getSubscriptionType();
    final status = _businessController.business['subscriptionStatus'];

    Color statusColor;
    IconData statusIcon;
    String statusMessage;

    // Handle trial accounts without trialStart date
    if (daysLeft == null && status == 'subscription_ontrial') {
      statusColor = Colors.blue;
      statusIcon = Icons.access_time;
      statusMessage = 'Trial Active'.tr;
    } else if (daysLeft == null) {
      statusColor = Colors.grey;
      statusIcon = Icons.help_outline;
      statusMessage = 'No subscription data available'.tr;
    } else if (daysLeft < 0) {
      statusColor = Colors.red;
      statusIcon = Icons.error_outline;
      statusMessage = 'Subscription Expired'.tr;
    } else if (daysLeft <= 2) {
      statusColor = Colors.red;
      statusIcon = Icons.warning_amber;
      statusMessage = subscriptionType == 'Trial'
          ? 'Trial Ending Soon!'.tr
          : 'Subscription Ending Soon!'.tr;
    } else if (daysLeft <= 7) {
      statusColor = Colors.orange;
      statusIcon = Icons.warning_amber;
      statusMessage = subscriptionType == 'Trial'
          ? 'Trial Active'.tr
          : 'Subscription Active'.tr;
    } else {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle_outline;
      statusMessage = subscriptionType == 'Trial'
          ? 'Trial Active'.tr
          : 'Subscription Active'.tr;
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [statusColor, statusColor.withOpacity(0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          Icon(statusIcon, color: Colors.white, size: 64),
          SizedBox(height: 16),
          Text(
            statusMessage,
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8),
          if (daysLeft != null && daysLeft >= 0)
            Text(
              daysLeft == 0
                  ? 'Expires Today'.tr
                  : daysLeft == 1
                      ? 'Expires Tomorrow'.tr
                      : '$daysLeft ${'days remaining'.tr}',
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 16,
              ),
            ),
          if (daysLeft == null && status == 'subscription_ontrial')
            Text(
              '30-day trial period'.tr,
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 16,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionCard() {
    final subscriptionType = _businessController.getSubscriptionType();
    final status = _businessController.business['subscriptionStatus'];
    final expiryDate = _businessController.getFormattedExpiryDate();

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16),
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.card_membership, color: primaryColor, size: 28),
                SizedBox(width: 12),
                Text(
                  'Subscription Details'.tr,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            Divider(height: 24),
            _buildInfoRow(
              Icons.type_specimen,
              'Type'.tr,
              subscriptionType,
              _getTypeColor(subscriptionType),
            ),
            SizedBox(height: 16),
            _buildInfoRow(
              Icons.info_outline,
              'Status'.tr,
              _formatStatus(status),
              _getStatusColor(status),
            ),
            SizedBox(height: 16),
            if (expiryDate != null)
              _buildInfoRow(
                Icons.event,
                'Expiry Date'.tr,
                expiryDate,
                null,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsCard() {
    final subscriptionType = _businessController.getSubscriptionType();
    final daysLeft = _businessController.getDaysUntilSubscriptionExpiry();

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16),
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.calendar_today, color: primaryColor, size: 28),
                SizedBox(width: 12),
                Text(
                  'Timeline'.tr,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            Divider(height: 24),
            if (subscriptionType == 'Trial')
              _buildInfoRow(
                Icons.schedule,
                'Trial Period'.tr,
                '30 ${'days'.tr}',
                Colors.blue,
              ),
            if (subscriptionType == 'Trial')
              SizedBox(height: 16),
            if (subscriptionType == 'Trial' &&
                _businessController.business['trialStart'] != null)
              _buildInfoRow(
                Icons.play_circle_outline,
                'Trial Start Date'.tr,
                _formatDate((_businessController.business['trialStart']
                        as Timestamp)
                    .toDate()),
                null,
              ),
            if (subscriptionType == 'Trial' &&
                _businessController.business['trialStart'] != null)
              SizedBox(height: 16),
            if (subscriptionType == 'Trial' && daysLeft != null)
              _buildInfoRow(
                Icons.hourglass_bottom,
                'Trial Days Used'.tr,
                '${30 - daysLeft} ${'of'.tr} 30 ${'days'.tr}',
                Colors.grey[700],
              ),
            if (subscriptionType == 'Trial' && daysLeft != null)
              SizedBox(height: 16),
            if (subscriptionType == 'Trial' && daysLeft == null)
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info, color: Colors.blue[700], size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Your 30-day trial is active. Detailed tracking will begin within 24 hours.',
                        style: TextStyle(
                          color: Colors.blue[700],
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (subscriptionType == 'Trial' && daysLeft == null)
              SizedBox(height: 16),
            if (subscriptionType == 'Paid' &&
                _businessController.business['paymentStart'] != null)
              _buildInfoRow(
                Icons.payment,
                'Payment Date'.tr,
                _formatDate((_businessController.business['paymentStart']
                        as Timestamp)
                    .toDate()),
                null,
              ),
            if (subscriptionType == 'Paid' &&
                _businessController.business['paymentStart'] != null)
              SizedBox(height: 16),
            if (daysLeft != null)
              _buildInfoRow(
                Icons.timelapse,
                'Days Remaining'.tr,
                daysLeft < 0 ? 'Expired'.tr : '$daysLeft ${'days'.tr}',
                daysLeft < 0
                    ? Colors.red
                    : daysLeft <= 7
                        ? Colors.orange
                        : Colors.green,
              ),
            if (subscriptionType == 'Trial')
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info, color: Colors.blue[700], size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Subscribe to continue using all features after trial'.tr,
                          style: TextStyle(
                            color: Colors.blue[700],
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentButton(BuildContext context) {
    final subscriptionType = _businessController.getSubscriptionType();
    final daysLeft = _businessController.getDaysUntilSubscriptionExpiry();

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: Text('Payment'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          subscriptionType == 'Trial'
                              ? 'Subscribe to continue after trial'.tr
                              : 'Renew your subscription'.tr,
                        ),
                        SizedBox(height: 16),
                        PaymentDialogContent(),
                      ],
                    ),
                  ),
                );
              },
              icon: Icon(Icons.payment, size: 24),
              label: Text(
                subscriptionType == 'Trial'
                    ? 'Subscribe Now'.tr
                    : 'Renew Subscription'.tr,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: daysLeft != null && daysLeft <= 7
                    ? Colors.orange
                    : primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          if (subscriptionType == 'Paid')
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'Manage your subscription and payment methods'.tr,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, Color? valueColor) {
    return Row(
      children: [
        Icon(icon, color: Colors.grey[600], size: 20),
        SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 14,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: valueColor ?? Colors.black87,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Color _getTypeColor(String type) {
    if (type == 'Trial') return Colors.blue;
    if (type == 'Paid') return Colors.green;
    return Colors.grey;
  }

  String _formatStatus(String? status) {
    if (status == null) return 'Unknown';
    if (status == 'subscription_ok') return 'Active';
    if (status == 'subscription_ontrial') return 'On Trial';
    if (status == 'trial_expired') return 'Trial Expired';
    if (status == 'subscription_ended') return 'Expired';
    return status;
  }

  Color _getStatusColor(String? status) {
    if (status == 'subscription_ok') return Colors.green;
    if (status == 'subscription_ontrial') return Colors.blue;
    if (status == 'trial_expired') return Colors.red;
    if (status == 'subscription_ended') return Colors.red;
    return Colors.grey;
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }
}
