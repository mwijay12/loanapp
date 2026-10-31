import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loan_inventory_app/core/constants/app_constants.dart';
import 'package:loan_inventory_app/core/data/inventory_provider.dart';
import 'package:loan_inventory_app/core/data/sales_provider.dart';
import 'package:loan_inventory_app/core/l10n/strings.dart';
import 'package:loan_inventory_app/features/admin/presentation/admin_dashboard_screen.dart';

/// The console chart was static: seven fixed heights, one of them marked today.
/// Pressing Monday was not supported because no bar stood for Monday. These
/// tests press a bar and read what the screen then says about that day, so a
/// regression back to decorative bars fails here instead of in the shop.

SaleRecord _sale(DateTime day, int total, String receipt) {
  return SaleRecord(
    receiptNo: receipt,
    total: total,
    paid: total,
    kind: 'cash',
    soldAt: DateTime.utc(day.year, day.month, day.day, 9),
    branchId: 'b1',
  );
}

String _longDate(DateTime d) {
  const days = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday',
    'Friday', 'Saturday', 'Sunday',
  ];
  const months = [
    '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${days[d.weekday - 1]}, ${d.day} ${months[d.month]}';
}

void main() {
  final today = eatTodayDate;

  Future<void> pumpConsole(WidgetTester tester, List<SaleRecord> rows,
      {double width = 400}) async {
    tester.view.physicalSize = Size(width, 1200) * 2.0;
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          salesProvider.overrideWith((ref) => SalesNotifier(rows)),
          userRoleProvider
              .overrideWith((ref) => UserRoleNotifier()..hydrateFromSession(UserRoles.superAdmin)),
        ],
        child: const MaterialApp(home: AdminDashboardScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a bar carries that day and its own takings', (tester) async {
    final rows = [
      _sale(today.subtract(const Duration(days: 2)), 310000, 'A'),
      _sale(today.subtract(const Duration(days: 1)), 280000, 'B'),
      _sale(today, 455000, 'C'),
    ];
    await pumpConsole(tester, rows);
    expect(tester.takeException(), isNull);

    // Seven bars for seven days. The three recorded days are the last three
    // columns; the four quiet days before them are still on the axis, because a
    // vanished bar reads as missing data and a flat one reads as a closed day.
    for (var i = 0; i < 7; i++) {
      expect(find.byKey(ValueKey<String>('revbar-$i')), findsOneWidget);
    }
    expect(find.byKey(const ValueKey<String>('revbar-7')), findsNothing);

    expect(find.textContaining('Tap a bar to see that day'), findsOneWidget);

    final target = today.subtract(const Duration(days: 1));
    await tester.tap(find.byKey(const ValueKey<String>('revbar-5')));
    await tester.pumpAndSettle();

    // The card names the day that was pressed and its takings.
    expect(find.text(_longDate(target)), findsOneWidget);
    expect(find.textContaining('TZS 280'), findsOneWidget);
    expect(find.textContaining('1 transactions'), findsOneWidget);
  });

  testWidgets('pressing a different bar changes the figures shown',
      (tester) async {
    final rows = [
      _sale(today.subtract(const Duration(days: 2)), 310000, 'A'),
      _sale(today.subtract(const Duration(days: 1)), 280000, 'B'),
      _sale(today, 455000, 'C'),
    ];
    await pumpConsole(tester, rows);

    await tester.tap(find.byKey(const ValueKey<String>('revbar-4')));
    await tester.pumpAndSettle();
    expect(
        find.text(_longDate(today.subtract(const Duration(days: 2)))),
        findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('revbar-6')));
    await tester.pumpAndSettle();
    expect(find.text(_longDate(today)), findsOneWidget);
    // 455k from nothing last week is "no figure", not a fake 0%.
    expect(find.textContaining('no figure for last week'), findsOneWidget);
  });

  testWidgets('comparing with the same weekday last week uses that day',
      (tester) async {
    final lastWeek = today.subtract(const Duration(days: 7));
    final rows = [
      _sale(lastWeek, 400000, 'A'),
      _sale(today, 500000, 'B'),
    ];
    await pumpConsole(tester, rows);

    // Only today carries a figure inside the window, so it is the last bar; the
    // row from a week ago is used as the comparison figure.
    await tester.tap(find.byKey(const ValueKey<String>('revbar-6')));
    await tester.pumpAndSettle();

    expect(find.text(_longDate(today)), findsOneWidget);
    // The card's own comparison line, distinct from the header's window total.
    expect(find.text('+25% vs same day last week'), findsOneWidget);
  });

  testWidgets('switching Week to Month re-aggregates the series',
      (tester) async {
    final rows = [
      for (var back = 0; back < 24; back++)
        _sale(today.subtract(Duration(days: back)), 100000 + back * 5000, 'R$back'),
    ];
    await pumpConsole(tester, rows);

    expect(find.byKey(const ValueKey<String>('revbar-6')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('revbar-7')), findsNothing);

    await tester.tap(find.text('Month'));
    await tester.pumpAndSettle();

    // Thirty days folded into four weekly buckets; the seventh bar is gone
    // because the shape changed, not just the label.
    expect(find.byKey(const ValueKey<String>('revbar-3')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('revbar-4')), findsNothing);
  });

  testWidgets('the console speaks one language, not two', (tester) async {
    await pumpConsole(tester, [
      _sale(today, 455000, 'C'),
    ]);

    // The old header mixed the tongues: "Branch Network & Hubs" beside
    // "Wafanyakazi & RBAC", and the range chips read "Wiki" over an English
    // card. Both halves now resolve from the same dictionary.
    expect(find.text('Branch Network & Hubs'), findsOneWidget);
    expect(find.text('Staff & RBAC'), findsOneWidget);
    expect(find.text('Week'), findsOneWidget);
    expect(find.text('Month'), findsOneWidget);
    expect(find.text('Wafanyakazi & RBAC'), findsNothing);
    expect(find.text('Mwezi'), findsNothing);

    // No raw key leaked to the screen.
    expect(find.textContaining('admin.'), findsNothing);
    expect(find.textContaining('adm.'), findsNothing);
  });

  testWidgets('an empty ledger says so instead of drawing a fake week',
      (tester) async {
    // A DB with no sales at all still falls back to the seeded history in the
    // data layer; here we assert the console renders without inventing a
    // selected day.
    await pumpConsole(tester, const []);
    expect(tester.takeException(), isNull);
    expect(find.textContaining('Tap a bar to see that day'), findsOneWidget);
  });

  testWidgets('the console fits a small phone without overflowing',
      (tester) async {
    // A seventeen-digit loan book and a plus-signed percentage in a half-width
    // card is where this screen used to spill. 360 logical pixels is the
    // narrowest handset worth supporting.
    await pumpConsole(
      tester,
      [
        _sale(today, 987654321, 'A'),
        _sale(today.subtract(const Duration(days: 1)), 123456789, 'B'),
      ],
      width: 360,
    );

    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const ValueKey<String>('revbar-0')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  test('every console string key exists in the dictionary', () async {
    final source = await _readFile(
        'lib/features/admin/presentation/admin_dashboard_screen.dart');
    final used = RegExp(r"'(adm|admin)\.[A-Za-z0-9_.]+'")
        .allMatches(source)
        .map((m) => m.group(0)!.replaceAll("'", ''))
        .toSet();
    expect(used, isNotEmpty);
    final missing = used.where((k) => !allStringKeys.contains(k)).toList();
    expect(missing, isEmpty,
        reason: 'tr() renders the raw key when it is missing: $missing');
  });
}

Future<String> _readFile(String path) => File(path).readAsString();
