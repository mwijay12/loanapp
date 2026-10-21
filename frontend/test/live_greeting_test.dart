import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:loan_inventory_app/core/data/sales_provider.dart';
import 'package:loan_inventory_app/core/widgets/live_greeting.dart';

void main() {
  group('greeting', () {
    test('follows the hour', () {
      expect(greetingFor(6), 'Good morning');
      expect(greetingFor(11), 'Good morning');
      expect(greetingFor(12), 'Good afternoon');
      expect(greetingFor(16), 'Good afternoon');
      expect(greetingFor(17), 'Good evening');
      expect(greetingFor(22), 'Good evening');
    });

    test('late night is evening, not morning', () {
      // The old code greeted at 02:00 with "Good morning" because the string was
      // a literal; this pins the shift boundary.
      expect(greetingFor(2), 'Good evening');
      expect(greetingFor(4), 'Good evening');
      expect(greetingFor(5), 'Good morning');
    });

    test('eat clock is three hours ahead of UTC', () {
      final now = DateTime.now();
      final offset = eatNow().difference(now.toUtc()).inMinutes;
      expect(offset, closeTo(180, 1));
    });
  });

  group('sales totals', () {
    SaleRecord sale({
      required DateTime at,
      required int paid,
      String kind = 'cash',
    }) =>
        SaleRecord(
          receiptNo: 'R-${at.millisecondsSinceEpoch}',
          total: paid,
          paid: paid,
          kind: kind,
          soldAt: at,
        );

    test('only today counts', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final now = DateTime.now();

      container.read(salesProvider.notifier).replaceAll([
        sale(at: now, paid: 500000),
        sale(at: now.subtract(const Duration(days: 1)), paid: 900000),
      ]);

      expect(container.read(salesTodayTotalProvider), 500000);
      expect(container.read(salesTodayCountProvider), 1);
    });

    test('a new sale moves the total immediately', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final before = container.read(salesTodayTotalProvider);

      container.read(salesProvider.notifier).add(
            sale(at: DateTime.now(), paid: 250000),
          );

      expect(container.read(salesTodayTotalProvider), before + 250000);
    });

    test('empty ledger reads zero, not a stale figure', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(salesTodayTotalProvider), 0);
      expect(container.read(salesTodayCountProvider), 0);
    });
  });
}
