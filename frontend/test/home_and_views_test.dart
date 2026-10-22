import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:loan_inventory_app/core/data/inventory_provider.dart';
import 'package:loan_inventory_app/core/data/mock_lims_data.dart';
import 'package:loan_inventory_app/core/l10n/greetings.dart';
import 'package:loan_inventory_app/core/l10n/locale_provider.dart';
import 'package:loan_inventory_app/core/l10n/strings.dart';
import 'package:loan_inventory_app/core/theme/app_theme.dart';
import 'package:loan_inventory_app/core/widgets/view_toggle.dart';
import 'package:loan_inventory_app/features/home/presentation/cashier_dashboard.dart';
import 'package:loan_inventory_app/features/loans/presentation/loans_screen.dart';
import 'package:loan_inventory_app/features/stock/presentation/stock_screen.dart';

/// The home header, the list/grid switch and the haptic ticks behind them.
///
/// Three things a cashier asked for in one breath: the greeting should follow the
/// clock instead of saying "welcome back" all day, the tall header should shrink
/// into a bar that stays on screen, and both Inventory and Loans should be
/// readable as rows or as cards. Each is pinned here so a later rebuild cannot
/// quietly take it away again.

ProductItem _phone({
  required int id,
  required String name,
  int stock = 3,
  int price = 1000000,
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
    );

void _phoneView(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844) * 2.0;
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);
}

/// The opacity of the block that owns [text] — the tall or the compact copy.
double _opacityOf(WidgetTester tester, Finder text) {
  final f = find.ancestor(of: text, matching: find.byType(Opacity)).first;
  return tester.widget<Opacity>(f).opacity;
}

void main() {
  group('the greeting follows the East Africa clock', () {
    test('the three bands meet at 05:00, 12:00 and 17:00', () {
      // UTC noon is 15:00 in Dar es Salaam.
      expect(dayPartAt(DateTime.utc(2026, 10, 22, 12)), DayPart.afternoon);
      // 02:00 UTC is 05:00 EAT — the first minute of morning.
      expect(dayPartAt(DateTime.utc(2026, 10, 22, 2)), DayPart.morning);
      expect(dayPartAt(DateTime.utc(2026, 10, 22, 1, 59)), DayPart.evening);
      // 09:00 UTC is 12:00 EAT.
      expect(dayPartAt(DateTime.utc(2026, 10, 22, 9)), DayPart.afternoon);
      expect(dayPartAt(DateTime.utc(2026, 10, 22, 8, 59)), DayPart.morning);
      // 14:00 UTC is 17:00 EAT.
      expect(dayPartAt(DateTime.utc(2026, 10, 22, 14)), DayPart.evening);
      expect(dayPartAt(DateTime.utc(2026, 10, 22, 13, 59)), DayPart.afternoon);
    });

    test('each band maps to its own sentence, and none says welcome back', () {
      expect(salutationKeyFor(DayPart.morning), 'greet.morning');
      expect(salutationKeyFor(DayPart.afternoon), 'greet.afternoon');
      expect(salutationKeyFor(DayPart.evening), 'greet.evening');

      const locale = Locale('en');
      for (final key in [
        'greet.morning',
        'greet.afternoon',
        'greet.evening',
      ]) {
        final text = tr(locale, key);
        expect(text, isNotEmpty);
        expect(text.toLowerCase(), isNot(contains('welcome')));
      }
      expect(tr(const Locale('sw'), 'greet.morning'), 'Habari za asubuhi');
    });
  });

  group('the home header sticks and shrinks', () {
    testWidgets('the tall greeting shrinks to a bar that stays on screen',
        (tester) async {
      _phoneView(tester);
      const locale = Locale('en');
      final salutation = tr(locale, salutationKeyAt(DateTime.now()));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localeProvider.overrideWith((ref) => locale),
            inventoryProvider.overrideWith(
              (ref) => InventoryNotifier([_phone(id: 1, name: 'iPhone 15')]),
            ),
          ],
          child: const MaterialApp(home: CashierDashboard()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      // The header is a pinned sliver, not the first two list items it used to be.
      expect(find.byType(SliverPersistentHeader), findsOneWidget);
      expect(find.text(salutation), findsNWidgets(2));

      // Two copies: the tall one, and the compact bar that takes over.
      final tallCopy = find.text(salutation).first;
      final barCopy = find.text(salutation).last;
      expect(tester.widget<Text>(tallCopy).style?.fontSize, 32);
      expect(tester.widget<Text>(barCopy).style?.fontSize, 11);
      expect(_opacityOf(tester, tallCopy), greaterThan(0.9));
      expect(_opacityOf(tester, barCopy), lessThan(0.1));

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
      await tester.pumpAndSettle();

      // The tall greeting has faded out and the compact bar has taken over, at a
      // fixed position near the top of the screen.
      expect(_opacityOf(tester, tallCopy), lessThan(0.1));
      expect(_opacityOf(tester, barCopy), greaterThan(0.9));
      expect(tester.getTopLeft(barCopy).dy, lessThan(20));
      expect(tester.takeException(), isNull);
    });
  });

  group('inventory switches between rows and cards', () {
    testWidgets('the switch draws a grid, ticks the phone, and comes back',
        (tester) async {
      _phoneView(tester);
      final haptics = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        haptics.add(call.method);
        return null;
      });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null);
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            inventoryProvider.overrideWith(
              (ref) => InventoryNotifier([
                _phone(id: 1, name: 'iPhone 15 Pro'),
                _phone(id: 2, name: 'Galaxy S24'),
              ]),
            ),
          ],
          child: const MaterialApp(home: StockScreen()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(ViewToggle), findsOneWidget);
      expect(find.byType(GridView), findsNothing);

      await tester.tap(find.byIcon(Icons.grid_view_rounded));
      await tester.pumpAndSettle();

      expect(find.byType(GridView), findsOneWidget);
      final grid = tester.widget<GridView>(find.byType(GridView));
      final delegate =
          grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(delegate.crossAxisCount, 2);
      // The phone was told the thumb landed on something.
      expect(haptics, contains('HapticFeedback.vibrate'));

      await tester.tap(find.byIcon(Icons.view_agenda_rounded));
      await tester.pumpAndSettle();
      expect(find.byType(GridView), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('loans switches between rows and cards', () {
    testWidgets('the same control is on the borrower list', (tester) async {
      _phoneView(tester);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            loansProvider.overrideWith(
              (ref) => LoansNotifier([
                LoanItem(
                  name: 'Amina Juma',
                  item: 'iPhone 15',
                  amount: 1200000,
                  paid: 40,
                  due: '2 weeks',
                  status: 'current',
                  grad: const [Color(0xFF7C5CFC), Color(0xFF5B3BD6)],
                  phone: '0712345678',
                ),
              ]),
            ),
          ],
          child: const MaterialApp(home: LoansScreen()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(ViewToggle), findsOneWidget);
      expect(find.byType(GridView), findsNothing);

      await tester.tap(find.byIcon(Icons.grid_view_rounded));
      await tester.pumpAndSettle();

      expect(find.byType(GridView), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  test('the app theme carries the fade transition, not the default zoom', () {
    final builders = AppTheme.lightTheme.pageTransitionsTheme.builders;
    expect(
      builders[TargetPlatform.android],
      isA<LimsPageTransitionsBuilder>(),
    );
    // Cupertino stays on iOS so the edge-swipe back gesture survives.
    expect(
      builders[TargetPlatform.iOS],
      isA<CupertinoPageTransitionsBuilder>(),
    );
  });
}
