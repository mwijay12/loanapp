import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loan_inventory_app/core/data/inventory_provider.dart';
import 'package:loan_inventory_app/core/data/mock_lims_data.dart';
import 'package:loan_inventory_app/core/data/sales_provider.dart';
import 'package:loan_inventory_app/core/l10n/greetings.dart';
import 'package:loan_inventory_app/core/l10n/locale_provider.dart';
import 'package:loan_inventory_app/core/l10n/strings.dart';
import 'package:loan_inventory_app/features/home/presentation/auditor_dashboard.dart';
import 'package:loan_inventory_app/features/home/presentation/branch_manager_dashboard.dart';
import 'package:loan_inventory_app/features/home/presentation/cashier_dashboard.dart';
import 'package:loan_inventory_app/features/home/presentation/loan_officer_dashboard.dart';

/// The four role homes that sit under the Admin console.
///
/// A redesign of these screens is only worth shipping if the figures still come
/// from the ledgers, an empty day reads zero, and no role is handed an action it
/// cannot perform. These tests pin exactly that for each screen.

ProductItem _phone({required int id, required int stock, required int min}) {
  return ProductItem(
    id: id,
    name: 'Phone $id',
    variant: '128GB',
    sku: 'SKU-$id',
    price: 420000,
    stock: stock,
    min: min,
    cat: 'phones',
    grad: const [Color(0xFF347FF5), Color(0xFFBBD9FF)],
    status: stock <= min ? 'low' : 'in',
    soldToday: 0,
    onLoan: 0,
  );
}

LoanItem _loan({
  required String name,
  required int amount,
  required int paid,
  required String status,
}) {
  return LoanItem(
    name: name,
    item: 'Samsung A15',
    amount: amount,
    paid: paid,
    due: '12 Oct',
    status: status,
    grad: const [Color(0xFF1B6EF3), Color(0xFF0A49B8)],
    phone: '',
  );
}

SaleRecord _sale({
  required String receipt,
  required int paid,
  String kind = 'cash',
}) {
  return SaleRecord(
    receiptNo: receipt,
    total: paid,
    paid: paid,
    kind: kind,
    soldAt: DateTime.now(),
    customerName: 'Amina',
  );
}

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  List<ProductItem> products = const [],
  List<LoanItem> loans = const [],
  List<SaleRecord> sales = const [],
  Locale locale = const Locale('en'),
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size * 2.0;
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        localeProvider.overrideWith((ref) => locale),
        inventoryProvider.overrideWith((ref) => InventoryNotifier(products)),
        loansProvider.overrideWith((ref) => LoansNotifier(loans)),
        salesProvider.overrideWith((ref) => SalesNotifier(sales)),
      ],
      child: MaterialApp(home: child),
    ),
  );
  await tester.pump(const Duration(milliseconds: 400));
  // The dashboard now arrives: sections rise 55ms apart and a figure counts to its
  // value. A single 400ms pump therefore used to catch a tile showing a number on its
  // way up, which made "the totals it shows are the shared ledgers" fail for the
  // wrong reason - it was asserting a mid-flight frame, not a wrong total. Settling
  // keeps the assertion about the figure, which is what the test is for. Motion is
  // covered separately in motion_test.dart, where the animation itself is the thing
  // under test.
  await tester.pumpAndSettle();
}

/// The role homes scroll inside the shared [DashPage] shell, which is a
/// [CustomScrollView] because of the pinned greeting bar. Screens that have not
/// moved onto that shell yet still use a plain [ListView], so the helper picks
/// whichever scrollable this screen actually has.
Future<void> _scroll(WidgetTester tester, [double dy = -600]) async {
  final custom = find.byType(CustomScrollView);
  final target =
      custom.evaluate().isNotEmpty ? custom.first : find.byType(ListView).first;
  await tester.drag(target, Offset(0, dy));
  await tester.pump(const Duration(milliseconds: 300));
}

/// The greeting the screen is allowed to show at this moment.
///
/// The copy is no longer a fixed "Welcome Back," — the East Africa clock picks
/// morning, afternoon or evening — so the test asks the same pure function the
/// header uses instead of pinning the old line back into the screen.
String _greeting(Locale locale) => tr(locale, salutationKeyAt(DateTime.now()));

void main() {
  group('cashier home', () {
    testWidgets('a morning with no sales reads zero, not a sample figure',
        (tester) async {
      await _pump(tester, const CashierDashboard());

      expect(find.text(_greeting(const Locale('en'))), findsWidgets);
      expect(find.text('Welcome Back,'), findsNothing);
      expect(find.text('Counter Cashier'), findsWidgets);
      expect(find.text('TZS 0'), findsOneWidget);
      expect(find.text('0 receipts today'), findsOneWidget);

      await _scroll(tester);
      expect(
        find.textContaining('The register is empty'),
        findsOneWidget,
      );
    });

    testWidgets('a sale today appears in the register with its own amount',
        (tester) async {
      await _pump(
        tester,
        const CashierDashboard(),
        sales: [_sale(receipt: 'RCP-9001', paid: 420000)],
      );

      expect(find.text('1 receipts today'), findsOneWidget);
      await _scroll(tester);
      expect(find.text('RCP-9001'), findsOneWidget);
      expect(find.text('Cash · Amina'), findsOneWidget);
      // Once on the till card, once on the register row.
      expect(find.text('TZS 420,000'), findsNWidgets(2));
    });

    testWidgets('the four counter actions are real routes', (tester) async {
      await _pump(tester, const CashierDashboard());

      expect(find.text('Counter POS Actions'), findsOneWidget);
      expect(find.text('New POS Sale'), findsWidgets);
      expect(find.text('Customer Directory'), findsOneWidget);
      expect(find.text('Scan Cabinet'), findsOneWidget);
      expect(find.text('Clock Shift'), findsOneWidget);
    });

    testWidgets('speaks Swahili on its own screen', (tester) async {
      await _pump(
        tester,
        const CashierDashboard(),
        locale: const Locale('sw'),
      );

      expect(find.text(_greeting(const Locale('sw'))), findsWidgets);
      expect(find.text('Mweka Hazina'), findsWidgets);
      expect(find.text('Karibu Tena,'), findsNothing);
      expect(find.text('Counter Cashier'), findsNothing);
    });
  });

  group('loan officer home', () {
    testWidgets('outstanding is the unpaid remainder of open loans',
        (tester) async {
      await _pump(
        tester,
        const LoanOfficerDashboard(),
        loans: [
          _loan(name: 'Juma', amount: 1000000, paid: 60, status: 'current'),
          _loan(name: 'Neema', amount: 500000, paid: 0, status: 'overdue'),
        ],
      );

      // 400,000 + 500,000
      expect(find.text('TZS 900,000'), findsOneWidget);
      expect(find.text('2 active · 1 overdue'), findsOneWidget);
    });

    testWidgets('arrears are one line with the money, not a borrower list',
        (tester) async {
      await _pump(
        tester,
        const LoanOfficerDashboard(),
        loans: [
          _loan(name: 'Neema', amount: 500000, paid: 0, status: 'overdue')
        ],
      );
      await _scroll(tester, -800);

      // The officer still learns how much is out and how many accounts.
      expect(find.text('Overdue Accounts'), findsOneWidget);
      expect(find.text('TZS 500,000 still to recover'), findsOneWidget);

      // But the home no longer spends five rows naming borrowers; that list
      // lives in the loan book the row opens.
      expect(find.text('Neema'), findsNothing);
      expect(find.text('Samsung A15 · 0% paid'), findsNothing);
    });

    testWidgets('the credit actions stay above the arrears line',
        (tester) async {
      await _pump(
        tester,
        const LoanOfficerDashboard(),
        loans: [
          for (var i = 0; i < 6; i++)
            _loan(
                name: 'Borrower $i',
                amount: 500000,
                paid: 0,
                status: 'overdue'),
        ],
      );
      await _scroll(tester, -400);

      // Six overdue accounts must not push the actions off the screen.
      expect(find.text('Issue Loan'), findsOneWidget);
      expect(find.text('Borrower 5'), findsNothing);
    });

    testWidgets('an empty book says every account is on schedule',
        (tester) async {
      await _pump(tester, const LoanOfficerDashboard());
      await _scroll(tester, -800);
      expect(find.text('Every account is on schedule'), findsOneWidget);
      // A quiet book shows the reassuring line and no count badge.
      expect(find.text('Overdue Accounts'), findsOneWidget);
    });
  });

  group('branch manager home', () {
    testWidgets('the branch name, takings and shelf count come from data',
        (tester) async {
      await _pump(
        tester,
        BranchManagerDashboard(onLowStockTap: () {}, onSupervisorPin: () {}),
        products: [
          _phone(id: 1, stock: 10, min: 5),
          _phone(id: 2, stock: 1, min: 6),
        ],
        sales: [_sale(receipt: 'RCP-1', paid: 250000)],
      );

      expect(find.text('TZS 250,000'), findsOneWidget);
      expect(find.text('1 receipts · 11 handsets on hand'), findsOneWidget);
      expect(find.text('Branch Manager'), findsWidgets);
    });

    testWidgets('the control tiles are the existing tools, not new claims',
        (tester) async {
      await _pump(
        tester,
        BranchManagerDashboard(onLowStockTap: () {}, onSupervisorPin: () {}),
      );

      expect(find.text('Sales Audit'), findsOneWidget);
      expect(find.text('Supervisor PIN'), findsOneWidget);
      expect(find.text('Branch Stock'), findsOneWidget);
      expect(find.text('Staff Shifts'), findsOneWidget);
    });
  });

  group('auditor home', () {
    testWidgets('inspection only: no selling action is offered',
        (tester) async {
      await _pump(tester, const AuditorDashboard());

      expect(find.text('Read-only'), findsOneWidget);
      expect(find.text('Auditor'), findsWidgets);
      expect(find.text('New POS Sale'), findsNothing);
      expect(find.text('Issue Loan'), findsNothing);
      await _scroll(tester);
      expect(find.text('Sales Register'), findsOneWidget);
      expect(find.text('Loan Ledger'), findsOneWidget);
      expect(find.text('Stock Register'), findsOneWidget);
      expect(find.text('Device & IMEI Inspector'), findsOneWidget);
    });

    testWidgets('the totals it shows are the shared ledgers', (tester) async {
      await _pump(
        tester,
        const AuditorDashboard(),
        products: [_phone(id: 1, stock: 7, min: 2)],
        loans: [_loan(name: 'Juma', amount: 100, paid: 0, status: 'current')],
      );

      expect(find.text('7'), findsWidgets);
      expect(find.text('1'), findsWidgets);
    });
  });

  testWidgets('every role home fits a 360x640 phone', (tester) async {
    final screens = <Widget>[
      const CashierDashboard(),
      const LoanOfficerDashboard(),
      BranchManagerDashboard(onLowStockTap: () {}, onSupervisorPin: () {}),
      const AuditorDashboard(),
    ];

    for (final screen in screens) {
      await _pump(
        tester,
        screen,
        products: [_phone(id: 1, stock: 4, min: 6)],
        loans: [
          _loan(name: 'Juma', amount: 900000, paid: 25, status: 'overdue')
        ],
        sales: [_sale(receipt: 'RCP-1', paid: 900000)],
        size: const Size(360, 640),
      );
      expect(tester.takeException(), isNull);
      await _scroll(tester, -900);
      expect(tester.takeException(), isNull);
    }
  });
}
