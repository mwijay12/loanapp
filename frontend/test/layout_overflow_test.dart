import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:loan_inventory_app/core/constants/app_constants.dart';
import 'package:loan_inventory_app/core/data/inventory_provider.dart';
import 'package:loan_inventory_app/core/theme/app_theme.dart';
import 'package:loan_inventory_app/features/admin/presentation/admin_dashboard_screen.dart';
import 'package:loan_inventory_app/features/notifications/presentation/notifications_screen.dart';
import 'package:loan_inventory_app/core/theme/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// Overflow guard for the narrowest phones we support.
///
/// A RenderFlex overflow is a layout assertion, so a widget test catches it
/// deterministically — no browser, no debug server. These run at 320 logical
/// pixels, below any phone the shop actually uses, so a pass here leaves room
/// for the wider devices.
void main() {
  Future<void> pumpAt(WidgetTester tester, Widget child, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // The admin screen is Super Admin only; without this it renders the
          // locked-out placeholder and the tab capsule never gets built.
          userRoleProvider.overrideWith((ref) => UserRoleNotifier()..hydrateFromSession(UserRoles.superAdmin)),
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
          home: child,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('admin dashboard lays out without overflow at 320px',
      (tester) async {
    await pumpAt(tester, const AdminDashboardScreen(), const Size(320, 568));
    expect(tester.takeException(), isNull);
  });

  testWidgets('notifications lay out without overflow at 320px',
      (tester) async {
    await pumpAt(tester, const NotificationsScreen(), const Size(320, 568));
    expect(tester.takeException(), isNull);
  });
}
