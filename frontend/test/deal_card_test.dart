import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loan_inventory_app/core/widgets/phone_deals_carousel.dart';

/// The featured deal card on the till home.
///
/// The redesign moved the ROM, the colour and the unit count out of the text
/// column and onto one line at the foot of the card, on the right, directly
/// under the handset — the corner that used to be empty. The action pill took
/// the left end of that same strip. These tests pin the things that could
/// quietly regress: the line stays one line, it sits in the right half below
/// the picture, the action stays left, and the card still fits a 360-wide
/// phone without overflowing.

FeaturedPhoneDeal _deal() {
  return FeaturedPhoneDeal(
    id: 'deal_1',
    title: 'Infinix Zero 40',
    subtitle: 'Deposit TZS 196.5K · TZS 73.7K/wk',
    badge: 'IN STOCK',
    badgeBg: const Color(0x3322D3EE),
    badgeTextColor: const Color(0xFFA5F3FC),
    gradient: const [Color(0xFF0F766E), Color(0xFF14B8A6)],
    glowColor: const Color(0xFF14B8A6),
    spec: '256GB · Stardust Silver',
    units: '27 units',
    cashPrice: 'TZS 655K',
    monthlyDue: 'TZS 73.7K/wk',
    actionLabel: 'Issue Loan',
    onTap: () {},
  );
}

Future<void> _mount(WidgetTester tester, {double width = 390}) async {
  tester.view.physicalSize = Size(width, 844) * 2.0;
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Align(
            alignment: Alignment.topCenter,
            child: FeaturedPhoneDealCard(deal: _deal()),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the spec, the colour and the units share one line',
      (tester) async {
    await _mount(tester);

    final line = find.text('256GB · Stardust Silver · 27 units');
    expect(line, findsOneWidget);

    // One line, not three facts stacked: the painted box is a single row of
    // text, and the widget is told to ellipsize rather than wrap.
    final text = tester.widget<Text>(line);
    expect(text.maxLines, 1);
    expect(text.overflow, TextOverflow.ellipsis);
    expect(tester.getSize(line).height, lessThan(18));

    // The old arrangement put "27 units" in its own glass chip.
    expect(find.text('27 units'), findsNothing);
  });

  testWidgets('the line sits under the handset, level with the action',
      (tester) async {
    await _mount(tester);

    final card = tester.getRect(find.byType(FeaturedPhoneDealCard));
    final line = tester.getRect(find.text('256GB · Stardust Silver · 27 units'));
    final cta = tester.getRect(find.text('Issue Loan'));

    // Level with the CTA: one bottom strip, not a stacked block.
    expect((line.center.dy - cta.center.dy).abs(), lessThan(10));
    // Below the vertical middle, i.e. under the picture rather than beside it.
    expect(line.top, greaterThan(card.center.dy - 20));
    // In the right half — the strip under the handset, not the text column.
    expect(line.left, greaterThan(card.center.dx));
    // The action owns the left end of that strip.
    expect(cta.left, lessThan(card.center.dx));
    // Still inside the card.
    expect(line.bottom, lessThan(card.bottom));
    expect(line.right, lessThanOrEqualTo(card.right));
  });

  testWidgets('the badge states the status, the line carries the count',
      (tester) async {
    await _mount(tester);

    expect(find.text('IN STOCK'), findsOneWidget);
    expect(find.textContaining('IN STOCK'), findsOneWidget);
  });

  testWidgets('the card is the height the carousel gives it', (tester) async {
    await _mount(tester);

    expect(kDealCardHeight, 158);
    expect(
      tester.getSize(find.byType(FeaturedPhoneDealCard)).height,
      kDealCardHeight,
    );
  });

  testWidgets('fits a 360-wide phone without overflowing', (tester) async {
    await _mount(tester, width: 360);

    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byType(FeaturedPhoneDealCard)).width,
      lessThanOrEqualTo(360),
    );
  });
}
