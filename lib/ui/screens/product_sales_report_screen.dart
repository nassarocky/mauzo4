import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:mauzo/controllers/business_controller.dart';
import 'package:mauzo/controllers/product_controller.dart';
import 'package:mauzo/models/sale_model.dart';
import 'package:mauzo/services/product_sales_export_service.dart';
import 'package:mauzo/utils/constants.dart';
import 'package:mauzo/utils/product_sales_stats.dart';

/// Most-sold products for a chosen period and optional product selection,
/// with PDF / Excel export.
class ProductSalesReportScreen extends StatefulWidget {
  const ProductSalesReportScreen({super.key, required this.sales});

  final List<Sale> sales;

  @override
  State<ProductSalesReportScreen> createState() =>
      _ProductSalesReportScreenState();
}

class _ProductSalesReportScreenState extends State<ProductSalesReportScreen> {
  final BusinessController _businessController = Get.find();
  final ProductController _productController = Get.find();
  final DateFormat _dateFmt = DateFormat('dd/MM/yyyy');

  late DateTime _start;
  late DateTime _end;
  final Set<String> _selectedProductIds = {};
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    final today = DateUtils.dateOnly(DateTime.now());
    _end = today;
    _start = today.subtract(const Duration(days: 29));
  }

  String get _currency =>
      (_businessController.business['mainCurrency'] ?? '').toString();

  String get _businessName =>
      (_businessController.business['name'] ?? '').toString();

  List<ProductSalesRow> get _rows => computeProductSalesStats(
        widget.sales,
        start: _start,
        end: _end,
        productIds: _selectedProductIds,
      );

  Future<void> _pickDate({required bool isStart}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _start : _end,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    setState(() {
      final day = DateUtils.dateOnly(picked);
      if (isStart) {
        _start = day;
        if (_end.isBefore(_start)) _end = _start;
      } else {
        _end = day;
        if (_start.isAfter(_end)) _start = _end;
      }
    });
  }

  Future<void> _pickProducts() async {
    final products = _productController.products.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final working = Set<String>.from(_selectedProductIds);
    String query = '';

    final result = await showDialog<Set<String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final shown = products
              .where((p) => p.name.toLowerCase().contains(query.toLowerCase()))
              .toList();
          return AlertDialog(
            title: Text('select_products'.tr),
            content: SizedBox(
              width: double.maxFinite,
              height: MediaQuery.of(ctx).size.height * 0.55,
              child: Column(
                children: [
                  TextField(
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: 'search'.tr,
                    ),
                    onChanged: (v) => setLocal(() => query = v),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: shown.length,
                      itemBuilder: (_, i) {
                        final p = shown[i];
                        return CheckboxListTile(
                          dense: true,
                          value: working.contains(p.id),
                          title: Text(p.name),
                          onChanged: (on) => setLocal(() {
                            if (on == true) {
                              working.add(p.id);
                            } else {
                              working.remove(p.id);
                            }
                          }),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, <String>{}),
                child: Text('all_products'.tr),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('cancel'.tr),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, working),
                child: Text('apply'.tr),
              ),
            ],
          );
        },
      ),
    );
    if (result == null) return;
    setState(() {
      _selectedProductIds
        ..clear()
        ..addAll(result);
    });
  }

  Future<void> _export({required bool pdf}) async {
    final rows = _rows;
    if (rows.isEmpty) return;
    setState(() => _exporting = true);
    try {
      if (pdf) {
        await ProductSalesExportService.sharePdf(
          rows: rows,
          businessName: _businessName,
          currency: _currency,
          start: _start,
          end: _end,
          selectedProductsOnly: _selectedProductIds.isNotEmpty,
        );
      } else {
        await ProductSalesExportService.shareExcel(
          rows: rows,
          businessName: _businessName,
          currency: _currency,
          start: _start,
          end: _end,
          selectedProductsOnly: _selectedProductIds.isNotEmpty,
        );
      }
    } catch (e) {
      errorSnackbar(e.toString());
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  String _qty(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    final rows = _rows;
    final totalQty = rows.fold<double>(0, (s, r) => s + r.quantity);
    final totalRevenue = rows.fold<double>(0, (s, r) => s + r.revenue);

    return Scaffold(
      appBar: AppBar(
        title: Text('products_sold_report'.tr),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'export_pdf'.tr,
            icon: const Icon(Icons.picture_as_pdf_outlined),
            onPressed: rows.isEmpty || _exporting
                ? null
                : () => _export(pdf: true),
          ),
          IconButton(
            tooltip: 'export_excel'.tr,
            icon: const Icon(Icons.table_chart_outlined),
            onPressed: rows.isEmpty || _exporting
                ? null
                : () => _export(pdf: false),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.event, size: 18),
                    label: Text('${'from_date'.tr}: ${_dateFmt.format(_start)}'),
                    onPressed: () => _pickDate(isStart: true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.event, size: 18),
                    label: Text('${'to_date'.tr}: ${_dateFmt.format(_end)}'),
                    onPressed: () => _pickDate(isStart: false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.inventory_2_outlined, size: 18),
                label: Text(
                  _selectedProductIds.isEmpty
                      ? 'all_products'.tr
                      : '${_selectedProductIds.length} ${'products_selected'.tr}',
                ),
                onPressed: _pickProducts,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF00AD30),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('total_sales_statistics'.tr, style: bodyText(whiteColor)),
                  const SizedBox(height: 4),
                  Text(formatCurrency(totalRevenue, _currency),
                      style: h5(whiteColor)),
                  const SizedBox(height: 2),
                  Text('${'sold'.tr}: ${_qty(totalQty)}',
                      style: bodyText(whiteColor)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: rows.isEmpty
                  ? Center(child: Text('no_products_sold'.tr))
                  : ListView.separated(
                      itemCount: rows.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final r = rows[i];
                        return ListTile(
                          dense: true,
                          leading: CircleAvatar(
                            radius: 14,
                            child: Text('${i + 1}',
                                style: const TextStyle(fontSize: 12)),
                          ),
                          title: Text(r.name),
                          subtitle: Text(
                              '${'sold'.tr}: ${_qty(r.quantity)} · ${r.salesCount}'),
                          trailing: Text(
                            formatCurrency(r.revenue, _currency),
                            style: bodyText(greenColor),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
