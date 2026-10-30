import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/inventory_provider.dart';
import '../../../core/data/notifications_provider.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../../core/l10n/strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ui_kit.dart';
import 'dashboard_kit.dart';

/// The loan officer's home.
///
/// The headline is the money still to collect, summed from `loansProvider` as
/// `amount × (100 − paid) ÷ 100` per open account. Nothing is smoothed: an empty
/// book reads TZS 0 and the arrears line says every account is on schedule.
///
/// Arrears are one tappable line, not a list. The list belongs in the loan book,
/// which is where the row goes — five borrower cards on the home screen only
/// pushed the credit actions below the fold.
class LoanOfficerDashboard extends ConsumerWidget {
  const LoanOfficerDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final staff = ref.watch(activeStaffMemberProvider);
    final unread = ref.watch(unreadNotificationsProvider);
    final loans = ref.watch(loansProvider);

    final open = loans.where((l) => l.status != 'cleared').toList();
    final overdue = open.where((l) => l.status == 'overdue').toList();
    final outstanding = open.fold<int>(
      0,
      (sum, l) => sum + l.remainingAmount,
    );
    final onTime = loans.isEmpty
        ? 0
        : (((loans.length - overdue.length) / loans.length) * 100).round();
    final overdueDue = overdue.fold<int>(
      0,
      (sum, l) => sum + l.remainingAmount,
    );

    return DashPage(
      header: DashHomeHeader(
        locale: locale,
        name: staff.name,
        asset: staff.avatarAsset,
        grad: staff.grad,
        unread: unread,
        roleLabel: tr(locale, 'role.loanOfficer'),
        onAvatarTap: () => context.push('/settings'),
        onBellTap: () => context.push('/notifications'),
      ),
      children: [
        DashFeatureCard(
          eyebrow: tr(locale, 'dash.creditOutstanding'),
          icon: Icons.account_balance_wallet_rounded,
          value: LimsFormatters.currency(outstanding),
          caption: trf(locale, 'dash.creditCaption', {
            'active': open.length,
            'overdue': overdue.length,
          }),
          art: 'assets/images/icon_credit_3d.png',
          gradient: const [Color(0xFF4C3BD6), Color(0xFF8B7BFF)],
          ctaLabel: tr(locale, 'dash.creditReview'),
          onCta: () => context.go('/loans'),
        ),
        const SizedBox(height: 12),
        DashStatPair(
          leftIcon: Icons.people_alt_rounded,
          leftLabel: tr(locale, 'home.activeLoans'),
          leftValue: '${open.length}',
          leftNumeric: open.length,
          leftTint: const Color(0xFFEAF2FF),
          leftColor: AppTheme.brand600,
          onLeftTap: () => context.go('/loans'),
          rightIcon: Icons.verified_rounded,
          rightLabel: tr(locale, 'dash.onTimeTile'),
          rightValue: '$onTime%',
          rightNumeric: onTime,
          rightFormat: (v) => '${v.toInt()}%',
          rightTint: const Color(0xFFE7F9EF),
          rightColor: const Color(0xFF15A34A),
          onRightTap: () => context.push('/reports'),
        ),
        const SizedBox(height: 14),
        DashAiCard(
          locale: locale,
          onTap: () => context.push('/ai'),
        ),
        const SizedBox(height: 22),
        DashSectionHeader(
          title: tr(locale, 'dash.creditOps'),
          pill: tr(locale, 'role.loanOfficer'),
        ),
        const SizedBox(height: 12),
        DashActionGrid(
          actions: [
            DashAction(
              icon: Icons.badge_outlined,
              tint: const Color(0xFFF1EBFF),
              iconColor: const Color(0xFF7C5CFC),
              title: tr(locale, 'dash.issueLoan'),
              sub: tr(locale, 'dash.issueLoanSub'),
              route: '/sell-loan?type=LOAN',
            ),
            DashAction(
              icon: Icons.assignment_turned_in_rounded,
              tint: const Color(0xFFE7F9EF),
              iconColor: const Color(0xFF15A34A),
              title: tr(locale, 'dash.creditReviewTile'),
              sub: tr(locale, 'dash.creditReviewSub'),
              onTap: () => context.go('/loans'),
            ),
            DashAction(
              icon: Icons.qr_code_scanner_rounded,
              tint: const Color(0xFFE6F7FE),
              iconColor: const Color(0xFF0EA5E9),
              title: tr(locale, 'dash.inspector'),
              sub: tr(locale, 'dash.inspectorSub'),
              route: '/scan',
            ),
            DashAction(
              icon: Icons.notifications_active_rounded,
              tint: const Color(0xFFFFF3E8),
              iconColor: const Color(0xFFE08A24),
              title: tr(locale, 'dash.collections'),
              sub: tr(locale, 'dash.collectionsSub'),
              onTap: () => context.go('/loans'),
            ),
          ],
        ),
        const SizedBox(height: 18),
        DashAlertRow(
          icon:
              overdue.isEmpty ? Icons.verified_rounded : Icons.schedule_rounded,
          tint: overdue.isEmpty
              ? const Color(0xFFE7F9EF)
              : const Color(0xFFFFEDEE),
          iconColor: overdue.isEmpty
              ? const Color(0xFF15A34A)
              : const Color(0xFFE5484D),
          title: tr(locale, 'dash.dueBook'),
          sub: overdue.isEmpty
              ? tr(locale, 'dash.dueClearSub')
              : trf(locale, 'dash.dueAlertSub', {
                  'amount': LimsFormatters.currency(overdueDue),
                }),
          count: overdue.isEmpty ? null : '${overdue.length}',
          onTap: () => context.go('/loans'),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
