import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/sales_provider.dart';
import 'api_service.dart';

/// Where a delivery came from. The shop buys from suppliers, moves units between
/// its own branches, and takes handsets back from customers; those three are not
/// the same event and should not look identical in the ledger.
enum StockSource { supplier, transfer, customerReturn }

extension StockSourceLabel on StockSource {
  String get code => switch (this) {
        StockSource.supplier => 'supplier',
        StockSource.transfer => 'transfer',
        StockSource.customerReturn => 'return',
      };
}

/// One delivery, as the storekeeper entered it.
class StockReceipt {
  const StockReceipt({
    required this.branch,
    required this.source,
    required this.lines,
    required this.imeis,
    this.supplierName,
    this.invoiceNo,
    this.fromBranch,
    this.note,
  });

  final String branch;
  final StockSource source;
  final List<StockReceiptLine> lines;
  final List<String> imeis;
  final String? supplierName;
  final String? invoiceNo;
  final String? fromBranch;
  final String? note;

  int get units => lines.fold(0, (sum, l) => sum + l.qty);

  int get value => lines.fold(0, (sum, l) => sum + (l.qty * l.unitCost));

  /// A supplier delivery needs a name; a transfer needs the branch it left.
  String? validate() {
    if (lines.isEmpty) return 'lines';
    if (lines.any((l) => l.qty <= 0)) return 'quantity';
    switch (source) {
      case StockSource.supplier:
        if ((supplierName ?? '').trim().isEmpty) return 'supplier';
      case StockSource.transfer:
        if ((fromBranch ?? '').trim().isEmpty) return 'fromBranch';
      case StockSource.customerReturn:
        break;
    }
    return null;
  }
}

class StockReceiptLine {
  const StockReceiptLine({
    required this.productId,
    required this.name,
    required this.sku,
    required this.qty,
    required this.unitCost,
    this.imageAsset,
    this.imageUrl,
  });

  final int productId;
  final String name;
  final String sku;
  final int qty;

  /// What the shop paid per unit. Defaults to the catalogue cost, so a delivery's
  /// value is the shop's own number rather than a guess.
  final int unitCost;

  final String? imageAsset;
  final String? imageUrl;
}

/// What actually happened when the storekeeper confirmed.
class ReceiveResult {
  const ReceiveResult({
    required this.updated,
    required this.failed,
    required this.persisted,
    this.error,
  });

  final List<String> updated;
  final List<String> failed;

  /// False when the build has no database: the stock moved in this session only.
  final bool persisted;

  final String? error;

  bool get ok => failed.isEmpty && updated.isNotEmpty;
}

class StockReceiptService {
  StockReceiptService(this._api);

  final ApiService _api;

  Future<ReceiveResult> receive(StockReceipt receipt) async {
    final updated = <String>[];
    final failed = <String>[];
    String? error;

    for (final line in receipt.lines) {
      try {
        final ok = await _api.addStock(
          productId: line.productId,
          quantity: line.qty,
        );
        if (ok) {
          updated.add(line.name);
        } else {
          failed.add(line.name);
        }
      } catch (e) {
        failed.add(line.name);
        error ??= e.toString();
      }
    }

    return ReceiveResult(
      updated: updated,
      failed: failed,
      persisted: _api.isConfigured,
      error: error ?? ApiService.lastBackendError,
    );
  }
}

final stockReceiptServiceProvider = Provider<StockReceiptService>((ref) {
  return StockReceiptService(ref.watch(apiServiceProvider));
});

/// Today's receiving value, for the storekeeper card.
final receivingTodayProvider = Provider<int>((ref) => 0);

/// Stable key for the delivery: branch + date + invoice, so the same supplier
/// invoice cannot be received twice by accident.
String receiptKey(StockReceipt r, DateTime now) {
  final d = eatDateOf(now);
  final stamp = '${d.year}${d.month.toString().padLeft(2, '0')}'
      '${d.day.toString().padLeft(2, '0')}';
  final ref = (r.invoiceNo ?? '').trim().replaceAll(RegExp(r'\s+'), '');
  return '${r.branch}|$stamp|${r.source.code}|$ref';
}
