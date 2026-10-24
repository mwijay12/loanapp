import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One completed sale, as stored in `public.sales`.
class SaleRecord {
  const SaleRecord({
    required this.receiptNo,
    required this.total,
    required this.paid,
    required this.kind,
    required this.soldAt,
    this.branchId,
    this.imei,
    this.customerName,
    this.productId,
  });

  final String receiptNo;
  final int total;
  final int paid;
  final String kind;
  final DateTime soldAt;
  final String? branchId;
  final String? imei;
  final String? customerName;
  final int? productId;

  bool get isCash => kind == 'cash';
  int get balance => (total - paid).clamp(0, 1 << 62);

  factory SaleRecord.fromRow(Map<String, dynamic> row) {
    return SaleRecord(
      receiptNo: (row['receipt_no'] ?? '').toString(),
      total: _money(row['total']),
      paid: _money(row['paid']),
      kind: (row['kind'] ?? 'cash').toString(),
      soldAt: DateTime.tryParse((row['sold_at'] ?? '').toString())?.toLocal() ??
          DateTime.now(),
      branchId: row['branch_id']?.toString(),
      imei: row['imei']?.toString(),
      customerName: row['customer_name']?.toString(),
      productId: row['product_id'] is int ? row['product_id'] as int : null,
    );
  }

  static int _money(dynamic v) {
    if (v is num) return v.round();
    if (v is String) {
      final cleaned = v.replaceAll(RegExp(r'[^0-9.\-]'), '');
      return double.tryParse(cleaned)?.round() ?? 0;
    }
    return 0;
  }
}

class SalesNotifier extends StateNotifier<List<SaleRecord>> {
  SalesNotifier([List<SaleRecord> seed = const []]) : super(List.from(seed));

  void replaceAll(List<SaleRecord> rows) {
    state = List<SaleRecord>.from(rows);
  }

  /// Adds a sale the counter just wrote, so the totals move immediately instead
  /// of waiting for the next reload.
  void add(SaleRecord sale) {
    state = [sale, ...state];
  }

  void clear() => state = <SaleRecord>[];
}

final salesProvider =
    StateNotifierProvider<SalesNotifier, List<SaleRecord>>((ref) {
  return SalesNotifier();
});

/// The shop's day, not the device's.
///
/// A browser in Shanghai and a till in Dar es Salaam are on different dates for
/// five hours every night. Counting "today" with the device clock made the card
/// read zero while the shop had taken money, so day boundaries are computed in
/// East Africa Time here too.
DateTime eatClock(DateTime t) => t.toUtc().add(const Duration(hours: 3));

/// Date-only in the shop's timezone. Comparing date-only values avoids the trap
/// that bit this file: shifting an already-shifted instant moved it to the next
/// day and every sale fell outside "today".
DateTime eatDateOf(DateTime t) {
  final e = eatClock(t);
  return DateTime(e.year, e.month, e.day);
}

DateTime get eatTodayDate => eatDateOf(DateTime.now());

bool isEatToday(DateTime t) => eatDateOf(t) == eatTodayDate;

/// Today's revenue (actual cash collected).
final salesTodayTotalProvider = Provider<int>((ref) {
  return ref
      .watch(salesProvider)
      .where((s) => isEatToday(s.soldAt))
      .fold<int>(0, (sum, s) => sum + s.paid);
});

/// Today's gross sales (total value of items sold, including pending loan balances).
final salesTodayValueProvider = Provider<int>((ref) {
  return ref
      .watch(salesProvider)
      .where((s) => isEatToday(s.soldAt))
      .fold<int>(0, (sum, s) => sum + s.total);
});

final salesTodayCountProvider = Provider<int>((ref) {
  return ref.watch(salesProvider).where((s) => isEatToday(s.soldAt)).length;
});

/// Last seven days, oldest first, for the home sparkline.
final salesLastSevenDaysProvider = Provider<List<int>>((ref) {
  final sales = ref.watch(salesProvider);
  final today = eatTodayDate;
  return List<int>.generate(7, (i) {
    final day = today.subtract(Duration(days: 6 - i));
    return sales
        .where((s) => eatDateOf(s.soldAt) == day)
        .fold<int>(0, (sum, s) => sum + s.paid);
  });
});
