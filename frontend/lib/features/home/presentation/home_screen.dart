import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/data/inventory_provider.dart';
import '../../../core/data/product_art.dart';
import '../../../core/data/mock_lims_data.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../core/widgets/phone_deals_carousel.dart';
import '../../loans/presentation/borrower_loan_details_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _isSyncing = false;

  final List<String> _branches = [
    'Kariakoo Branch',
    'Posta Main Branch',
    'Mwenge Branch',
    'Mlimani City Mall',
    'Mbezi Branch',
    'Mwanza Branch',
    'Arusha Branch',
    'Dodoma Branch',
    'Zanzibar Branch',
  ];

  // P0: client-side role switcher removed. Role is server-assigned and
  // shown read-only in the header chip below.

  void _triggerSync() async {
    if (_isSyncing) return;
    setState(() => _isSyncing = true);
    await Future.delayed(const Duration(milliseconds: 1200));
    if (mounted) {
      setState(() => _isSyncing = false);
      LimsToast.show(
        context,
        'All branch stock & transactions synced with HQ',
        isSuccess: true,
      );
    }
  }

  void _openBranchSelector() {
    final currentRole = ref.read(userRoleProvider);
    final isSuperAdmin =
        UserRoles.normalize(currentRole) == UserRoles.superAdmin;
    final activeBranch = ref.read(activeBranchProvider);

    if (!isSuperAdmin) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.only(
            bottom: MediaQuery.of(context).size.height - 160,
            left: 18,
            right: 18,
          ),
          backgroundColor: const Color(0xFF0F172A),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.lock_rounded,
                    color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Branch Switching Restricted',
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          fontSize: 13),
                    ),
                    Text(
                      '$currentRole permissions are scoped to $activeBranch terminal.',
                      style: const TextStyle(
                          color: Color(0xFF94A3B8), fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
      return;
    }

    LimsBottomSheet.show(
      context: context,
      builder: (ctx) => LimsBottomSheet(
        title: 'Select Active Branch',
        subtitle:
            'Switch terminal location & live stock inventory (Super Admin Scope)',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ..._branches.map((b) {
              final isSelected = activeBranch == b;
              return ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                leading: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.brand100
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.storefront_rounded,
                    color: isSelected ? AppTheme.brand600 : AppTheme.ink500,
                    size: 20,
                  ),
                ),
                title: Text(
                  b,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected ? AppTheme.brand600 : AppTheme.ink900,
                  ),
                ),
                trailing: isSelected
                    ? const Icon(Icons.check_circle_rounded,
                        color: AppTheme.brand600)
                    : null,
                onTap: () {
                  ref.read(activeBranchProvider.notifier).setBranch(b);
                  Navigator.pop(ctx);
                  LimsToast.show(context, 'Switched terminal to $b',
                      isSuccess: true);
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  void _showTopNotificationsModal(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Notifications',
      barrierColor: Colors.black.withValues(alpha: 0.45),
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (ctx, anim1, anim2) {
        return Align(
          alignment: Alignment.topCenter,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: double.infinity,
              margin: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 10,
                left: 14,
                right: 14,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x330F3478),
                    blurRadius: 30,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 14, 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                    Icons.notifications_active_rounded,
                                    color: Color(0xFF1E60F2),
                                    size: 18),
                              ),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text(
                                  'In-App Notifications',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF0F172A)),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded,
                              size: 20, color: Color(0xFF64748B)),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),
                  _buildNotificationItem(
                    icon: Icons.warning_amber_rounded,
                    iconBg: const Color(0xFFFEF2F2),
                    iconColor: const Color(0xFFDC2626),
                    title: 'Critical Stock: Galaxy A55',
                    subtitle:
                        '4 units remaining in safe buffer. Reorder needed.',
                    time: '10m ago',
                    onTap: () {
                      Navigator.pop(ctx);
                      _showAllLowStock();
                    },
                  ),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  _buildNotificationItem(
                    icon: Icons.payments_rounded,
                    iconBg: const Color(0xFFEFF6FF),
                    iconColor: const Color(0xFF1E60F2),
                    title: 'Loan Installment Due Today',
                    subtitle: 'John Mwalimu · TZS 225,000 via M-Pesa.',
                    time: '35m ago',
                    onTap: () {
                      Navigator.pop(ctx);
                      context.go('/loans');
                    },
                  ),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  _buildNotificationItem(
                    icon: Icons.qr_code_scanner_rounded,
                    iconBg: const Color(0xFFEFF6FF),
                    iconColor: AppTheme.brand600,
                    title: 'Hardware Serial Ledger Verification',
                    subtitle:
                        'All branch serialized IMEIs matched against physical inventory.',
                    time: '1h ago',
                    onTap: () {
                      Navigator.pop(ctx);
                      context.push('/scanner');
                    },
                  ),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  _buildNotificationItem(
                    icon: Icons.how_to_reg_rounded,
                    iconBg: const Color(0xFFECFDF5),
                    iconColor: const Color(0xFF059669),
                    title: 'Shift Attendance Logged',
                    subtitle:
                        'Zawadi Nnaji clocked in at 07:58 AM (Geofence verified).',
                    time: '07:58 AM',
                    onTap: () {
                      Navigator.pop(ctx);
                      context.push('/attendance');
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content:
                                  Text('All notifications marked as read.'),
                              backgroundColor: Color(0xFF10B981),
                            ),
                          );
                        },
                        child: const Text('Mark all as read',
                            style: TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 12.5)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      transitionBuilder: (ctx, anim1, anim2, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -0.4),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic)),
          child: FadeTransition(opacity: anim1, child: child),
        );
      },
    );
  }

  Widget _buildNotificationItem({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String time,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: iconBg, borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          time,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 10.5, color: Color(0xFF94A3B8)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11.5, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAllLowStock() {
    final lowStockItems = ref
        .read(inventoryProvider)
        .where((p) => p.status == 'low' || p.stock <= p.min)
        .toList();
    LimsBottomSheet.show(
      context: context,
      builder: (ctx) => LimsBottomSheet(
        title: 'Low Stock Models',
        subtitle: '${lowStockItems.length} models require urgent restock',
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFFFEDF1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '${lowStockItems.length} critical',
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFFF43F5E)),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (lowStockItems.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text('All models are currently well stocked!',
                      style: TextStyle(
                          color: AppTheme.ink500, fontWeight: FontWeight.w600)),
                ),
              )
            else
              ...lowStockItems.map((p) {
                return Column(
                  children: [
                    _buildLowStockItem(
                      name: p.name,
                      leftCount: p.stock,
                      colorType: p.name.toLowerCase().contains('samsung')
                          ? 'navy'
                          : 'silver',
                      onTap: () {
                        Navigator.pop(ctx);
                        _showPhoneQuickAction(p.name, p.stock);
                      },
                    ),
                    const Divider(height: 18, color: Color(0xFFF1F5F9)),
                  ],
                );
              }),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  context.push('/receive');
                },
                icon: const Icon(Icons.archive_rounded, size: 18),
                label: const Text('Request Hub Restock (PO)',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.brand600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSupervisorPinDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(22),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3F2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.pin_outlined,
                            color: Color(0xFFD92D20), size: 20),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Supervisor Override PIN',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A)),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Column(
                children: [
                  Text(
                    'Active Branch Override Master PIN',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B)),
                  ),
                  SizedBox(height: 6),
                  Text(
                    '8 8 2 1',
                    style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 8,
                        color: Color(0xFF1E60F2)),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Use this PIN at counter to authorize custom cash discounts or override minimum deposit requirements.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Pending Counter Requests (1)',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.discount_rounded,
                      color: Color(0xFF1E60F2), size: 22),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Galaxy A15 · TZS 30,000 Discount',
                            style: TextStyle(
                                fontSize: 12.5, fontWeight: FontWeight.w700)),
                        Text('Requested by Zawadi (Till #2) · Cash Buyer',
                            style: TextStyle(
                                fontSize: 11, color: Color(0xFF475569))),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'Discount authorized! OTP PIN dispatched to Till #2.'),
                          backgroundColor: Color(0xFF10B981),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E60F2),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      minimumSize: Size.zero,
                    ),
                    child: const Text('Approve',
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                            fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentRole = ref.watch(userRoleProvider);
    final activeStaff = ref.watch(activeStaffMemberProvider);
    final isSuperAdmin = currentRole == UserRoles.superAdmin;
    final isBranchManager = currentRole == UserRoles.branchManager;
    final isLoanOfficer = currentRole == UserRoles.loanOfficer;
    final isStorekeeper = currentRole == UserRoles.storekeeper;
    final isAuditor = currentRole == UserRoles.auditor;

    final activeBranch = ref.watch(activeBranchProvider);
    final totalStock = ref.watch(totalPhonesCountProvider);
    final activeLoans = ref.watch(loansProvider).length;
    final todaySales = ref.watch(todaySalesTotalProvider);
    final todayTx = ref.watch(todayTransactionsCountProvider);
    // Portfolio health is derived, not typed in: a rate that never moves is the
    // fastest way to lose trust in a dashboard.
    final _loanList = ref.watch(loansProvider);
    final _overdueCount =
        _loanList.where((l) => l.status == 'overdue').length;
    final _onTimeRate = _loanList.isEmpty
        ? 0
        : (((_loanList.length - _overdueCount) / _loanList.length) * 100).round();
    final allLowStock = ref
        .watch(inventoryProvider)
        .where((p) => p.status == 'low' || p.stock <= p.min)
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FC),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF8EC5FC), Color(0xFFE2EAF8), Color(0xFFF4F7FC)],
            stops: [0.0, 0.14, 0.35],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 110),
            children: [
              // Header with active staff profile
              _buildHeader(context, currentRole, activeBranch, activeStaff),
              const SizedBox(height: 18),

              // Role-Specific Hero Banners & Consoles
              if (isSuperAdmin) ...[
                _buildHeroCard(todaySales, todayTx),
                const SizedBox(height: 16),
                _buildAdminConsoleSection(context),
                const SizedBox(height: 16),
              ] else if (isBranchManager) ...[
                _buildBranchManagerHeroCard(todaySales, todayTx, activeBranch),
                const SizedBox(height: 16),
                _buildBranchManagerConsoleSection(context, activeBranch),
                const SizedBox(height: 16),
              ] else if (isLoanOfficer) ...[
                _buildLoanOfficerHeroCard(activeLoans, 1),
                const SizedBox(height: 16),
              ] else if (isStorekeeper) ...[
                _buildStorekeeperHeroCard(totalStock, allLowStock.length),
                const SizedBox(height: 16),
              ] else if (isAuditor) ...[
                // Read-only role: no till figure, no sales actions.
                _buildAuditorNoticeCard(),
                const SizedBox(height: 16),
              ] else ...[
                // Counter Cashier Hero (the only remaining operational role)
                _buildCashierTillHeroCard(todaySales, todayTx),
                const SizedBox(height: 16),
                _buildFeaturedDealsSection(context),
                const SizedBox(height: 16),
              ],

              // Two Metric Cards: Total Stock & Active Loans (Redesigned)
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      icon: Icons.phone_android_rounded,
                      label: isStorekeeper ? 'Warehouse Units' : 'Total Stock',
                      value: '$totalStock',
                      unit: 'phones',
                      trend: '$todayTx sold today',
                      trendColor: const Color(0xFF10B981),
                      iconBg: const Color(0xFFEFF5FE),
                      iconColor: const Color(0xFF1E60F2),
                      subText: '${allLowStock.length} low stock alerts',
                      onTap: _showAllLowStock,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricCard(
                      icon: Icons.people_outline_rounded,
                      label:
                          isLoanOfficer ? 'Credit Portfolio' : 'Active Loans',
                      value: '$activeLoans',
                      unit: 'accounts',
                      trend: '$_onTimeRate% on-time',
                      trendColor: const Color(0xFF6366F1),
                      iconBg: const Color(0xFFF3E8FF),
                      iconColor: const Color(0xFF7C3AED),
                      subText: '$_overdueCount overdue payment${_overdueCount == 1 ? '' : 's'}',
                      onTap: () => context.go('/loans'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Ask LIMS AI Card
              _buildAskAiCard(context),
              const SizedBox(height: 18),

              // Quick Actions Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      isSuperAdmin
                          ? 'HQ Management Hub'
                          : (isBranchManager
                              ? 'Branch Operations'
                              : (isLoanOfficer
                                  ? 'Credit Operations'
                                  : (isStorekeeper
                                      ? 'Logistics Operations'
                                      : 'Counter POS Actions'))),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE9F2FE),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      // Show the real session role. The old nested ternary had no
                      // Auditor branch, so an Auditor was displayed as
                      // 'Counter Cashier'.
                      child: Text(
                        UserRoles.normalize(currentRole) ?? '—',
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E60F2),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 2x2 Bento Action Grid tailored strictly by Role (No Counter ordering shipments!)
              Column(
                children: isSuperAdmin
                    ? [
                        Row(
                          children: [
                            Expanded(
                              child: _buildBentoActionCard(
                                icon: Icons.admin_panel_settings_rounded,
                                iconBg: const Color(0xFFF3E8FF),
                                iconColor: const Color(0xFF7C3AED),
                                title: 'Admin Hub',
                                subtitle: 'HQ Control & Staff',
                                onTap: () => context.push('/admin'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildBentoActionCard(
                                icon: Icons.fact_check_outlined,
                                iconBg: const Color(0xFFE0EDFE),
                                iconColor: const Color(0xFF1E60F2),
                                title: 'Stock Audits',
                                subtitle: 'Verify IMEI Balance',
                                onTap: () => context.push('/admin'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _buildBentoActionCard(
                                icon: Icons.swap_horiz_rounded,
                                iconBg: const Color(0xFFE0F2FE),
                                iconColor: const Color(0xFF0284C7),
                                title: 'Transfers',
                                subtitle: 'Between Hubs',
                                onTap: () => context.push('/transfer'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildBentoActionCard(
                                icon: Icons.bar_chart_rounded,
                                iconBg: const Color(0xFFDCFCE7),
                                iconColor: const Color(0xFF16A34A),
                                title: 'Margins',
                                subtitle: 'Profit Analysis',
                                onTap: () => context.push('/reports'),
                              ),
                            ),
                          ],
                        ),
                      ]
                    : (isBranchManager
                        ? [
                            Row(
                              children: [
                                Expanded(
                                  child: _buildBentoActionCard(
                                    icon: Icons.assessment_rounded,
                                    iconBg: const Color(0xFFE0EDFE),
                                    iconColor: const Color(0xFF1E60F2),
                                    title: 'Sales Audit',
                                    subtitle: 'Reconcile Tills',
                                    onTap: () => context.push('/reports'),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _buildBentoActionCard(
                                    icon: Icons.lock_open_rounded,
                                    iconBg: const Color(0xFFFEF3F2),
                                    iconColor: const Color(0xFFD92D20),
                                    title: 'Supervisor PIN',
                                    subtitle: 'Discount Overrides',
                                    onTap: () =>
                                        _showSupervisorPinDialog(context),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildBentoActionCard(
                                    icon: Icons.store_mall_directory_rounded,
                                    iconBg: const Color(0xFFE0F2FE),
                                    iconColor: const Color(0xFF0284C7),
                                    title: 'Branch Stock',
                                    subtitle: 'Cabinet & Safe Buffer',
                                    onTap: () => context.push('/stock'),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _buildBentoActionCard(
                                    icon: Icons.access_time_filled_rounded,
                                    iconBg: const Color(0xFFDCFCE7),
                                    iconColor: const Color(0xFF16A34A),
                                    title: 'Staff Shifts',
                                    subtitle: 'Attendance Roster',
                                    onTap: () => context.push('/attendance'),
                                  ),
                                ),
                              ],
                            ),
                          ]
                        : (isLoanOfficer
                            ? [
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildBentoActionCard(
                                        icon: Icons.badge_outlined,
                                        iconBg: const Color(0xFFF3E8FF),
                                        iconColor: const Color(0xFF7C3AED),
                                        title: 'Issue Loan',
                                        subtitle: 'KYC & Collateral',
                                        onTap: () => context
                                            .push('/sell-loan?type=LOAN'),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _buildBentoActionCard(
                                        icon:
                                            Icons.assignment_turned_in_rounded,
                                        iconBg: const Color(0xFFDCFCE7),
                                        iconColor: const Color(0xFF16A34A),
                                        title: 'Credit Review',
                                        subtitle: 'Approve Tier 1 & 2',
                                        onTap: () => context.go('/loans'),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildBentoActionCard(
                                        icon: Icons.qr_code_scanner_rounded,
                                        iconBg: const Color(0xFFEFF6FF),
                                        iconColor: AppTheme.brand600,
                                        title: 'Hardware Inspector',
                                        subtitle: 'Verify Phone IMEI',
                                        onTap: () => context.push('/scanner'),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _buildBentoActionCard(
                                        icon:
                                            Icons.notifications_active_rounded,
                                        iconBg: const Color(0xFFFEF08A),
                                        iconColor: const Color(0xFFCA8A04),
                                        title: 'Collections',
                                        subtitle: 'Overdue Queue',
                                        onTap: () => context.go('/loans'),
                                      ),
                                    ),
                                  ],
                                ),
                              ]
                            : (isStorekeeper
                                ? [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _buildBentoActionCard(
                                            icon: Icons.inventory_2_outlined,
                                            iconBg: const Color(0xFFE0EDFE),
                                            iconColor: const Color(0xFF1E60F2),
                                            title: 'Receive PO',
                                            subtitle: 'Supplier IMEI Intake',
                                            onTap: () =>
                                                context.push('/receive'),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: _buildBentoActionCard(
                                            icon: Icons.qr_code_scanner_rounded,
                                            iconBg: const Color(0xFFF3E8FF),
                                            iconColor: const Color(0xFF7C3AED),
                                            title: 'IMEI Scanner',
                                            subtitle: 'Barcode Inspection',
                                            onTap: () =>
                                                context.push('/scanner'),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _buildBentoActionCard(
                                            icon: Icons.local_shipping_rounded,
                                            iconBg: const Color(0xFFE0F2FE),
                                            iconColor: const Color(0xFF0284C7),
                                            title: 'Transfers',
                                            subtitle: 'Dispatch & Waybills',
                                            onTap: () =>
                                                context.push('/transfer'),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: _buildBentoActionCard(
                                            icon: Icons.shelves,
                                            iconBg: const Color(0xFFDCFCE7),
                                            iconColor: const Color(0xFF16A34A),
                                            title: 'Physical Count',
                                            subtitle: 'Cabinet Audits',
                                            onTap: () => context.push('/stock'),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ]
                                : [
                                    // Counter Cashier: strictly retail operations (Merged Cash/Loan Sale + Customer Directory)
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _buildBentoActionCard(
                                            icon: Icons.point_of_sale_rounded,
                                            iconBg: const Color(0xFFE0EDFE),
                                            iconColor: const Color(0xFF1E60F2),
                                            title: 'New POS Sale',
                                            subtitle: 'Cash or Loan Checkout',
                                            onTap: () =>
                                                context.push('/sell-loan'),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: _buildBentoActionCard(
                                            icon: Icons.badge_outlined,
                                            iconBg: const Color(0xFFF3E8FF),
                                            iconColor: const Color(0xFF7C3AED),
                                            title: 'Customer Directory',
                                            subtitle: 'View Profiles & Status',
                                            onTap: () => context.go('/loans'),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _buildBentoActionCard(
                                            icon: Icons.qr_code_scanner_rounded,
                                            iconBg: const Color(0xFFE0F2FE),
                                            iconColor: const Color(0xFF0284C7),
                                            title: 'Scan Cabinet',
                                            subtitle: 'Check Stock Ready',
                                            onTap: () =>
                                                context.push('/scanner'),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: _buildBentoActionCard(
                                            icon: Icons
                                                .access_time_filled_rounded,
                                            iconBg: const Color(0xFFDCFCE7),
                                            iconColor: const Color(0xFF16A34A),
                                            title: 'Clock Shift',
                                            subtitle: 'Till Log & Drawer',
                                            onTap: () =>
                                                context.push('/attendance'),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ]))),
              ),
              const SizedBox(height: 20),

              // Branch Operational Pulse (Crisp, High-Yield Status Hub)
              _buildOperationalPulseSection(
                  context, allLowStock, ref.watch(loansProvider)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBorrowerQuickWatchList(
      BuildContext context, List<LoanItem> loans) {
    final watchLoans = loans.take(3).toList();

    return Column(
      children: watchLoans.map((l) {
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: l.isKnoxLocked
                  ? const Color(0xFFFECDD3)
                  : const Color(0xFFE2E8F0),
            ),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x080F3478),
                  blurRadius: 14,
                  offset: Offset(0, 3)),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (ctx) =>
                        BorrowerLoanDetailsScreen(loanId: l.id, initialLoan: l),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                            colors: l.grad,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          l.initials,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 13),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  l.name,
                                  style: const TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w800,
                                      color: AppTheme.ink900),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (l.isKnoxLocked) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFEDF1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text('ON HOLD',
                                      style: TextStyle(
                                          fontSize: 8.5,
                                          fontWeight: FontWeight.w800,
                                          color: AppTheme.errorColor)),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${l.item} · ${l.due}',
                            style: const TextStyle(
                                fontSize: 11, color: AppTheme.ink500),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          l.formattedRemainingAmount,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: l.status == 'overdue'
                                ? AppTheme.errorColor
                                : AppTheme.brand600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${l.paid}% repaid',
                          style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF9AA8BF)),
                        ),
                      ],
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right_rounded,
                        color: Color(0xFFCBD5E1), size: 18),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  void _showPhoneQuickAction(String name, int left) {
    final activeBranch = ref.read(activeBranchProvider);
    final currentRole = ref.read(userRoleProvider);
    final isCashier = currentRole == UserRoles.counterCashier;

    LimsBottomSheet.show(
      context: context,
      builder: (ctx) => LimsBottomSheet(
        title: name,
        subtitle: 'Only $left units remaining at $activeBranch',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEDF1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: Color(0xFFF43F5E), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isCashier
                          ? 'Stock is below buffer threshold. Notify storekeeper for cabinet replenishment.'
                          : 'Stock is below minimum reorder point for $activeBranch. Initiate transfer or issue PO.',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFF43F5E)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      context.push('/sell-loan?type=SELL');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.brand600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Sell at Counter',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      if (isCashier) {
                        LimsToast.show(context,
                            'Replenishment request for $name sent to Storekeeper.',
                            isSuccess: true);
                      } else {
                        context.push('/receive');
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.brand600,
                      side: const BorderSide(color: Color(0xFFCEE1FE)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(isCashier ? 'Request Stock' : 'Restock PO',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------- Branch Operational Pulse
  Widget _buildOperationalPulseSection(
      BuildContext context, List<ProductItem> lowStock, List<LoanItem> loans) {
    final activeBranch = ref.watch(activeBranchProvider);
    final overdueLoans = loans.where((l) => l.status == 'overdue').length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F3478),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Row(
                  children: [
                    Icon(Icons.insights_rounded,
                        size: 18, color: AppTheme.brand600),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Branch Operations Pulse',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF5FE),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    activeBranch,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.brand600,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Low Stock Alert Banner (shows alert beacon if items need restocking)
          if (lowStock.isNotEmpty) ...[
            _buildLowStockNotificationBanner(context, lowStock),
            const SizedBox(height: 12),
          ],

          // Low Stock Quick Row
          InkWell(
            onTap: _showAllLowStock,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFFEDD5)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEA580C),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.warning_amber_rounded,
                        color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${lowStock.length} Phone Models Need Restock',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF9A3412),
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Tap to view inventory buffer & restock PO',
                          style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFFC2410C),
                              fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded,
                      color: Color(0xFFEA580C), size: 20),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Device hold & collection quick row
          InkWell(
            onTap: () => context.go('/loans'),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFDBEAFE)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.security_rounded,
                        color: Colors.white, size: 19),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$overdueLoans Overdue Accounts Requiring Action',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1E40AF),
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Tap to review borrower dossier and contact guarantor',
                          style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF1D4ED8),
                              fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded,
                      color: Color(0xFF2563EB), size: 20),
                ],
              ),
            ),
          ),

          // Critical Overdue / recovery borrower preview (if any)
          if (loans.any((l) => l.status == 'overdue')) ...[
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'Critical Collections & Arrears',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => context.go('/loans'),
                  child: const Text(
                    'Manage all',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E60F2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildBorrowerQuickWatchList(
              context,
              loans.where((l) => l.status == 'overdue').take(2).toList(),
            ),
          ],
        ],
      ),
    );
  }

  // ------------------------------------------------------------- Header
  Widget _buildHeader(BuildContext context, String currentRole,
      String activeBranch, StaffMember activeStaff) {
    final isSuperAdmin = currentRole == UserRoles.superAdmin;
    final isBranchManager = currentRole == UserRoles.branchManager;
    final isLoanOfficer = currentRole == UserRoles.loanOfficer;
    final isStorekeeper = currentRole == UserRoles.storekeeper;

    final Color roleColor = isSuperAdmin
        ? const Color(0xFF7C3AED)
        : (isBranchManager
            ? const Color(0xFF1E60F2)
            : (isLoanOfficer
                ? const Color(0xFF059669)
                : (isStorekeeper
                    ? const Color(0xFF0284C7)
                    : const Color(0xFFEA580C))));

    final IconData roleIcon = isSuperAdmin
        ? Icons.admin_panel_settings_rounded
        : (isBranchManager
            ? Icons.manage_accounts_rounded
            : (isLoanOfficer
                ? Icons.verified_user_rounded
                : (isStorekeeper
                    ? Icons.inventory_2_rounded
                    : Icons.point_of_sale_rounded)));

    final allLowStock = ref
        .watch(inventoryProvider)
        .where((p) => p.status == 'low' || p.stock <= p.min)
        .toList();
    final firstName = activeStaff.name.split(' ')[0];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Left Profile Info with Responsive Expanded Constraints
        Expanded(
          child: Row(
            children: [
              // Circular Avatar Photo
              InkWell(
                onTap: () => context.push('/settings'),
                borderRadius: BorderRadius.circular(99),
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x1F0F3478),
                        blurRadius: 10,
                        offset: Offset(0, 3),
                      ),
                    ],
                    gradient: LinearGradient(
                      colors: activeStaff.grad,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      UserRoles.avatarAsset(activeStaff.role),
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Center(
                        child: Text(
                          activeStaff.initials,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Good morning,',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(height: 1),
                    Row(
                      children: [
                        Text(
                          firstName,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.4,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          // P0: read-only role badge. No tap — role is server-assigned.
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: roleColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(99),
                              border: Border.all(
                                color: roleColor.withValues(alpha: 0.35),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  roleIcon,
                                  size: 11,
                                  color: roleColor,
                                ),
                                const SizedBox(width: 3),
                                Flexible(
                                  child: Text(
                                    currentRole,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w800,
                                      color: roleColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    InkWell(
                      onTap: _openBranchSelector,
                      borderRadius: BorderRadius.circular(6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.location_on_rounded,
                              size: 13, color: Color(0xFF1E293B)),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              activeBranch,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                          ),
                          const SizedBox(width: 2),
                          Icon(
                              isSuperAdmin
                                  ? Icons.keyboard_arrow_down_rounded
                                  : Icons.lock_outline_rounded,
                              size: 13,
                              color: const Color(0xFF1E293B)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),

        // Right Action Items: Bell with Badge & Sync Status (Top-Pinned Notifications)
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: () => _showTopNotificationsModal(context),
              borderRadius: BorderRadius.circular(99),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    child: const Icon(
                      Icons.notifications_none_rounded,
                      size: 24,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  if (allLowStock.isNotEmpty)
                    Positioned(
                      top: 2,
                      right: 2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: Text(
                          '${allLowStock.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 2),
            InkWell(
              onTap: _triggerSync,
              borderRadius: BorderRadius.circular(99),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _isSyncing
                        ? const SizedBox(
                            width: 10,
                            height: 10,
                            child: CircularProgressIndicator(
                                strokeWidth: 1.6, color: Color(0xFF059669)),
                          )
                        : const Icon(Icons.check_circle_rounded,
                            size: 12, color: Color(0xFF059669)),
                    const SizedBox(width: 3),
                    Text(
                      _isSyncing ? 'Syncing…' : 'Live Sync',
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF059669),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ------------------------------------------------------------- Featured Deals Carousel Section
  Widget _buildFeaturedDealsSection(BuildContext context) {
    // Deals are read from live inventory instead of a hand-written list. When a
    // cashier sells a handset its stock drops here immediately, and a model that
    // runs out disappears from the carousel instead of advertising a device the
    // shop no longer has.
    final phones = ref
        .watch(inventoryProvider)
        .where((p) => p.cat == 'phones' && p.stock > 0 && p.status != 'out')
        .toList()
      ..sort((a, b) => b.stock.compareTo(a.stock));

    const palettes = <List<Color>>[
      [Color(0xFF312E81), Color(0xFF4338CA), Color(0xFF6366F1)],
      [Color(0xFF134E4A), Color(0xFF0F766E), Color(0xFF14B8A6)],
      [Color(0xFF1E3A8A), Color(0xFF1D4ED8), Color(0xFF3B82F6)],
      [Color(0xFF78350F), Color(0xFFB45309), Color(0xFFF59E0B)],
    ];
    const glows = <Color>[
      Color(0xFF6366F1),
      Color(0xFF14B8A6),
      Color(0xFF3B82F6),
      Color(0xFFF59E0B),
    ];

    final deals = <FeaturedPhoneDeal>[];
    for (var i = 0; i < phones.length && i < 4; i++) {
      final p = phones[i];
      final deposit = (p.price * 0.25).round();
      final monthly = (p.price * 0.75 / 8).round();
      deals.add(
        FeaturedPhoneDeal(
          id: 'deal_${p.id}',
          title: p.name,
          subtitle:
              'Deposit ${LimsFormatters.currencyCompact(deposit)} · ${LimsFormatters.currencyCompact(monthly)} / month',
          badge: p.status == 'low' ? '⚠️ STOCK NDOGO' : '⚡ 0% DOWNPAYMENT',
          badgeBg: p.status == 'low'
              ? const Color(0x33F59E0B)
              : const Color(0x33FBBF24),
          badgeTextColor: const Color(0xFFFDE68A),
          gradient: palettes[i % palettes.length],
          glowColor: glows[i % glows.length],
          imageAsset: p.imageAsset ??
              ProductArt.resolve(brand: p.brand, name: p.name, category: p.cat),
          tag1: '${p.stock} in stock',
          tag2: p.imei1 != null ? 'IMEI registered' : p.variant,
          cashPrice: LimsFormatters.currencyCompact(p.price),
          monthlyDue: '${LimsFormatters.currencyCompact(monthly)}/mo',
          actionLabel: 'Issue Loan',
          onTap: () => context.push('/sell-loan?type=LOAN'),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Row(
                children: [
                  Icon(Icons.local_fire_department_rounded,
                      size: 18, color: Color(0xFFEF4444)),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Featured Phone Deals & Loan Offers',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.swipe_rounded, size: 12, color: Color(0xFFDC2626)),
                  SizedBox(width: 4),
                  Text(
                    'Swipe',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFDC2626)),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        PhoneDealsCarousel(deals: deals),
      ],
    );
  }

  // ------------------------------------------------------------- Hero Card (Today's Sales)
  // Product renders ship on BLACK backgrounds, so hero art always sits on
  // a white photo tile to stay visible on the dark hero gradients.
  Widget _buildHeroPhonePhoto(String asset) {
    // The product shot used to sit inside a white rounded tile, which read as a
    // pasted image on the gradient. The artwork is transparent now, so it floats
    // on the card with a soft glow instead of a white box.
    return SizedBox(
      width: 146,
      height: 168,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.22),
                  Colors.white.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(6),
            child: Image.asset(
              asset,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
              errorBuilder: (context, error, stackTrace) =>
                  _buildDualPhoneArtwork(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCard(int todaySales, int todayTx) {
    return Container(
      constraints: const BoxConstraints(minHeight: 164),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1652E1), Color(0xFF1E60F2), Color(0xFF3B82F6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x381E60F2),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // Subtle glowing wave in background
            Positioned(
              right: -30,
              top: -30,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.12),
                ),
              ),
            ),

            // Left Content
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.trending_up_rounded,
                          color: Colors.white, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        "Today's Sales",
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    LimsFormatters.currency(todaySales),
                    style: const TextStyle(
                      fontSize: 27,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.6,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 15,
                          height: 15,
                          decoration: const BoxDecoration(
                            color: Color(0xFF34D399),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.arrow_upward_rounded,
                              size: 10, color: Color(0xFF064E3B)),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '+$todayTx transactions today',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Right 3D Dual-Phone Photorealistic Asset
            Positioned(
              right: 4,
              bottom: -8,
              child: _buildHeroPhonePhoto('assets/images/blue_iphones_duo.png'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBranchManagerHeroCard(
      int branchSales, int branchTx, String activeBranch) {
    return Container(
      constraints: const BoxConstraints(minHeight: 164),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF312E81), Color(0xFF4338CA), Color(0xFF6366F1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x384338CA),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            Positioned(
              right: -30,
              top: -30,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.12),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.storefront_rounded,
                          color: Colors.white, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        "Branch Sales Today · $activeBranch",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    LimsFormatters.currency(branchSales),
                    style: const TextStyle(
                      fontSize: 27,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.6,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 15,
                          height: 15,
                          decoration: const BoxDecoration(
                            color: Color(0xFF34D399),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.arrow_upward_rounded,
                              size: 10, color: Color(0xFF064E3B)),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '+$branchTx branch sales today',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              right: 4,
              bottom: -8,
              child: _buildHeroPhonePhoto(
                  'assets/images/samsung_galaxy_ultra.png'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoanOfficerHeroCard(int activeLoans, int overdueCount) {
    return Container(
      constraints: const BoxConstraints(minHeight: 164),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF064E3B), Color(0xFF047857), Color(0xFF059669)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x38059669),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            Positioned(
              right: -30,
              top: -30,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.12),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.verified_user_rounded,
                          color: Colors.white, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        "Active Credit Portfolio",
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "TZS 28,450,000",
                    style: TextStyle(
                      fontSize: 27,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.6,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.shield_outlined,
                            size: 14, color: Colors.white),
                        const SizedBox(width: 6),
                        Text(
                          '$activeLoans loans · 98% on-time · $overdueCount overdue',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              right: 4,
              bottom: -8,
              child:
                  _buildHeroPhonePhoto('assets/images/redmi_note_13_pro.png'),
            ),
          ],
        ),
      ),
    );
  }

  /// Auditor landing card.
  ///
  /// The Auditor role is read-only. It deliberately shows no till balance, no
  /// sales figure and no action button, so a reader cannot mistake oversight
  /// access for operating access.
  Widget _buildAuditorNoticeCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E293B), Color(0xFF334155)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F334155),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0x1AFFFFFF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.visibility_rounded,
                    color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Read-only audit access',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'You can inspect registers, loan history and reports. Creating, editing, approving or disbursing is not available to this role.',
            style: TextStyle(
                fontSize: 12.5, height: 1.5, color: Color(0xFFCBD5E1)),
          ),
        ],
      ),
    );
  }

  Widget _buildStorekeeperHeroCard(int totalStock, int lowStockCount) {
    return Container(
      constraints: const BoxConstraints(minHeight: 164),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF0369A1), Color(0xFF0284C7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x380284C7),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            Positioned(
              right: -30,
              top: -30,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.12),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 148, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.inventory_2_rounded,
                          color: Colors.white, size: 18),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          "Warehouse Inventory Reserve",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "$totalStock Handsets",
                    style: const TextStyle(
                      fontSize: 27,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.6,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.qr_code_scanner_rounded,
                            size: 14, color: Colors.white),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            '+14 IMEI today · 2 POs',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              right: 4,
              bottom: -8,
              child: _buildHeroPhonePhoto('assets/images/tecno_camon_30.png'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCashierTillHeroCard(int drawerAmount, int salesCount) {
    return Container(
      constraints: const BoxConstraints(minHeight: 164),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3A8A), Color(0xFF2563EB), Color(0xFF3B82F6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x382563EB),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            Positioned(
              right: -30,
              top: -30,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.12),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.point_of_sale_rounded,
                          color: Colors.white, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        "My POS Till (Shift #104)",
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    LimsFormatters.currency(drawerAmount),
                    style: const TextStyle(
                      fontSize: 27,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.6,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_circle_rounded,
                            size: 14, color: Color(0xFF34D399)),
                        const SizedBox(width: 6),
                        Text(
                          '$salesCount sales closed today · Drawer balanced',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              right: 4,
              bottom: -8,
              child: _buildHeroPhonePhoto('assets/images/blue_iphones_duo.png'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBranchManagerConsoleSection(
      BuildContext context, String activeBranch) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C0F3478),
            blurRadius: 18,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF5FE),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.manage_accounts_rounded,
                          color: AppTheme.brand600, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Branch Supervisor Hub',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.ink900,
                            ),
                          ),
                          Text(
                            '$activeBranch · Drawer & Staff Shift Audit',
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
                  ],
                ),
              ),
              InkWell(
                onTap: () => context.push('/reports'),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5.5),
                  decoration: BoxDecoration(
                    color: AppTheme.brand600,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    children: [
                      Text(
                        'Audit Till',
                        style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.white),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward_rounded,
                          size: 12, color: Colors.white),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildAdminMiniKpi(
                  title: 'Drawer Cash',
                  val: 'TZS 3.2M',
                  color: const Color(0xFF12B76A),
                  sub: 'Balanced',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildAdminMiniKpi(
                  title: 'Overrides',
                  val: '1 Pending',
                  color: const Color(0xFFF79009),
                  sub: 'Awaiting approval',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildAdminMiniKpi(
                  title: 'Staff Active',
                  val: '4 / 4',
                  color: AppTheme.brand600,
                  sub: 'Present',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDualPhoneArtwork() {
    return SizedBox(
      width: 132,
      height: 148,
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          // Rear Phone (Titanium Blue body with camera island)
          Positioned(
            right: 48,
            bottom: 0,
            child: Transform.rotate(
              angle: -0.06,
              child: Container(
                width: 58,
                height: 120,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF708DA9), Color(0xFF415A77)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border:
                      Border.all(color: const Color(0xFF8DA9C4), width: 1.5),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x40000000),
                      blurRadius: 16,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    // Camera Island
                    Positioned(
                      top: 7,
                      left: 7,
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: const Color(0xFF293B52),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildLens(),
                                _buildLens(),
                              ],
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildLens(),
                                Container(
                                  width: 4,
                                  height: 4,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFFEF08A),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Front Phone (Display with colorful abstract wallpaper)
          Positioned(
            right: 0,
            bottom: 0,
            child: Transform.rotate(
              angle: 0.04,
              child: Container(
                width: 68,
                height: 138,
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF1E293B), width: 2),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x55000000),
                      blurRadius: 20,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Stack(
                    children: [
                      // Screen Wallpaper Gradient
                      Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Color(0xFF0F172A),
                              Color(0xFF1E3A8A),
                              Color(0xFF3B82F6),
                              Color(0xFF93C5FD),
                              Color(0xFFF43F5E),
                            ],
                            stops: [0.0, 0.25, 0.55, 0.8, 1.0],
                            begin: Alignment.bottomLeft,
                            end: Alignment.topRight,
                          ),
                        ),
                      ),

                      // Dynamic Island Pill
                      Positioned(
                        top: 5,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Container(
                            width: 18,
                            height: 4.5,
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLens() {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF64748B), width: 1),
      ),
      child: Center(
        child: Container(
          width: 3,
          height: 3,
          decoration: const BoxDecoration(
            color: Color(0xFF1E40AF),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------- 2 Metric Cards
  Widget _buildMetricCard({
    required IconData icon,
    required String label,
    required String value,
    required String unit,
    required String trend,
    required Color trendColor,
    required Color iconBg,
    required Color iconColor,
    required String subText,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A0F3478),
              blurRadius: 18,
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
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: trendColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.trending_up_rounded,
                            size: 11, color: trendColor),
                        const SizedBox(width: 2),
                        Flexible(
                          child: Text(
                            trend,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: trendColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 2),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 27,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.6,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  unit,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: trendColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    subText,
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF64748B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded,
                    size: 10, color: Color(0xFFCBD5E1)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------- Bento Action Cards (2x2 Grid)
  Widget _buildBentoActionCard({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x080F3478),
              blurRadius: 14,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF64748B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                size: 16, color: Color(0xFFCBD5E1)),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------- Low Stock Alert Banner
  Widget _buildLowStockNotificationBanner(
      BuildContext context, List<ProductItem> lowItems) {
    if (lowItems.isEmpty) return const SizedBox.shrink();

    final currentRole = ref.watch(userRoleProvider);
    final isCashier = currentRole == UserRoles.counterCashier;
    final itemNames =
        lowItems.take(2).map((p) => '${p.name} (${p.stock} left)').join(', ');
    final moreCount =
        lowItems.length > 2 ? ' +${lowItems.length - 2} more' : '';

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF1F2), Color(0xFFFFF7ED)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFFD4D8)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0DF43F5E),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFFF43F5E),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFF43F5E).withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(Icons.notifications_active_rounded,
                    color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Flexible(
                          child: Text(
                            'Low Stock Critical Alert',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF9F1239),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFE4E6),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${lowItems.length} Models',
                            style: const TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFE11D48),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$itemNames$moreCount',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFFBE123C),
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _showAllLowStock,
                  icon: const Icon(Icons.visibility_rounded, size: 14),
                  label: const Text('View All',
                      style: TextStyle(
                          fontSize: 11.5, fontWeight: FontWeight.w700)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF9F1239),
                    side: const BorderSide(color: Color(0xFFFECDD3)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: isCashier
                      ? () {
                          LimsToast.show(
                            context,
                            'Restock notification sent to Storekeeper and Branch Manager.',
                            isSuccess: true,
                          );
                        }
                      : () => context.push('/receive'),
                  icon: Icon(
                    isCashier
                        ? Icons.campaign_rounded
                        : Icons.add_shopping_cart_rounded,
                    size: 14,
                  ),
                  label: Text(
                    isCashier ? 'Notify Storekeeper' : 'Purchase Order (PO)',
                    style: const TextStyle(
                        fontSize: 11.5, fontWeight: FontWeight.w800),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE11D48),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------- Ask LIMS AI Card (Elevated Design)
  Widget _buildAskAiCard(BuildContext context) {
    return InkWell(
      onTap: () => context.push('/ai'),
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFEEF4FF), Color(0xFFF5F3FF), Color(0xFFFAF5FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFDDD6FE)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x127C3AED),
              blurRadius: 18,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2563EB), Color(0xFF7C3AED)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7C3AED).withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Ask LIMS AI',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFF7C3AED).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Gemini Pro',
                          style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF7C3AED)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Get instant branch insights & sales intelligence',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Icon(
                Icons.arrow_forward_rounded,
                size: 16,
                color: Color(0xFF7C3AED),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------- Low Stock Item
  Widget _buildLowStockItem({
    required String name,
    required int leftCount,
    required String colorType,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            // Dual mini phone thumbnail
            _buildPhoneMiniThumbnail(colorType),
            const SizedBox(width: 14),

            // Name & red count pill
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: const BoxDecoration(
                                color: Color(0xFFEF4444),
                                shape: BoxShape.circle,
                              ),
                              child: const Center(
                                child: Text(
                                  '!',
                                  style: TextStyle(
                                    fontSize: 8.5,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$leftCount units left',
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFDC2626),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const Icon(Icons.chevron_right_rounded,
                color: Color(0xFF94A3B8), size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildPhoneMiniThumbnail(String type) {
    final isBlue = type == 'blue';
    final isSilver = type == 'silver';

    final chassisColor = isBlue
        ? const Color(0xFF1E293B)
        : (isSilver ? const Color(0xFFE2E8F0) : const Color(0xFF0F172A));

    final screenGradient = isBlue
        ? const LinearGradient(
            colors: [Color(0xFF1E3A8A), Color(0xFF60A5FA)],
            begin: Alignment.bottomLeft,
            end: Alignment.topRight,
          )
        : const LinearGradient(
            colors: [Color(0xFF6B21A8), Color(0xFFC084FC)],
            begin: Alignment.bottomLeft,
            end: Alignment.topRight,
          );

    return SizedBox(
      width: 48,
      height: 48,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Rear Phone
          Positioned(
            left: 2,
            child: Container(
              width: 22,
              height: 42,
              decoration: BoxDecoration(
                color: chassisColor,
                borderRadius: BorderRadius.circular(5),
                border: Border.all(
                    color: Colors.black.withValues(alpha: 0.1), width: 0.5),
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: 3,
                    left: 3,
                    child: Container(
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                        color: Colors.black,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Front Phone with screen
          Positioned(
            right: 4,
            child: Container(
              width: 24,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF1E293B), width: 1),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x20000000),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: screenGradient,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminConsoleSection(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C0F3478),
            blurRadius: 18,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0EBFF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.admin_panel_settings_rounded,
                          color: Color(0xFF7C5CFC), size: 20),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Admin Executive Hub',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.ink900,
                            ),
                          ),
                          Text(
                            'HQ Multi-Branch Oversight & Audits',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
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
              ),
              InkWell(
                onTap: () => context.push('/admin'),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C5CFC),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    children: [
                      Text(
                        'Full Console',
                        style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.white),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward_rounded,
                          size: 12, color: Colors.white),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildAdminMiniKpi(
                  title: 'Net Margin',
                  val: '31.8%',
                  color: const Color(0xFF12B76A),
                  sub: '+2.4% vs target',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildAdminMiniKpi(
                  title: 'HQ Sales',
                  val: '18.4M',
                  color: AppTheme.brand600,
                  sub: '6 Branches',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildAdminMiniKpi(
                  title: 'Audits',
                  val: '2 Flagged',
                  color: const Color(0xFFF79009),
                  sub: 'Discrepancy',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAdminMiniKpi({
    required String title,
    required String val,
    required Color color,
    required String sub,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEDF2F7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 2),
          Text(
            val,
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w800, color: color),
          ),
          const SizedBox(height: 1),
          Text(
            sub,
            style: const TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w500,
                color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }
}
