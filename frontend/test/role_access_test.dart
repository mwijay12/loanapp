import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:loan_inventory_app/core/constants/app_constants.dart';
import 'package:loan_inventory_app/core/data/inventory_provider.dart';
import 'package:loan_inventory_app/core/l10n/locale_provider.dart';
import 'package:loan_inventory_app/core/theme/app_localizations.dart';
import 'package:loan_inventory_app/core/theme/app_theme.dart';
import 'package:loan_inventory_app/features/admin/presentation/admin_dashboard_screen.dart';

/// The console must look different to each role.
///
/// A Branch Manager was landing on "Admin Console" with the staff and RBAC tab
/// in reach, which implies a privilege the role does not hold. These tests pin
/// the boundary: managers get a branch console, admins get the full console, and
/// everyone else is told they have no access instead of seeing a trimmed copy.
void main() {
  Future<void> pumpAs(WidgetTester tester, String role) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userRoleProvider.overrideWith(
            (ref) => UserRoleNotifier()..hydrateFromSession(role),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          locale: const Locale('sw'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en'), Locale('sw')],
          home: const AdminDashboardScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('Branch Manager gets a branch console, not the admin console',
      (tester) async {
    await pumpAs(tester, UserRoles.branchManager);

    expect(find.text('Branch Console'), findsOneWidget);
    expect(find.text('Admin Console'), findsNothing);
    // The staff and RBAC tab is admin-only and must not be rendered at all.
    expect(find.text('Staff & RBAC'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Super Admin gets the admin console with the RBAC tab',
      (tester) async {
    await pumpAs(tester, UserRoles.superAdmin);

    expect(find.text('Admin Console'), findsOneWidget);
    expect(find.text('Branch Console'), findsNothing);
    expect(find.text('Staff & RBAC'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a Branch Manager cannot deep-link into the staff console',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userRoleProvider.overrideWith(
            (ref) =>
                UserRoleNotifier()..hydrateFromSession(UserRoles.branchManager),
          ),
        ],
        child: const MaterialApp(
          // The menu row that used to carry this link was shown to managers and
          // pushed /admin?tab=staff. The tab is now refused by role as well.
          home: AdminDashboardScreen(initialTab: 'staff'),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Staff directory & credentials'), findsNothing);
    expect(find.text('Branch Console'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a cashier is refused the console', (tester) async {
    await pumpAs(tester, UserRoles.counterCashier);

    expect(find.text('No console access'), findsOneWidget);
    expect(find.text('Admin Console'), findsNothing);
    expect(find.text('Staff & RBAC'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a loan officer is refused the console', (tester) async {
    await pumpAs(tester, UserRoles.loanOfficer);
    expect(find.text('No console access'), findsOneWidget);
  });

  testWidgets('the console follows the language setting as a whole',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final container = ProviderContainer(
      overrides: [
        userRoleProvider.overrideWith(
          (ref) => UserRoleNotifier()..hydrateFromSession(UserRoles.superAdmin),
        ),
        localeProvider.overrideWith((ref) => const Locale('sw')),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const AdminDashboardScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    // One language per screen: the whole card flips, rather than the heading
    // staying English while the chips turn Swahili.
    expect(find.text('Kituo cha Msimamizi'), findsOneWidget);
    expect(find.text('Mtandao wa Matawi'), findsOneWidget);
    expect(find.text('Wiki'), findsOneWidget);
    expect(find.text('Week'), findsNothing);
    expect(find.text('Mauzo ya leo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the revenue range switch is available on the network view',
      (tester) async {
    await pumpAs(tester, UserRoles.superAdmin);

    // English is the default locale, so the console must render English only -
    // the screen used to print "Wiki" and "Mwezi" inside an English card.
    expect(find.text('Week'), findsOneWidget);
    expect(find.text('Month'), findsOneWidget);
    expect(find.text('Wiki'), findsNothing);
    expect(find.textContaining('this week'), findsOneWidget);

    await tester.tap(find.text('Month'));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.textContaining('this month'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
