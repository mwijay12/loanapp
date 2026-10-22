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

  /// Days shown on the axis.
  int get days => this == RevenueRange.week ? 7 : 30;
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

  final today = ledger.last.date;
  final start = today.subtract(Duration(days: range.days - 1));
  final window = ledger.where((d) => !d.date.isBefore(start)).toList();
  final prevStart = start.subtract(Duration(days: range.days));
  final previous =
      ledger.where((d) => !d.date.isBefore(prevStart) && d.date.isBefore(start));

  final total = window.fold<int>(0, (s, d) => s + d.amount);
  final previousTotal = previous.fold<int>(0, (s, d) => s + d.amount);
  final peak = window.isEmpty
      ? 0
      : window.map((d) => d.amount).reduce((a, b) => a > b ? a : b);

  const shortDays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  const monthNames = [
    '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  String shortDate(DateTime d) => '${d.day} ${monthNames[d.month]}';

  // Previous figures are looked up by date, because "the same weekday last week"
  // is a date, not a bar position.
  final byDate = {for (final d in ledger) d.date: d};

  final points = <RevenuePoint>[];
  if (range == RevenueRange.week) {
    for (final d in window) {
      final prevDate = d.date.subtract(const Duration(days: 7));
      final prev = byDate[prevDate];
      points.add(
        RevenuePoint(
          label: shortDays[d.date.weekday - 1],
          value: d.amount,
          isCurrent: d.date == today,
          isPeak: d.amount == peak,
          date: d.date,
          transactions: d.transactions,
          previousValue: prev?.amount ?? 0,
          previousLabel: shortDate(prevDate),
        ),
      );
    }
  } else {
    // Month view groups the 30 days into four weekly buckets, which keeps the
    // axis readable at phone width instead of cramming thirty labels.
    final prevWindow =
        ledger.where((d) => !d.date.isBefore(prevStart) && d.date.isBefore(start)).toList();
    for (var i = 0; i < 4; i++) {
      final bucketStart = i * 7;
      final bucket = window.skip(bucketStart).take(7).toList();
      if (bucket.isEmpty) break;
      final sum = bucket.fold<int>(0, (s, d) => s + d.amount);
      final tx = bucket.fold<int>(0, (s, d) => s + d.transactions);
      final prevBucket = prevWindow.skip(bucketStart).take(7).toList();
      final prevSum = prevBucket.fold<int>(0, (s, d) => s + d.amount);
      points.add(
        RevenuePoint(
          label: 'W${i + 1}',
          value: sum,
          isCurrent: i == (window.length / 7).ceil() - 1,
          isPeak: false,
          date: bucket.first.date,
          transactions: tx,
          previousValue: prevSum,
          previousLabel: prevBucket.isEmpty
              ? ''
              : 'W${i + 1} prior',
        ),
      );
    }
  }

  final peakValue = points.isEmpty
      ? 0
      : points.map((p) => p.value).reduce((a, b) => a > b ? a : b);
  final withPeak = points
      .map((p) => RevenuePoint(
            label: p.label,
            value: p.value,
            isCurrent: p.isCurrent,
            isPeak: p.value == peakValue,
            date: p.date,
            transactions: p.transactions,
            previousValue: p.previousValue,
            previousLabel: p.previousLabel,
          ))
      .toList();

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
