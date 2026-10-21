import 'package:flutter_test/flutter_test.dart';
import 'package:loan_inventory_app/core/services/stock_receipts.dart';

/// Receiving used to accept anything: the line list was hardcoded and the confirm
/// button wrote to product ids 1–4 whatever the delivery said. These tests pin the
/// rules that decide whether a delivery is complete enough to apply.
void main() {
  StockReceiptLine line({int qty = 4, int cost = 2500000}) => StockReceiptLine(
        productId: 7,
        name: 'iPhone 15 Pro Max',
        sku: 'IP15PM-256-NT',
        qty: qty,
        unitCost: cost,
      );

  test('a supplier delivery without a supplier name is refused', () {
    final r = StockReceipt(
      branch: 'Kariakoo',
      source: StockSource.supplier,
      lines: [line()],
      imeis: const [],
    );
    expect(r.validate(), 'supplier');
  });

  test('a transfer without a source branch is refused', () {
    final r = StockReceipt(
      branch: 'Kariakoo',
      source: StockSource.transfer,
      lines: [line()],
      imeis: const [],
    );
    expect(r.validate(), 'fromBranch');
  });

  test('an empty delivery is refused before it can touch stock', () {
    final r = StockReceipt(
      branch: 'Kariakoo',
      source: StockSource.supplier,
      lines: const [],
      imeis: const [],
      supplierName: 'Tech Distributors',
    );
    expect(r.validate(), 'lines');
  });

  test('a complete supplier delivery is accepted and totals its lines', () {
    final r = StockReceipt(
      branch: 'Kariakoo',
      source: StockSource.supplier,
      lines: [line(qty: 4), line(qty: 2)],
      imeis: const ['358920112849101'],
      supplierName: 'Tech Distributors',
      invoiceNo: 'INV-2026-0412',
    );
    expect(r.validate(), isNull);
    expect(r.units, 6);
    expect(r.value, 6 * 2500000);
  });

  test('a customer return needs neither supplier nor branch', () {
    final r = StockReceipt(
      branch: 'Kariakoo',
      source: StockSource.customerReturn,
      lines: [line(qty: 1)],
      imeis: const [],
    );
    expect(r.validate(), isNull);
  });

  test('the receipt key is stable for the same invoice on the same day', () {
    final r = StockReceipt(
      branch: 'Kariakoo',
      source: StockSource.supplier,
      lines: [line()],
      imeis: const [],
      supplierName: 'Tech Distributors',
      invoiceNo: 'INV-2026-0412',
    );
    final a = receiptKey(r, DateTime.utc(2026, 10, 22, 9));
    final b = receiptKey(r, DateTime.utc(2026, 10, 22, 15));
    expect(a, b);
  });
}
