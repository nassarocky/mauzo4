import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:mauzo/controllers/product_transfer_controller.dart';
import 'package:mauzo/controllers/profile_controller.dart';
import 'package:mauzo/controllers/business_controller.dart';
import 'package:mauzo/models/product_transfer_request.dart';
import 'package:mauzo/utils/constants.dart';
import 'package:mauzo/utils/preferences.dart';
import 'package:mauzo/ui/widgets/tiles/transfer_request_tile.dart';
import 'package:mauzo/ui/widgets/dialogs/double_action_dialog.dart';

import '../sale/edit_sale.screen.dart';

class TransferRequestsScreen extends StatefulWidget {
  const TransferRequestsScreen({Key? key}) : super(key: key);

  @override
  State<TransferRequestsScreen> createState() => _TransferRequestsScreenState();
}

class _TransferRequestsScreenState extends State<TransferRequestsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ProductTransferController _transferController = Get.find();
  final ProfileController _profileController = Get.find();
  final BusinessController _businessController = Get.find();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Preferences.getTheme()
          ? Theme.of(context).scaffoldBackgroundColor
          : const Color(0xFFE5E5E5),
      appBar: AppBar(
        title: Text(
          'Transfer Requests'.tr,
          style: TextStyle(color: Colors.black),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.black),
            onPressed: () async {
              try {
                await _transferController.refreshTransferRequests();
                Get.snackbar(
                  'Refreshed'.tr,
                  'Transfer requests updated'.tr,
                  backgroundColor: Colors.green,
                  colorText: Colors.white,
                  duration: Duration(seconds: 1),
                );
              } catch (e) {
                Get.snackbar(
                  'Error'.tr,
                  'Failed to refresh transfer requests'.tr,
                  backgroundColor: Colors.red,
                  colorText: Colors.white,
                  duration: Duration(seconds: 2),
                );
              }
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Preferences.getTheme() ? primaryLightColor : primaryColor,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Preferences.getTheme() ? primaryLightColor : primaryColor,
          tabs: [
            Tab(
              child: Obx(() => Text(
                'Incoming (${_transferController.incomingTransferRequests.length})',
                style: TextStyle(fontSize: 14),
              )),
            ),
            Tab(
              child: Obx(() => Text(
                'Outgoing (${_transferController.outgoingTransferRequests.length})',
                style: TextStyle(fontSize: 14),
              )),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Incoming Transfer Requests Tab
          _buildIncomingRequestsTab(),
          // Outgoing Transfer Requests Tab
          _buildOutgoingRequestsTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          print('[DEBUG] FAB pressed: Navigating to /sale/add with userData=transfer');
          Navigator.pushNamed(context, '/sale/add', arguments: {'userData': UserData('transfer')});
        },
        child: Icon(Icons.add),
        backgroundColor: Preferences.getTheme() ? primaryLightColor : primaryColor,
        tooltip: 'Transfer Products',
      ),
    );
  }

  Widget _buildIncomingRequestsTab() {
    return Obx(() {
      if (_transferController.incomingTransferRequests.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.inbox_outlined,
                size: 64,
                color: Colors.grey[400],
              ),
              SizedBox(height: 16),
              Text(
                'No incoming transfer requests'.tr,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        );
      }

      return RefreshIndicator(
        onRefresh: () async {
          try {
            await _transferController.refreshTransferRequests();
            Get.snackbar(
              'Refreshed'.tr,
              'Transfer requests updated'.tr,
              backgroundColor: Colors.green,
              colorText: Colors.white,
              duration: Duration(seconds: 1),
            );
          } catch (e) {
            Get.snackbar(
              'Error'.tr,
              'Failed to refresh transfer requests'.tr,
              backgroundColor: Colors.red,
              colorText: Colors.white,
              duration: Duration(seconds: 2),
            );
          }
        },
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _transferController.incomingTransferRequests.length,
          itemBuilder: (context, index) {
            final request = _transferController.incomingTransferRequests[index];
            return TransferRequestTile(
              request: request,
              isIncoming: true,
              onAccept: () => _handleAcceptRequest(request),
              onReject: () => _handleRejectRequest(request),
            );
          },
        ),
      );
    });
  }

  Widget _buildOutgoingRequestsTab() {
    return Obx(() {
      if (_transferController.outgoingTransferRequests.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.outbox_outlined,
                size: 64,
                color: Colors.grey[400],
              ),
              SizedBox(height: 16),
              Text(
                'No outgoing transfer requests'.tr,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        );
      }

      return RefreshIndicator(
        onRefresh: () async {
          try {
            await _transferController.refreshTransferRequests();
            Get.snackbar(
              'Refreshed'.tr,
              'Transfer requests updated'.tr,
              backgroundColor: Colors.green,
              colorText: Colors.white,
              duration: Duration(seconds: 1),
            );
          } catch (e) {
            Get.snackbar(
              'Error'.tr,
              'Failed to refresh transfer requests'.tr,
              backgroundColor: Colors.red,
              colorText: Colors.white,
              duration: Duration(seconds: 2),
            );
          }
        },
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _transferController.outgoingTransferRequests.length,
          itemBuilder: (context, index) {
            final request = _transferController.outgoingTransferRequests[index];
            return TransferRequestTile(
              request: request,
              isIncoming: false,
              onAccept: null, // Outgoing requests can't be accepted by sender
              onReject: null, // Outgoing requests can't be rejected by sender
            );
          },
        ),
      );
    });
  }

  void _handleAcceptRequest(ProductTransferRequest request) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => DoubleActionDialog(
        title: 'Accept Transfer Request'.tr,
        content: 'Are you sure you want to accept this transfer request?'.tr,
        confirm: 'Accept'.tr,
        cancel: 'Cancel'.tr,
        onConfirm: () => Navigator.pop(context, true),
        onCancel: () => Navigator.pop(context, false),
      ),
    );

    if (confirmed == true) {
      try {
        await _transferController.acceptTransferRequest(
          request.id,
          _profileController.user['id'],
        );
        Get.snackbar(
          'Success'.tr,
          'Transfer request accepted successfully'.tr,
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      } catch (e) {
        Get.snackbar(
          'Error'.tr,
          'Failed to accept transfer request'.tr,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    }
  }

  void _handleRejectRequest(ProductTransferRequest request) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => DoubleActionDialog(
        title: 'Reject Transfer Request'.tr,
        content: 'Are you sure you want to reject this transfer request?'.tr,
        confirm: 'Reject'.tr,
        cancel: 'Cancel'.tr,
        onConfirm: () => Navigator.pop(context, true),
        onCancel: () => Navigator.pop(context, false),
      ),
    );

    if (confirmed == true) {
      try {
        await _transferController.rejectTransferRequest(
          request.id,
          _profileController.user['id'],
        );
        Get.snackbar(
          'Success'.tr,
          'Transfer request rejected successfully'.tr,
          backgroundColor: Colors.orange,
          colorText: Colors.white,
        );
      } catch (e) {
        Get.snackbar(
          'Error'.tr,
          'Failed to reject transfer request'.tr,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    }
  }
} 