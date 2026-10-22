import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/inventory_provider.dart';
import '../../../core/data/notifications_provider.dart';
import '../../../core/data/sales_provider.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../../core/l10n/strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ui_kit.dart';
import 'dashboard_kit.dart';

/// The branch manager's home.
///
/// One branch, one day: today's takings from the sales ledger, the handset count
/// on the shelf, and the two numbers a manager is actually called about — stock
/// below minimum and loans past due. The console, the supervisor override and
/// the shift roster keep the routes they already had.
class BranchManagerDashboard extends ConsumerWidget {
  const BranchManagerDashboard({
    super.key,
    required this.onLowStockTap,
    required this.onSupervisorPin,
  });

  /// Opens the low-stock sheet that lives in HomeScreen, so the branch filter
  /// stays in one place.
  final VoidCallback onLowStockTap;

  /// The existing supervisor-PIN prompt. Passed in rather than copied here.
  final VoidCallback onSupervisorPin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final staff = ref.watch(activeStaffMemberProvider);
    final unread = ref.watch(unreadNotificationsProvider);
    final branch = ref.watch(activeBranchProvider);
    final takings = ref.watch(salesTodayTotalProvider);
    final receipts = ref.watch(salesTodayCountProvider);
    final handsets = ref.watch(totalPhonesCountProvider);
    final lowStock = ref.watch(lowStockCountProvider);
    final overdue =
        ref.watch(loansProvider).where((l) => l.status == 'overdue').length;

    return DashPage(
      children: [
        DashProfileRow(
          name: staff.name,
          asset: staff.avatarAsset,
          grad: staff.grad,
          unread: unread,
          onAvatarTap: () => context.push('/settings'),
          onBellTap: () => context.push('/notifications'),
        ),
        const SizedBox(height: 18),
        DashGreeting(
          locale: locale,
          roleLabel: tr(locale, 'role.branchManager'),
        ),
        const SizedBox(height: 20),
        DashFeatureCard(
          eyebrow: branch.isEmpty
              ? tr(locale, 'dash.branchToday')
              : '${tr(locale, 'dash.branchToday')} · $branch',
          icon: Icons.storefront_rounded,
          value: LimsFormatters.currency(takings),
          caption: trf(locale, 'dash.branchCaption', {
            'n': receipts,
            'stock': handsets,
          }),
          art: 'assets/images/icon_store_3d.png',
          gradient: const [Color(0xFF0C4BC4), Color(0xFF3E8BFF)],
          ctaLabel: tr(locale, 'dash.branchConsole'),
          onCta: () => context.push('/admin'),
        ),
        const SizedBox(height: 12),
        DashStatPair(
          leftIcon: Icons.inventory_2_outlined,
          leftLabel: tr(locale, 'dash.lowStockTile'),
          leftValue: '$lowStock',
          leftTint: const Color(0xFFFFF3E8),
          leftColor: const Color(0xFFE08A24),
          onLeftTap: onLowStockTap,
          rightIcon: Icons.schedule_rounded,
          rightLabel: tr(locale, 'dash.overdueTile'),
          rightValue: '$overdue',
          rightTint: const Color(0xFFFFEDEE),
          rightColor: const Color(0xFFE5484D),
          onRightTap: () => context.go('/loans'),
        ),
        const SizedBox(height: 14),
        DashAiCard(
          locale: locale,
          onTap: () => context.push('/ai'),
        ),
        const SizedBox(height: 22),
        DashSectionHeader(
          title: tr(locale, 'dash.branchOps'),
          pill: tr(locale, 'role.branchManager'),
        ),
        const SizedBox(height: 12),
        DashActionGrid(
          actions: [
            DashAction(
              icon: Icons.assessment_rounded,
              tint: const Color(0xFFEAF2FF),
              iconColor: AppTheme.brand600,
              title: tr(locale, 'dash.salesAudit'),
              sub: tr(locale, 'dash.salesAuditSub'),
              route: '/reports',
            ),
            DashAction(
              icon: Icons.lock_open_rounded,
              tint: const Color(0xFFFFEDEE),
              iconColor: const Color(0xFFE5484D),
              title: tr(locale, 'dash.supervisorPin'),
              sub: tr(locale, 'dash.supervisorPinSub'),
              onTap: onSupervisorPin,
            ),
            DashAction(
              icon: Icons.store_mall_directory_rounded,
              tint: const Color(0xFFE6F7FE),
              iconColor: const Color(0xFF0EA5E9),
              title: tr(locale, 'dash.branchStock'),
              sub: tr(locale, 'dash.branchStockSub'),
              route: '/stock',
            ),
            DashAction(
              icon: Icons.access_time_filled_rounded,
              tint: const Color(0xFFE7F9EF),
              iconColor: const Color(0xFF15A34A),
              title: tr(locale, 'dash.staffShifts'),
              sub: tr(locale, 'dash.staffShiftsSub'),
              route: '/attendance',
            ),
          ],
        ),
      ],
    );
  }
}
