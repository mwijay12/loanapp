import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/data/inventory_provider.dart';
import '../../../core/data/sales_provider.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../../core/l10n/strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/clay.dart';
import '../../../core/widgets/person_avatar.dart';
import '../../../core/widgets/ui_kit.dart';

import '../../../core/data/analytics.dart';
import '../../../core/data/branch_provider.dart';
import '../../../core/data/branch_stats.dart';
import '../../../core/data/mock_lims_data.dart';
import '../../../core/motion/motion.dart';
import '../../../core/motion/motion_widgets.dart';
import 'members_panel.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  final String? initialTab;

  const AdminDashboardScreen({super.key, this.initialTab});

  @override
  ConsumerState<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  late int _selectedTab;
  RevenueRange _range = RevenueRange.week;

  /// Which bar was last tapped. Null means "the latest one", so the card always
  /// opens on today instead of an empty slot.
  int? _selectedBar;

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTab == 'staff' ? 1 : 0;
  }

  /// The staff tab is the Super Admin's console.
  ///
  /// `?tab=staff` used to open it for whoever held the link, and the menu row
  /// that carried it was rendered for Branch Managers too. Opening the tab is
  /// now decided by the role as well as by the link, and the build falls back to
  /// the network view, which is what a manager is scoped to.
  bool get _mayOpenStaffTab =>
      UserRoles.canAdministerStaff(ref.watch(userRoleProvider));

  /// Today's takings against the same day-shape yesterday, or null when there is
  /// no yesterday to compare with.
  int? get _yesterdayDelta {
    final ledger = ref.watch(salesLedgerProvider);
    if (ledger.length < 2) return null;
    final today = ledger.last;
    final prev = ledger[ledger.length - 2];
    if (prev.date != today.date.subtract(const Duration(days: 1))) return null;
    if (prev.amount <= 0) return null;
    return (((today.amount - prev.amount) / prev.amount) * 100).round();
  }

  String _yesterdayTrendText() {
    final d = _yesterdayDelta;
    if (d == null) {
      return tr(ref.read(localeProvider), 'admin.noYesterday');
    }
    return '${d >= 0 ? '+' : ''}$d% ${tr(ref.read(localeProvider), 'admin.vsYesterday')}';
  }

  int get _activeBranchCount =>
      ref.watch(branchesProvider).where((b) => b.active).length;

  int get _overdueLoans =>
      ref.watch(loansProvider).where((l) => l.status == 'overdue').length;

  @override
  Widget build(BuildContext context) {
    final todaySales = ref.watch(salesTodayValueProvider);
    final activeLoansTotal = ref.watch(activeLoansTotalProvider);
    final lowStockCount = ref.watch(lowStockCountProvider);
    final currentRole = ref.watch(userRoleProvider);
    final canAdminister = UserRoles.canAdministerStaff(currentRole);
    final isBranchManager =
        UserRoles.normalize(currentRole) == UserRoles.branchManager;

    // A Branch Manager used to land on "Admin Console" with the staff and RBAC
    // tab available, which read as a privilege they do not have. The console is
    // now scoped by role: the network view for a manager, the full console for a
    // Super Admin, and nothing for everyone else.
    if (!canAdminister && !isBranchManager) {
      return _buildNoAccess();
    }

    // Chart data comes from the ledger, so switching Wiki/Mwezi changes the
    // numbers. It used to be seven fixed heights with a fixed total.
    // Branch rows come from the branch store, not from four map literals, so a
    // branch can be opened, renamed or closed without touching code. A closed
    // branch stays in the list as a record rather than disappearing, because
    // sales and loans still point at it.
    final branchRecords = ref.watch(branchesProvider);
    final branches = branchRecords
        .where((b) => b.active)
        .map((b) {
              final stats = ref.watch(branchStatsProvider(b.id));
              return <String, dynamic>{
              'id': b.id,
              'name': b.name,
              'city': b.city,
              'units': stats.units,
              'models': stats.models,
              'revenue': stats.revenue,
              'retail': stats.retailValue,
              'sales': formatTzsCompact(b.salesToday),
              'low': stats.lowStock,
              'active': b.active,
              'color': b.lowStock >= 8
                  ? const Color(0xFFF79009)
                  : const Color(0xFF12B76A),
            };
            })
        .toList()
      ..sort((a, b) {
        final byUnits = (b['units'] as int).compareTo(a['units'] as int);
        if (byUnits != 0) return byUnits;
        return (b['revenue'] as int).compareTo(a['revenue'] as int);
      });

    // Alerts are the shop's own counts, not a scripted list. The previous
    // version printed "Overdue loan — Amina Komba", "Galaxy A55 below minimum",
    // "Zanzibar Branch sync delayed" and "Daily close completed" every time,
    // whether or not any of it was true. A notice that cannot be wrong is not a
    // notice.
    final locale0 = ref.watch(localeProvider);
    final alertList = <Map<String, dynamic>>[];
    if (_overdueLoans > 0) {
      alertList.add({
        'title': trf(locale0, 'admin.alertOverdue', {'n': _overdueLoans}),
        'sub': trf(locale0, 'admin.overdue', {'n': _overdueLoans}),
        'icon': Icons.warning_amber_rounded,
        'color': const Color(0xFFF43F5E),
        'bg': const Color(0xFFFFEDF1),
        'kind': 'overdue',
      });
    }
    if (lowStockCount > 0) {
      alertList.add({
        'title': trf(locale0, 'admin.alertLowStock', {'n': lowStockCount}),
        'sub': trf(locale0, 'admin.lowStockModels', {'n': lowStockCount}),
        'icon': Icons.inventory_2_outlined,
        'color': const Color(0xFFF79009),
        'bg': const Color(0xFFFEF3E4),
        'kind': 'lowStock',
      });
    }
    if (todaySales == 0) {
      alertList.add({
        'title': tr(locale0, 'admin.alertNoSalesToday'),
        'sub': tr(locale0, 'admin.alertNoSalesTodaySub'),
        'icon': Icons.point_of_sale_rounded,
        'color': AppTheme.brand600,
        'bg': AppTheme.brand100,
        'kind': 'noSales',
      });
    }

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.ink900),
          onPressed: () => context.go('/home'),
        ),
        title: Text(
          tr(ref.watch(localeProvider),
              canAdminister ? 'admin.titleAdmin' : 'admin.titleBranch'),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppTheme.ink900,
          ),
        ),
        actions: [
          // Active Role Badge Pill
          InkWell(
            onTap: _mayOpenStaffTab
                ? () => setState(() => _selectedTab = 1)
                : null,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              margin: const EdgeInsets.only(right: 14),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFE9F2FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: AppTheme.brand600,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    currentRole,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.brand600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        bottom: canAdminister
            ? PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  decoration: const BoxDecoration(
                    border:
                        Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() => _selectedTab = 0),
                          borderRadius: BorderRadius.circular(12),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: _selectedTab == 0
                                  ? AppTheme.brand600
                                  : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              tr(ref.watch(localeProvider), 'admin.tabNetwork'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: _selectedTab == 0
                                    ? Colors.white
                                    : AppTheme.ink600,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() => _selectedTab = 1),
                          borderRadius: BorderRadius.circular(12),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: _selectedTab == 1
                                  ? AppTheme.brand600
                                  : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.badge_rounded,
                                  size: 15,
                                  color: _selectedTab == 1
                                      ? Colors.white
                                      : AppTheme.ink600,
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    tr(ref.watch(localeProvider),
                                        'admin.staffTab'),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: _selectedTab == 1
                                          ? Colors.white
                                          : AppTheme.ink600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : null,
      ),
      // The console sits on a coloured ground so the white cards read as cards.
      // A flat grey page made every tile look like the same sheet of paper.
      body: AuroraBackdrop(
        child: SafeArea(
          child: (_selectedTab == 0 || !canAdminister || !_mayOpenStaffTab)
              ? _buildNetworkOverviewTab(todaySales, activeLoansTotal,
                  lowStockCount, branches, alertList)
              : _buildStaffRbacTab(),
        ),
      ),
    );
  }

  /// Shown to a role with no place in the console, rather than rendering a
  /// downgraded copy of it.
  Widget _buildNoAccess() {
    final currentRole = ref.watch(userRoleProvider);
    return Scaffold(
      backgroundColor: const Color(0xFFF5F8FD),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.ink900),
          onPressed: () => context.go('/home'),
        ),
        title: Text(
          tr(ref.watch(localeProvider), 'admin.console'),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppTheme.ink900,
          ),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: const BoxDecoration(
                  color: Color(0xFFE9F2FF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.shield_outlined,
                    size: 34, color: AppTheme.brand600),
              ),
              const SizedBox(height: 16),
              Text(
                tr(ref.watch(localeProvider), 'admin.noAccessTitle'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.ink900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                trf(ref.watch(localeProvider), 'admin.noAccessBody', {
                  'role':
                      UserRoles.label(UserRoles.normalize(currentRole) ?? ''),
                }),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: AppTheme.ink600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNetworkOverviewTab(
    int todaySales,
    int activeLoansTotal,
    int lowStockCount,
    List<Map<String, dynamic>> branches,
    List<Map<String, dynamic>> alerts,
  ) {
    final currentRole = ref.watch(userRoleProvider);
    final canAdminister = UserRoles.canAdministerStaff(currentRole);
    final series = ref.watch(revenueSeriesProvider(_range));

    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        // One figure carries the screen. Before this, four equally-sized cards
        // said "these four things matter equally", which is never true on a
        // dashboard: today's takings are the question, the rest are context.
        _buildHeroKpi(
          label: tr(ref.watch(localeProvider), 'admin.revenueToday'),
          value: formatTzsCompact(todaySales),
          numeric: todaySales,
          format: (v) => formatTzsCompact(v.toInt()),
          trend: _yesterdayTrendText(),
          trendColor: _yesterdayDelta == null
              ? AppTheme.ink500
              : (_yesterdayDelta! >= 0
                  ? const Color(0xFF12B76A)
                  : const Color(0xFFE11D48)),
          asset: 'assets/images/icon_pos_3d.png',
          tint: const Color(0xFF12B76A),
          wash: const Color(0xFFE7F8F0),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildMiniKpi(
                label: tr(ref.watch(localeProvider), 'admin.activeBranches'),
                value: '$_activeBranchCount',
                numeric: _activeBranchCount,
                format: (v) => v.toInt().toString(),
                arrivalIndex: 1,
                trend: trf(ref.watch(localeProvider), 'admin.branchesOpen', {
                  'n': _activeBranchCount,
                  'total': ref.watch(branchesProvider).length,
                }),
                asset: 'assets/images/icon_store_3d.png',
                tint: AppTheme.brand600,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMiniKpi(
                label: tr(ref.watch(localeProvider), 'admin.loansOutstanding'),
                value: LimsFormatters.currencyCompact(activeLoansTotal),
                numeric: activeLoansTotal,
                format: LimsFormatters.currencyCompact,
                arrivalIndex: 2,
                trend: trf(ref.watch(localeProvider), 'admin.overdue', {
                  'n': _overdueLoans,
                }),
                trendColor: _overdueLoans > 0
                    ? const Color(0xFFE11D48)
                    : AppTheme.ink500,
                asset: 'assets/images/icon_credit_3d.png',
                tint: const Color(0xFFF43F5E),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMiniKpi(
                label: tr(ref.watch(localeProvider), 'admin.alerts'),
                value: '${lowStockCount + _overdueLoans}',
                numeric: lowStockCount + _overdueLoans,
                format: (v) => v.toInt().toString(),
                arrivalIndex: 3,
                trend: lowStockCount + _overdueLoans == 0
                    ? tr(ref.watch(localeProvider), 'admin.nothingPending')
                    : tr(ref.watch(localeProvider), 'admin.needsReview'),
                trendColor: lowStockCount + _overdueLoans == 0
                    ? const Color(0xFF12B76A)
                    : const Color(0xFFF79009),
                asset: 'assets/images/icon_shield_3d.png',
                tint: const Color(0xFFF79009),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Petty Cash Quick Access
        InkWell(
          onTap: () => context.push('/petty-cash'),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFECACA)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0C0F3478),
                  blurRadius: 10,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDC2626),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.monetization_on_rounded,
                      color: Colors.white, size: 22),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Petty Cash',
                        style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 14.5,
                            color: Color(0xFF991B1B)),
                      ),
                      Text(
                        'Record cleaning, food, or operational expenses',
                        style:
                            TextStyle(fontSize: 11.5, color: Color(0xFFDC2626)),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded,
                    size: 14, color: Color(0xFFDC2626)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Network Revenue Chart Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0C0F3478),
                blurRadius: 20,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      trf(
                        ref.watch(localeProvider),
                        canAdminister
                            ? 'admin.networkRevenue'
                            : 'admin.branchRevenue',
                        {
                          'period': tr(
                              ref.watch(localeProvider),
                              _range == RevenueRange.week
                                  ? 'admin.periodWeek'
                                  : 'admin.periodMonth'),
                        },
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.ink900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.brand100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        formatTzsCompact(series.total),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.brand600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  for (final r in RevenueRange.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(9),
                        onTap: () => setState(() {
                          _range = r;
                          _selectedBar = null;
                        }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _range == r
                                ? AppTheme.brand600
                                : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Text(
                            tr(
                                ref.watch(localeProvider),
                                r == RevenueRange.week
                                    ? 'admin.rangeWeek'
                                    : 'admin.rangeMonth'),
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color:
                                  _range == r ? Colors.white : AppTheme.ink600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  const Spacer(),
                  Flexible(
                    child: Text(
                      trf(ref.watch(localeProvider), 'admin.vsPrev', {
                        'n':
                            '${series.changePercent >= 0 ? '+' : ''}${series.changePercent}',
                      }),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: series.changePercent >= 0
                            ? const Color(0xFF12B76A)
                            : const Color(0xFFE11D48),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildRevenueChart(series),
            ],
          ),
        ),
        const SizedBox(height: 20),

        Text(
          tr(ref.watch(localeProvider), 'admin.branches'),
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
            color: AppTheme.ink900,
          ),
        ),
        const SizedBox(height: 10),

        // Branch List
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0C0F3478),
                blurRadius: 20,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: branches.asMap().entries.map((entry) {
              final idx = entry.key;
              final b = entry.value;
              final isLast = idx == branches.length - 1;

              return InkWell(
                onLongPress: () => _showBranchActions(context, b),
                onTap: () => _showBranchAuditModal(context, b),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    border: isLast
                        ? null
                        : const Border(
                            bottom: BorderSide(color: Color(0xFFF1F5F9))),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: b['color'] as Color,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              b['name'] as String,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.ink900,
                              ),
                            ),
                            Text(
                              '${b['units']} units · ${b['models']} models · ${b['low']} low',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.ink500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        formatTzsCompact(b['revenue'] as int),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.ink900,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.chevron_right_rounded,
                          size: 16, color: Color(0xFFCBD5E1)),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 20),

        Text(
          tr(ref.watch(localeProvider), 'admin.alertsTitle'),
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
            color: AppTheme.ink900,
          ),
        ),
        const SizedBox(height: 10),

        // Alerts List
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0C0F3478),
                blurRadius: 20,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: alerts.isEmpty
              ? Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline_rounded,
                          size: 16, color: Color(0xFF12B76A)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          tr(ref.watch(localeProvider), 'admin.noAlerts'),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.ink600,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: alerts.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final a = entry.value;
                    final isLast = idx == alerts.length - 1;

                    return InkWell(
                      onTap: () => _showAlertActionModal(context, a),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          border: isLast
                              ? null
                              : const Border(
                                  bottom: BorderSide(color: Color(0xFFF1F5F9))),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: a['bg'] as Color,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(a['icon'] as IconData,
                                  size: 18, color: a['color'] as Color),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    a['title'] as String,
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.ink900,
                                    ),
                                  ),
                                  Text(
                                    a['sub'] as String,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: AppTheme.ink500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios_rounded,
                                size: 12, color: Color(0xFFCBD5E1)),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }

  /// Close or reopen a branch from the list.
  ///
  /// Closing is reversible and keeps history; deleting a branch would orphan the
  /// sales, loans and audit rows that reference it, so it is not offered.
  Future<void> _showBranchActions(
      BuildContext context, Map<String, dynamic> branch) async {
    final isActive = branch['active'] as bool? ?? true;
    final id = branch['id'] as String;
    final name = branch['name'] as String;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              name,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppTheme.ink900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              tr(ref.read(localeProvider),
                  isActive ? 'adm.branchActive' : 'adm.branchClosed'),
              style: const TextStyle(fontSize: 12, color: AppTheme.ink500),
            ),
            const SizedBox(height: 10),
            ListTile(
              leading: Icon(
                isActive ? Icons.lock_outline_rounded : Icons.lock_open_rounded,
                color: AppTheme.brand600,
              ),
              title: Text(tr(ref.read(localeProvider),
                  isActive ? 'admin.closeBranch' : 'admin.reopenBranch')),
              subtitle: Text(
                tr(
                    ref.read(localeProvider),
                    isActive
                        ? 'admin.closeBranchHint'
                        : 'admin.reopenBranchHint'),
                style: const TextStyle(fontSize: 11.5),
              ),
              onTap: () {
                final notifier = ref.read(branchesProvider.notifier);
                if (isActive) {
                  notifier.closeBranch(id);
                } else {
                  notifier.reopenBranch(id);
                }
                Navigator.pop(ctx);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildStaffRbacTab() {
    final staffList = ref.watch(staffProvider);
    final currentRole = ref.watch(userRoleProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        // P0: persona switcher removed. Role is server-assigned and shown
        // read-only — the client can never elevate itself.
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFD4E5FF), width: 1.2),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0C0F3478),
                blurRadius: 18,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE9F2FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.verified_user_rounded,
                        color: AppTheme.brand600, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr(ref.watch(localeProvider),
                              'admin.activeRoleTitle'),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.ink900,
                          ),
                        ),
                        Text(
                          trf(ref.watch(localeProvider), 'admin.signedInAs',
                              {'role': currentRole}),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.ink500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Persona Privileges Summary
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Icon(
                      UserRoles.canAdministerStaff(currentRole)
                          ? Icons.shield_rounded
                          : Icons.lock_outline_rounded,
                      size: 15,
                      color: AppTheme.brand600,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _getRolePrivilegeDescription(currentRole),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.ink700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Logins first, roster second. A person who can sign in is the thing an
        // admin came here to manage; the roster below is a name list.
        const MembersPanel(),
        const SizedBox(height: 20),

        // Staff Directory Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr(ref.watch(localeProvider), 'admin.staffDirectory'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.ink900,
                    ),
                  ),
                  Text(
                    trf(ref.watch(localeProvider), 'admin.staffCount',
                        {'n': staffList.length}),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.ink500,
                    ),
                  ),
                ],
              ),
            ),
            // The button that used to live here said "Add staff" and created
            // nothing that could sign in. The real one is "Add member" in the
            // panel above, so this header is a roster heading and nothing more.
          ],
        ),
        const SizedBox(height: 12),

        // Staff Cards List
        ...staffList.map((s) => _buildStaffCard(s)),
      ],
    );
  }

  String _getRolePrivilegeDescription(String role) {
    // Normalise first so a legacy row ('Inventory Officer', 'Staff') still
    // resolves to its canonical role instead of falling through to default.
    final locale = ref.read(localeProvider);
    final key = switch (UserRoles.normalize(role)) {
      UserRoles.superAdmin => 'admin.roleSuperAdmin',
      UserRoles.branchManager => 'admin.roleBranchManager',
      UserRoles.loanOfficer => 'admin.roleCredit',
      UserRoles.storekeeper => 'admin.roleInventory',
      UserRoles.counterCashier => 'admin.roleStaff',
      UserRoles.auditor => 'admin.roleAuditor',
      UserRoles.pending => 'admin.roleInvited',
      _ => 'admin.roleUnknown',
    };
    return tr(locale, key);
  }

  Widget _buildStaffCard(StaffMember s) {
    final isActive = s.status == 'Active';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F3478),
            blurRadius: 16,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Avatar. No role fallback: a new staff member gets their
              // initials until somebody sets their own photo.
              PersonAvatar(
                name: s.name,
                asset: s.avatarAsset,
                size: 44,
                radius: 14,
                grad: s.grad,
              ),
              const SizedBox(width: 12),

              // Name & Code
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.ink900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${s.staffCode} · ${s.branch}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.ink500,
                      ),
                    ),
                  ],
                ),
              ),

              // Role Badge & Status
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _buildRoleBadge(s.role),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isActive
                              ? const Color(0xFF12B76A)
                              : const Color(0xFFF43F5E),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        s.status,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isActive
                              ? const Color(0xFF12B76A)
                              : const Color(0xFFF43F5E),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Contact & Supervisor PIN row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFF1F5F9)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.phone_rounded,
                          size: 13, color: AppTheme.ink500),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          s.phone,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.ink700),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3E4),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Supervisor PIN: ${s.supervisorPin}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFB54708),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Permissions Row
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildPermBadge('Mikopo > 1M', s.canDisburseLoans),
              _buildPermBadge('Device hold', s.canKnoxLock),
              _buildPermBadge('Faida / Margins', s.canViewMargins),
              _buildPermBadge('Hariri Stock', s.canEditStock),
              _buildPermBadge('Overrides', s.canApproveOverrides),
            ],
          ),
          const SizedBox(height: 14),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    ref.read(staffProvider.notifier).toggleStatus(s.id);
                    LimsToast.show(
                      context,
                      isActive
                          ? 'Akaunti ya ${s.name} imesimamishwa.'
                          : 'Akaunti ya ${s.name} imewezeshwa.',
                      isError: isActive,
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isActive
                        ? const Color(0xFFF43F5E)
                        : const Color(0xFF12B76A),
                    side: BorderSide(
                        color: isActive
                            ? const Color(0xFFFECDD3)
                            : const Color(0xFFA7F3D0)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(
                    isActive ? 'Simamisha' : 'Wezesha',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 11.5),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: () => _showEditStaffModal(s),
                  icon: const Icon(Icons.manage_accounts_rounded, size: 15),
                  label: const Text('Hariri Majukumu & PIN',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 11.5)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.brand600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRoleBadge(String role) {
    Color bg;
    Color fg;
    final canonical = UserRoles.normalize(role) ?? role;

    switch (canonical) {
      case UserRoles.superAdmin:
        bg = const Color(0xFFE9F2FF);
        fg = AppTheme.brand600;
        break;
      case UserRoles.branchManager:
        bg = const Color(0xFFF3E8FF);
        fg = const Color(0xFF7C5CFC);
        break;
      case UserRoles.loanOfficer:
        bg = const Color(0xFFE7F8F0);
        fg = const Color(0xFF12B76A);
        break;
      case UserRoles.counterCashier:
        bg = const Color(0xFFFEF3E4);
        fg = const Color(0xFFF79009);
        break;
      case UserRoles.storekeeper:
        bg = const Color(0xFFE0F2FE);
        fg = const Color(0xFF0284C7);
        break;
      case UserRoles.auditor:
        bg = const Color(0xFFEEF2F6);
        fg = const Color(0xFF475569);
        break;
      case 'Pending':
        bg = const Color(0xFFF1F5F9);
        fg = const Color(0xFF64748B);
        break;
      default:
        bg = const Color(0xFFF1F5F9);
        fg = const Color(0xFF64748B);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        role,
        style:
            TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: fg),
      ),
    );
  }

  Widget _buildPermBadge(String title, bool isEnabled) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: isEnabled ? const Color(0xFFE7F8F0) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isEnabled
                ? Icons.check_circle_rounded
                : Icons.remove_circle_outline_rounded,
            size: 11,
            color:
                isEnabled ? const Color(0xFF12B76A) : const Color(0xFF94A3B8),
          ),
          const SizedBox(width: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color:
                  isEnabled ? const Color(0xFF0E9355) : const Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditStaffModal(StaffMember staff) {
    String currentRole = staff.role;
    String currentBranch = staff.branch;
    final pinCtrl = TextEditingController(text: staff.supervisorPin);
    bool canDisburse = staff.canDisburseLoans;
    bool canKnox = staff.canKnoxLock;
    bool canMargins = staff.canViewMargins;
    bool canStock = staff.canEditStock;
    bool canOverrides = staff.canApproveOverrides;

    LimsBottomSheet.show(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) {
          return LimsBottomSheet(
            title: tr(ref.read(localeProvider), 'adm.editRbacTitle'),
            subtitle: '${staff.name} · ${staff.staffCode}',
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Role Dropdown
                Text(tr(ref.read(localeProvider), 'adm.roleLabel'),
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.ink900)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: currentRole,
                  // Built from the canonical role list so the dropdown can
                  // never drift from what the database accepts.
                  items: [
                    for (final role in UserRoles.assignable)
                      DropdownMenuItem(
                          value: role, child: Text(UserRoles.label(role))),
                  ],
                  onChanged: (v) {
                    if (v != null) setModalState(() => currentRole = v);
                  },
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 14),

                // Supervisor PIN field
                const Text('PIN ya Uidhinishaji (Supervisor PIN):',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.ink900)),
                const SizedBox(height: 6),
                TextField(
                  controller: pinCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: '••••',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 14),

                const Text('Granular RBAC Permissions:',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.ink900)),
                const SizedBox(height: 8),

                // Switch tiles
                _buildSwitchRow('Approve Loans > TZS 1M', canDisburse,
                    (v) => setModalState(() => canDisburse = v)),
                _buildSwitchRow('Device hold policy', canKnox,
                    (v) => setModalState(() => canKnox = v)),
                _buildSwitchRow('View Cost Price & Margins', canMargins,
                    (v) => setModalState(() => canMargins = v)),
                _buildSwitchRow('Edit Stock & Inventory Levels', canStock,
                    (v) => setModalState(() => canStock = v)),
                _buildSwitchRow('Approve Overrides & Discounts', canOverrides,
                    (v) => setModalState(() => canOverrides = v)),
                const SizedBox(height: 20),

                // Save Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      final updated = staff.copyWith(
                        role: currentRole,
                        branch: currentBranch,
                        supervisorPin: pinCtrl.text.trim(),
                        canDisburseLoans: canDisburse,
                        canKnoxLock: canKnox,
                        canViewMargins: canMargins,
                        canEditStock: canStock,
                        canApproveOverrides: canOverrides,
                      );
                      ref.read(staffProvider.notifier).updateStaff(updated);
                      Navigator.pop(ctx);
                      LimsToast.show(
                          context,
                          trf(ref.read(localeProvider), 'adm.staffUpdated',
                              {'name': staff.name}));
                    },
                    icon: const Icon(Icons.check_circle_rounded, size: 18),
                    label: Text(tr(ref.read(localeProvider), 'adm.saveChanges'),
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 13.5)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.brand600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSwitchRow(
      String label, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.ink900),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            thumbColor: WidgetStatePropertyAll(AppTheme.brand600),
          ),
        ],
      ),
    );
  }

  /// The bar chart. Each bar is a real day (or week, in month view) and tapping it
  /// opens that period's figures underneath. Before this, the bars were seven
  /// fixed heights: pressing Monday could not show Monday, because there was no
  /// Monday behind the pixels.
  Widget _buildRevenueChart(RevenueSeries series) {
    if (series.points.isEmpty) {
      return Container(
        height: 84,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          tr(ref.watch(localeProvider), 'admin.noSalesYet'),
          style: const TextStyle(fontSize: 11.5, color: AppTheme.ink500),
        ),
      );
    }

    final peak =
        series.points.map((p) => p.value).fold<int>(0, (a, b) => a > b ? a : b);
    final selected = (_selectedBar != null &&
            _selectedBar! >= 0 &&
            _selectedBar! < series.points.length)
        ? series.points[_selectedBar!]
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 96,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < series.points.length; i++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: _bar(series.points[i], i, peak,
                        isSelected: _selectedBar == i),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            for (var i = 0; i < series.points.length; i++)
              Expanded(
                child: TweenAnimationBuilder<Color?>(
                  duration: Motion.d(context, Motion.state),
                  curve: Motion.standard,
                  tween: ColorTween(
                    end:
                        _selectedBar == i ? AppTheme.brand600 : AppTheme.ink500,
                  ),
                  builder: (_, Color? c, __) => Text(
                    series.points[i].label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight:
                          _selectedBar == i ? FontWeight.w800 : FontWeight.w600,
                      color: c ?? AppTheme.ink500,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        // The figures under the chart change entirely on a tap. In place they blink;
        // keyed on the selection they cross-fade, which reads as "this is that day's
        // panel" instead of "the text below me was edited".
        FadeSwap(
          alignment: Alignment.topLeft,
          child: KeyedSubtree(
            key: ValueKey<String>('bar-detail-${selected?.label ?? 'none'}'),
            child: _buildBarDetail(selected),
          ),
        ),
      ],
    );
  }

  /// One bar.
  ///
  /// The bars already grew, but every one of them started on the same frame, so a
  /// week of sales arrived as a single block of pixels. Sequenced left to right the
  /// eye travels the shape - which is the one thing a bar chart is for. The value of
  /// the selected bar rides above it instead of only appearing underneath, so the
  /// tap answers the bar that was tapped rather than a line further down the card.
  ///
  /// The 16px label slot is always there, animated only in opacity. Making it appear
  /// by adding height would move the bars themselves, and a chart whose baseline
  /// shifts when you touch it feels broken rather than responsive.
  Widget _bar(RevenuePoint p, int index, int peak, {required bool isSelected}) {
    final double frac = peak <= 0 ? 0.06 : (p.value / peak).clamp(0.06, 1.0);
    // A zero-sales day still draws a stub, so a gap is visible as a gap rather
    // than as a missing bar the eye reads as "no data collected".
    final color = isSelected
        ? AppTheme.brand600
        : (p.value == 0
            ? const Color(0xFFE2E8F0)
            : (p.isPeak ? AppTheme.brand400 : AppTheme.brand200));

    // Pressable rather than a bare GestureDetector: the admin screen is used on a PC
    // all day, so a bar should answer a mouse hovering it and a keyboard tabbing to
    // it, not only a finger. It carries the button and selected semantics itself, so
    // the wrapper that used to supply them is replaced rather than doubled.
    return Pressable(
      key: ValueKey<String>('revbar-$index'),
      semanticLabel: '${p.label} ${formatTzsCompact(p.value)}',
      selected: isSelected,
      onTap: () => setState(() => _selectedBar = isSelected ? null : index),
      scale: 0.985,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          GrowFraction(
            value: frac,
            delay: Motion.delayFor(
              context,
              index,
              each: const Duration(milliseconds: 40),
            ),
            builder: (h) => Container(
              height: (96 * h).clamp(4.0, 96.0),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(isSelected ? 9 : 7),
                boxShadow: isSelected
                    ? const [
                        BoxShadow(
                          color: Color(0x331B6EF3),
                          blurRadius: 12,
                          offset: Offset(0, 3),
                        ),
                      ]
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarDetail(RevenuePoint? p) {
    final locale = ref.watch(localeProvider);
    if (p == null) {
      final isReal = ref.watch(ledgerIsRealProvider);
      final days = ref.watch(salesLedgerProvider).length;
      return Row(
        children: [
          const Icon(Icons.touch_app_rounded, size: 13, color: AppTheme.ink400),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              isReal && days < _range.days
                  ? '${tr(locale, 'admin.tapBar')} · '
                      '${tr(locale, 'admin.onlyDays').replaceAll('{n}', '$days')}'
                  : tr(locale, 'admin.tapBar'),
              style: const TextStyle(fontSize: 10.5, color: AppTheme.ink500),
            ),
          ),
        ],
      );
    }

    final delta = p.deltaPercent;
    final deltaText = delta == null
        ? tr(locale, 'admin.noEarlierFigure')
        : '${delta >= 0 ? '+' : ''}$delta% ${tr(locale, 'admin.vsLastWeek')}';
    final deltaColor = delta == null
        ? AppTheme.ink500
        : (delta >= 0 ? const Color(0xFF12B76A) : const Color(0xFFE11D48));

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE9EFF7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  p.date == null ? p.label : _longDate(p.date!),
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.ink900,
                  ),
                ),
              ),
              Text(
                formatTzsCompact(p.value),
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.brand600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              Text(
                '${p.transactions} ${tr(locale, 'admin.transactions')}',
                style: const TextStyle(fontSize: 10.5, color: AppTheme.ink600),
              ),
              if (p.previousLabel.isNotEmpty)
                Text(
                  '${tr(locale, 'admin.was')} ${formatTzsCompact(p.previousValue)}'
                  ' · ${p.previousLabel}',
                  style:
                      const TextStyle(fontSize: 10.5, color: AppTheme.ink500),
                ),
              Text(
                deltaText,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: deltaColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _longDate(DateTime d) {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    const months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${days[d.weekday - 1]}, ${d.day} ${months[d.month]}';
  }

  /// Today's takings, at the size of the answer to "how did we do".
  ///
  /// Three planes, in order: a ghosted repeat of the figure behind everything,
  /// the number and its label in the middle, and the icon breaking out over the
  /// card edge in front. The overlap is what stops the card reading as a
  /// rectangle with a picture in it.
  Widget _buildHeroKpi({
    required String label,
    required String value,
    required String trend,
    required String asset,
    required Color tint,
    required Color wash,
    Color? trendColor,
    num? numeric,
    String Function(num value)? format,
  }) {
    const valueStyle = TextStyle(
      fontSize: 38,
      height: 1.05,
      fontWeight: FontWeight.w900,
      letterSpacing: -1.4,
      color: AppTheme.ink900,
    );
    return Entrance(
      delay: Motion.delayFor(context, 0),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 15, 124, 15),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.white, Color.lerp(Colors.white, wash, 0.8)!],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: tint.withValues(alpha: 0.14)),
              boxShadow: [
                BoxShadow(
                  color: tint.withValues(alpha: 0.13),
                  blurRadius: 30,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // The back plane: the same figure, unreadable on purpose.
                Positioned(
                  right: -86,
                  bottom: -34,
                  child: Text(
                    value,
                    style: const TextStyle(
                      fontSize: 92,
                      height: 0.9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -4,
                      color: Color(0x0A0F3478),
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        letterSpacing: 0.3,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.ink500,
                      ),
                    ),
                    const SizedBox(height: 7),
                    if (numeric != null &&
                        format != null &&
                        Motion.enabled(context))
                      MetricText(
                        display: value,
                        value: numeric,
                        format: format,
                        style: valueStyle,
                      )
                    else
                      Text(value, style: valueStyle),
                    const SizedBox(height: 5),
                    Text(
                      trend,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: trendColor ?? AppTheme.ink500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Positioned(
            right: 4,
            top: -14,
            child: Clay3DIcon(asset: asset, tint: tint, size: 104),
          ),
        ],
      ),
    );
  }

  /// A supporting figure. Deliberately small: three of these under a hero card
  /// are context, and making them the same size as the revenue was the reason
  /// nothing on the page looked important.
  Widget _buildMiniKpi({
    required String label,
    required String value,
    required String trend,
    required String asset,
    required Color tint,
    Color? trendColor,
    num? numeric,
    String Function(num value)? format,
    int arrivalIndex = 0,
  }) {
    const valueStyle = TextStyle(
      fontSize: 17,
      height: 1.1,
      fontWeight: FontWeight.w900,
      letterSpacing: -0.4,
      color: AppTheme.ink900,
    );
    return Entrance(
      delay: Motion.delayFor(context, arrivalIndex),
      child: Container(
        padding: const EdgeInsets.fromLTRB(11, 11, 11, 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: tint.withValues(alpha: 0.12)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A0F3478),
              blurRadius: 14,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Clay3DIcon(asset: asset, tint: tint, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 9,
                letterSpacing: 0.2,
                fontWeight: FontWeight.w800,
                color: AppTheme.ink500,
              ),
            ),
            const SizedBox(height: 3),
            if (numeric != null && format != null && Motion.enabled(context))
              MetricText(
                display: value,
                value: numeric,
                format: format,
                style: valueStyle,
              )
            else
              Text(value, style: valueStyle),
            const SizedBox(height: 3),
            Text(
              trend,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: trendColor ?? AppTheme.ink500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// One branch, measured from its own rows.
  ///
  /// This used to name a custodian ("David Erick Mwijage"), a drawer balance of
  /// TZS 3,840,000 and an "Operational" status for whichever branch was tapped.
  /// None of it was read from anywhere. What follows is counted.
  void _showBranchAuditModal(BuildContext context, Map<String, dynamic> b) {
    final id = b['id'] as String;
    final stats = ref.read(branchStatsProvider(id));
    final city = (b['city'] as String?) ?? '';
    final trading = stats.units > 0 || stats.salesCount > 0;

    Widget row(String label, String value, {Color? colour}) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(label,
                  style: const TextStyle(fontSize: 12, color: AppTheme.ink500)),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: colour ?? AppTheme.ink900,
                ),
              ),
            ),
          ],
        ),
      );
    }

    LimsBottomSheet.show(
      context: context,
      builder: (ctx) => LimsBottomSheet(
        title: b['name'] as String,
        subtitle: city.isEmpty ? 'Branch' : city,
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: trading ? const Color(0xFFE7F8F0) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            trading ? 'Trading' : 'No stock yet',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: trading ? const Color(0xFF12B76A) : const Color(0xFF64748B),
            ),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  row('Devices on the shelf', '${stats.units} units'),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  row('Catalogue lines held', '${stats.models} models'),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  row('Needs restocking', '${stats.lowStock} models',
                      colour: stats.lowStock > 0
                          ? const Color(0xFFF79009)
                          : const Color(0xFF12B76A)),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  row('Taken here today', formatTzsCompact(stats.revenueToday),
                      colour: AppTheme.brand600),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  row('Taken here all time',
                      formatTzsCompact(stats.revenue)),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  row('Shelf value at marked price',
                      formatTzsCompact(stats.retailValue)),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  row('Receipts written', '${stats.salesCount}'),
                  if (stats.costValue > 0) ...[
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    row('Stock at cost', formatTzsCompact(stats.costValue)),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              stats.costValue == 0 && stats.units > 0
                  ? 'The cost of this stock is not recorded, so its value can '
                      'only be shown at retail.'
                  : 'Counted from the products and receipts that carry this '
                      'branch. Nothing here is typed in by hand.',
              style: const TextStyle(fontSize: 11, height: 1.45, color: Color(0xFF64748B)),
            ),
          ],
        ),
      ),
    );
  }


  void _showAlertActionModal(BuildContext context, Map<String, dynamic> a) {
    final title = a['title'] as String;
    // The sheet used to branch on the alert's English wording ('loan' in the
    // title), which broke the moment the text was translated. The alert now
    // carries a stable kind.
    final isLoan = a['kind'] == 'overdue';

    LimsBottomSheet.show(
      context: context,
      builder: (ctx) => LimsBottomSheet(
        title: title,
        subtitle: a['sub'] as String,
        trailing: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
              color: a['bg'] as Color, borderRadius: BorderRadius.circular(12)),
          child:
              Icon(a['icon'] as IconData, color: a['color'] as Color, size: 20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isLoan) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEDF1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Sera ya LIMS: kifaa cha mteja kinatiwa alama ya "hold" kwenye mfumo hadi deni lilipwe. Hii ni rekodi ya biashara — LIMS haiwezi kufunga simu kwa mbali.',
                  style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF9F1239),
                      fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    LimsToast.show(
                      context,
                      'Hold imewekwa. Kifaa kimetiwa alama kwenye mfumo; mteja ataarifiwa kwa simu au SMS.',
                      isError: true,
                    );
                  },
                  icon: const Icon(Icons.lock_person_rounded, size: 18),
                  label: Text(tr(ref.read(localeProvider), 'adm.deviceHold'),
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF43F5E),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ] else ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    context.push('/receive');
                  },
                  icon: const Icon(Icons.check_circle_rounded, size: 18),
                  label: const Text('Resolve & Restock Now',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.brand600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
