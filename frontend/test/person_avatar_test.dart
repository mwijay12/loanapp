import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loan_inventory_app/core/widgets/person_avatar.dart';

/// The fault these tests lock down: a person with no portrait was shown the
/// photo of whoever holds their job title. A new storekeeper became the demo
/// storekeeper's face, and "Baraka Mushi" was greeted as a woman.
void main() {
  const grad = [Color(0xFF1E60F2), Color(0xFF7C3AED)];

  Future<void> pump(WidgetTester tester, String? asset) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PersonAvatar(name: 'Staff Member', asset: asset, grad: grad),
      ),
    ));
    await tester.pump();
  }

  testWidgets('a person with no portrait shows their initials', (tester) async {
    await pump(tester, null);

    expect(find.text('SM'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('a person with a portrait shows the picture, not initials',
      (tester) async {
    await pump(tester, 'assets/images/avatar_person_m30.png');

    expect(find.byType(Image), findsOneWidget);
    expect(find.text('SM'), findsNothing);
  });

  testWidgets('the tile is square when a radius is given', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: PersonAvatar(
          name: 'Amina Komba',
          grad: grad,
          radius: 14,
          size: 40,
        ),
      ),
    ));

    expect(tester.getSize(find.byType(PersonAvatar)), const Size(40, 40));
    expect(find.text('AK'), findsOneWidget);
  });
}
