import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loan_inventory_app/core/constants/app_constants.dart';
import 'package:loan_inventory_app/core/data/inventory_provider.dart';
import 'package:loan_inventory_app/core/data/mock_lims_data.dart';
import 'package:loan_inventory_app/core/data/sales_provider.dart';
import 'package:loan_inventory_app/core/l10n/locale_provider.dart';
import 'package:loan_inventory_app/core/theme/app_theme.dart';
import 'package:loan_inventory_app/features/ai/presentation/ai_screen.dart';
import 'package:loan_inventory_app/features/home/presentation/dashboard_kit.dart';
import 'package:loan_inventory_app/features/notifications/presentation/notifications_screen.dart';
import 'package:loan_inventory_app/features/settings/presentation/settings_screen.dart';

/// Sub-pages open from the role homes, so they have to look like they were
/// opened from the role homes.
///
/// Settings, Notifications and the assistant each grew their own white app bar
/// while every home ran on the shared gradient — three shades of the same
/// chrome, none of them matching the shell behind it. These tests pin the one
/// header they now share, and pin that an empty feed still reads honestly.

Future<ProviderContainer> _pump(
  WidgetTester tester,
  Widget screen, {
  List<ProductItem> products = const [],
  List<LoanItem> loans = const [],
  Locale locale = const Locale('en'),
}) async {
  tester.view.physicalSize = const Size(390, 900) * 2.0;
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);

  final container = ProviderContainer(
    overrides: [
      userRoleProvider.overrideWith(
        (ref) =>
            UserRoleNotifier()..hydrateFromSession(UserRoles.branchManager),
      ),
      signedInNameProvider.overrideWith((ref) => 'Neema Julius'),
      signedInBranchProvider.overrideWith((ref) => 'Mbagala Branch'),
      localeProvider.overrideWith((ref) => locale),
      inventoryProvider.overrideWith((ref) => InventoryNotifier(products)),
      loansProvider.overrideWith((ref) => LoansNotifier(loans)),
      salesProvider.overrideWith((ref) => SalesNotifier(const [])),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(theme: AppTheme.lightTheme, home: screen),
    ),
  );
  await tester.pump(const Duration(milliseconds: 400));
  return container;
}

void main() {
  group('sub-page chrome', () {
    testWidgets('notifications uses the shared header, not an app bar',
        (tester) async {
      await _pump(tester, const NotificationsScreen());

      expect(find.byType(DashPageHeader), findsOneWidget);
      expect(find.byType(AppBar), findsNothing);
      expect(find.text('Notifications'), findsOneWidget);
    });

    testWidgets('the assistant uses the shared header, not an app bar',
        (tester) async {
      await _pump(tester, const AIScreen());

      expect(find.byType(DashPageHeader), findsOneWidget);
      expect(find.byType(AppBar), findsNothing);
      expect(find.text('LIMS Assistant'), findsOneWidget);
      // The assistant says what it reads, and does not name a model it cannot
      // promise to be running.
      expect(find.text('Reads your shop data'), findsOneWidget);
      expect(find.textContaining('Mercury'), findsNothing);
    });

    testWidgets('settings uses the shared header, not an app bar',
        (tester) async {
      await _pump(tester, const SettingsScreen());

      expect(find.byType(DashPageHeader), findsOneWidget);
      expect(find.byType(AppBar), findsNothing);
      expect(find.text('Settings & Profile'), findsOneWidget);
    });
  });

  group('notifications honesty', () {
    testWidgets('an empty feed reads all read and offers no mark-all',
        (tester) async {
      await _pump(tester, const NotificationsScreen());

      expect(find.text('All read'), findsOneWidget);
      // Nothing to mark, so the action is not offered.
      expect(find.byTooltip('Mark all read'), findsNothing);
    });

    testWidgets('a quiet feed does not invent notifications', (tester) async {
      await _pump(tester, const NotificationsScreen());

      // The empty state is the only thing on the page: no row was invented.
      expect(find.textContaining('Nothing needs attention'), findsOneWidget);
    });
  });
}
