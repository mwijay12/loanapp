import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loan_inventory_app/core/data/inventory_provider.dart';
import 'package:loan_inventory_app/core/l10n/locale_provider.dart';
import 'package:loan_inventory_app/core/theme/app_theme.dart';
import 'package:loan_inventory_app/features/scanner/presentation/device_imei_inspector_screen.dart';

/// A verification tool that invents its verdict is worse than no tool.
///
/// The inspector used to open with an iPhone 15 Pro Max, a borrower called
/// Bakari Juma Mwambungu, a TZS 2,450,000 balance and a serial nobody had
/// scanned; it offered three "Mifano" IMEIs that produced a full inspection of
/// handsets that did not exist; and it printed four audit rows (a purchase order
/// at Kariakoo Main Hub, a signature, a disbursement, an instalment with an
/// M-Pesa code) that were typed into the widget. These tests pin the fix.

void main() {
  Future<void> pumpInspector(
    WidgetTester tester, {
    Locale locale = const Locale('en'),
    String? initialImei,
  }) async {
    tester.view.physicalSize = const Size(390, 900) * 2.0;
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localeProvider.overrideWith((ref) => locale),
          inventoryProvider.overrideWith((ref) => InventoryNotifier(const [])),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: DeviceImeiInspectorScreen(initialImei: initialImei),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('the screen opens empty instead of describing a made-up handset',
      (tester) async {
    await pumpInspector(tester);

    expect(find.text('iPhone 15 Pro Max'), findsNothing);
    expect(find.textContaining('Bakari Juma Mwambungu'), findsNothing);
    expect(find.textContaining('354928104829104'), findsNothing);
    expect(find.textContaining('Mifano'), findsNothing);
    // Nothing has been looked up, so nothing is claimed about a device.
    expect(find.text('Device audit trail'), findsNothing);
  });

  testWidgets('no sample serials are offered when no unit has one',
      (tester) async {
    await pumpInspector(tester);

    expect(find.textContaining('Serials on file'), findsNothing);
    expect(find.text('iPhone 15 Pro (Mkopo)'), findsNothing);
    expect(find.text('Redmi (Overdue Loan)'), findsNothing);
    expect(find.text('Galaxy A15 (Stoo)'), findsNothing);
  });

  testWidgets('an unknown serial is reported as unknown, not given a borrower',
      (tester) async {
    await pumpInspector(tester, initialImei: '356984112048591');
    await tester.pump(const Duration(milliseconds: 800));

    // The lookup never reaches the database in a widget test, so this is the
    // "not registered here" branch — and it must not borrow an identity.
    expect(find.textContaining('Bakari'), findsNothing);
    expect(find.textContaining('Selemani'), findsNothing);
    expect(find.textContaining('0754 892 314'), findsNothing);
  });

  testWidgets('the screen speaks one language when English is selected',
      (tester) async {
    await pumpInspector(tester, initialImei: '356984112048591');
    await tester.pump(const Duration(milliseconds: 800));

    for (final swahili in ['Kagua', 'Salio Lililobaki', 'Jalada la Mkopaji', 'Hali ya Waranti', 'Mifano']) {
      expect(find.text(swahili), findsNothing, reason: '$swahili leaked into an English session');
    }
    expect(find.text('Check'), findsOneWidget);
  });
}
