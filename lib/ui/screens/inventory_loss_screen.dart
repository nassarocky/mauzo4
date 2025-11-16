import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../controllers/business_controller.dart';
import '../../controllers/inventory_loss_controller.dart';
import '../../controllers/profile_controller.dart';
import '../../models/inventory_loss_model.dart';
import '../../utils/constants.dart';

class InventoryLossScreen extends StatefulWidget {
  const InventoryLossScreen({Key? key}) : super(key: key);

  @override
  State<InventoryLossScreen> createState() => _InventoryLossScreenState();
}

class _InventoryLossScreenState extends State<InventoryLossScreen> {
  final InventoryLossController _lossController = Get.find();
  final BusinessController _businessController = Get.find();
  final ProfileController _profileController = Get.find();

  String _selectedFilter = 'all';
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    // Start loading data when screen opens
    _lossController.startListening();
  }

  @override
  void dispose() {
    // Stop loading data when screen closes to save resources
    _lossController.stopListening();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Inventory Losses'),
        actions: [
          // Time Period Toggle
          Obx(() => TextButton.icon(
            onPressed: () {
              _lossController.toggleTimeFilter();
            },
            icon: Icon(
              _lossController.showAllTime.value 
                ? Icons.history 
                : Icons.calendar_today,
              color: Colors.white,
              size: 20,
            ),
            label: Text(
              _lossController.showAllTime.value ? 'All Time' : 'Current Period',
              style: TextStyle(color: Colors.white),
            ),
            style: TextButton.styleFrom(
              backgroundColor: _lossController.showAllTime.value 
                ? Colors.blue.withOpacity(0.3)
                : Colors.orange.withOpacity(0.3),
            ),
          )),
          IconButton(
            icon: Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
          IconButton(
            icon: Icon(Icons.info_outline),
            onPressed: _showStatistics,
          ),
        ],
      ),
      body: Column(
        children: [
          // Statistics Summary
          _buildStatisticsSummary(),

          // Filter Chips
          _buildFilterChips(),

          // Loss List
          Expanded(
            child: Obx(() {
              final filteredLosses = _getFilteredLosses();

              if (_lossController.isLoading.value) {
                return Center(child: CircularProgressIndicator());
              }

              if (filteredLosses.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'No inventory losses recorded',
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                itemCount: filteredLosses.length,
                padding: EdgeInsets.all(16),
                itemBuilder: (context, index) {
                  final loss = filteredLosses[index];
                  return _buildLossCard(loss);
                },
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsSummary() {
    return Obx(() {
      final stats = _lossController.getLossStatistics();
      final totalLosses = stats['totalLosses'] as int;
      final totalValue = stats['totalValue'] as double;
      final currency = _businessController.business['mainCurrency'] ?? 'TZS';
      final isAllTime = _lossController.showAllTime.value;
      final resetTime = _businessController.business['reset_time'];

      return Container(
        margin: EdgeInsets.all(16),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.red[400]!, Colors.red[600]!],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.red.withOpacity(0.3),
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // Period indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isAllTime ? Icons.history : Icons.calendar_today,
                  color: Colors.white70,
                  size: 16,
                ),
                SizedBox(width: 4),
                Text(
                  isAllTime 
                    ? 'All Time Data' 
                    : resetTime != null
                      ? 'From ${DateFormat('dd MMM yyyy').format((resetTime as Timestamp).toDate())}'
                      : 'Current Period',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total Losses',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        totalLosses.toString(),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: Colors.white30,
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total Value',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '$currency ${totalValue.toStringAsFixed(0)}',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    });
  }

  Widget _buildFilterChips() {
    final filters = [
      {'value': 'all', 'label': 'All', 'icon': '📋'},
      {'value': 'damaged', 'label': 'Damaged', 'icon': '🔨'},
      {'value': 'expired', 'label': 'Expired', 'icon': '📅'},
      {'value': 'stolen', 'label': 'Stolen', 'icon': '🚨'},
      {'value': 'spoiled', 'label': 'Spoiled', 'icon': '🗑️'},
      {'value': 'other', 'label': 'Other', 'icon': '📋'},
    ];

    return Container(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 16),
        itemCount: filters.length,
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = _selectedFilter == filter['value'];

          return Padding(
            padding: EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(filter['icon']!),
                  SizedBox(width: 4),
                  Text(filter['label']!),
                ],
              ),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedFilter = filter['value']!;
                });
              },
              selectedColor: primaryColor.withOpacity(0.2),
              checkmarkColor: primaryColor,
            ),
          );
        },
      ),
    );
  }

  Widget _buildLossCard(InventoryLoss loss) {
    final currency = _businessController.business['mainCurrency'] ?? 'TZS';

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showLossDetails(loss),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Loss Type Icon
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _getLossTypeColor(loss.lossType).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      InventoryLoss.getLossTypeIcon(loss.lossType),
                      style: TextStyle(fontSize: 24),
                    ),
                  ),
                  SizedBox(width: 12),
                  
                  // Product Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          loss.productName,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          loss.lossTypeDisplayName,
                          style: TextStyle(
                            color: _getLossTypeColor(loss.lossType),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Loss Value
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$currency ${loss.totalValue.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.red,
                        ),
                      ),
                      Text(
                        'Qty: ${loss.quantity}',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: 12),
              
              // Reason
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  loss.reason,
                  style: TextStyle(fontSize: 13),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(height: 8),
              
              // Footer
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.person, size: 14, color: Colors.grey),
                      SizedBox(width: 4),
                      Text(
                        loss.recordedByName,
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                  Text(
                    DateFormat('dd MMM yyyy').format(loss.dateOccurred),
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getLossTypeColor(String lossType) {
    switch (lossType) {
      case 'damaged':
        return Colors.orange;
      case 'expired':
        return Colors.purple;
      case 'stolen':
        return Colors.red;
      case 'spoiled':
        return Colors.brown;
      default:
        return Colors.grey;
    }
  }

  List<InventoryLoss> _getFilteredLosses() {
    List<InventoryLoss> filteredList = _lossController.losses.toList();

    // Filter by type
    if (_selectedFilter != 'all') {
      filteredList = filteredList.where((loss) => loss.lossType == _selectedFilter).toList();
    }

    // Filter by date range
    if (_startDate != null && _endDate != null) {
      filteredList = filteredList.where((loss) {
        return loss.dateOccurred.isAfter(_startDate!) &&
               loss.dateOccurred.isBefore(_endDate!.add(Duration(days: 1)));
      }).toList();
    }

    return filteredList;
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Filter by Date Range'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text('Start Date'),
              subtitle: Text(_startDate != null
                  ? DateFormat('dd MMM yyyy').format(_startDate!)
                  : 'Not set'),
              trailing: Icon(Icons.calendar_today),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _startDate ?? DateTime.now(),
                  firstDate: DateTime(2015),
                  lastDate: DateTime.now(),
                );
                if (date != null) {
                  setState(() {
                    _startDate = date;
                  });
                  Navigator.pop(context);
                  _showFilterDialog();
                }
              },
            ),
            ListTile(
              title: Text('End Date'),
              subtitle: Text(_endDate != null
                  ? DateFormat('dd MMM yyyy').format(_endDate!)
                  : 'Not set'),
              trailing: Icon(Icons.calendar_today),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _endDate ?? DateTime.now(),
                  firstDate: _startDate ?? DateTime(2015),
                  lastDate: DateTime.now(),
                );
                if (date != null) {
                  setState(() {
                    _endDate = date;
                  });
                  Navigator.pop(context);
                  _showFilterDialog();
                }
              },
            ),
            if (_startDate != null || _endDate != null)
              TextButton(
                onPressed: () {
                  setState(() {
                    _startDate = null;
                    _endDate = null;
                  });
                  Navigator.pop(context);
                },
                child: Text('Clear Dates'),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showStatistics() {
    final stats = _lossController.getLossStatistics();
    final countByType = stats['countByType'] as Map<String, int>;
    final valueByType = stats['valueByType'] as Map<String, double>;
    final currency = _businessController.business['mainCurrency'] ?? 'TZS';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Loss Statistics'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Breakdown by Type',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 16),
              ...InventoryLoss.lossTypes.map((type) {
                final typeValue = type['value']!;
                final count = countByType[typeValue] ?? 0;
                final value = valueByType[typeValue] ?? 0;

                return Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Text(
                        InventoryLoss.getLossTypeIcon(typeValue),
                        style: TextStyle(fontSize: 20),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              type['label']!,
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                            Text(
                              '$count losses • $currency ${value.toStringAsFixed(0)}',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showLossDetails(InventoryLoss loss) {
    final currency = _businessController.business['mainCurrency'] ?? 'TZS';
    final bool canDelete = _profileController.isManagerOrOwner();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Text(InventoryLoss.getLossTypeIcon(loss.lossType)),
            SizedBox(width: 8),
            Expanded(child: Text('Loss Details')),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Product', loss.productName),
              _buildDetailRow('Code', loss.productCode),
              _buildDetailRow('Loss Type', loss.lossTypeDisplayName),
              _buildDetailRow('Quantity Lost', loss.quantity.toString()),
              _buildDetailRow('Unit Cost', '$currency ${loss.unitPrice.toStringAsFixed(2)}'),
              _buildDetailRow('Total Value', '$currency ${loss.totalValue.toStringAsFixed(2)}',
                  valueColor: Colors.red),
              Divider(),
              _buildDetailRow('Date Occurred',
                  DateFormat('dd MMM yyyy').format(loss.dateOccurred)),
              _buildDetailRow('Recorded By', loss.recordedByName),
              _buildDetailRow('Recorded On',
                  DateFormat('dd MMM yyyy HH:mm').format(loss.dateRecorded)),
              Divider(),
              Text(
                'Reason:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 4),
              Text(loss.reason),
            ],
          ),
        ),
        actions: [
          if (canDelete)
            TextButton(
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text('Delete Loss Record'),
                    content: Text('Are you sure you want to delete this loss record? This action cannot be undone.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: TextButton.styleFrom(foregroundColor: Colors.red),
                        child: Text('Delete'),
                      ),
                    ],
                  ),
                );

                if (confirm == true) {
                  await _lossController.deleteLoss(loss.id);
                  Navigator.pop(context);
                }
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: Text('Delete'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
