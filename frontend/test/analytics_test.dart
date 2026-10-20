import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:loan_inventory_app/core/data/analytics.dart';

/// The chart has to react to the range switch.
///
/// It previously drew seven fixed bar heights and a fixed total, so "this week"
/// and "this month" were the same picture with a different caption. These tests
/// check that the numbers are aggregated from a ledger instead.
void main() {
  final today = DateTime(2026, 10, 20);
  final ledger = demoLedger(today);

  ProviderContainer container() => ProviderContainer(
        overrides: [salesLedgerProvider.overrideWithValue(ledger)],
      );

  test('the ledger has a stable 90-day history ending today', () {
    expect(ledger.length, 90);
    expect(ledger.last.date, DateTime(2026, 10, 20));
    expect(ledger.first.date, DateTime(2026, 7, 23));
    expect(ledger.every((d) => d.amount > 0), isTrue);
  });

  test('the same day always produces the same figure', () {
    final again = demoLedger(today);
    expect(again.last.amount, ledger.last.amount);
    expect(again.first.amount, ledger.first.amount);
  });

  test('a week has seven points and a month aggregates into four buckets', () {
    final c = container();
    addTearDown(c.dispose);

    final week = c.read(revenueSeriesProvider(RevenueRange.week));
    final month = c.read(revenueSeriesProvider(RevenueRange.month));

    expect(week.points.length, 7);
    expect(month.points.length, 4);
    // Month total must be larger than a single week, otherwise the switch is
    // cosmetic.
    expect(month.total, greaterThan(week.total));
  });

  test('the weekly total equals the sum of its points', () {
    final c = container();
    addTearDown(c.dispose);

    final week = c.read(revenueSeriesProvider(RevenueRange.week));
    final sum = week.points.fold<int>(0, (s, p) => s + p.value);
    expect(sum, week.total);
  });

  test('the change percentage compares against the previous window', () {
    final c = container();
    addTearDown(c.dispose);

    final week = c.read(revenueSeriesProvider(RevenueRange.week));
    final expected =
        (((week.total - week.previousTotal) / week.previousTotal) * 100).round();
    expect(week.changePercent, expected);
  });

  test('exactly one point is marked as the peak, and one as current', () {
    final c = container();
    addTearDown(c.dispose);

    final week = c.read(revenueSeriesProvider(RevenueRange.week));
    expect(week.points.where((p) => p.isPeak).length, 1);
    expect(week.points.where((p) => p.isCurrent).length, 1);
  });

  test('compact money formatting stays readable', () {
    expect(formatTzsCompact(126800000), 'TZS 126.8M');
    expect(formatTzsCompact(8500), 'TZS 9K');
    expect(formatTzsCompact(500), 'TZS 500');
  });
}
