import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  String get label => this == RevenueRange.week ? 'Wiki' : 'Mwezi';

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

/// Ledger for the signed-in build. Demo mode seeds a fixed history.
final salesLedgerProvider = Provider<List<DailySale>>((ref) {
  return demoLedger(DateTime.now());
});

class RevenuePoint {
  const RevenuePoint({
    required this.label,
    required this.value,
    required this.isCurrent,
    required this.isPeak,
  });

  final String label;
  final int value;
  final bool isCurrent;
  final bool isPeak;
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

  final points = <RevenuePoint>[];
  if (range == RevenueRange.week) {
    for (final d in window) {
      points.add(
        RevenuePoint(
          label: shortDays[d.date.weekday - 1],
          value: d.amount,
          isCurrent: d.date.day == today.day && d.date.month == today.month,
          isPeak: d.amount == peak,
        ),
      );
    }
  } else {
    // Month view groups the 30 days into four weekly buckets, which keeps the
    // axis readable at phone width instead of cramming thirty labels.
    for (var i = 0; i < 4; i++) {
      final bucketStart = i * 7;
      final bucket = window.skip(bucketStart).take(7).toList();
      if (bucket.isEmpty) break;
      final sum = bucket.fold<int>(0, (s, d) => s + d.amount);
      final label = 'W${i + 1}';
      points.add(
        RevenuePoint(
          label: label,
          value: sum,
          isCurrent: i == 3,
          isPeak: false,
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
