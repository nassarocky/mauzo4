import 'package:flutter_test/flutter_test.dart';
import 'package:mauzo/services/delivery_note_service.dart';

void main() {
  test('lines keep name and quantity with unit, and drop prices', () {
    final lines = deliveryNoteLinesFromProducts([
      {'name': 'Rice', 'quantity': 3, 'price': 2500, 'saleUomLabel': 'Bag'},
      {'name': 'Sugar', 'quantity': 1.5, 'price': 3000},
    ]);
    expect(lines.length, 2);
    expect(lines[0].name, 'Rice');
    expect(lines[0].quantity, '3 Bag');
    expect(lines[1].quantity, '1.50');
  });

  test('blank names, zero quantities and non-map entries are skipped', () {
    final lines = deliveryNoteLinesFromProducts([
      {'name': '  ', 'quantity': 2},
      {'name': 'Oil', 'quantity': 0},
      'garbage',
      {'name': 'Salt', 'quantity': '4'},
    ]);
    expect(lines.length, 1);
    expect(lines.single.name, 'Salt');
    expect(lines.single.quantity, '4');
  });

  test('PDF builds and has content for a multi-item note', () async {
    final bytes = await buildDeliveryNoteBytes(
      businessName: 'Duka',
      businessPhone: '0758422100',
      date: DateTime(2026, 8, 14, 10, 30),
      clientName: 'Shamba la Kuku',
      lines: [
        for (var i = 0; i < 80; i++)
          DeliveryNoteLine(name: 'Item $i', quantity: '${i + 1}'),
      ],
      remarks: 'Leave at gate',
      deliveredBy: 'Asha',
    );
    expect(bytes.length, greaterThan(1000));
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
  });
}
