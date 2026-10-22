import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loan_inventory_app/features/transfers/presentation/transfer_screen.dart';

/// The old screen could be "sent" with three invented items and wrote stock off
/// the company. These tests pin the replacement's floor: with no serials on file
/// it explains itself instead of offering a fake transfer.
void main() {
  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844) * 2.0;
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(home: TransferScreen()),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('with no serials on file it says so, and cannot send',
      (tester) async {
    await pump(tester);

    expect(tester.takeException(), isNull);
    expect(find.textContaining('No serials at this branch yet'), findsOneWidget);

    // The primary action is inert until devices are selected.
    final button = tester.widget<FilledButton>(find.byType(FilledButton).last);
    expect(button.onPressed, isNull);
    expect(find.textContaining('Select devices to send'), findsOneWidget);
  });

  testWidgets('destination chips come from the branch list', (tester) async {
    await pump(tester);

    expect(find.text('Kariakoo'), findsOneWidget);
    expect(find.text('Mwanza'), findsOneWidget);
    expect(find.text('FROM'), findsOneWidget);
    expect(find.text('TO'), findsOneWidget);
  });
}
