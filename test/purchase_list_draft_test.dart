import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mauzo/models/purchase_list_draft.dart';
import 'package:mauzo/services/purchase_list_export_service.dart';

void main() {
  final draft = PurchaseListDraft(
    id: 'draft-1',
    businessId: 'business-1',
    supplierId: 'supplier-1',
    supplierName: 'Supplier',
    supplierPhone: '0765908208',
    products: const [
      {
        'id': 'product-1',
        'name': 'Sugar',
        'quantity': 4.0,
        'itemType': 'product',
      },
      {
        'id': 'product-2',
        'name': 'Rice',
        'quantity': 2.0,
        'itemType': 'product',
      },
    ],
    status: 'draft',
    createdBy: 'user-1',
    createdByName: 'Owner',
    createdAt: Timestamp.fromMillisecondsSinceEpoch(1000),
    updatedAt: Timestamp.fromMillisecondsSinceEpoch(2000),
  );

  test('draft stores requested quantities without purchase amounts', () {
    final map = draft.toMap();

    expect(draft.totalQuantity, 6);
    expect(map['products'], hasLength(2));
    expect(map.containsKey('payment'), isFalse);
    expect(map.containsKey('debt'), isFalse);
    expect(map.containsKey('price'), isFalse);
  });

  test('draft supports no selected supplier', () {
    final supplierFreeDraft = PurchaseListDraft(
      id: 'draft-2',
      businessId: 'business-1',
      supplierId: '',
      supplierName: '',
      supplierPhone: '',
      products: draft.products,
      status: 'draft',
      createdBy: 'user-1',
      createdByName: 'Owner',
      createdAt: draft.createdAt,
      updatedAt: draft.updatedAt,
    );

    final map = supplierFreeDraft.toMap();
    expect(map['supplierId'], isEmpty);
    expect(map['supplierName'], isEmpty);
    expect(map['products'], hasLength(2));
  });

  test('draft Excel export includes selected products', () {
    final bytes = PurchaseListExportService.buildExcel(
      draft: draft,
      businessName: 'Hesabu Mauzo',
    );

    expect(bytes, isNotEmpty);
  });

  test('draft PDF export is generated', () async {
    final bytes = await PurchaseListExportService.buildPdf(
      draft: draft,
      businessName: 'Hesabu Mauzo',
    );

    expect(bytes, isNotEmpty);
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });
}
