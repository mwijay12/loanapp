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
    this.paymentChannel,
  });

  final String receiptNo;
  final int total;
  final int paid;
  final String kind;
  final DateTime soldAt;
  final String? branchId;
  final String? imei;
  final String? customerName;

  /// How the money arrived: cash, mpesa, airtel, tigopesa, or card ••••1234.
  /// Kept because the reports have to answer "how much of today was cash".
  final String? paymentChannel;
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
      paymentChannel: row['payment_channel']?.toString(),
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

  /// Applies one `sales` row delivered by the realtime stream.
  ///
  /// Keyed on `receipt_no`, not `id`: [SaleRecord] is the ledger the screens read
  /// and it carries no uuid, while `sales.receipt_no` is `unique not null` in
  /// 2026_10_21_02c_sales.sql. The two together mean a receipt identifies exactly
  /// one row.
  ///
  /// The dedupe is the point. The counter writes its own sale and prepends it with
  /// [add]; a moment later the socket delivers the same insert. Without a key
  /// check here the shop would count that sale twice, and the second copy is the
  /// one that looks live. Rows stay newest-first, which is the order
  /// `SupabaseSource.fetchSales` returns and what the ledger screens assume.
  void mergeRow(SaleRecord sale) {
    final exists = state.any((s) => s.receiptNo == sale.receiptNo);
    if (exists) {
      state = [
        for (final s in state)
          if (s.receiptNo == sale.receiptNo) sale else s,
      ];
      return;
    }
    final merged = <SaleRecord>[sale, ...state]
      ..sort((a, b) => b.soldAt.compareTo(a.soldAt));
    state = merged;
  }

  /// A sale deleted or voided at the database. Leaving it on screen keeps the
  /// day's revenue wrong on a header that claims to be live.
  void removeRow(String receiptNo) {
    state = [
      for (final s in state)
        if (s.receiptNo != receiptNo) s,
    ];
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
