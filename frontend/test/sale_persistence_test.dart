import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:loan_inventory_app/core/data/inventory_provider.dart';
import 'package:loan_inventory_app/core/data/lims_repository.dart';
import 'package:loan_inventory_app/core/data/mock_lims_data.dart';
import 'package:loan_inventory_app/core/data/sale_ledger.dart';
import 'package:loan_inventory_app/core/data/sales_provider.dart';
import 'package:loan_inventory_app/core/services/pdf_report_service.dart';

/// A sale is only a sale once the ledger says so.
///
/// These tests replace the Supabase write with a fake that can answer
/// "confirmed", "refused", "no connection" or "no answer at all", so the three
/// outcomes that used to collapse into one `false` stay distinct. No demo user,
/// no demo data and no network is involved.

class _FakeLedger implements SaleLedger {
  _FakeLedger(this.response);

  /// What the write answers when no [gate] is installed.
  SaleLedgerWrite response;

  /// When set, the write waits on it, which lets a test observe the moment
  /// between "sent" and "answered".
  Completer<SaleLedgerWrite>? gate;

  int writes = 0;
  final List<String> receipts = [];
  final List<String> kinds = [];

  /// Recorded so a test can see whether an approval token reached the ledger. The
  /// token's own behaviour is proven against the live database
  /// (`tools/verify_manager_override.py`), not here: it is issued by Postgres.
  final List<String?> overrideTokens = [];

  @override
  Future<SaleLedgerWrite> write({
    required String receiptNo,
    required String kind,
    required int total,
    required int paid,
    required int balance,
    required String paymentChannel,
    required String customerName,
    required String customerPhone,
    required String phoneModel,
    String? imei,
    String? branchId,
    int? productId,
    String? overrideToken,
  }) {
    writes++;
    overrideTokens.add(overrideToken);
    receipts.add(receiptNo);
    kinds.add(kind);
    final pending = gate;
    if (pending != null) return pending.future;
    return Future.value(response);
  }
}

ProductItem _phone({int id = 1, int stock = 3, int price = 1000000}) =>
    ProductItem(
      id: id,
      name: 'Test Phone',
      brand: 'Test',
      variant: '128GB',
      sku: 'TEST-128',
      price: price,
      stock: stock,
      min: 1,
      cat: 'phones',
      grad: const [Color(0xFF1B6EF3), Color(0xFF0A49B8)],
      status: 'in',
      soldToday: 0,
      onLoan: 0,
    );

/// The repository takes a [WidgetRef], so the tests mount the smallest widget
/// that can hand one over and then drive the repository directly.
Future<WidgetRef> _mount(
    WidgetTester tester, ProviderContainer container) async {
  WidgetRef? captured;
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Consumer(
          builder: (context, ref, _) {
            captured = ref;
            return const SizedBox.shrink();
          },
        ),
      ),
    ),
  );
  return captured!;
}

/// A container with one handset on the shelf and nothing else in the book.
ProviderContainer _container(_FakeLedger ledger) {
  final container = ProviderContainer(
    overrides: [
      limsRepositoryProvider
          .overrideWithValue(MockLimsRepository(ledger: ledger)),
    ],
  );
  container.read(inventoryProvider.notifier).replaceAll([_phone()]);
  return container;
}

LoanQuote _quote() => LoanQuote.calculate(
      cashPrice: 1000000,
      downPayment: 250000,
      tenureWeeks: 8,
    );

/// A sale in a chosen persistence state, for the paths that never reach a
/// ledger and would touch the printer if they were allowed to.
POSSaleResult _sale(SalePersistence persistence) => POSSaleResult(
      persistence: persistence,
      receiptId: 'POS-CASH-20261022-12345',
      transactionType: 'CASH',
      phoneModel: 'Test Phone',
      primaryImei: '356789012345678',
      customerName: 'Cash Customer',
      customerPhone: '0712345678',
      totalAmount: 1000000,
      amountPaid: 1000000,
      balanceRemaining: 0,
      paymentChannel: 'cash',
      timestamp: DateTime(2026, 10, 22, 10, 30),
    );

void main() {
  testWidgets('1. a confirmed write produces a successful sale',
      (tester) async {
    final ledger =
        _FakeLedger(const SaleLedgerWrite(SalePersistence.confirmed));
    final container = _container(ledger);
    addTearDown(container.dispose);
    final ref = await _mount(tester, container);

    final result = await container.read(limsRepositoryProvider).executeCashSale(
      ref: ref,
      phone: container.read(inventoryProvider).first,
      customerName: 'Cash Customer (0712345678)',
      customerPhone: '0712345678',
      paymentChannel: 'cash',
    );

    expect(result.success, isTrue);
    expect(result.isSaved, isTrue);
    expect(result.errorMessage, isNull);
  });

  testWidgets('1b. the confirmed sale moves stock, the ledger and the feed',
      (tester) async {
    final ledger =
        _FakeLedger(const SaleLedgerWrite(SalePersistence.confirmed));
    final container = _container(ledger);
    addTearDown(container.dispose);
    final ref = await _mount(tester, container);

    final before = container.read(inventoryProvider).first;
    final repo = container.read(limsRepositoryProvider);

    final result = await repo.executeCashSale(
      ref: ref,
      phone: before,
      customerName: 'Cash Customer (0712345678)',
      customerPhone: '0712345678',
      paymentChannel: 'cash',
    );

    expect(result.isSaved, isTrue);
    expect(container.read(salesProvider).length, 1);
    expect(container.read(salesProvider).first.receiptNo, result.receiptId);
    final after =
        container.read(inventoryProvider).firstWhere((p) => p.id == before.id);
    expect(after.stock, before.stock - 1);
    expect(container.read(activitiesProvider).length, 1);
    expect(ledger.writes, 1);
  });

  testWidgets('2. success is not returned before the write finishes',
      (tester) async {
    final ledger =
        _FakeLedger(const SaleLedgerWrite(SalePersistence.confirmed));
    final gate = Completer<SaleLedgerWrite>();
    ledger.gate = gate;
    final container = _container(ledger);
    addTearDown(container.dispose);
    final ref = await _mount(tester, container);

    final repo = container.read(limsRepositoryProvider);
    var finished = false;
    final pending = repo
        .executeCashSale(
      ref: ref,
      phone: container.read(inventoryProvider).first,
      customerName: 'Cash Customer',
      customerPhone: '0712345678',
      paymentChannel: 'cash',
    )
        .then((value) {
      finished = true;
      return value;
    });

    // The write is in flight: no result, no ledger row, no stock movement.
    await tester.pump();
    expect(finished, isFalse);
    expect(container.read(salesProvider), isEmpty);
    expect(container.read(inventoryProvider).first.stock, 3);
    expect(container.read(activitiesProvider), isEmpty);

    gate.complete(const SaleLedgerWrite(SalePersistence.confirmed));
    final result = await pending;

    expect(finished, isTrue);
    expect(result.success, isTrue);
    expect(container.read(salesProvider).length, 1);
    expect(container.read(inventoryProvider).first.stock, 2);
  });

  testWidgets('3. a refused write produces a failed sale', (tester) async {
    final ledger = _FakeLedger(
      const SaleLedgerWrite(
          SalePersistence.failed, 'The server refused the sale record.'),
    );
    final container = _container(ledger);
    addTearDown(container.dispose);
    final ref = await _mount(tester, container);

    final result = await container.read(limsRepositoryProvider).executeCashSale(
          ref: ref,
          phone: container.read(inventoryProvider).first,
          customerName: 'Cash Customer',
          customerPhone: '0712345678',
          paymentChannel: 'cash',
        );

    expect(result.success, isFalse);
    expect(result.isSaved, isFalse);
    expect(result.persistence, SalePersistence.failed);
    expect(result.errorMessage, 'The server refused the sale record.');
  });

  testWidgets('4. the persistence error is carried to the caller',
      (tester) async {
    final ledger = _FakeLedger(
      const SaleLedgerWrite(
          SalePersistence.failed, 'permission denied for table sales'),
    );
    final container = _container(ledger);
    addTearDown(container.dispose);
    final ref = await _mount(tester, container);

    final result = await container.read(limsRepositoryProvider).executeCashSale(
          ref: ref,
          phone: container.read(inventoryProvider).first,
          customerName: 'Cash Customer',
          customerPhone: '0712345678',
          paymentChannel: 'cash',
        );

    expect(result.errorMessage, contains('permission denied'));
    expect(result.errorMessage, isNotEmpty);
  });

  testWidgets(
      '5. a refused write leaves no trace a receipt could be printed from',
      (tester) async {
    final ledger = _FakeLedger(
      const SaleLedgerWrite(SalePersistence.failed, 'refused'),
    );
    final container = _container(ledger);
    addTearDown(container.dispose);
    final ref = await _mount(tester, container);

    final before = container.read(inventoryProvider).first;
    final result =
        await container.read(limsRepositoryProvider).executeLoanDisbursement(
              ref: ref,
              phone: before,
              customerName: 'Amina',
              customerPhone: '0712345678',
              customerNida: '19900101-12345-00001-01',
              residence: 'Kariakoo',
              guarantorName: 'Juma',
              guarantorPhone: '0765432109',
              quote: _quote(),
              paymentChannel: 'cash',
            );

    // The dialog, the toast and the PDF are gated on `success`; nothing here may
    // be able to satisfy that gate.
    expect(result.success, isFalse);
    expect(result.isSaved, isFalse);
    expect(container.read(salesProvider), isEmpty);
    expect(container.read(loansProvider), isEmpty);
    expect(container.read(activitiesProvider), isEmpty);
    expect(container.read(inventoryProvider).first.stock, before.stock);
  });

  testWidgets(
      '5b. an unanswered write is reported as unknown, not as a failure',
      (tester) async {
    final ledger = _FakeLedger(
      const SaleLedgerWrite(
        SalePersistence.unconfirmed,
        'The sale was sent but the database did not confirm it.',
      ),
    );
    final container = _container(ledger);
    addTearDown(container.dispose);
    final ref = await _mount(tester, container);

    final result = await container.read(limsRepositoryProvider).executeCashSale(
          ref: ref,
          phone: container.read(inventoryProvider).first,
          customerName: 'Cash Customer',
          customerPhone: '0712345678',
          paymentChannel: 'cash',
        );

    expect(result.isUnconfirmed, isTrue);
    expect(result.persistence, SalePersistence.unconfirmed);
    expect(result.isSaved, isFalse);
    expect(result.success, isFalse);
    // One attempt only: an unconfirmed write is never resent automatically.
    expect(ledger.writes, 1);
    expect(container.read(salesProvider), isEmpty);
  });

  testWidgets('5c. a confirmed loan sale books one borrower and one unit',
      (tester) async {
    final ledger =
        _FakeLedger(const SaleLedgerWrite(SalePersistence.confirmed));
    final container = _container(ledger);
    addTearDown(container.dispose);
    final ref = await _mount(tester, container);

    final quote = _quote();
    final before = container.read(inventoryProvider).first;
    final result =
        await container.read(limsRepositoryProvider).executeLoanDisbursement(
              ref: ref,
              phone: before,
              customerName: 'Amina',
              customerPhone: '0712345678',
              customerNida: '19900101-12345-00001-01',
              residence: 'Kariakoo',
              guarantorName: 'Juma',
              guarantorPhone: '0765432109',
              quote: quote,
              paymentChannel: 'cash',
            );

    expect(result.isSaved, isTrue);
    expect(result.balanceRemaining, quote.financedAmount);
    expect(container.read(loansProvider).length, 1);
    expect(container.read(loansProvider).first.name, 'Amina');
    expect(container.read(salesProvider).length, 1);
    expect(ledger.kinds, ['loan']);
    final after =
        container.read(inventoryProvider).firstWhere((p) => p.id == before.id);
    expect(after.onLoan, before.onLoan + 1);
  });

  testWidgets('6. a second submission is refused while the first is in flight',
      (tester) async {
    final guard = SaleSubmitGuard();

    expect(guard.tryBegin(), isTrue);
    expect(guard.isInFlight, isTrue);
    // The review sheet pops before the await, so this is the tap that used to
    // start a second sale.
    expect(guard.tryBegin(), isFalse);
    guard.release();
    expect(guard.isInFlight, isFalse);
    expect(guard.tryBegin(), isTrue);
  });

  testWidgets(
      '6b. a retry after a refusal writes once more and duplicates nothing',
      (tester) async {
    final ledger = _FakeLedger(
      const SaleLedgerWrite(SalePersistence.failed, 'refused'),
    );
    final container = _container(ledger);
    addTearDown(container.dispose);
    final ref = await _mount(tester, container);
    final repo = container.read(limsRepositoryProvider);
    final phone = container.read(inventoryProvider).first;

    final first = await repo.executeCashSale(
      ref: ref,
      phone: phone,
      customerName: 'Cash Customer',
      customerPhone: '0712345678',
      paymentChannel: 'cash',
    );
    ledger.response = const SaleLedgerWrite(SalePersistence.confirmed);
    final second = await repo.executeCashSale(
      ref: ref,
      phone: phone,
      customerName: 'Cash Customer',
      customerPhone: '0712345678',
      paymentChannel: 'cash',
    );

    expect(first.isSaved, isFalse);
    expect(second.isSaved, isTrue);
    // Exactly one row reached the local ledger, one unit left the shelf and one
    // line reached the feed: the refused attempt left nothing behind to
    // duplicate.
    expect(ledger.writes, 2);
    expect(container.read(salesProvider).length, 1);
    expect(container.read(activitiesProvider).length, 1);
    expect(container.read(inventoryProvider).first.stock, 2);
    // No assertion that the two receipts differ. The number is
    // `POS-CASH-<yyyyMMdd>-<epochMs.toString().substring(8)>`, and that last
    // field is the epoch millisecond **modulo 100000** — the millisecond's
    // position inside the current 100-second cycle, not a sequence. So two
    // attempts collide when their timestamps are equal modulo 100000: the same
    // millisecond (which is why the two calls in this test, microseconds apart,
    // were handed one number), or exactly 100 seconds apart. It is not true that
    // any two attempts inside 100 s collide, and it is not true that the numbers
    // are always distinct. Pre-existing numbering, unchanged here.
  });

  testWidgets(
      '6c. an unconfigured build still sells, and says nothing was stored',
      (tester) async {
    final ledger =
        _FakeLedger(const SaleLedgerWrite(SalePersistence.notConfigured));
    final container = _container(ledger);
    addTearDown(container.dispose);
    final ref = await _mount(tester, container);

    final result = await container.read(limsRepositoryProvider).executeCashSale(
          ref: ref,
          phone: container.read(inventoryProvider).first,
          customerName: 'Cash Customer',
          customerPhone: '0712345678',
          paymentChannel: 'cash',
        );

    // The demo build has no database. It must keep ringing up sales, and the
    // result must say plainly that no row was stored.
    expect(result.success, isTrue);
    expect(result.isSaved, isFalse);
    expect(result.persistence, SalePersistence.notConfigured);
    expect(container.read(inventoryProvider).first.stock, 2);
    expect(container.read(salesProvider), isEmpty);
  });

  group('F-1. only a stored sale may be printed as a receipt', () {
    test('a demo sale completes but cannot produce a receipt PDF', () async {
      final sale = _sale(SalePersistence.notConfigured);

      // The workflow still calls this a completed sale, which is why the
      // printer must ask a different question.
      expect(sale.success, isTrue);
      expect(sale.isSaved, isFalse);

      // No printing plugin is registered in a unit test: if this reached
      // `Printing.layoutPdf` it would throw, so a clean `false` is the guard
      // doing its job rather than a call that happened to survive.
      expect(
        await PdfReportService.generateAndDownloadSaleReceipt(
          sale: sale,
          branchName: 'Mbogala',
          servedBy: 'Cashier',
        ),
        isFalse,
      );
    });

    test('refused and unanswered sales cannot produce a receipt PDF either',
        () async {
      for (final persistence in [
        SalePersistence.failed,
        SalePersistence.unconfirmed,
      ]) {
        expect(_sale(persistence).isSaved, isFalse, reason: '$persistence');
        expect(
          await PdfReportService.generateAndDownloadSaleReceipt(
            sale: _sale(persistence),
            branchName: 'Mbogala',
            servedBy: 'Cashier',
          ),
          isFalse,
          reason: '$persistence must not print',
        );
      }
    });
  });
}
