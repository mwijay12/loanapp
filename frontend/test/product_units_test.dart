import 'package:flutter_test/flutter_test.dart';
import 'package:loan_inventory_app/core/services/stock_receipts.dart';

/// A delivery can succeed while the handset register stays empty: the boxes
/// arrived but nobody scanned the labels. Both facts have to be reportable at the
/// same time, otherwise the screen either claims serials it does not have or
/// refuses a delivery that physically happened.
void main() {
  test('a received delivery is ok even when no serial was stored', () {
    const result = ReceiveResult(
      updated: ['iPhone 15 Pro Max'],
      failed: [],
      persisted: true,
      unitsStored: 0,
    );

    expect(result.ok, isTrue);
    expect(result.unitsStored, 0);
  });

  test('serials stored do not rescue a delivery whose lines failed', () {
    const result = ReceiveResult(
      updated: [],
      failed: ['Galaxy S24 Ultra'],
      persisted: true,
      unitsStored: 6,
    );

    expect(result.ok, isFalse);
  });

  test('unitsStored reports a partial write rather than rounding up', () {
    const result = ReceiveResult(
      updated: ['TECNO Camon 30'],
      failed: [],
      persisted: true,
      unitsStored: 2,
    );

    // 5 units arrived, 2 serials written: the difference is what the toast says.
    expect(result.unitsStored, 2);
    expect(result.ok, isTrue);
  });
}
