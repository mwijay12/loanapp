import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/inventory_provider.dart';
import '../../../core/data/notifications_provider.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../../core/l10n/strings.dart';
import '../../../core/theme/app_theme.dart';
import 'dashboard_kit.dart';

/// The auditor's home.
///
/// Inspection only. The four destinations here are registers that already exist
/// and are read-only by construction; there is deliberately no POS tile, no
/// approve button and no disbursement shortcut, because the role cannot do those
/// things. The figures shown are the same ledger totals every other role sees,
/// not a separate audit figure that could drift.
class AuditorDashboard extends ConsumerWidget {
  const AuditorDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final staff = ref.watch(activeStaffMemberProvider);
    final unread = ref.watch(unreadNotificationsProvider);
    final handsets = ref.watch(totalPhonesCountProvider);
    final openLoans =
        ref.watch(loansProvider).where((l) => l.status != 'cleared').length;

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
          roleLabel: tr(locale, 'role.auditor'),
        ),
        const SizedBox(height: 20),
        DashFeatureCard(
          eyebrow: tr(locale, 'dash.auditAccess'),
          icon: Icons.visibility_rounded,
          value: tr(locale, 'dash.readOnly'),
          caption: tr(locale, 'dash.auditBody'),
          art: 'assets/images/icon_shield_3d.png',
          gradient: const [Color(0xFF1B2537), Color(0xFF3C4F6B)],
        ),
        const SizedBox(height: 12),
        DashStatPair(
          leftIcon: Icons.phone_android_rounded,
          leftLabel: tr(locale, 'home.totalStock'),
          leftValue: '$handsets',
          leftTint: const Color(0xFFEAF2FF),
          leftColor: AppTheme.brand600,
          onLeftTap: () => context.push('/stock'),
          rightIcon: Icons.people_outline_rounded,
          rightLabel: tr(locale, 'home.activeLoans'),
          rightValue: '$openLoans',
          rightTint: const Color(0xFFF1EBFF),
          rightColor: const Color(0xFF7C5CFC),
          onRightTap: () => context.go('/loans'),
        ),
        const SizedBox(height: 14),
        DashAiCard(
          locale: locale,
          onTap: () => context.push('/ai'),
        ),
        const SizedBox(height: 22),
        DashSectionHeader(
          title: tr(locale, 'dash.auditBooks'),
          pill: tr(locale, 'role.auditor'),
        ),
        const SizedBox(height: 12),
        DashActionGrid(
          actions: [
            DashAction(
              icon: Icons.receipt_long_rounded,
              tint: const Color(0xFFEAF2FF),
              iconColor: AppTheme.brand600,
              title: tr(locale, 'dash.salesRegister'),
              sub: tr(locale, 'dash.salesRegisterSub'),
              route: '/reports',
            ),
            DashAction(
              icon: Icons.account_balance_wallet_rounded,
              tint: const Color(0xFFF1EBFF),
              iconColor: const Color(0xFF7C5CFC),
              title: tr(locale, 'dash.loanLedger'),
              sub: tr(locale, 'dash.loanLedgerSub'),
              onTap: () => context.go('/loans'),
            ),
            DashAction(
              icon: Icons.shelves,
              tint: const Color(0xFFE6F7FE),
              iconColor: const Color(0xFF0EA5E9),
              title: tr(locale, 'dash.stockRegister'),
              sub: tr(locale, 'dash.stockRegisterSub'),
              route: '/stock',
            ),
            DashAction(
              icon: Icons.qr_code_scanner_rounded,
              tint: const Color(0xFFE7F9EF),
              iconColor: const Color(0xFF15A34A),
              title: tr(locale, 'dash.imeiInspector'),
              sub: tr(locale, 'dash.imeiInspectorSub'),
              route: '/imei-inspector',
            ),
          ],
        ),
      ],
    );
  }
}
