import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'branch_provider.dart';
import 'sales_provider.dart';

/// Revenue history behind the console chart.
///
/// The chart used to be seven hand-written bar heights, so changing the range
/// from week to month changed the label and nothing else. These series are built
/// from a daily ledger, which means a range switch actually re-aggregates and the
/// bars move.
///
/// Demo data is generated from a fixed seed: the same day always produces the
/// same figure, so a screenshot taken today still matches the screen tomorrow and
/// nobody sees sales wobble between two page loads. A live build would read the
/// same shape from a `sales` table instead.
enum RevenueRange { week, month }

extension RevenueRangeLabel on RevenueRange {
  String get label => this == RevenueRange.week ? 'Week' : 'Month';

  String get caption => this == RevenueRange.week ? 'this week' : 'this month';

  /// Days covered by the window. The month is four whole weeks, because the
  /// bars are weekly buckets: a 30-day window would leave a two-day bucket on
  /// the end that looks like a bad week rather than a short one.
  int get days => this == RevenueRange.week ? 7 : 28;
}

class DailySale {
  const DailySale({
    required this.date,
    required this.amount,
    required this.branch,
    required this.transactions,
  });

  final DateTime date;
  final int amount;
  final String branch;
  final int transactions;
}

/// Deterministic pseudo-random in [0,1) for a given seed pair.
double _noise(int a, int b) {
  final h = (a * 73856093) ^ (b * 19349663);
  final x = (h & 0x7fffffff) % 1000;
  return x / 1000.0;
}

/// Ninety days of branch sales, ending today.
///
/// The shape is deliberate rather than uniform: weekends carry more walk-in
/// trade, month-end carries salary buyers, and each branch has its own baseline,
/// so the bars look like a shop instead of a test fixture.
List<DailySale> demoLedger(DateTime today) {
  const branches = <String, int>{
    'Mbezi Branch': 4200000,
    'Kariakoo Branch': 3600000,
    'Mwanza Branch': 2400000,
    'Arusha Branch': 2100000,
  };

  final days = <DailySale>[];
  for (var back = 89; back >= 0; back--) {
    final date = DateTime(today.year, today.month, today.day)
        .subtract(Duration(days: back));

    var total = 0;
    var tx = 0;
    var bi = 0;
    for (final entry in branches.entries) {
      final base = entry.value;
      final weekend = (date.weekday >= 5) ? 1.22 : 1.0;
      final monthEnd = date.day >= 26 ? 1.15 : 1.0;
      // +/-18% day to day, stable for the same date and branch.
      final wobble = 0.82 + _noise(date.day + date.month * 31, bi) * 0.36;
      final amount =
          (base * weekend * monthEnd * wobble / 4).round(); // one branch share
      total += amount;
      tx += 2 + (_noise(date.day, bi + 7) * 6).round();
      bi++;
    }
    days.add(
      DailySale(
        date: date,
        amount: total,
        branch: 'All branches',
        transactions: tx,
      ),
    );
  }
  return days;
}

/// The shop's own takings, one entry per East Africa Time day.
///
/// This used to be `demoLedger` unconditionally: a seeded ninety-day history with
/// weekend bumps and month-end lifts. It looked convincing and it was fiction - a
/// bar never corresponded to a cash sale, and pressing it could not have shown
/// anything real because there was nothing real behind it.
///
/// The ledger now aggregates `public.sales`. The seeded history is kept only for a
/// build that has no database at all, so the demo link still renders something.
final salesLedgerProvider = Provider<List<DailySale>>((ref) {
  final rows = ref.watch(salesProvider);
  if (rows.isEmpty) {
    return demoLedger(eatTodayDate);
  }

  final branches = ref.watch(branchesProvider);
  final nameById = {for (final b in branches) b.id: b.name};

  final byDate = <DateTime, List<SaleRecord>>{};
  for (final r in rows) {
    final d = eatDateOf(r.soldAt);
    byDate.putIfAbsent(d, () => []).add(r);
  }

  final dates = byDate.keys.toList()..sort();
  return [
    for (final d in dates)
      DailySale(
        date: d,
        amount: byDate[d]!.fold<int>(0, (s, r) => s + r.total),
        branch: nameById[byDate[d]!.first.branchId] ?? 'All branches',
        transactions: byDate[d]!.length,
      ),
  ];
});

/// Whether the chart is drawing the shop's own ledger or the seeded fallback.
final ledgerIsRealProvider = Provider<bool>((ref) {
  return ref.watch(salesProvider).isNotEmpty;
});

class RevenuePoint {
  const RevenuePoint({
    required this.label,
    required this.value,
    required this.isCurrent,
    required this.isPeak,
    this.date,
    this.transactions = 0,
    this.previousValue = 0,
    this.previousLabel = '',
  });

  final String label;
  final int value;
  final bool isCurrent;
  final bool isPeak;

  /// The day (or week) this bar stands for, so tapping it can name the date.
  final DateTime? date;

  final int transactions;

  /// The same weekday one week earlier, or the same bucket in the previous
  /// window. Zero is a real answer: the shop sold nothing that day.
  final int previousValue;

  /// e.g. "8 Oct", so the comparison can be read without opening a calendar.
  final String previousLabel;

  /// Percent change against the equivalent earlier period. Null when there was
  /// no earlier figure to compare with, which is different from "no change".
  int? get deltaPercent {
    if (previousValue <= 0) return null;
    return (((value - previousValue) / previousValue) * 100).round();
  }
}

class RevenueSeries {
  const RevenueSeries({
    required this.points,
    required this.total,
    required this.previousTotal,
    required this.range,
  });

  final List<RevenuePoint> points;
  final int total;
  final int previousTotal;
  final RevenueRange range;

  /// Percent change against the preceding window of the same length.
  int get changePercent {
    if (previousTotal <= 0) return 0;
    return (((total - previousTotal) / previousTotal) * 100).round();
  }
}

/// Aggregates the ledger into the points the chart and the headline use.
///
/// The axis is built from the calendar, not from the rows. It used to iterate
/// the days that happened to have sales, so a week with trade on four days drew
/// four bars - Saturday, Tuesday, Wednesday, Friday, evenly spaced - and a quiet
/// day vanished instead of reading as a closed day. Worse, the window was
/// anchored on the newest sale rather than today, so a shop that had not sold
/// anything yet showed last week's chart under this week's heading.
final revenueSeriesProvider =
    Provider.family<RevenueSeries, RevenueRange>((ref, range) {
  final ledger = ref.watch(salesLedgerProvider);
  if (ledger.isEmpty) {
    return RevenueSeries(
      points: const [],
      total: 0,
      previousTotal: 0,
      range: range,
    );
  }

  final today = eatTodayDate;
  final byDate = {for (final d in ledger) d.date: d};
  int amountOn(DateTime d) => byDate[d]?.amount ?? 0;
  int txOn(DateTime d) => byDate[d]?.transactions ?? 0;

  const shortDays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  const monthNames = [
    '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  String shortDate(DateTime d) => '${d.day} ${monthNames[d.month]}';

  final points = <RevenuePoint>[];
  var total = 0;
  var previousTotal = 0;

  if (range == RevenueRange.week) {
    for (var back = range.days - 1; back >= 0; back--) {
      final date = today.subtract(Duration(days: back));
      final prevDate = date.subtract(const Duration(days: 7));
      final value = amountOn(date);
      final prevValue = amountOn(prevDate);
      total += value;
      previousTotal += prevValue;
      points.add(
        RevenuePoint(
          label: shortDays[date.weekday - 1],
          value: value,
          isCurrent: back == 0,
          isPeak: false,
          date: date,
          transactions: txOn(date),
          previousValue: prevValue,
          previousLabel: shortDate(prevDate),
        ),
      );
    }
  } else {
    // Four contiguous seven-day buckets. They cover the same days the week view
    // would have shown, added up, so switching the chip moves the bars instead
    // of relabelling the same ones.
    final buckets = (range.days / 7).ceil();
    for (var bucket = buckets - 1; bucket >= 0; bucket--) {
      var sum = 0;
      var tx = 0;
      var prevSum = 0;
      var start = today;
      for (var i = 6; i >= 0; i--) {
        final date = today.subtract(Duration(days: bucket * 7 + i));
        if (i == 6) start = date;
        sum += amountOn(date);
        tx += txOn(date);
        prevSum += amountOn(date.subtract(const Duration(days: 28)));
      }
      total += sum;
      previousTotal += prevSum;
      points.add(
        RevenuePoint(
          label: 'W${buckets - bucket}',
          value: sum,
          isCurrent: bucket == 0,
          isPeak: false,
          date: start,
          transactions: tx,
          previousValue: prevSum,
          previousLabel: shortDate(start.subtract(const Duration(days: 28))),
        ),
      );
    }
  }

  // The peak is flagged once. An all-zero window has no peak: marking the first
  // empty bar as the best day of the week would be a lie the colour states.
  final peakValue =
      points.map((p) => p.value).fold<int>(0, (a, b) => a > b ? a : b);
  final withPeak = [
    for (final p in points)
      RevenuePoint(
        label: p.label,
        value: p.value,
        isCurrent: p.isCurrent,
        isPeak: peakValue > 0 && p.value == peakValue,
        date: p.date,
        transactions: p.transactions,
        previousValue: p.previousValue,
        previousLabel: p.previousLabel,
      ),
  ];

  return RevenueSeries(
    points: withPeak,
    total: total,
    previousTotal: previousTotal,
    range: range,
  );
});

/// Compact TZS formatting used across the console, e.g. 126.8M.
String formatTzsCompact(int amount) {
  if (amount >= 1000000000) {
    return 'TZS ${(amount / 1000000000).toStringAsFixed(2)}B';
  }
  if (amount >= 1000000) {
    return 'TZS ${(amount / 1000000).toStringAsFixed(1)}M';
  }
  if (amount >= 1000) {
    return 'TZS ${(amount / 1000).toStringAsFixed(0)}K';
  }
  return 'TZS $amount';
}

/// Months belong to the localisation of money, not analytics, but this keeps the
/// month-name helper out of the widget tree.
String monthName(int month) => const [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ][month - 1];
