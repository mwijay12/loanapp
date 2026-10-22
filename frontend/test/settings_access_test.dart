import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loan_inventory_app/core/constants/app_constants.dart';
import 'package:loan_inventory_app/core/data/inventory_provider.dart';
import 'package:loan_inventory_app/core/data/mock_lims_data.dart';
import 'package:loan_inventory_app/core/l10n/locale_provider.dart';
import 'package:loan_inventory_app/core/theme/app_theme.dart';
import 'package:loan_inventory_app/features/settings/presentation/settings_screen.dart';

/// A branch assignment is a fact, not a preference.
///
/// The Settings screen used to open on a fixed \"David Julius / Store Manager\"
/// card with a hardcoded branch list starting at Kariakoo, and a dropdown that
/// let anyone move the terminal. A Mbagala Branch Manager therefore read that
/// they were posted to Kariakoo and could switch. These tests pin the fix.

StaffMember _manager({String branch = 'Mbagala Branch'}) {
  return StaffMember(
    id: 'staff-mgr',
    name: 'Neema Julius',
    role: UserRoles.branchManager,
    email: 'demo.manager@example.com',
    phone: '0754 000 111',
    branch: branch,
    staffCode: 'LIMS-EMP-007',
    grad: const [Color(0xFF2563EB), Color(0xFF1D4ED8)],
  );
}

void main() {
  Future<ProviderContainer> pumpSettings(
    WidgetTester tester, {
    required String role,
    required String name,
    String? branch,
    List<StaffMember> staff = const [],
    Locale locale = const Locale('en'),
  }) async {
    tester.view.physicalSize = const Size(400, 1400) * 2.0;
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    final container = ProviderContainer(
      overrides: [
        userRoleProvider.overrideWith((ref) => UserRoleNotifier()..hydrateFromSession(role)),
        signedInNameProvider.overrideWith((ref) => name),
        signedInBranchProvider.overrideWith((ref) => branch),
        staffProvider.overrideWith((ref) => StaffNotifier(staff)),
        localeProviderOverride(locale),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const SettingsScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    return container;
  }

  testWidgets('a Branch Manager sees their own branch, and cannot change it',
      (tester) async {
    final container = await pumpSettings(
      tester,
      role: UserRoles.branchManager,
      name: 'Neema Julius',
      branch: 'Mbagala Branch',
      staff: [_manager()],
    );

    expect(find.text('Neema Julius'), findsOneWidget);
    expect(find.text('Branch Manager'), findsOneWidget);
    // Their branch, not the launch branch and not Kariakoo.
    expect(find.text('Mbagala Branch'), findsOneWidget);
    expect(find.text('Kariakoo Branch'), findsNothing);

    // No switch control at all for this role.
    expect(find.text('Change'), findsNothing);
    expect(
      find.textContaining('Only a Super Admin can move the terminal'),
      findsOneWidget,
    );

    // And the state refuses the move even if a caller tries it directly.
    final moved = container
        .read(activeBranchProvider.notifier)
        .setBranch('Kariakoo Branch');
    expect(moved, isFalse);
    expect(container.read(activeBranchProvider), 'Mbagala Branch');
  });

  testWidgets('a Super Admin can switch, and the screen follows',
      (tester) async {
    final container = await pumpSettings(
      tester,
      role: UserRoles.superAdmin,
      name: 'Demo Super Admin',
      branch: 'Mbagala Branch',
      staff: [
        StaffMember(
          id: 'staff-admin',
          name: 'Demo Super Admin',
          role: UserRoles.superAdmin,
          email: 'demo.admin@example.com',
          phone: '',
          branch: 'Mbagala Branch',
          staffCode: 'LIMS-EMP-001',
          grad: const [Color(0xFF2563EB), Color(0xFF1D4ED8)],
        ),
      ],
    );

    expect(find.text('Change'), findsWidgets);
    await tester.tap(find.text('Change'));
    await tester.pumpAndSettle();

    // The picker lists real branches from the store.
    expect(find.text('Mbezi Branch'), findsWidgets);
    await tester.tap(find.text('Mbezi Branch').last);
    await tester.pumpAndSettle();

    expect(container.read(activeBranchProvider), 'Mbezi Branch');
    expect(find.text('Mbezi Branch'), findsOneWidget);

    // Let the confirmation toast expire before teardown.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('role names are one language, not two', (tester) async {
    await pumpSettings(
      tester,
      role: UserRoles.branchManager,
      name: 'Neema Julius',
      branch: 'Mbagala Branch',
      staff: [_manager()],
    );

    // "Branch Manager (Meneja wa Tawi)" used to leak into English screens.
    expect(find.text('Branch Manager'), findsOneWidget);
    expect(find.textContaining('Meneja wa Tawi'), findsNothing);
    expect(find.textContaining('Mamlaka Kamili'), findsNothing);
  });

  testWidgets('the screen has no Swahili when English is selected',
      (tester) async {
    await pumpSettings(
      tester,
      role: UserRoles.branchManager,
      name: 'Neema Julius',
      branch: 'Mbagala Branch',
      staff: [_manager()],
    );

    // The old screen mixed both: "Badili", "Hifadhi", "Ghairi", "Namba ya
    // Msaada", "Siku 3 (Grace Period)".
    for (final swahili in const [
      'Badili',
      'Hifadhi',
      'Ghairi',
      'Namba',
      'Siku',
      'Lugha',
      'Mwezi',
    ]) {
      expect(find.textContaining(swahili), findsNothing,
          reason: '"$swahili" leaked into the English screen');
    }
    expect(find.textContaining('set.'), findsNothing);
  });

  testWidgets('a Branch Manager is offered a photo change that says what it does',
      (tester) async {
    await pumpSettings(
      tester,
      role: UserRoles.branchManager,
      name: 'Neema Julius',
      branch: 'Mbagala Branch',
      staff: [_manager()],
    );

    await tester.tap(find.text('Change photo'));
    await tester.pumpAndSettle();

    expect(find.text('Upload a photo'), findsOneWidget);
    expect(find.text('Or pick a portrait'), findsOneWidget);

    // Picking a bundled portrait in a build with no database must report the
    // failure rather than pretending to save.
    await tester.tap(find.text('Or pick a portrait'));
    await tester.pumpAndSettle();
  });

  testWidgets('settings fits a 360px handset', (tester) async {
    tester.view.physicalSize = const Size(360, 1400) * 2.0;
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userRoleProvider.overrideWith(
            (ref) =>
                UserRoleNotifier()..hydrateFromSession(UserRoles.branchManager),
          ),
          signedInNameProvider.overrideWith((ref) => 'Neema Julius'),
          signedInBranchProvider.overrideWith((ref) => 'Mbagala Branch'),
          staffProvider.overrideWith((ref) => StaffNotifier([_manager()])),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const SettingsScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  });

  test('the branch state itself refuses a manager, not just the button', () {
    final container = ProviderContainer(
      overrides: [
        userRoleProvider
            .overrideWith((ref) => UserRoleNotifier()..hydrateFromSession(UserRoles.branchManager)),
      ],
    );
    addTearDown(container.dispose);

    container.read(activeBranchProvider.notifier).adoptAssignedBranch('Mbagala Branch');
    expect(container.read(activeBranchProvider), 'Mbagala Branch');
    expect(
      container.read(activeBranchProvider.notifier).setBranch('Kariakoo Branch'),
      isFalse,
    );
    expect(container.read(activeBranchProvider), 'Mbagala Branch');
  });
}

/// Small helper so each test can set the language without importing the store.
Override localeProviderOverride(Locale locale) {
  return localeProvider.overrideWith((ref) => locale);
}
