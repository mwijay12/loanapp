import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/sale_ledger.dart';

/// One sale the counter took while the network was down.
///
/// [clientRef] is minted on the till **before** the first attempt and reused on
/// every retry. The database has a unique index on it, so a resend after a
/// dropped connection cannot ring the same handset up twice: the second insert
/// is refused and treated as "already recorded".
@immutable
class QueuedSale {
  const QueuedSale({
    required this.clientRef,
    required this.receiptNo,
    required this.kind,
    required this.total,
    required this.paid,
    required this.balance,
    required this.paymentChannel,
    required this.customerName,
    required this.customerPhone,
    required this.phoneModel,
    required this.queuedAt,
    this.imei,
    this.branchId,
    this.productId,
  });

  final String clientRef;
  final String receiptNo;
  final String kind;
  final int total;
  final int paid;
  final int balance;
  final String paymentChannel;
  final String customerName;
  final String customerPhone;
  final String phoneModel;
  final DateTime queuedAt;
  final String? imei;
  final String? branchId;
  final int? productId;

  Map<String, dynamic> toJson() => {
        'clientRef': clientRef,
        'receiptNo': receiptNo,
        'kind': kind,
        'total': total,
        'paid': paid,
        'balance': balance,
        'paymentChannel': paymentChannel,
        'customerName': customerName,
        'customerPhone': customerPhone,
        'phoneModel': phoneModel,
        'queuedAt': queuedAt.toIso8601String(),
        'imei': imei,
        'branchId': branchId,
        'productId': productId,
      };

  static QueuedSale? fromJson(Map<String, dynamic> j) {
    final ref = j['clientRef'];
    final receipt = j['receiptNo'];
    if (ref is! String || receipt is! String) return null;
    return QueuedSale(
      clientRef: ref,
      receiptNo: receipt,
      kind: (j['kind'] ?? 'cash').toString(),
      total: (j['total'] as num?)?.toInt() ?? 0,
      paid: (j['paid'] as num?)?.toInt() ?? 0,
      balance: (j['balance'] as num?)?.toInt() ?? 0,
      paymentChannel: (j['paymentChannel'] ?? 'cash').toString(),
      customerName: (j['customerName'] ?? '').toString(),
      customerPhone: (j['customerPhone'] ?? '').toString(),
      phoneModel: (j['phoneModel'] ?? '').toString(),
      queuedAt: DateTime.tryParse((j['queuedAt'] ?? '').toString()) ?? DateTime.now(),
      imei: j['imei']?.toString(),
      branchId: j['branchId']?.toString(),
      productId: (j['productId'] as num?)?.toInt(),
    );
  }
}

/// Sales that could not be written yet, held on this device.
///
/// `shared_preferences` is the right size for this: a handful of rows, written
/// once, read on start-up. A queue that outgrows a drawer is a sign the shop has
/// been offline for days, and by then the cashier has more to worry about than
/// storage.
class OfflineSaleQueue {
  const OfflineSaleQueue();

  static const _key = 'lims.pending_sales.v1';

  Future<List<QueuedSale>> pending() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return <QueuedSale>[];
    try {
      final list = jsonDecode(raw);
      if (list is! List) return <QueuedSale>[];
      final out = <QueuedSale>[];
      for (final e in list) {
        if (e is! Map) continue;
        final parsed = QueuedSale.fromJson(Map<String, dynamic>.from(e));
        if (parsed != null) out.add(parsed);
      }
      return out;
    } catch (e) {
      debugPrint('LIMS: pending sales unreadable -> $e');
      return <QueuedSale>[];
    }
  }

  Future<int> count() async => (await pending()).length;

  Future<void> add(QueuedSale sale) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await pending();
    if (list.any((s) => s.clientRef == sale.clientRef)) return;
    list.add(sale);
    await prefs.setString(_key, jsonEncode([for (final s in list) s.toJson()]));
  }

  Future<void> remove(String clientRef) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await pending();
    list.removeWhere((s) => s.clientRef == clientRef);
    await prefs.setString(_key, jsonEncode([for (final s in list) s.toJson()]));
  }
}

/// How many sales are waiting, for the badge on the home screen.
class PendingSalesNotifier extends StateNotifier<int> {
  PendingSalesNotifier(this._queue) : super(0) {
    refresh();
  }

  final OfflineSaleQueue _queue;

  Future<void> refresh() async {
    final n = await _queue.count();
    if (mounted) state = n;
  }
}

final offlineSaleQueueProvider = Provider<OfflineSaleQueue>((ref) => const OfflineSaleQueue());

final pendingSalesProvider = StateNotifierProvider<PendingSalesNotifier, int>(
  (ref) => PendingSalesNotifier(ref.watch(offlineSaleQueueProvider)),
);

/// Sends everything that is waiting, oldest first.
///
/// Stops at the first write that comes back *unknown*: that one may already be
/// in the database, and carrying on would reorder the day's takings around a
/// row nobody has confirmed. A refusal (the server said no) is dropped, because
/// retrying a refusal forever would block the queue behind a sale that will
/// never be accepted.
class OfflineSyncResult {
  const OfflineSyncResult({required this.sent, required this.remaining});
  final int sent;
  final int remaining;
  bool get isClear => remaining == 0;
}

Future<OfflineSyncResult> syncPendingSales({
  required SaleLedger ledger,
  OfflineSaleQueue queue = const OfflineSaleQueue(),
}) async {
  final pending = await queue.pending();
  var sent = 0;
  for (final s in pending) {
    final write = await ledger.write(
      receiptNo: s.receiptNo,
      kind: s.kind,
      total: s.total,
      paid: s.paid,
      balance: s.balance,
      paymentChannel: s.paymentChannel,
      customerName: s.customerName,
      customerPhone: s.customerPhone,
      phoneModel: s.phoneModel,
      imei: s.imei,
      branchId: s.branchId,
      productId: s.productId,
      clientRef: s.clientRef,
    );
    if (write.status == SalePersistence.unconfirmed) break;
    await queue.remove(s.clientRef);
    if (write.isConfirmed) sent++;
  }
  return OfflineSyncResult(sent: sent, remaining: await queue.count());
}
