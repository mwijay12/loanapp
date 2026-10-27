import 'package:flutter_test/flutter_test.dart';

import 'package:loan_inventory_app/core/data/branch_provider.dart';
import 'package:loan_inventory_app/core/data/inventory_provider.dart';
import 'package:loan_inventory_app/core/data/sales_provider.dart';
import 'package:loan_inventory_app/core/services/live_data.dart';
import 'package:loan_inventory_app/core/services/realtime_bridge.dart';

/// Every published table in [kLiveTables] has exactly one of three outcomes, and
/// the difference matters on a counter: `merged` means the number on screen moved,
/// `refetched` means a full read was issued, `unknownTable` means the row could not
/// be placed at all. A row that quietly does nothing is the failure the shop
/// reported — a figure that looked live and was yesterday's.
class Harness {
  final InventoryNotifier inventory = InventoryNotifier();
  final LoansNotifier loans = LoansNotifier();
  final StaffNotifier staff = StaffNotifier();
  final BranchesNotifier branches = BranchesNotifier();
  final SalesNotifier sales = SalesNotifier();

  int salesRefetches = 0;
  int activityRefetches = 0;
  int unknownCalls = 0;

  Future<LiveApplyOutcome> apply(LiveChange change) {
    return applyLiveRow(
      change,
      inventory: inventory,
      loans: loans,
      staff: staff,
      branches: branches,
      sales: sales,
      refetchSales: () async {
        salesRefetches++;
      },
      refetchActivities: () async {
        activityRefetches++;
      },
      onUnknownTable: () => unknownCalls++,
    );
  }
}

LiveChange inserted(String table, Map<String, dynamic> row) => LiveChange(
      table: table,
      kind: LiveEventKind.inserted,
      record: row,
    );

LiveChange updated(String table, Map<String, dynamic> row) => LiveChange(
      table: table,
      kind: LiveEventKind.updated,
      record: row,
    );

/// A delete under `REPLICA IDENTITY DEFAULT` carries the primary key and nothing
/// else, which is exactly what the real socket sends.
LiveChange deleted(String table, Object? id) => LiveChange(
      table: table,
      kind: LiveEventKind.deleted,
      record: const {},
      oldRecord: <String, dynamic>{if (id != null) 'id': id},
    );

Map<String, dynamic> productRow({
  int id = 7,
  String name = 'Tecno Spark 20',
  int stock = 4,
  int price = 385000,
}) =>
    <String, dynamic>{
      'id': id,
      'name': name,
      'variant': '128GB',
      'sku': 'SKU-$id',
      'price': price,
      'stock': stock,
      'min_stock': 2,
      'category': 'phone',
      'status': 'in',
      'sold_today': 0,
      'on_loan': 0,
    };

Map<String, dynamic> loanRow({
  String id = 'L-1',
  String borrower = 'Amina Juma',
  String status = 'current',
}) =>
    <String, dynamic>{
      'id': id,
      'borrower_name': borrower,
      'item_name': 'Tecno Spark 20',
      'amount': 400000,
      'paid_percent': 20,
      'due_info': 'Ijumaa 14 Okt',
      'status': status,
    };

Map<String, dynamic> staffRow({
  String id = 'S-9',
  String name = 'Neema Joseph',
  String status = 'Active',
}) =>
    <String, dynamic>{
      'id': id,
      'name': name,
      'role': 'Storekeeper',
      'email': 'neema@example.co.tz',
      'phone': '0754137251',
      'branch': 'Mbezi Branch',
      'staff_code': 'ST-09',
      'status': status,
    };

Map<String, dynamic> branchRow({
  String id = 'BR-09',
  String name = 'Tabora Branch',
}) =>
    <String, dynamic>{
      'id': id,
      'name': name,
      'city': 'Tabora',
      'sales': 0,
      'sales_today': 1200000,
      'low_stock': 4,
      'status': 'green',
    };

Map<String, dynamic> saleRow({
  String receipt = 'RC-0001',
  int total = 385000,
  DateTime? at,
}) =>
    <String, dynamic>{
      'id': 'uuid-$receipt',
      'receipt_no': receipt,
      'total': total,
      'paid': total,
      'kind': 'cash',
      'sold_at': (at ?? DateTime(2026, 10, 27, 10, 30)).toIso8601String(),
    };

void main() {
  group('products', () {
    test('an insert becomes one row the screens can read', () async {
      final h = Harness();
      final outcome = await h.apply(inserted('products', productRow()));

      expect(outcome, LiveApplyOutcome.merged);
      expect(h.inventory.state, hasLength(1));
      expect(h.inventory.state.single.name, 'Tecno Spark 20');
      expect(h.inventory.state.single.stock, 4);
      expect(h.inventory.state.single.price, 385000);
    });

    test('a stock update patches the same row instead of adding a second one',
        () async {
      final h = Harness();
      await h.apply(inserted('products', productRow(stock: 4)));
      await h.apply(updated('products', productRow(stock: 1)));

      expect(h.inventory.state, hasLength(1),
          reason: 'two copies of one handset is a phantom ten units');
      expect(h.inventory.state.single.stock, 1);
    });

    test('a redelivered event changes nothing', () async {
      final h = Harness();
      await h.apply(inserted('products', productRow()));
      await h.apply(inserted('products', productRow()));

      expect(h.inventory.state, hasLength(1));
    });

    test('a delete removes by integer id', () async {
      final h = Harness();
      await h.apply(inserted('products', productRow(id: 7)));
      final outcome = await h.apply(deleted('products', 7));

      expect(outcome, LiveApplyOutcome.removed);
      expect(h.inventory.state, isEmpty);
    });

    test('a delete whose id is not an integer asks for a reload', () async {
      final h = Harness();
      await h.apply(inserted('products', productRow()));
      final outcome = await h.apply(deleted('products', 'not-a-number'));

      expect(outcome, LiveApplyOutcome.unknownTable);
      expect(h.unknownCalls, 1);
      expect(h.inventory.state, hasLength(1),
          reason: 'guessing here would drop the wrong product');
    });

    test('a row without a usable key never reaches the store', () async {
      final h = Harness();
      final outcome = await h.apply(deleted('products', null));

      expect(outcome, LiveApplyOutcome.unknownTable);
      expect(h.unknownCalls, 1);
    });

    test('a malformed product row throws rather than half-applying', () async {
      final h = Harness();
      // `parseProducts` reads `id` as a num; a payload without one is a transport
      // fault. It must surface so the bridge counts it as dropped and refetches.
      await expectLater(
        h.apply(inserted('products', <String, dynamic>{'name': 'No id'})),
        throwsA(anything),
      );
      expect(h.inventory.state, isEmpty);
    });
  });

  group('loans, staff and branches', () {
    test('a new loan appears', () async {
      final h = Harness();
      expect(await h.apply(inserted('loans', loanRow())), LiveApplyOutcome.merged);
      expect(h.loans.state.single.name, 'Amina Juma');
    });

    test('a loan marked paid off updates in place', () async {
      final h = Harness();
      await h.apply(inserted('loans', loanRow(status: 'current')));
      await h.apply(updated('loans', loanRow(status: 'cleared')));

      expect(h.loans.state, hasLength(1));
      expect(h.loans.state.single.status, 'cleared');
    });

    test('a deleted loan leaves the list', () async {
      final h = Harness();
      await h.apply(inserted('loans', loanRow(id: 'L-5')));
      expect(await h.apply(deleted('loans', 'L-5')), LiveApplyOutcome.removed);
      expect(h.loans.state, isEmpty);
    });

    test('a staff row keeps the role the database sent', () async {
      final h = Harness();
      await h.apply(inserted('staff', staffRow()));

      expect(h.staff.state.single.role, 'Storekeeper');
      expect(h.staff.state.single.status, 'Active');
    });

    test('a suspension applied at head office lands on the directory', () async {
      final h = Harness();
      await h.apply(inserted('staff', staffRow()));
      await h.apply(updated('staff', staffRow(status: 'Suspended')));

      expect(h.staff.state, hasLength(1));
      expect(h.staff.state.single.status, 'Suspended');
    });

    test('a branch opened today is appended, not replacing the seeded four',
        () async {
      final h = Harness();
      final before = h.branches.state.length;
      await h.apply(inserted('branches', branchRow()));

      expect(h.branches.state, hasLength(before + 1));
      expect(h.branches.state.last.name, 'Tabora Branch');
    });

    test('a branch renamed is replaced in place', () async {
      final h = Harness();
      final before = h.branches.state.length;
      await h.apply(updated('branches', branchRow(id: 'BR-01', name: 'Mbezi City')));

      expect(h.branches.state, hasLength(before));
      expect(
        h.branches.state.firstWhere((b) => b.id == 'BR-01').name,
        'Mbezi City',
      );
    });
  });

  group('sales', () {
    test('a sale from another branch lands newest-first', () async {
      final h = Harness();
      await h.apply(inserted('sales', saleRow(receipt: 'RC-1', at: DateTime(2026, 10, 27, 9))));
      await h.apply(inserted('sales', saleRow(receipt: 'RC-2', at: DateTime(2026, 10, 27, 11))));

      expect(h.sales.state.map((s) => s.receiptNo), ['RC-2', 'RC-1']);
    });

    test('the counter\'s own sale is not counted twice when the socket echoes it',
        () async {
      final h = Harness();
      // The POS prepends the sale it just wrote, then Realtime delivers the same
      // insert a moment later. Without the receipt_no key the day's revenue would
      // double, which is the number the owner reads.
      h.sales.add(SaleRecord(
        receiptNo: 'RC-7',
        total: 500000,
        paid: 500000,
        kind: 'cash',
        soldAt: DateTime(2026, 10, 27, 11),
      ));

      await h.apply(inserted('sales', saleRow(receipt: 'RC-7', total: 500000)));

      expect(h.sales.state, hasLength(1));
      expect(h.sales.state.fold<int>(0, (a, s) => a + s.paid), 500000);
    });

    test('a payment recorded against a receipt updates that receipt', () async {
      final h = Harness();
      await h.apply(inserted('sales', saleRow(receipt: 'RC-8', total: 600000)));
      await h.apply(updated('sales', <String, dynamic>{
        ...saleRow(receipt: 'RC-8', total: 600000),
        'paid': 250000,
      }));

      expect(h.sales.state, hasLength(1));
      expect(h.sales.state.single.paid, 250000);
      expect(h.sales.state.single.balance, 350000);
    });

    test('a voided sale refetches instead of being dropped by uuid', () async {
      final h = Harness();
      await h.apply(inserted('sales', saleRow(receipt: 'RC-9')));
      final outcome = await h.apply(deleted('sales', 'uuid-RC-9'));

      // `sales.id` is a uuid and SaleRecord is keyed on receipt_no, so the key in
      // oldRecord matches nothing. Refetching is the honest answer.
      expect(outcome, LiveApplyOutcome.refetched);
      expect(h.salesRefetches, 1);
      expect(h.sales.state, hasLength(1),
          reason: 'removing by a key we do not hold would remove nothing anyway');
    });
  });

  group('activities', () {
    test('an activity refetches the feed', () async {
      final h = Harness();
      final outcome = await h.apply(inserted('activities', <String, dynamic>{
        'id': 1,
        'type': 'sale',
        'title': 'Sale RC-1',
        'created_at': DateTime(2026, 10, 27, 10).toIso8601String(),
      }));

      expect(outcome, LiveApplyOutcome.refetched);
      expect(h.activityRefetches, 1);
    });

    test('a deleted activity refetches too', () async {
      final h = Harness();
      expect(await h.apply(deleted('activities', 1)), LiveApplyOutcome.refetched);
      expect(h.activityRefetches, 1);
    });
  });

  group('tables the loader does not own', () {
    test('an unowned table asks for a reload and says so', () async {
      final h = Harness();
      final outcome = await h.apply(inserted('product_units', <String, dynamic>{
        'id': 3,
        'imei': '354958109871234',
        'branch': 'Mbezi Branch',
        'status': 'in_stock',
      }));

      expect(outcome, LiveApplyOutcome.unknownTable);
      expect(h.unknownCalls, 1,
          reason: 'the caller must only see unknownTable after a reload was asked for');
    });

    test('a petty_cash row is never placed, even though the table exists',
        () async {
      final h = Harness();
      expect(
        await h.apply(inserted('petty_cash', <String, dynamic>{'id': 1})),
        LiveApplyOutcome.unknownTable,
      );
      expect(h.unknownCalls, 1);
    });

    test('a keyed delete on an unowned table still asks for a reload', () async {
      final h = Harness();
      expect(await h.apply(deleted('stock_receipts', 12)),
          LiveApplyOutcome.unknownTable);
      expect(h.unknownCalls, 1);
    });
  });
}
