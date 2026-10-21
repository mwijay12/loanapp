import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/data/branch_provider.dart';
import '../../../core/data/inventory_provider.dart';
import '../../../core/data/mock_lims_data.dart';
import '../../../core/data/sales_provider.dart';
import '../../../core/data/supabase_source.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../../core/l10n/strings.dart';
import '../../../core/services/live_data.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/live_greeting.dart';
import '../../../core/widgets/ui_kit.dart';

/// The home screen, cut down to what a person can act on.
///
/// It used to stack eight sections: a role hero, an admin console, a branch
/// console, two metric cards, an AI card, a 2×2 grid of actions, a featured-phone
/// carousel, a low-stock banner, an overdue list and an operations pulse. On a
/// 5-inch phone that was four screens of scrolling before anything happened, and
/// three of those sections repeated numbers already shown above.
///
/// What is left is one column with four jobs:
///   1. who you are and which branch you are in
///   2. the two numbers that matter for your role
///   3. the four things you can do from here
///   4. anything that is actually wrong right now
///
/// The header sits outside the scroll view, so the branch, the person and the
/// connection state stay on screen while the rest moves under them.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _refreshing = false;

  /// Pulls the live rows again and reports what actually came back.
  ///
  /// The old control was a two-second delay followed by "All branch stock &
  /// transactions synced with HQ". Nothing was fetched, nothing was written, and
  /// the toast said otherwise. This one calls the same loader the app boots with,
  /// and its message is the row count the database returned.
  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    final locale = ref.read(localeProvider);
    try {
      final snapshot = await const SupabaseSource().load();
      if (!mounted) return;
      if (snapshot.isEmpty) {
        LimsToast.show(
          context,
          snapshot.error ?? tr(locale, 'home.refreshEmpty'),
          isError: true,
        );
        return;
      }
      ref.read(inventoryProvider.notifier).replaceAll(snapshot.products);
      ref.read(loansProvider.notifier).replaceAll(snapshot.loans);
      ref.read(branchesProvider.notifier).replaceAll(snapshot.branches);
      ref.read(activitiesProvider.notifier).replaceAll(snapshot.activities);
      ref
          .read(salesProvider.notifier)
          .replaceAll(await SupabaseSource.fetchSales());
      if (!mounted) return;
      LimsToast.show(
        context,
        trf(locale, 'home.refreshed', {
          'products': snapshot.products.length,
          'loans': snapshot.loans.length,
        }),
        isSuccess: true,
      );
    } catch (e) {
      if (mounted) {
        LimsToast.show(context, e.toString(), isError: true);
      }
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final role = UserRoles.normalize(ref.watch(userRoleProvider)) ?? UserRoles.pending;
    final staff = ref.watch(activeStaffMemberProvider);
    final branch = ref.watch(activeBranchProvider);
    final source = ref.watch(dataSourceProvider);

    final todaySales = ref.watch(todaySalesTotalProvider);
    final todayTx = ref.watch(todayTransactionsCountProvider);
    final stock = ref.watch(totalPhonesCountProvider);
    final loans = ref.watch(loansProvider);
    final overdue = loans.where((l) => l.status == 'overdue').toList();
    final lowStock = ref
        .watch(inventoryProvider)
        .where((p) => p.status == 'low' || p.stock <= p.min)
        .toList();

    final isCashier = role == UserRoles.counterCashier;
    final isStorekeeper = role == UserRoles.storekeeper;
    final isLoanOfficer = role == UserRoles.loanOfficer;
    final isManager = role == UserRoles.branchManager;
    final isAdmin = role == UserRoles.superAdmin;
    final isAuditor = role == UserRoles.auditor;

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Pinned. Everything else scrolls beneath it.
            _HomeHeader(
              locale: locale,
              staff: staff,
              role: role,
              branch: branch,
              source: source,
              refreshing: _refreshing,
              onRefresh: _refresh,
              onBranchTap: () => context.push('/settings'),
              onNotifications: () => context.push('/notifications'),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refresh,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
                  children: [
                    _SummaryCard(
                      locale: locale,
                      role: role,
                      branch: branch,
                      todaySales: todaySales,
                      todayTx: todayTx,
                      stock: stock,
                      loans: loans.length,
                      overdue: overdue.length,
                      lowStock: lowStock.length,
                    ),
                    const SizedBox(height: 20),
                    _SectionLabel(text: tr(locale, 'home.quickActions')),
                    const SizedBox(height: 10),
                    _QuickActions(
                      locale: locale,
                      role: role,
                      onSupervisorPin: _showSupervisorPinDialog,
                    ),
                    const SizedBox(height: 20),
                    _AttentionList(
                      locale: locale,
                      lowStock: lowStock,
                      overdue: overdue,
                      showStock: isStorekeeper || isManager || isAdmin,
                      showCredit: isLoanOfficer || isManager || isAdmin || isCashier,
                      readOnly: isAuditor,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showSupervisorPinDialog() async {
    final controller = TextEditingController();
    final locale = ref.read(localeProvider);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          tr(locale, 'sell.supervisorTitle'),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        content: TextField(
          controller: controller,
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: 6,
          decoration: InputDecoration(
            labelText: tr(locale, 'sell.supervisorPin'),
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(tr(locale, 'common.cancel')),
          ),
          FilledButton(
            onPressed: () {
              // The PIN is checked by the branch manager's account, not by a
              // constant in the app. Until that endpoint exists the dialog says
              // so rather than accepting any four digits.
              Navigator.pop(ctx);
              LimsToast.show(
                context,
                tr(locale, 'home.pinNotEnforced'),
                isError: true,
              );
            },
            child: Text(tr(locale, 'common.save')),
          ),
        ],
      ),
    );
    controller.dispose();
  }
}

/// Person, branch, role and connection state. Never scrolls away.
class _HomeHeader extends StatelessWidget {
  const _HomeHeader({
    required this.locale,
    required this.staff,
    required this.role,
    required this.branch,
    required this.source,
    required this.refreshing,
    required this.onRefresh,
    required this.onBranchTap,
    required this.onNotifications,
  });

  final Locale locale;
  final StaffMember staff;
  final String role;
  final String branch;
  final DataSourceState source;
  final bool refreshing;
  final Future<void> Function() onRefresh;
  final VoidCallback onBranchTap;
  final VoidCallback onNotifications;

  @override
  Widget build(BuildContext context) {
    final live = source.kind == DataSourceKind.live;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 12, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE8EEF7))),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _Avatar(staff: staff, role: role),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // The clock here is East Africa Time and ticks, so a shop
                    // that opens at 08:00 greets people correctly at 08:00.
                    Row(
                      children: [
                        Flexible(
                          child: LiveGreeting(
                            locale: locale,
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.ink500,
                            ),
                          ),
                        ),
                        Flexible(
                          child: Text(
                            _firstName(staff.name),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.ink700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 1),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            role,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.3,
                              color: AppTheme.ink900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: live
                                ? const Color(0xFF10B981)
                                : const Color(0xFFF59E0B),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: refreshing ? null : () => onRefresh(),
                tooltip: tr(locale, 'home.refresh'),
                icon: refreshing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded,
                        size: 20, color: AppTheme.ink500),
              ),
              IconButton(
                onPressed: onNotifications,
                tooltip: tr(locale, 'home.notifications'),
                icon: const Icon(Icons.notifications_none_rounded,
                    size: 20, color: AppTheme.ink500),
              ),
            ],
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: onBranchTap,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F7FC),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.storefront_rounded,
                      size: 14, color: AppTheme.brand600),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      branch,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.ink700,
                      ),
                    ),
                  ),
                  Text(
                    live
                        ? tr(locale, 'home.live')
                        : tr(locale, 'home.offline'),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: live
                          ? const Color(0xFF027A48)
                          : const Color(0xFFB45309),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _firstName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '';
    return trimmed.split(RegExp(r'\s+')).first;
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.staff, required this.role});

  final StaffMember staff;
  final String role;

  @override
  Widget build(BuildContext context) {
    // Person first, role second, initials last. The order matters: choosing by
    // role handed every storekeeper the same face, which is how a man ended up
    // with the shop manager's portrait.
    final asset = (staff.avatarAsset != null && staff.avatarAsset!.isNotEmpty)
        ? staff.avatarAsset!
        : UserRoles.avatarAsset(role);

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppTheme.brand100,
        border: Border.all(color: Colors.white, width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        asset,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Center(
          child: Text(
            _initials(staff.name),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppTheme.brand600,
            ),
          ),
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '—';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }
}

/// The two numbers that answer "how is today going?" for this role.
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.locale,
    required this.role,
    required this.branch,
    required this.todaySales,
    required this.todayTx,
    required this.stock,
    required this.loans,
    required this.overdue,
    required this.lowStock,
  });

  final Locale locale;
  final String role;
  final String branch;
  final int todaySales;
  final int todayTx;
  final int stock;
  final int loans;
  final int overdue;
  final int lowStock;

  @override
  Widget build(BuildContext context) {
    final money = _money(todaySales);
    final isAuditor = role == UserRoles.auditor;
    final primaryLabel =
        isAuditor ? tr(locale, 'home.salesToday') : tr(locale, 'home.todaySales');
    final secondaryLabel =
        role == UserRoles.storekeeper ? tr(locale, 'home.totalStock') : tr(locale, 'home.activeLoans');
    final secondaryValue =
        role == UserRoles.storekeeper ? '$stock' : '$loans';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B6EF3), Color(0xFF0A49B8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Color(0x331B6EF3), blurRadius: 18, offset: Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            primaryLabel,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFFC7DBFF),
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              'TZS $money',
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.8,
                color: Colors.white,
              ),
            ),
          ),
          Text(
            trf(locale, 'home.txCount', {'n': todayTx}),
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFFC7DBFF),
            ),
          ),
          const SizedBox(height: 12),
          Container(height: 1, color: const Color(0x33FFFFFF)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _MiniStat(label: secondaryLabel, value: secondaryValue),
              ),
              Container(width: 1, height: 26, color: const Color(0x33FFFFFF)),
              const SizedBox(width: 12),
              Expanded(
                child: _MiniStat(
                  label: role == UserRoles.storekeeper
                      ? tr(locale, 'home.lowStock')
                      : tr(locale, 'home.overdue'),
                  value: role == UserRoles.storekeeper ? '$lowStock' : '$overdue',
                  alarming: role == UserRoles.storekeeper ? lowStock > 0 : overdue > 0,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _money(int value) {
    final whole = value.round().toString();
    final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return whole.replaceAllMapped(reg, (m) => '${m[1]},');
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value, this.alarming = false});

  final String label;
  final String value;
  final bool alarming;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            color: alarming ? const Color(0xFFFDE68A) : Colors.white,
          ),
        ),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Color(0xFFC7DBFF),
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.2,
        color: AppTheme.ink900,
      ),
    );
  }
}

/// Four actions per role, defined as data.
///
/// This was a five-deep nested ternary building two rows of cards inline, which
/// is why the file reached 3,800 lines and why adding a role meant editing four
/// places. A list of four entries says the same thing and can be read.
class _QuickAction {
  const _QuickAction(this.icon, this.labelKey, this.subKey, this.route);

  final IconData icon;
  final String labelKey;
  final String subKey;
  final String route;
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.locale,
    required this.role,
    required this.onSupervisorPin,
  });

  final Locale locale;
  final String role;
  final VoidCallback onSupervisorPin;

  List<_QuickAction> _actionsFor(String role) {
    switch (role) {
      case UserRoles.superAdmin:
        return const [
          _QuickAction(Icons.admin_panel_settings_rounded, 'action.adminHub', 'action.adminHubSub', '/admin'),
          _QuickAction(Icons.fact_check_outlined, 'action.audit', 'action.auditSub', '/admin'),
          _QuickAction(Icons.bar_chart_rounded, 'action.reports', 'action.reportsSub', '/reports'),
          _QuickAction(Icons.swap_horiz_rounded, 'action.transfers', 'action.transfersSub', '/transfer'),
        ];
      case UserRoles.branchManager:
        return const [
          _QuickAction(Icons.point_of_sale_rounded, 'action.newSale', 'action.newSaleSub', '/sell-loan'),
          _QuickAction(Icons.assessment_rounded, 'action.reports', 'action.reportsSub', '/reports'),
          _QuickAction(Icons.inventory_2_outlined, 'action.stock', 'action.stockSub', '/stock'),
          _QuickAction(Icons.access_time_filled_rounded, 'action.shifts', 'action.shiftsSub', '/attendance'),
        ];
      case UserRoles.loanOfficer:
        return const [
          _QuickAction(Icons.badge_outlined, 'action.issueLoan', 'action.issueLoanSub', '/sell-loan?type=LOAN'),
          _QuickAction(Icons.notifications_active_rounded, 'action.collections', 'action.collectionsSub', '/loans'),
          _QuickAction(Icons.qr_code_scanner_rounded, 'action.scan', 'action.scanSub', '/scanner'),
          _QuickAction(Icons.people_outline_rounded, 'action.borrowers', 'action.borrowersSub', '/loans'),
        ];
      case UserRoles.storekeeper:
        return const [
          _QuickAction(Icons.inventory_2_outlined, 'action.receive', 'action.receiveSub', '/receive-stock'),
          _QuickAction(Icons.qr_code_scanner_rounded, 'action.scan', 'action.scanSub', '/scanner'),
          _QuickAction(Icons.swap_horiz_rounded, 'action.transfers', 'action.transfersSub', '/transfer'),
          _QuickAction(Icons.shelves, 'action.count', 'action.countSub', '/stock'),
        ];
      case UserRoles.auditor:
        return const [
          _QuickAction(Icons.receipt_long_rounded, 'action.reports', 'action.reportsSub', '/reports'),
          _QuickAction(Icons.qr_code_scanner_rounded, 'action.scan', 'action.scanSub', '/scanner'),
          _QuickAction(Icons.people_outline_rounded, 'action.borrowers', 'action.borrowersSub', '/loans'),
          _QuickAction(Icons.inventory_2_outlined, 'action.stock', 'action.stockSub', '/stock'),
        ];
      default:
        return const [
          _QuickAction(Icons.point_of_sale_rounded, 'action.newSale', 'action.newSaleSub', '/sell-loan'),
          _QuickAction(Icons.badge_outlined, 'action.customers', 'action.customersSub', '/loans'),
          _QuickAction(Icons.qr_code_scanner_rounded, 'action.scan', 'action.scanSub', '/scanner'),
          _QuickAction(Icons.access_time_filled_rounded, 'action.shifts', 'action.shiftsSub', '/attendance'),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final actions = _actionsFor(role);
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        mainAxisExtent: 88,
      ),
      itemCount: actions.length,
      itemBuilder: (context, i) {
        final action = actions[i];
        return _ActionTile(
          icon: action.icon,
          title: tr(locale, action.labelKey),
          subtitle: tr(locale, action.subKey),
          onTap: () => context.push(action.route),
        );
      },
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: AppTheme.brand600),
              const SizedBox(height: 8),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.ink900,
                ),
              ),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10, color: AppTheme.ink500),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Only what is wrong, capped at two rows.
///
/// The old screen showed low stock in three places (a banner, a metric sub-label
/// and a list) and overdue accounts in two. Repeating an alert does not make it
/// more urgent; it makes the screen longer.
class _AttentionList extends StatelessWidget {
  const _AttentionList({
    required this.locale,
    required this.lowStock,
    required this.overdue,
    required this.showStock,
    required this.showCredit,
    required this.readOnly,
  });

  final Locale locale;
  final List<ProductItem> lowStock;
  final List<LoanItem> overdue;
  final bool showStock;
  final bool showCredit;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];

    if (showStock && lowStock.isNotEmpty) {
      rows.add(_AttentionRow(
        icon: Icons.warning_amber_rounded,
        tint: const Color(0xFFEA580C),
        title: trf(locale, 'home.restockModels', {'n': lowStock.length}),
        subtitle: lowStock.take(2).map((p) => p.name).join(' · '),
        onTap: readOnly ? null : () => context.push('/stock'),
      ));
    }

    if (showCredit && overdue.isNotEmpty) {
      final past = overdue.first;
      rows.add(_AttentionRow(
        icon: Icons.schedule_rounded,
        tint: const Color(0xFFD92D20),
        title: trf(locale, 'home.overdueAccounts', {'n': overdue.length}),
        subtitle: '${past.name} · ${past.item}',
        onTap: readOnly ? null : () => context.push('/loans'),
      ));
    }

    if (rows.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFECFDF5),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle_rounded,
                size: 18, color: Color(0xFF027A48)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                tr(locale, 'home.allClear'),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF027A48),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(text: tr(locale, 'home.needsAttention')),
        const SizedBox(height: 10),
        ...rows,
      ],
    );
  }
}

class _AttentionRow extends StatelessWidget {
  const _AttentionRow({
    required this.icon,
    required this.tint,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final Color tint;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8EEF7)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: tint.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 18, color: tint),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.ink900,
                        ),
                      ),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 10.5, color: AppTheme.ink500),
                      ),
                    ],
                  ),
                ),
                if (onTap != null)
                  const Icon(Icons.chevron_right_rounded,
                      size: 18, color: AppTheme.ink400),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
