import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:loan_inventory_app/core/motion/motion.dart';
import 'package:loan_inventory_app/core/motion/motion_widgets.dart';

/// Motion is only worth having if it ends. These four tests are the contract the
/// rest of the app relies on: everything settles, the settled value is the real one,
/// and the OS "reduce motion" switch genuinely stops it rather than shortening it.
/// A host with just enough of a widget tree for these widgets to build, and a
/// `MediaQuery` we can dial the reduce-motion flag on and off in.
Widget _host(Widget child, {bool reduce = false}) => MediaQuery(
      data: const MediaQueryData().copyWith(disableAnimations: reduce),
      child: Directionality(textDirection: TextDirection.ltr, child: child),
    );

void main() {
  tearDown(() {
    // The flag is process-wide on purpose (a test harness and nothing else), so it
    // must not leak into the next file that runs in the same isolate.
    Motion.ambientEnabled = true;
  });

  testWidgets('a metric counts to the figure and stops there', (tester) async {
    await tester.pumpWidget(_host(
      CountUp(
        value: 166,
        builder: (v) => Text(v.toInt().toString()),
      ),
    ));

    await tester.pump(const Duration(milliseconds: 120));
    // Mid-flight the widget is showing something smaller than the answer. If this
    // ever stops being true the count-up is decoration, not motion.
    expect(find.text('166'), findsNothing);

    await tester.pumpAndSettle();
    expect(find.text('166'), findsOneWidget);
  });

  testWidgets('a change of figure animates from the previous one',
      (tester) async {
    await tester.pumpWidget(_host(
      CountUp(
        key: const ValueKey('n'),
        value: 166,
        builder: (v) => Text(v.toInt().toString()),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('166'), findsOneWidget);

    await tester.pumpWidget(_host(
      CountUp(
        key: const ValueKey('n'),
        value: 266,
        builder: (v) => Text(v.toInt().toString()),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.text('266'), findsNothing);
    expect(find.textContaining('2'), findsWidgets);

    await tester.pumpAndSettle();
    expect(find.text('266'), findsOneWidget);
  });

  testWidgets('reduce motion shows the final figure on the first frame',
      (tester) async {
    await tester.pumpWidget(_host(
      CountUp(value: 166, builder: (v) => Text(v.toInt().toString())),
      reduce: true,
    ));

    // No pumping to a settle: the value has to be right immediately, because the
    // person who turned animations off asked not to wait for anything.
    expect(find.text('166'), findsOneWidget);
  });

  testWidgets('an entrance never hides its child from the tree',
      (tester) async {
    await tester.pumpWidget(_host(
      const Entrance(
        delay: Duration(milliseconds: 200),
        child: Text('shelf', key: Key('payload')),
      ),
    ));

    // Mid-flight the text exists (opacity and translate, not visibility), so a
    // screen reader and a test can both still find it - only the eye waits.
    expect(find.byKey(const Key('payload')), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('shelf'), findsOneWidget);
  });

  testWidgets('a chart bar grows to its fraction and stays', (tester) async {
    double? seen;
    await tester.pumpWidget(_host(
      GrowFraction(
        value: 0.5,
        delay: const Duration(milliseconds: 80),
        builder: (f) {
          seen = f;
          return const SizedBox(width: 8, height: 8);
        },
      ),
    ));
    await tester.pump(const Duration(milliseconds: 40));
    expect(seen, lessThan(0.5));

    await tester.pumpAndSettle();
    expect(seen, closeTo(0.5, 0.0001));
  });

  testWidgets('Motion.ambientEnabled=false stops everything, for harnesses',
      (tester) async {
    Motion.ambientEnabled = false;
    await tester.pumpWidget(_host(
      CountUp(value: 166, builder: (v) => Text(v.toInt().toString())),
    ));
    expect(find.text('166'), findsOneWidget);
  });
}
