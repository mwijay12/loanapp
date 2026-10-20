import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:loan_inventory_app/core/constants/app_constants.dart';
import 'package:loan_inventory_app/core/theme/app_theme.dart';
import 'package:loan_inventory_app/features/onboarding/presentation/onboarding_screen.dart';

// The generated counter test that used to live here pumped the real app and
// asserted a `+` button, so it failed as soon as the app stopped being the
// template. These check something the product actually promises.

void main() {
  testWidgets('onboarding renders its first slide and the primary action',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.lightTheme, home: const OnboardingScreen()),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Every device, accounted for'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('every role resolves to a portrait asset', (tester) async {
    for (final role in [
      UserRoles.superAdmin,
      UserRoles.branchManager,
      UserRoles.loanOfficer,
      UserRoles.storekeeper,
      UserRoles.counterCashier,
      UserRoles.auditor,
    ]) {
      expect(UserRoles.avatarAsset(role), startsWith('assets/images/avatar_'));
    }
    // A role we do not recognise still gets a tile rather than an empty circle.
    expect(UserRoles.avatarAsset('unknown role'), isNotEmpty);
  });
}
