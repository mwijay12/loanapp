import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:loan_inventory_app/core/constants/app_constants.dart';
import 'package:loan_inventory_app/core/data/inventory_provider.dart';
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
    expect(find.text('Wafanyakazi & RBAC'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Super Admin gets the admin console with the RBAC tab',
      (tester) async {
    await pumpAs(tester, UserRoles.superAdmin);

    expect(find.text('Admin Console'), findsOneWidget);
    expect(find.text('Branch Console'), findsNothing);
    expect(find.text('Wafanyakazi & RBAC'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a cashier is refused the console', (tester) async {
    await pumpAs(tester, UserRoles.counterCashier);

    expect(find.text('Huna ruhusa ya console'), findsOneWidget);
    expect(find.text('Admin Console'), findsNothing);
    expect(find.text('Wafanyakazi & RBAC'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a loan officer is refused the console', (tester) async {
    await pumpAs(tester, UserRoles.loanOfficer);
    expect(find.text('Huna ruhusa ya console'), findsOneWidget);
  });

  testWidgets('the revenue range switch is available on the network view',
      (tester) async {
    await pumpAs(tester, UserRoles.superAdmin);

    expect(find.text('Wiki'), findsOneWidget);
    expect(find.text('Mwezi'), findsOneWidget);
    expect(find.textContaining('this week'), findsOneWidget);

    await tester.tap(find.text('Mwezi'));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.textContaining('this month'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
