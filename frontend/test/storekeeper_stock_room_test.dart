import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loan_inventory_app/core/constants/app_constants.dart';
import 'package:loan_inventory_app/core/data/inventory_provider.dart';
import 'package:loan_inventory_app/core/l10n/locale_provider.dart';
import 'package:loan_inventory_app/core/widgets/empty_state.dart';
import 'package:loan_inventory_app/features/loans/presentation/loans_screen.dart';
import 'package:loan_inventory_app/features/stock/presentation/stock_room_screen.dart';

/// The screen used to be offered to a role that the database refuses, and then
/// to apologise for the resulting emptiness in words that blamed the reader's
/// own search box. These tests pin the two halves of the fix: the predicate
/// that mirrors `loans_read`, and a refusal that says who is refusing.

Override localeProviderOverride(Locale locale) =>
    localeProvider.overrideWith((ref) => locale);

ProviderContainer containerFor(String role) {
  final container = ProviderContainer(
    overrides: [
      userRoleProvider.overrideWith(
        (ref) => UserRoleNotifier()..hydrateFromSession(role),
      ),
      loansProvider.overrideWith((ref) => LoansNotifier()),
      localeProviderOverride(const Locale('en')),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Future<void> pumpLoans(WidgetTester tester, String role) async {
  tester.view.physicalSize = const Size(420, 1500) * 2.0;
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: containerFor(role),
      child: const MaterialApp(home: LoansScreen()),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  group('canViewLoans transcribes the RLS policy, not an opinion', () {
    // loans_read in 2026_10_20_01_rls_policies.sql:133-136 names exactly four
    // roles. If that list changes in SQL and not here, a door gets shown that
    // the database will slam — which is the bug being fixed.
    test('the four roles the policy names are allowed', () {
      expect(UserRoles.canViewLoans(UserRoles.superAdmin), isTrue);
      expect(UserRoles.canViewLoans(UserRoles.branchManager), isTrue);
      expect(UserRoles.canViewLoans(UserRoles.loanOfficer), isTrue);
      expect(UserRoles.canViewLoans(UserRoles.auditor), isTrue);
    });

    test('Storekeeper and Counter Cashier are refused', () {
      expect(UserRoles.canViewLoans(UserRoles.storekeeper), isFalse);
      expect(UserRoles.canViewLoans(UserRoles.counterCashier), isFalse);
    });

    test('a retired title still resolves to its canonical role', () {
      // 'Inventory Officer' became Storekeeper, so it must be refused too.
      expect(UserRoles.canViewLoans('Inventory Officer'), isFalse);
      expect(UserRoles.canViewLoans('Loan Officer'), isTrue);
    });

    test('an unknown or empty role never gains the door', () {
      expect(UserRoles.canViewLoans(null), isFalse);
      expect(UserRoles.canViewLoans(''), isFalse);
      expect(UserRoles.canViewLoans('Regional Governor'), isFalse);
      expect(UserRoles.canViewLoans(UserRoles.noSession), isFalse);
    });
  });

  group('the loans screen refuses in plain words', () {
    testWidgets('a Storekeeper is told it is the role, not his typing',
        (tester) async {
      await pumpLoans(tester, UserRoles.storekeeper);

      expect(find.byType(EmptyState), findsOneWidget);
      expect(
        find.text('Borrower files are not part of your role'),
        findsOneWidget,
      );
      // The sentence that used to appear and blame the reader must not appear.
      expect(find.textContaining('No borrower matches'), findsNothing);
      // The KPI row that made an unreadable table look like an idle shop.
      expect(find.text('Active borrowers'), findsNothing);
    });

    testWidgets('a Branch Manager is not refused', (tester) async {
      await pumpLoans(tester, UserRoles.branchManager);

      expect(find.byType(EmptyState), findsNothing);
      expect(
        find.text('Borrower files are not part of your role'),
        findsNothing,
      );
    });

    testWidgets('an unrecognised role is refused too, never trusted',
        (tester) async {
      await pumpLoans(tester, 'Warehouse Guy');

      expect(
        find.text('Borrower files are not part of your role'),
        findsOneWidget,
      );
    });
  });

  group('the stock room answers with the tables a Storekeeper owns', () {
    testWidgets('a build with no database says so instead of showing zeros',
        (tester) async {
      tester.view.physicalSize = const Size(420, 1500) * 2.0;
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      final container = ProviderContainer(
        overrides: [
          userRoleProvider.overrideWith(
            (ref) =>
                UserRoleNotifier()..hydrateFromSession(UserRoles.storekeeper),
          ),
          inventoryProvider.overrideWith((ref) => InventoryNotifier()),
          localeProviderOverride(const Locale('en')),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: StockRoomScreen()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      // Without a configured project the only honest answer is that there is
      // nothing to ask; a row of zeros would read as an empty shop.
      expect(find.text('No database behind this build'), findsOneWidget);
      expect(
        find.textContaining('built without a Supabase URL and key'),
        findsOneWidget,
      );
      // The KPI row is not drawn at all, so no '—' placeholder is offered as a
      // count either. An unanswered question is not rendered as a number.
      expect(find.text('—'), findsNothing);
      expect(find.byType(EmptyState), findsOneWidget);
    });
  });
}
