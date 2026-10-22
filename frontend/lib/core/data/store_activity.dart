import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'inventory_provider.dart';
import 'sales_provider.dart';
import 'store_movement.dart';
import '../services/api_service.dart';

/// Start of the current shop day in East Africa Time, as an absolute instant.
///
/// `received_at` is a timestamp, so "today" has to be a real boundary and not
/// `now - 24h`: a delivery at 00:30 belongs to today, not to yesterday evening.
DateTime startOfShopDay(DateTime now) {
  final eat = eatClock(now);
  final midnightEat = DateTime.utc(eat.year, eat.month, eat.day);
  return midnightEat.subtract(const Duration(hours: 3));
}

/// Today's arrivals for the branch this terminal is signed in at.
final storeDayCountsProvider =
    FutureProvider.autoDispose<StoreDayCounts>((ref) async {
  final branch = ref.watch(activeBranchProvider);
  final api = ref.watch(apiServiceProvider);
  return api.getStoreDayCounts(
    branch: branch,
    since: startOfShopDay(DateTime.now()),
  );
});

/// The last few deliveries at this branch. Errors surface to the widget so the
/// card can say it could not load, rather than rendering as an empty day.
final recentStoreMovementsProvider =
    FutureProvider.autoDispose<List<StockMovement>>((ref) async {
  final branch = ref.watch(activeBranchProvider);
  final api = ref.watch(apiServiceProvider);
  return api.getRecentStoreMovements(branch: branch);
});
