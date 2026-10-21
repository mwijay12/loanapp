import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:loan_inventory_app/core/constants/app_constants.dart';
import 'package:loan_inventory_app/core/data/inventory_provider.dart';
import 'package:loan_inventory_app/core/l10n/locale_provider.dart';
import 'package:loan_inventory_app/core/l10n/strings.dart';
import 'package:loan_inventory_app/core/theme/app_localizations.dart';
import 'package:loan_inventory_app/core/theme/app_theme.dart';
import 'package:loan_inventory_app/features/home/presentation/home_screen.dart';

/// The home screen is the one screen every role opens first, and it used to be
/// long enough to hide its own actions below the fold. These tests hold two
/// promises: it lays out on a 320 px phone, and the header stays put while the
/// rest scrolls.
void main() {
  Future<void> pumpHome(
    WidgetTester tester,
    Locale locale, {
    String role = UserRoles.counterCashier,
    Size size = const Size(320, 568),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userRoleProvider.overrideWith(
            (ref) => UserRoleNotifier()..hydrateFromSession(role),
          ),
          localeProvider.overrideWith((ref) => locale),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          locale: locale,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en'), Locale('sw')],
          home: const HomeScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('lays out without overflow at 320px in English', (tester) async {
    await pumpHome(tester, const Locale('en'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('lays out without overflow at 320px in Kiswahili', (tester) async {
    await pumpHome(tester, const Locale('sw'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('lays out without overflow for every role', (tester) async {
    for (final role in const [
      UserRoles.superAdmin,
      UserRoles.branchManager,
      UserRoles.loanOfficer,
      UserRoles.storekeeper,
      UserRoles.counterCashier,
      UserRoles.auditor,
      UserRoles.pending,
    ]) {
      await pumpHome(tester, const Locale('sw'), role: role);
      expect(tester.takeException(), isNull, reason: 'role $role overflowed');
    }
  });

  testWidgets('the header stays while the body scrolls', (tester) async {
    await pumpHome(tester, const Locale('en'));

    // The branch pill lives in the pinned header.
    final branch = find.text(AppConstants.launchBranch);
    expect(branch, findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pump();

    // Still on screen after scrolling: the header is outside the scroll view.
    expect(branch, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('quick actions are labelled, not abbreviated codes', (tester) async {
    await pumpHome(tester, const Locale('en'));
    expect(find.text(tr(const Locale('en'), 'home.quickActions')), findsOneWidget);
    expect(find.text(tr(const Locale('en'), 'action.newSale')), findsOneWidget);
  });

  testWidgets('Kiswahili actually reaches the home strings', (tester) async {
    await pumpHome(tester, const Locale('sw'));
    expect(find.text(tr(const Locale('sw'), 'home.quickActions')), findsOneWidget);
    expect(find.text('Quick actions'), findsNothing);
  });
}
