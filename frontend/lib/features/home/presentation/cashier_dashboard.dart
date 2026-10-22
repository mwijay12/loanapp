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
import 'featured_deals_section.dart';

/// The counter cashier's home.
///
/// Same shell language as the storekeeper screen — one card that carries the
/// day's real figure, the AI shortcut, then the POS actions as a two-column
/// grid. The till figure is today's takings from `public.sales`, counted on the
/// East Africa shop day, so a quiet morning reads zero instead of yesterday's
/// total. A sale appears in the register list below the moment the till writes
/// it.
class CashierDashboard extends ConsumerWidget {
  const CashierDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final staff = ref.watch(activeStaffMemberProvider);
    final unread = ref.watch(unreadNotificationsProvider);
    final takings = ref.watch(salesTodayTotalProvider);
    final receipts = ref.watch(salesTodayCountProvider);
    final todaysSales = ref
        .watch(salesProvider)
        .where((s) => isEatToday(s.soldAt))
        .toList()
      ..sort((a, b) => b.soldAt.compareTo(a.soldAt));

    return DashPage(
      header: DashHomeHeader(
        locale: locale,
        name: staff.name,
        asset: staff.avatarAsset,
        grad: staff.grad,
        unread: unread,
        roleLabel: tr(locale, 'role.counterCashier'),
        onAvatarTap: () => context.push('/settings'),
        onBellTap: () => context.push('/notifications'),
      ),
      children: [
        DashFeatureCard(
          eyebrow: tr(locale, 'dash.cashTill'),
          icon: Icons.point_of_sale_rounded,
          value: LimsFormatters.currency(takings),
          caption: trf(locale, 'dash.cashSales', {'n': receipts}),
          art: 'assets/images/icon_pos_3d.png',
          gradient: const [Color(0xFF1550D8), Color(0xFF4C9BFF)],
          ctaLabel: tr(locale, 'dash.newSale'),
          onCta: () => context.push('/sell-loan'),
        ),
        const SizedBox(height: 18),
        // Back on the counter home: what the shop owner wants pushed today.
        const FeaturedDealsSection(),
        const SizedBox(height: 14),
        DashAiCard(
          locale: locale,
          onTap: () => context.push('/ai'),
        ),
        const SizedBox(height: 22),
        DashSectionHeader(
          title: tr(locale, 'dash.counter'),
          pill: tr(locale, 'role.counterCashier'),
        ),
        const SizedBox(height: 12),
        DashActionGrid(
          actions: [
            DashAction(
              icon: Icons.point_of_sale_rounded,
              tint: const Color(0xFFEAF2FF),
              iconColor: AppTheme.brand600,
              title: tr(locale, 'dash.newSale'),
              sub: tr(locale, 'dash.newSaleSub'),
              route: '/sell-loan',
            ),
            DashAction(
              icon: Icons.folder_shared_rounded,
              tint: const Color(0xFFF1EBFF),
              iconColor: const Color(0xFF7C5CFC),
              title: tr(locale, 'dash.customers'),
              sub: tr(locale, 'dash.customersSub'),
              onTap: () => context.go('/loans'),
            ),
            DashAction(
              icon: Icons.qr_code_scanner_rounded,
              tint: const Color(0xFFE6F7FE),
              iconColor: const Color(0xFF0EA5E9),
              title: tr(locale, 'dash.scanCabinet'),
              sub: tr(locale, 'dash.scanCabinetSub'),
              route: '/scan',
            ),
            DashAction(
              icon: Icons.access_time_filled_rounded,
              tint: const Color(0xFFE7F9EF),
              iconColor: const Color(0xFF15A34A),
              title: tr(locale, 'dash.clockShift'),
              sub: tr(locale, 'dash.clockShiftSub'),
              route: '/attendance',
            ),
          ],
        ),
        const SizedBox(height: 22),
        DashSectionHeader(
          title: tr(locale, 'dash.register'),
          pill: '$receipts',
        ),
        const SizedBox(height: 12),
        DashListCard(
          emptyIcon: Icons.receipt_long_rounded,
          emptyText: tr(locale, 'dash.registerEmpty'),
          children: [
            for (final s in todaysSales.take(6))
              DashListRow(
                icon: s.isCash
                    ? Icons.payments_rounded
                    : Icons.assignment_rounded,
                tint: s.isCash
                    ? const Color(0xFFE7F9EF)
                    : const Color(0xFFF1EBFF),
                iconColor: s.isCash
                    ? const Color(0xFF15A34A)
                    : const Color(0xFF7C5CFC),
                title: s.receiptNo.isEmpty ? '—' : s.receiptNo,
                sub: [
                  tr(locale, s.isCash ? 'dash.cash' : 'dash.loanKind'),
                  if ((s.customerName ?? '').isNotEmpty) s.customerName!,
                ].join(' · '),
                trailing: LimsFormatters.currency(s.paid),
              ),
          ],
        ),
      ],
    );
  }
}
