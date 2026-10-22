import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:loan_inventory_app/core/constants/app_constants.dart';
import 'package:loan_inventory_app/core/data/inventory_provider.dart';
import 'package:loan_inventory_app/core/data/mock_lims_data.dart';
import 'package:loan_inventory_app/core/data/supabase_source.dart';
import 'package:loan_inventory_app/core/l10n/locale_provider.dart';
import 'package:loan_inventory_app/core/routing/app_router.dart';
import 'package:loan_inventory_app/core/widgets/phone_deals_carousel.dart';
import 'package:loan_inventory_app/features/home/presentation/cashier_dashboard.dart';
import 'package:loan_inventory_app/features/home/presentation/featured_deals_section.dart';
import 'package:loan_inventory_app/features/stock/presentation/stock_screen.dart';

/// The scanner shortcut 404'd, and the offers rail went missing.
///
/// Two regressions from the same rebuild: four dashboards pushed `/scanner`,
/// a route that has never existed (the screen lives at `/scan`), and the
/// cashier's "Featured Phone Deals & Loan Offers" rail disappeared with the old
/// home. These tests pin both, plus the flag the shop owner sets.

ProductItem _phone({
  required int id,
  required String name,
  int stock = 3,
  int price = 1000000,
  bool onOffer = false,
}) =>
    ProductItem(
      id: id,
      name: name,
      variant: '128GB',
      sku: 'SKU-$id',
      price: price,
      stock: stock,
      min: 1,
      cat: 'phones',
      grad: const [Color(0xFF1B6EF3), Color(0xFF0A49B8)],
      status: 'in',
      soldToday: 0,
      onLoan: 0,
      onOffer: onOffer,
    );

Future<void> _pumpSection(
  WidgetTester tester,
  List<ProductItem> products, {
  Locale locale = const Locale('en'),
}) async {
  tester.view.physicalSize = const Size(390, 844) * 2.0;
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        localeProvider.overrideWith((ref) => locale),
        inventoryProvider.overrideWith((ref) => InventoryNotifier(products)),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: FeaturedDealsSection()),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  group('scanner route', () {
    testWidgets('/scanner lands on the scanner screen instead of "Page Not Found"',
        (tester) async {
      final container = ProviderContainer(
        overrides: [
          // The guard sends a signed-out user to /login, so the redirect can
          // only be observed from a real role.
          userRoleProvider.overrideWith((ref) {
            final notifier = UserRoleNotifier()
              ..hydrateFromSession(UserRoles.counterCashier);
            return notifier;
          }),
        ],
      );
      addTearDown(container.dispose);

      final router = container.read(routerProvider);
      addTearDown(router.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      router.go('/scanner');
      await tester.pumpAndSettle();

      // The location after redirect, not the one that was asked for.
      expect(router.routerDelegate.currentConfiguration.uri.path, '/scan');
      // A 404 from the framework would have shown this; the redirect must not.
      expect(find.text('Page Not Found'), findsNothing);
    });
  });

  group('on offer', () {
    test('the flag moves one handset, not the catalogue', () {
      final container = ProviderContainer(
        overrides: [
          inventoryProvider.overrideWith(
            (ref) => InventoryNotifier([
              _phone(id: 1, name: 'iPhone 15'),
              _phone(id: 2, name: 'Tecno Spark'),
            ]),
          ),
        ],
      );
      addTearDown(container.dispose);

      container.read(inventoryProvider.notifier).setOffer(1, true);

      final products = container.read(inventoryProvider);
      expect(products.firstWhere((p) => p.id == 1).onOffer, isTrue);
      expect(products.firstWhere((p) => p.id == 2).onOffer, isFalse);
    });

    testWidgets('an offered handset leads the rail', (tester) async {
      await _pumpSection(tester, [
        // More stock, but not on offer: the slow mover the owner flagged has to
        // come first regardless of how many units each model holds.
        _phone(id: 1, name: 'Samsung A15', stock: 9),
        _phone(id: 2, name: 'iPhone 15 Pro Max', stock: 2, onOffer: true),
      ]);

      final cards = tester
          .widgetList<FeaturedPhoneDealCard>(find.byType(FeaturedPhoneDealCard))
          .toList();
      expect(cards, isNotEmpty);
      expect(cards.first.deal.title, 'iPhone 15 Pro Max');
      expect(find.text('ON OFFER'), findsWidgets);
    });

    testWidgets('the rail says nothing when the shelf is empty', (tester) async {
      await _pumpSection(tester, [
        _phone(id: 1, name: 'Sold Out Handset', stock: 0, onOffer: true),
      ]);

      expect(find.byType(PhoneDealsCarousel), findsNothing);
    });

    testWidgets('Swahili keeps the same rail', (tester) async {
      await _pumpSection(
        tester,
        [_phone(id: 1, name: 'iPhone 15', onOffer: true)],
        locale: const Locale('sw'),
      );

      expect(find.text('Ofa za Simu na Mikopo'), findsOneWidget);
      expect(find.text('OFA MAALUM'), findsWidgets);
    });

    test('without a database the switch reports a session-only change', () async {
      // No dart-defines in a test run, so this is the demo build's answer. It
      // must not claim a write.
      final outcome = await SupabaseSource.setProductOffer(
        productId: 1,
        onOffer: true,
      );

      expect(outcome, OfferSaveOutcome.notConfigured);
    });
  });

  group('the wiring that disappeared', () {
    testWidgets('the cashier home carries the offers rail', (tester) async {
      tester.view.physicalSize = const Size(390, 844) * 2.0;
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            inventoryProvider.overrideWith(
              (ref) => InventoryNotifier([
                _phone(id: 1, name: 'iPhone 15 Pro Max', stock: 2, onOffer: true),
              ]),
            ),
          ],
          child: const MaterialApp(home: Scaffold(body: CashierDashboard())),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(PhoneDealsCarousel), findsOneWidget);
      expect(find.text('ON OFFER'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the stock sheet carries the owner switch', (tester) async {
      tester.view.physicalSize = const Size(390, 844) * 2.0;
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      final container = ProviderContainer(
        overrides: [
          inventoryProvider.overrideWith(
            (ref) => InventoryNotifier([_phone(id: 1, name: 'Tecno Spark')]),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: StockScreen()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.text('Tecno Spark').first);
      await tester.pumpAndSettle();

      expect(find.text('On offer at the till'), findsOneWidget);

      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();

      expect(container.read(inventoryProvider).first.onOffer, isTrue);

      // Let the confirmation toast time out; a pending timer fails the binding.
      await tester.pump(const Duration(seconds: 11));
    });
  });
}
