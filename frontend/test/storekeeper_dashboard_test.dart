import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loan_inventory_app/core/data/inventory_provider.dart';
import 'package:loan_inventory_app/core/data/mock_lims_data.dart';
import 'package:loan_inventory_app/core/l10n/locale_provider.dart';
import 'package:loan_inventory_app/features/home/presentation/storekeeper_dashboard.dart';

/// The storekeeper home draws its numbers from the ledger. These tests pin the
/// three things a redesign usually breaks: the figures must come from data, the
/// screen must fit a small phone without overflowing, and it must speak one
/// language.

ProductItem _phone({
  required int id,
  required String name,
  required int stock,
  required int min,
}) {
  return ProductItem(
    id: id,
    name: name,
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

Future<void> _pump(
  WidgetTester tester, {
  required List<ProductItem> products,
  Size size = const Size(390, 844),
  Locale locale = const Locale('en'),
}) async {
  tester.view.physicalSize = size * 2.0;
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        localeProvider.overrideWith((ref) => locale),
        inventoryProvider.overrideWith((ref) => InventoryNotifier(products)),
      ],
      child: MaterialApp(
        home: StorekeeperDashboard(onLowStockTap: () {}),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _scrollDown(WidgetTester tester, [double dy = -600]) async {
  await tester.drag(find.byType(ListView).first, Offset(0, dy));
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  final products = [
    _phone(id: 1, name: 'iPhone 15 Pro', stock: 100, min: 5),
    _phone(id: 2, name: 'Samsung A15', stock: 66, min: 5),
    _phone(id: 3, name: 'Tecno Camon', stock: 1, min: 6),
    _phone(id: 4, name: 'Redmi Note 13', stock: 2, min: 6),
    _phone(id: 5, name: 'itel A70', stock: 0, min: 6),
  ];

  testWidgets(
      'the header, search and section titles follow the reference order',
      (tester) async {
    await _pump(tester, products: products);

    expect(find.text('Welcome Back,'), findsOneWidget);
    expect(find.text('Storekeeper'), findsOneWidget);
    expect(find.text('Search IMEI, model, serial...'), findsOneWidget);
    expect(find.text("Today's Stock Activity"), findsOneWidget);

    await _scrollDown(tester);
    expect(find.text('Services'), findsOneWidget);
    expect(find.text('Recent Activity'), findsOneWidget);
  });

  testWidgets('the stock figure is summed from inventory, not typed in',
      (tester) async {
    await _pump(tester, products: products);

    // 100 + 66 + 1 + 2 + 0
    expect(find.text('169'), findsOneWidget);
    expect(find.text('handsets in stock'), findsOneWidget);
    expect(find.text('166'), findsNothing);
  });

  testWidgets('the alert card counts the rows below their minimum',
      (tester) async {
    await _pump(tester, products: products);

    // Tecno (1/6), Redmi (2/6) and itel (0/6) are below their minimum.
    expect(find.text('3 low stock alerts'), findsOneWidget);
  });

  testWidgets('an empty ledger reads zero and says nothing was recorded',
      (tester) async {
    await _pump(tester, products: const []);

    expect(find.text('0'), findsOneWidget);
    expect(find.text('No low stock alerts'), findsOneWidget);

    await _scrollDown(tester);
    expect(
      find.textContaining('No stock movements recorded yet'),
      findsOneWidget,
    );
    // The reference's sample figures must never appear on a real screen.
    expect(find.text('14 IMEIs added · 2 POs'), findsNothing);
  });

  testWidgets('fits a 360x640 phone without overflowing', (tester) async {
    await _pump(tester, products: products, size: const Size(360, 640));
    expect(tester.takeException(), isNull);
    expect(find.text('Welcome Back,'), findsOneWidget);

    await _scrollDown(tester, -900);
    await _scrollDown(tester, -900);
    expect(tester.takeException(), isNull);
  });

  testWidgets('speaks Swahili when Swahili is selected', (tester) async {
    await _pump(
      tester,
      products: products,
      locale: const Locale('sw'),
    );

    expect(find.text('Karibu Tena,'), findsOneWidget);
    expect(find.text('Afisa Stoo'), findsOneWidget);
    expect(find.text('Welcome Back,'), findsNothing);
    expect(find.text('3 low stock alerts'), findsNothing);
  });
}
