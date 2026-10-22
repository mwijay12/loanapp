import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loan_inventory_app/features/onboarding/presentation/onboarding_screen.dart';

/// The onboarding screen is the first thing a shopkeeper sees, on a phone that is
/// often a 360dp Android. A RenderFlex overflow there is not a cosmetic warning:
/// it is a yellow-striped first impression.
///
/// These tests pin the layout at the two sizes the shop actually uses, and check
/// that the plate grows with the artwork instead of cropping it into a circle.
void main() {
  Future<void> pumpAt(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size * 2.0;
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: OnboardingScreen()));
    await tester.pumpAndSettle();
  }

  testWidgets('390x844 shows the first slide without overflowing',
      (tester) async {
    await pumpAt(tester, const Size(390, 844));

    expect(tester.takeException(), isNull);
    expect(find.text('Every device, accounted for'), findsOneWidget);
    expect(find.text('100% AUDITABLE'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
  });

  testWidgets('360x640 keeps the headline and the button on screen',
      (tester) async {
    await pumpAt(tester, const Size(360, 640));

    expect(tester.takeException(), isNull);
    expect(find.text('Every device, accounted for'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
  });

  testWidgets('the artwork is a 3:2 plate, not a circular avatar',
      (tester) async {
    await pumpAt(tester, const Size(390, 844));

    final plate = find.byType(AspectRatio).first;
    final size = tester.getSize(plate);
    expect(size.width / size.height, closeTo(1.5, 0.02));

    // The cartoon mascot sat in a 160x160 circle; the plate is much wider.
    expect(size.width, greaterThan(280));
  });

  testWidgets('advancing reaches the third slide', (tester) async {
    await pumpAt(tester, const Size(390, 844));

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Loans without the chaos'), findsOneWidget);
    expect(find.text('Get started'), findsOneWidget);
  });
}
