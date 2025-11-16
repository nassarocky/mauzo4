import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../../controllers/inventory_loss_controller.dart';
import '../../../models/inventory_loss_model.dart';
import '../../../models/product_model.dart';
import '../../../utils/constants.dart';
import '../buttons/primary_button.dart';

class RecordLossDialog extends StatefulWidget {
  final Product product;

  const RecordLossDialog({Key? key, required this.product}) : super(key: key);

  @override
  State<RecordLossDialog> createState() => _RecordLossDialogState();
}

class _RecordLossDialogState extends State<RecordLossDialog> {
  final InventoryLossController _lossController = Get.find();
  final _quantityController = TextEditingController();
  final _reasonController = TextEditingController();
  
  String _selectedLossType = 'damaged';
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;

  @override
  void dispose() {
    _quantityController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2015),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _recordLoss() async {
    if (_quantityController.text.isEmpty) {
      errorSnackbar('Please enter quantity');
      return;
    }

    if (_reasonController.text.trim().isEmpty) {
      errorSnackbar('Please enter reason for loss');
      return;
    }

    final double? quantity = double.tryParse(_quantityController.text);
    if (quantity == null || quantity <= 0) {
      errorSnackbar('Please enter a valid quantity');
      return;
    }

    if (quantity > widget.product.quantity!) {
      errorSnackbar('Loss quantity cannot exceed available stock (${widget.product.quantity})');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final success = await _lossController.recordLoss(
      product: widget.product,
      quantity: quantity,
      lossType: _selectedLossType,
      reason: _reasonController.text.trim(),
      dateOccurred: _selectedDate,
    );

    setState(() {
      _isLoading = false;
    });

    if (success) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalValue = (double.tryParse(_quantityController.text) ?? 0) * 
                       widget.product.buyingPrice;

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      title: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Record Inventory Loss',
              style: h5(Theme.of(context).textTheme.bodyLarge!.color),
            ),
          ),
        ],
      ),
      content: _isLoading
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: CircularProgressIndicator(),
              ),
            )
          : SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product Info
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.product.name,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Code: ${widget.product.code}',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        Text(
                          'Available Stock: ${widget.product.quantity}',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        Text(
                          'Unit Cost: ${widget.product.buyingPrice.toStringAsFixed(2)}',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 20),

                  // Loss Type Dropdown
                  Text(
                    'Loss Type',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: borderColor),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButton<String>(
                      value: _selectedLossType,
                      isExpanded: true,
                      underline: SizedBox(),
                      items: InventoryLoss.lossTypes.map((type) {
                        return DropdownMenuItem<String>(
                          value: type['value'],
                          child: Row(
                            children: [
                              Text(
                                InventoryLoss.getLossTypeIcon(type['value']!),
                                style: TextStyle(fontSize: 20),
                              ),
                              SizedBox(width: 8),
                              Text(type['label']!),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedLossType = value!;
                        });
                      },
                    ),
                  ),
                  SizedBox(height: 16),

                  // Quantity TextField
                  Text(
                    'Quantity Lost',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  TextField(
                    controller: _quantityController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: 'Enter quantity',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    onChanged: (value) {
                      setState(() {}); // Refresh to update total value
                    },
                  ),
                  SizedBox(height: 16),

                  // Date Selector
                  Text(
                    'Date Occurred',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  InkWell(
                    onTap: _selectDate,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: borderColor),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(DateFormat('dd MMM yyyy').format(_selectedDate)),
                          Icon(Icons.calendar_today, size: 18),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 16),

                  // Reason TextField
                  Text(
                    'Reason / Notes',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  TextField(
                    controller: _reasonController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Describe the reason for this loss...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                  SizedBox(height: 16),

                  // Total Value Display
                  if (_quantityController.text.isNotEmpty)
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red[200]!),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total Loss Value:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            totalValue.toStringAsFixed(2),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
      actions: _isLoading
          ? []
          : [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text('Cancel'),
              ),
              SizedBox(
                height: 40,
                child: ElevatedButton(
                  onPressed: _recordLoss,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text('Record Loss', style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
    );
  }
}
