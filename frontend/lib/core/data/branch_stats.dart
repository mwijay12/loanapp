import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'branch_provider.dart';
import 'inventory_provider.dart';
import 'sales_provider.dart';

/// What one branch is actually holding and actually took.
///
/// Built from the rows themselves rather than from the `sales` text column on
/// the branch record. That column is a display string written by the seed
/// ("TZS 2.34M"), so every screen that read it was showing a number nobody had
/// measured against a single sale.
class BranchStats {
  const BranchStats({
    required this.units,
    required this.models,
    required this.lowStock,
    required this.salesCount,
    required this.revenue,
    required this.revenueToday,
    required this.costValue,
    required this.retailValue,
  });

  /// Handsets and accessories on the shelf, counted as physical units.
  final int units;

  /// Distinct catalogue rows, i.e. how many products the branch carries.
  final int models;

  /// Rows at or below their buffer level.
  final int lowStock;

  final int salesCount;

  /// Everything this branch has ever rung up.
  final int revenue;

  /// Today only, on the shop's clock.
  final int revenueToday;

  /// What the stock on the shelf cost, where a cost price is recorded.
  final int costValue;

  /// What the same stock would bring in at the marked price.
  final int retailValue;

  bool get isEmpty => units == 0 && salesCount == 0;
}

/// Stats for [branchId]. Empty and honest for a branch with nothing in it yet.
final branchStatsProvider =
    Provider.family<BranchStats, String>((ref, branchId) {
  final products =
      ref.watch(inventoryProvider).where((p) => p.branchId == branchId);
  final sales =
      ref.watch(salesProvider).where((s) => s.branchId == branchId).toList();

  var units = 0;
  var models = 0;
  var lowStock = 0;
  var costValue = 0;
  var retailValue = 0;
  for (final p in products) {
    units += p.stock;
    models++;
    if (p.status == 'low' || p.status == 'out' || p.stock <= p.min) lowStock++;
    final cost = p.costPrice;
    retailValue += p.price * p.stock;
    if (cost != null) costValue += cost * p.stock;
  }

  var revenue = 0;
  var revenueToday = 0;
  for (final s in sales) {
    revenue += s.total;
    if (isEatToday(s.soldAt)) revenueToday += s.total;
  }

  return BranchStats(
    units: units,
    models: models,
    lowStock: lowStock,
    salesCount: sales.length,
    revenue: revenue,
    revenueToday: revenueToday,
    costValue: costValue,
    retailValue: retailValue,
  );
});

/// The branches with something in them, most valuable first. Used by the
/// console's branch list so a presenter can see where the stock actually is.
final branchRankingProvider = Provider<List<({String id, BranchStats stats})>>(
    (ref) {
  final branches = ref.watch(branchesProvider);
  final rows = [
    for (final b in branches)
      if (b.active) (id: b.id, stats: ref.watch(branchStatsProvider(b.id))),
  ];
  rows.sort((a, b) => b.stats.units.compareTo(a.stats.units));
  return rows;
});
