import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:mauzo/controllers/product_transfer_controller.dart';
import 'package:mauzo/controllers/business_controller.dart';
import 'package:mauzo/models/product_transfer_request.dart';
import 'package:mauzo/utils/constants.dart';
import 'package:mauzo/utils/preferences.dart';
import 'package:mauzo/ui/widgets/buttons/primary_button.dart';
import 'package:mauzo/ui/widgets/buttons/secondary_button.dart';

class TransferRequestTile extends StatefulWidget {
  final ProductTransferRequest request;
  final bool isIncoming;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;

  const TransferRequestTile({
    Key? key,
    required this.request,
    required this.isIncoming,
    this.onAccept,
    this.onReject,
  }) : super(key: key);

  @override
  State<TransferRequestTile> createState() => _TransferRequestTileState();
}

class _TransferRequestTileState extends State<TransferRequestTile> {
  final ProductTransferController _transferController = Get.find();
  final BusinessController _businessController = Get.find();
  
  String? fromBusinessName;
  String? toBusinessName;
  String? productName;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadAdditionalData();
  }

  Future<void> _loadAdditionalData() async {
    setState(() {
      isLoading = true;
    });

    try {
      // Load business names
      fromBusinessName = await _transferController.getBusinessName(widget.request.fromBusinessId);
      toBusinessName = await _transferController.getBusinessName(widget.request.toBusinessId);
      
      // Load product details
      final productDetails = await _transferController.getProductDetails(widget.request.productId);
      if (productDetails != null) {
        productName = productDetails['name'] ?? 'Unknown Product';
      } else {
        productName = 'Product Not Found';
      }
    } catch (e) {
      print('Error loading additional data: $e');
      fromBusinessName = widget.request.fromBusinessId;
      toBusinessName = widget.request.toBusinessId;
      productName = 'Unknown Product';
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'accepted':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'Pending'.tr;
      case 'accepted':
        return 'Accepted'.tr;
      case 'rejected':
        return 'Rejected'.tr;
      default:
        return 'Unknown'.tr;
    }
  }

  String _getRelativeTime(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inSeconds < 60) {
      return '${difference.inSeconds} seconds ago';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minutes ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else if (difference.inDays < 30) {
      return '${difference.inDays ~/ 7} weeks ago';
    } else if (difference.inDays < 365) {
      return '${difference.inDays ~/ 30} months ago';
    } else {
      return '${difference.inDays ~/ 365} years ago';
    }
  }

  @override
  Widget build(BuildContext context) {
    // Check if request is recent (less than 24 hours old)
    final now = DateTime.now();
    final requestTime = widget.request.requestedAt.toDate();
    final isRecent = now.difference(requestTime).inHours < 24;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Preferences.getTheme() ? darkGrayColor : whiteColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isRecent 
              ? (Preferences.getTheme() ? primaryLightColor : primaryColor)
              : (Preferences.getTheme() ? mediumGrayColor : borderColor),
          width: isRecent ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    widget.isIncoming ? Icons.inbox : Icons.outbox,
                    color: Preferences.getTheme() ? primaryLightColor : primaryColor,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text(
                    widget.isIncoming ? 'Incoming Request'.tr : 'Outgoing Request'.tr,
                    style: h6(Preferences.getTheme() ? primaryLightColor : primaryColor),
                  ),
                  if (isRecent) ...[
                    SizedBox(width: 8),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'NEW',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusColor(widget.request.status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _getStatusColor(widget.request.status)),
                ),
                child: Text(
                  _getStatusText(widget.request.status),
                  style: TextStyle(
                    color: _getStatusColor(widget.request.status),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          
          SizedBox(height: 12),
          
          // Product information
          if (widget.request.products != null && widget.request.products!.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Products:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 4),
                ...widget.request.products!.map<Widget>((product) {
                  final name = product['name'] ?? 'Unknown Product';
                  final quantity = product['quantity'] ?? 0.0;
                  final itemType = product['itemType'] ?? 'product';
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '- $name',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                          ),
                        ),
                        Text(
                          'Qty: ${quantity.toString()}',
                          style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                        ),
                        SizedBox(width: 8),
                        if (itemType == 'service')
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text('Service', style: TextStyle(fontSize: 12, color: Colors.green[800])),
                          ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            )
          else
            // Single-product fallback
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.request.productName,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Quantity: ${widget.request.quantity.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Transfer: ${widget.request.transferQuantity.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.blue[700],
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Status: ${widget.request.status.toUpperCase()}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: _getStatusColor(widget.request.status),
                  ),
                ),
              ],
            ),
          
          SizedBox(height: 12),
          
          // Business information
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Preferences.getTheme() ? mediumGrayColor.withOpacity(0.1) : Colors.grey[50],
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.business,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                    SizedBox(width: 8),
                    Text(
                      'From: ${fromBusinessName ?? widget.request.fromBusinessId}',
                      style: bodyText(Colors.grey[700]),
                    ),
                  ],
                ),
                SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.business,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                    SizedBox(width: 8),
                    Text(
                      'To: ${toBusinessName ?? widget.request.toBusinessId}',
                      style: bodyText(Colors.grey[700]),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          SizedBox(height: 12),
          
          // Date information
          Row(
            children: [
              Icon(
                Icons.schedule,
                size: 16,
                color: Colors.grey[600],
              ),
              SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Requested: ${DateFormat('dd/MM/yyyy, hh:mm a').format(widget.request.requestedAt.toDate())}',
                      style: bodyText(Colors.grey[600]),
                    ),
                    Text(
                      _getRelativeTime(widget.request.requestedAt.toDate()),
                      style: TextStyle(
                        fontSize: 12,
                        color: isRecent ? Colors.green[600] : Colors.grey[500],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          if (widget.request.respondedAt != null) ...[
            SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.check_circle,
                  size: 16,
                  color: Colors.grey[600],
                ),
                SizedBox(width: 8),
                Text(
                  'Responded: ${DateFormat('dd/MM/yyyy, hh:mm a').format(widget.request.respondedAt!.toDate())}',
                  style: bodyText(Colors.grey[600]),
                ),
              ],
            ),
          ],
          
          // Action buttons for incoming pending requests
          if (widget.isIncoming && widget.request.status == 'pending' && widget.onAccept != null && widget.onReject != null) ...[
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: SecondaryButton(
                    text: 'Reject'.tr,
                    onPressed: widget.onReject!,
                    color: Colors.red,
                    textColor: Colors.white,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: PrimaryButton(
                    text: 'Accept'.tr,
                    onPressed: widget.onAccept!,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
} 