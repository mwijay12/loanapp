/// What the storekeeper dashboard is allowed to claim.
///
/// These are read shapes, not decorations: every number the dashboard draws comes
/// from `stock_receipts` and `product_units`, and an empty table produces zero
/// rather than a number borrowed from a design mock.
library;

/// Today's arrivals for one branch.
class StoreDayCounts {
  const StoreDayCounts({
    required this.serialsAdded,
    required this.deliveries,
    required this.purchaseOrders,
    required this.available,
  });

  /// Serials registered at this branch since the start of the shop day.
  final int serialsAdded;

  /// Deliveries of any kind (supplier, transfer, return).
  final int deliveries;

  /// Supplier deliveries only — what a storekeeper calls a PO.
  final int purchaseOrders;

  /// False when the build has no database, so the UI can say "not connected"
  /// instead of showing a confident zero.
  final bool available;

  const StoreDayCounts.unavailable()
      : serialsAdded = 0,
        deliveries = 0,
        purchaseOrders = 0,
        available = false;
}

/// One line of a delivery: how many of which model.
class StockMovementLine {
  const StockMovementLine({
    required this.name,
    required this.qty,
    this.sku,
  });

  final String name;
  final int qty;
  final String? sku;
}

/// One delivery, as recorded in `stock_receipts`.
class StockMovement {
  const StockMovement({
    required this.id,
    required this.branch,
    required this.source,
    required this.units,
    required this.receivedAt,
    this.supplierName,
    this.fromBranch,
    this.invoiceNo,
    this.lines = const [],
  });

  final int id;
  final String branch;

  /// `supplier`, `transfer` or `return`.
  final String source;
  final int units;
  final DateTime? receivedAt;
  final String? supplierName;
  final String? fromBranch;
  final String? invoiceNo;
  final List<StockMovementLine> lines;

  /// "Samsung A15 · 25 units", or the invoice/supplier when no line was keyed.
  String get summary {
    if (lines.isEmpty) {
      final who =
          supplierName?.trim().isNotEmpty == true ? supplierName! : null;
      return who ?? '$units';
    }
    final first = lines.first;
    final more = lines.length > 1 ? ' +${lines.length - 1}' : '';
    return '${first.name}$more · ${first.qty}';
  }
}
