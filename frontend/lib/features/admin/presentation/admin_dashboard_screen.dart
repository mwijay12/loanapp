import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/data/inventory_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ui_kit.dart';

import '../../../core/data/analytics.dart';
import '../../../core/data/mock_lims_data.dart';

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

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTab == 'staff' ? 1 : 0;
  }

  @override
  Widget build(BuildContext context) {
    final todaySales = ref.watch(todaySalesTotalProvider);
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
    final series = ref.watch(revenueSeriesProvider(_range));
    final peak =
        series.points.fold<int>(0, (m, p) => p.value > m ? p.value : m);
    final bars = series.points
        .map((p) => <String, dynamic>{
              'day': p.label,
              'height': peak == 0 ? 0.02 : (p.value / peak).clamp(0.05, 1.0),
              'today': p.isCurrent,
            })
        .toList();

    final branches = [
      {
        'name': 'Mbezi Branch',
        'sales': 'TZS 4.85M',
        'low': 12,
        'color': const Color(0xFF12B76A)
      },
      {
        'name': 'Kariakoo Branch',
        'sales': 'TZS 3.92M',
        'low': 5,
        'color': const Color(0xFF12B76A)
      },
      {
        'name': 'Mwanza Branch',
        'sales': 'TZS 2.71M',
        'low': 8,
        'color': const Color(0xFFF79009)
      },
      {
        'name': 'Arusha Branch',
        'sales': 'TZS 2.34M',
        'low': 3,
        'color': const Color(0xFF12B76A)
      },
      {
        'name': 'Dodoma Branch',
        'sales': 'TZS 1.88M',
        'low': 0,
        'color': const Color(0xFF12B76A)
      },
      {
        'name': 'Zanzibar Branch',
        'sales': 'TZS 1.42M',
        'low': 6,
        'color': const Color(0xFFF43F5E)
      },
    ];

    final alerts = [
      {
        'title': 'Overdue loan — Amina Komba',
        'sub': 'TZS 1.85M · 2 days overdue',
        'icon': Icons.warning_amber_rounded,
        'color': const Color(0xFFF43F5E),
        'bg': const Color(0xFFFFEDF1),
      },
      {
        'title': 'Galaxy A55 below minimum',
        'sub': '4 left at Mbezi Branch',
        'icon': Icons.inventory_2_outlined,
        'color': const Color(0xFFF79009),
        'bg': const Color(0xFFFEF3E4),
      },
      {
        'title': 'Zanzibar Branch sync delayed',
        'sub': 'Last sync 12 minutes ago',
        'icon': Icons.sync_problem_rounded,
        'color': AppTheme.brand600,
        'bg': AppTheme.brand100,
      },
      {
        'title': 'Daily close completed',
        'sub': 'Arusha Branch · TZS 2.1M',
        'icon': Icons.check_circle_outline_rounded,
        'color': const Color(0xFF12B76A),
        'bg': const Color(0xFFE7F8F0),
      },
    ];

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
          canAdminister ? 'Admin Console' : 'Branch Console',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppTheme.ink900,
          ),
        ),
        actions: [
          // Active Role Badge Pill
          InkWell(
            onTap:
                canAdminister ? () => setState(() => _selectedTab = 1) : null,
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
                              'Branch Network & Hubs',
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
                                    'Wafanyakazi & RBAC',
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
      body: SafeArea(
        child: (_selectedTab == 0 || !canAdminister)
            ? _buildNetworkOverviewTab(todaySales, activeLoansTotal,
                lowStockCount, bars, branches, alerts)
            : _buildStaffRbacTab(),
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
        title: const Text(
          'Console',
          style: TextStyle(
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
              const Text(
                'Huna ruhusa ya console',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.ink900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Role yako ni ${UserRoles.label(UserRoles.normalize(currentRole) ?? '')}. Console inahitaji '
                'Super Admin au Branch Manager. Omba ruhusa kwa msimamizi wako.',
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
    List<Map<String, dynamic>> bars,
    List<Map<String, dynamic>> branches,
    List<Map<String, dynamic>> alerts,
  ) {
    final currentRole = ref.watch(userRoleProvider);
    final canAdminister = UserRoles.canAdministerStaff(currentRole);
    final series = ref.watch(revenueSeriesProvider(_range));

    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        // 4 KPI Cards
        Row(
          children: [
            Expanded(
              child: _buildKpiCard(
                label: 'Revenue today',
                value: LimsFormatters.currencyCompact(
                    todaySales > 0 ? todaySales * 4 : 18200000),
                trend: '+9% vs yesterday',
                icon: Icons.trending_up_rounded,
                color: const Color(0xFF12B76A),
                bg: const Color(0xFFE7F8F0),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildKpiCard(
                label: 'Active Branches',
                value: '12',
                trend: 'All synced',
                icon: Icons.storefront_rounded,
                color: AppTheme.brand600,
                bg: AppTheme.brand100,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildKpiCard(
                label: 'Loans Outstanding',
                value: LimsFormatters.currencyCompact(
                    activeLoansTotal > 0 ? activeLoansTotal : 96000000),
                trend: '21 overdue',
                icon: Icons.handshake_rounded,
                color: const Color(0xFFF43F5E),
                bg: const Color(0xFFFFEDF1),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildKpiCard(
                label: 'Alerts',
                value: '${lowStockCount + 2}',
                trend: 'Needs review',
                icon: Icons.warning_amber_rounded,
                color: const Color(0xFFF79009),
                bg: const Color(0xFFFEF3E4),
              ),
            ),
          ],
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
                      canAdminister
                          ? 'Network revenue · ${_range.caption}'
                          : 'Branch revenue · ${_range.caption}',
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
                        onTap: () => setState(() => _range = r),
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
                            r.label,
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
                      '${series.changePercent >= 0 ? '+' : ''}${series.changePercent}% vs prev',
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
              const SizedBox(height: 18),
              SizedBox(
                height: 84,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: bars.map((b) {
                    final isToday = b['today'] as bool;
                    final h = b['height'] as double;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Container(
                              height: 60 * h,
                              decoration: BoxDecoration(
                                gradient:
                                    isToday ? AppTheme.brandGradient : null,
                                color: isToday ? null : const Color(0xFFE2EAF8),
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              b['day'] as String,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight:
                                    isToday ? FontWeight.w800 : FontWeight.w600,
                                color: isToday
                                    ? AppTheme.brand600
                                    : const Color(0xFF9AA8BF),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        const Text(
          'Branches',
          style: TextStyle(
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
                              '${b['low']} low-stock models',
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
                        b['sales'] as String,
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

        const Text(
          'Alerts & Escalations',
          style: TextStyle(
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
          child: Column(
            children: alerts.asMap().entries.map((entry) {
              final idx = entry.key;
              final a = entry.value;
              final isLast = idx == alerts.length - 1;

              return InkWell(
                onTap: () => _showAlertActionModal(context, a),
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
                        const Text(
                          'Active Role (server-assigned)',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.ink900,
                          ),
                        ),
                        Text(
                          'Signed in as $currentRole. Role changes happen server-side.',
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

        // Staff Directory Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Staff Directory & Credentials',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.ink900,
                    ),
                  ),
                  Text(
                    '${staffList.length} staff registered across branches',
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
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _showAddStaffModal,
              icon: const Icon(Icons.person_add_rounded, size: 16),
              label: const Text('Ongeza Staff',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.brand600,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
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
    switch (UserRoles.normalize(role)) {
      case UserRoles.superAdmin:
        return 'Full Executive Access: network revenue, P&L profit margins, staff RBAC permissions, and the device-hold policy switch.';
      case UserRoles.branchManager:
        return 'Branch Supervision: Daily register & drawer audit, supervisor discount PIN overrides, staff shift audits.';
      case UserRoles.loanOfficer:
        return 'Credit & Risk: customer KYC scoring, loan approval or rejection, device-hold flags for defaulters, and collections.';
      case UserRoles.storekeeper:
        return 'Logistics & Warehouse: Inbound PO shipments intake, serialized IMEI barcode intake, audits, and branch transfers.';
      case UserRoles.counterCashier:
        return 'Retail POS: Fast cash & mobile money sales, customer loan KYC intake, stock scan, and shift clock-in.';
      case UserRoles.auditor:
        return 'Oversight Only: Read-only access to registers, loan history, stock movements and reports. Cannot create, approve, edit or disburse.';
      case UserRoles.pending:
        return 'Invited but not yet activated: the account exists but has no access until the invitation is accepted and a password is set.';
      default:
        return 'Unrecognised role — treated as read-only until a Super Admin assigns a valid role.';
    }
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
              // Avatar
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: s.grad,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.asset(
                    UserRoles.avatarAsset(s.role),
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Center(
                      child: Text(
                        s.initials,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ),
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
            title: 'Hariri Majukumu & Ruhusa (RBAC)',
            subtitle: '${staff.name} · ${staff.staffCode}',
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Role Dropdown
                const Text('Nafasi / Jukumu la Mfanyakazi:',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.ink900)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: currentRole,
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
                          context, 'Taarifa za ${staff.name} zimesasishwa!');
                    },
                    icon: const Icon(Icons.check_circle_rounded, size: 18),
                    label: const Text('Hifadhi Mabadiliko',
                        style: TextStyle(
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
            activeThumbColor: AppTheme.brand600,
          ),
        ],
      ),
    );
  }

  void _showAddStaffModal() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController(text: '07');
    final emailCtrl = TextEditingController();
    final staffCodeCtrl = TextEditingController(
        text: 'STF-${DateTime.now().millisecondsSinceEpoch % 1000}');
    final pinCtrl = TextEditingController();
    String selectedRole = UserRoles.loanOfficer;
    String selectedBranch = AppConstants.launchBranch;

    LimsBottomSheet.show(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) {
          return LimsBottomSheet(
            title: 'Ongeza Mfanyakazi Mpya',
            subtitle: 'Weka taarifa za mtumiaji na jukumu lake',
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: 'Jina Kamili la Mfanyakazi',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: phoneCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: 'Namba ya Simu',
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: staffCodeCtrl,
                        decoration: InputDecoration(
                          labelText: 'Staff ID / Code',
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Barua Pepe (Email)',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: selectedRole,
                  items: [
                    for (final role in UserRoles.assignable)
                      DropdownMenuItem(value: role, child: Text(role)),
                  ],
                  onChanged: (v) {
                    if (v != null) setModalState(() => selectedRole = v);
                  },
                  decoration: InputDecoration(
                    labelText: 'Jukumu (Role)',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: selectedBranch,
                  // Driven by AppConstants.branches. The old hand-written list
                  // omitted Mbagala entirely, so a Mbagala staff member could
                  // not be assigned to their own branch.
                  items: [
                    for (final b in AppConstants.branches)
                      DropdownMenuItem(value: b, child: Text(b)),
                  ],
                  onChanged: (v) {
                    if (v != null) setModalState(() => selectedBranch = v);
                  },
                  decoration: InputDecoration(
                    labelText: 'Tawi Lililopangiwa',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: pinCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  decoration: InputDecoration(
                    labelText: 'Supervisor Approval PIN',
                    counterText: '',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      final name = nameCtrl.text.trim();
                      if (name.isEmpty) {
                        LimsToast.show(
                            context, 'Tafadhali ingiza jina la mfanyakazi',
                            isError: true);
                        return;
                      }

                      final newMember = StaffMember(
                        id: 'STF-${DateTime.now().millisecondsSinceEpoch % 10000}',
                        name: name,
                        role: selectedRole,
                        email: emailCtrl.text.trim().isEmpty
                            ? '$name@limstanzania.co.tz'
                                .toLowerCase()
                                .replaceAll(' ', '.')
                            : emailCtrl.text.trim(),
                        phone: phoneCtrl.text.trim(),
                        branch: selectedBranch,
                        staffCode: staffCodeCtrl.text.trim(),
                        supervisorPin: pinCtrl.text.trim(),
                        status: 'Active',
                        canDisburseLoans: UserRoles.canHandleCash(selectedRole),
                        canKnoxLock: UserRoles.canApprove(selectedRole) ||
                            UserRoles.normalize(selectedRole) ==
                                UserRoles.loanOfficer,
                        canViewMargins: UserRoles.canApprove(selectedRole),
                        canEditStock: UserRoles.canManageStock(selectedRole),
                        canApproveOverrides: UserRoles.canApprove(selectedRole),
                        lastActive: 'Active now',
                        grad: const [AppTheme.brand600, AppTheme.brand700],
                      );

                      ref.read(staffProvider.notifier).addStaff(newMember);
                      Navigator.pop(ctx);
                      LimsToast.show(context, '$name amesajiliwa kikamilifu!');
                    },
                    icon: const Icon(Icons.check_circle_rounded, size: 18),
                    label: const Text('Sajili Mfanyakazi',
                        style: TextStyle(
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

  Widget _buildKpiCard({
    required String label,
    required String value,
    required String trend,
    required IconData icon,
    required Color color,
    required Color bg,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
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
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppTheme.ink500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16.5,
              fontWeight: FontWeight.w800,
              color: AppTheme.ink900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            trend,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  void _showBranchAuditModal(BuildContext context, Map<String, dynamic> b) {
    LimsBottomSheet.show(
      context: context,
      builder: (ctx) => LimsBottomSheet(
        title: b['name'] as String,
        subtitle: 'Live Branch Audit & Custodian Status',
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFE7F8F0),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text('Operational',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF12B76A))),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text('Shift Custodian (Active Staff):',
                            style: TextStyle(
                                fontSize: 12, color: AppTheme.ink500)),
                      ),
                      SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'David Erick Mwijage',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.ink900),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 16, color: Color(0xFFEDF2F7)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                          child: Text("Today's Net Sales:",
                              style: TextStyle(
                                  fontSize: 12, color: AppTheme.ink500))),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          b['sales'] as String,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.brand600),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 16, color: Color(0xFFEDF2F7)),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                          child: Text('Cash in Branch Safe / Drawer:',
                              style: TextStyle(
                                  fontSize: 12, color: AppTheme.ink500))),
                      SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'TZS 3,840,000',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF12B76A)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      context.push('/reports');
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Full Ledger',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      context.push('/transfer');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.brand600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Dispatch Stock',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showAlertActionModal(BuildContext context, Map<String, dynamic> a) {
    final title = a['title'] as String;
    final isLoan = title.contains('loan') || title.contains('Komba');

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
                  label: const Text('Weka Device Hold',
                      style: TextStyle(fontWeight: FontWeight.w700)),
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
