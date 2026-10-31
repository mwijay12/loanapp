import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loan_inventory_app/core/data/analytics.dart';
import 'package:loan_inventory_app/core/data/sales_provider.dart';

/// The console chart used to be seven hand-written bar heights. Changing the
/// range from Week to Month changed the label and nothing else, and pressing a
/// bar was impossible because no bar stood for a day. These tests pin the two
/// properties that made that visible: the series is rebuilt from the shop's own
/// sales rows, and each point carries the figure for the same day one week
/// earlier so a comparison is a lookup rather than a guess.

SaleRecord _sale(DateTime date, int total, {String? receipt}) {
  // Noon EAT keeps the row inside the intended shop-day regardless of how the
  // test host's clock is set.
  final at = DateTime.utc(date.year, date.month, date.day, 9);
  return SaleRecord(
    receiptNo: receipt ?? 'R-${date.toIso8601String()}-$total',
    total: total,
    paid: total,
    kind: 'cash',
    soldAt: at,
    branchId: 'b1',
  );
}

ProviderContainer _container(List<SaleRecord> rows) {
  final c = ProviderContainer(
    overrides: [salesProvider.overrideWith((ref) => SalesNotifier(rows))],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  final today = eatTodayDate;

  group('salesLedgerProvider', () {
    test('falls back to the seeded ledger only when there are no rows', () {
      final empty = _container(const []);
      expect(empty.read(ledgerIsRealProvider), isFalse);
      expect(empty.read(salesLedgerProvider), isNotEmpty);

      final real = _container([_sale(today, 500000)]);
      expect(real.read(ledgerIsRealProvider), isTrue);
      expect(real.read(salesLedgerProvider).length, 1);
    });

    test('aggregates several sales on one shop day into a single entry', () {
      final c = _container([
        _sale(today, 200000),
        _sale(today, 300000),
        _sale(today, 100000),
      ]);
      final ledger = c.read(salesLedgerProvider);
      expect(ledger.length, 1, reason: 'one bucket per East Africa Time day');
      expect(ledger.single.amount, 600000);
      expect(ledger.single.transactions, 3);
      expect(ledger.single.date, today);
    });
  });

  group('revenueSeriesProvider week view', () {
    late ProviderContainer c;
    setUp(() {
      c = _container([
        // Two weeks of takings, with the same weekday one week earlier carrying
        // a different amount on purpose.
        _sale(today.subtract(const Duration(days: 7)), 400000),
        _sale(today.subtract(const Duration(days: 3)), 250000),
        _sale(today.subtract(const Duration(days: 1)), 300000),
        _sale(today, 500000),
      ]);
    });

    test('a full week of bars, one per calendar day, newest last', () {
      final series = c.read(revenueSeriesProvider(RevenueRange.week));
      // The window is the last seven days, so the row from eight days back is
      // a comparison figure only - it does not get its own bar.
      expect(series.points.length, 7);
      expect(series.points.first.date, today.subtract(const Duration(days: 6)));
      expect(series.points.last.date, today);
      expect(series.total, 1050000);
      expect(series.previousTotal, 400000);
    });

    test('a day with no sales still gets a bar, at zero', () {
      final series = c.read(revenueSeriesProvider(RevenueRange.week));
      // Only four of the seven days have takings. The other three must be on
      // the axis: a missing bar reads as missing data, a flat one as a closed
      // day, and a shop with a quiet Tuesday needs to see the Tuesday.
      final quiet = series.points.where((p) => p.value == 0).toList();
      expect(quiet.length, 4, reason: 'four of the seven days took nothing');
      expect(quiet.every((p) => p.date != null), isTrue);

      // Each label is the weekday of the day it sits under, so the axis reads
      // left to right as a calendar week rather than a list of good days.
      const shortDays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
      for (final p in series.points) {
        expect(p.label, shortDays[p.date!.weekday - 1]);
      }
      expect(series.points.last.isCurrent, isTrue);
    });

    test('a point knows the same day last week, not the bar before it', () {
      final series = c.read(revenueSeriesProvider(RevenueRange.week));
      final current = series.points.firstWhere((p) => p.date == today);
      // Seven days earlier is the only row in the previous week.
      expect(current.previousValue, 400000);
      expect(current.previousLabel, isNotEmpty);
      expect(current.deltaPercent, 25); // 500k from 400k
    });

    test('today is flagged as current and the peak is flagged once', () {
      final series = c.read(revenueSeriesProvider(RevenueRange.week));
      expect(series.points.where((p) => p.isCurrent).length, 1);
      expect(series.points.singleWhere((p) => p.isPeak).value, 500000);
    });

    test('a day with no figure last week reports no comparison, not 0%', () {
      final series = c.read(revenueSeriesProvider(RevenueRange.week));
      // Only `today - 7d` falls inside the previous window, so the other days
      // have nothing to compare against.
      final yesterday =
          series.points.firstWhere((p) => p.date == today.subtract(const Duration(days: 1)));
      expect(yesterday.previousValue, 0);
      expect(yesterday.deltaPercent, isNull);
    });
  });

  group('range switch', () {
    test('month re-aggregates into weekly buckets instead of reusing the bars', () {
      final rows = <SaleRecord>[
        for (var back = 0; back < 25; back++)
          _sale(today.subtract(Duration(days: back)), 100000 + back * 1000),
      ];
      final c = _container(rows);

      final week = c.read(revenueSeriesProvider(RevenueRange.week));
      final month = c.read(revenueSeriesProvider(RevenueRange.month));

      expect(week.points.length, 7);
      expect(month.points.length, 4, reason: 'four whole weeks');
      expect(month.total, greaterThan(week.total));
      // Each month bucket is bigger than a single day, which is what makes the
      // bars move when the chip is pressed.
      expect(month.points.first.value, greaterThan(week.points.first.value));
    });

    test('a bar value is the sum of the sales behind it, not a fixed height', () {
      final rows = [
        _sale(today, 111000),
        _sale(today.subtract(const Duration(days: 1)), 222000),
      ];
      final c = _container(rows);
      final series = c.read(revenueSeriesProvider(RevenueRange.week));
      final values = series.points.map((p) => p.value).toList()..sort();
      // Five quiet days sit at zero; the two takings are the rows' own totals,
      // not heights chosen to make the chart look busy.
      expect(values, [0, 0, 0, 0, 0, 111000, 222000]);
    });
  });
}
