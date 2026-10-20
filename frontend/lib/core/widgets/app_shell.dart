import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../constants/app_constants.dart';
import '../data/inventory_provider.dart';
import '../theme/app_theme.dart';
import '../services/live_data.dart';
import 'session_guard.dart';

class AppShell extends ConsumerStatefulWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _getCurrentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    if (location.startsWith('/home')) return 0;
    if (location.startsWith('/stock')) return 1;
    if (location.startsWith('/scan')) return 2;
    if (location.startsWith('/loans')) return 3;
    return 0;
  }

  void _openMoreSheet(BuildContext context, WidgetRef ref) {
    final currentRole = ref.watch(userRoleProvider);
    final isSuperAdmin = currentRole == UserRoles.superAdmin;
    final isBranchManager = currentRole == UserRoles.branchManager;
    final isStorekeeper = currentRole == UserRoles.storekeeper;
    final isCashier = currentRole == UserRoles.counterCashier;
    final isAuditor = currentRole == UserRoles.auditor;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 640),
      builder: (ctx) {
        final List<Widget> opButtons = [];

        // Auditor is read-only by definition: it gets no money, stock or
        // approval action at all, only the registers it is meant to inspect.
        if (isAuditor) {
          opButtons.addAll([
            _buildOpButton(
              context: ctx,
              icon: Icons.receipt_long_rounded,
              iconColor: AppTheme.brand600,
              title: 'Reports',
              sub: 'Read-only registers',
              route: '/reports',
            ),
            _buildOpButton(
              context: ctx,
              icon: Icons.account_balance_wallet_rounded,
              iconColor: const Color(0xFF7C5CFC),
              title: 'Loan Register',
              sub: 'Inspect only',
              route: '/loans',
            ),
            _buildOpButton(
              context: ctx,
              icon: Icons.inventory_2_rounded,
              iconColor: const Color(0xFF0EA5E9),
              title: 'Stock Register',
              sub: 'Inspect only',
              route: '/stock',
            ),
            _buildOpButton(
              context: ctx,
              icon: Icons.auto_awesome_rounded,
              iconColor: const Color(0xFF7C5CFC),
              title: 'AI Assistant',
              sub: 'Ask anything',
              route: '/ai',
            ),
          ]);
        } else if (isCashier) {
          opButtons.addAll([
            _buildOpButton(
              context: ctx,
              icon: Icons.point_of_sale_rounded,
              iconColor: AppTheme.brand600,
              title: 'Sell Phone (POS)',
              sub: 'Cash or loan',
              route: '/sell-loan',
            ),
            _buildOpButton(
              context: ctx,
              icon: Icons.fingerprint_rounded,
              iconColor: const Color(0xFF12B76A),
              title: 'Attendance',
              sub: 'Clock in & out',
              route: '/attendance',
            ),
            _buildOpButton(
              context: ctx,
              icon: Icons.calculate_rounded,
              iconColor: const Color(0xFFF79009),
              title: 'Daily Close',
              sub: 'Reconcile drawer',
              route: '/daily-closing',
            ),
            _buildOpButton(
              context: ctx,
              icon: Icons.auto_awesome_rounded,
              iconColor: const Color(0xFF7C5CFC),
              title: 'AI Assistant',
              sub: 'Ask anything',
              route: '/ai',
            ),
          ]);
        } else if (isStorekeeper) {
          opButtons.addAll([
            _buildOpButton(
              context: ctx,
              icon: Icons.archive_rounded,
              iconColor: AppTheme.brand600,
              title: 'Receive Stock',
              sub: 'Verify shipments',
              route: '/receive',
            ),
            _buildOpButton(
              context: ctx,
              icon: Icons.swap_horiz_rounded,
              iconColor: const Color(0xFF7C5CFC),
              title: 'Transfer',
              sub: 'Between branches',
              route: '/transfer',
            ),
            _buildOpButton(
              context: ctx,
              icon: Icons.fingerprint_rounded,
              iconColor: const Color(0xFF12B76A),
              title: 'Attendance',
              sub: 'Clock in & out',
              route: '/attendance',
            ),
            _buildOpButton(
              context: ctx,
              icon: Icons.auto_awesome_rounded,
              iconColor: const Color(0xFF7C5CFC),
              title: 'AI Assistant',
              sub: 'Ask anything',
              route: '/ai',
            ),
          ]);
        } else {
          opButtons.addAll([
            _buildOpButton(
              context: ctx,
              icon: Icons.archive_rounded,
              iconColor: AppTheme.brand600,
              title: 'Receive Stock',
              sub: 'Verify shipments',
              route: '/receive',
            ),
            _buildOpButton(
              context: ctx,
              icon: Icons.swap_horiz_rounded,
              iconColor: const Color(0xFF7C5CFC),
              title: 'Transfer',
              sub: 'Between branches',
              route: '/transfer',
            ),
            _buildOpButton(
              context: ctx,
              icon: Icons.fingerprint_rounded,
              iconColor: const Color(0xFF12B76A),
              title: 'Attendance',
              sub: 'Clock in & out',
              route: '/attendance',
            ),
            _buildOpButton(
              context: ctx,
              icon: Icons.point_of_sale_rounded,
              iconColor: const Color(0xFFF79009),
              title: 'Daily Close',
              sub: 'Reconcile drawer',
              route: '/daily-closing',
            ),
            _buildOpButton(
              context: ctx,
              icon: Icons.bar_chart_rounded,
              iconColor: const Color(0xFFF43F5E),
              title: 'Reports',
              sub: 'Sales & loans',
              route: '/reports',
            ),
            _buildOpButton(
              context: ctx,
              icon: Icons.auto_awesome_rounded,
              iconColor: const Color(0xFF7C5CFC),
              title: 'AI Assistant',
              sub: 'Ask anything',
              route: '/ai',
            ),
          ]);
        }

        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.92,
          ),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: EdgeInsets.fromLTRB(
              20,
              14,
              20,
              20 + MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD4E0F0),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Flexible(
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Active Role Scope Badge
                        // Role scope badge. Every role maps to its own colour/scope so a
                        // read-only Auditor can never be labelled "Full Admin".
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isAuditor
                                ? const Color(0xFFEEF2F6)
                                : (isCashier
                                    ? const Color(0xFFFEF3E4)
                                    : (isStorekeeper
                                        ? const Color(0xFFF0EBFF)
                                        : const Color(0xFFEFF6FF))),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isAuditor
                                  ? const Color(0xFFCBD5E1)
                                  : (isCashier
                                      ? const Color(0xFFFDE68A)
                                      : (isStorekeeper
                                          ? const Color(0xFFD8B4FE)
                                          : const Color(0xFFBFDBFE))),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isAuditor
                                    ? Icons.visibility_rounded
                                    : (isCashier
                                        ? Icons.point_of_sale_rounded
                                        : (isStorekeeper
                                            ? Icons.inventory_2_rounded
                                            : Icons.shield_rounded)),
                                size: 16,
                                color: isAuditor
                                    ? const Color(0xFF475569)
                                    : (isCashier
                                        ? const Color(0xFFD97706)
                                        : (isStorekeeper
                                            ? const Color(0xFF7C3AED)
                                            : AppTheme.brand600)),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Role: $currentRole',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: isAuditor
                                        ? const Color(0xFF334155)
                                        : (isCashier
                                            ? const Color(0xFF92400E)
                                            : (isStorekeeper
                                                ? const Color(0xFF5B21B6)
                                                : const Color(0xFF1E40AF))),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  isAuditor
                                      ? 'Read-only'
                                      : (isCashier
                                          ? 'Till Scope'
                                          : (isStorekeeper
                                              ? 'Warehouse'
                                              : 'Branch Admin')),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.ink500),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        const Text(
                          'Operations',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.ink900,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isAuditor
                              ? 'Read-only inspection of registers and reports'
                              : (isCashier
                                  ? 'Cashier till, sales & shift actions'
                                  : (isStorekeeper
                                      ? 'Warehouse & stock movements'
                                      : 'Core branch workflows & management')),
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.ink500,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Operations 2-column Grid
                        GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 2,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 2.2,
                          children: opButtons,
                        ),
                        const SizedBox(height: 20),

                        const Text(
                          'Workspace',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.ink900,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Workspace list rows
                        if (isSuperAdmin || isBranchManager) ...[
                          _buildWorkspaceRow(
                            icon: Icons.admin_panel_settings_outlined,
                            iconColor: AppTheme.brand600,
                            title: 'Admin Console & Network',
                            onTap: () {
                              Navigator.pop(ctx);
                              context.push('/admin');
                            },
                          ),
                          _buildWorkspaceRow(
                            icon: Icons.badge_outlined,
                            iconColor: const Color(0xFF7C5CFC),
                            title: 'Staff Roles & Credentials (RBAC)',
                            onTap: () {
                              Navigator.pop(ctx);
                              context.push('/admin?tab=staff');
                            },
                          ),
                        ],
                        _buildWorkspaceRow(
                          icon: Icons.verified_outlined,
                          iconColor: const Color(0xFF0EA5E9),
                          title: 'Device & IMEI Inspector',
                          onTap: () {
                            Navigator.pop(ctx);
                            context.push('/imei-inspector');
                          },
                        ),
                        _buildWorkspaceRow(
                          icon: Icons.settings_outlined,
                          iconColor: const Color(0xFF1E60F2),
                          title: 'Settings & Profile',
                          onTap: () {
                            Navigator.pop(ctx);
                            context.push('/settings');
                          },
                        ),
                        _buildWorkspaceRow(
                          icon: Icons.logout_rounded,
                          iconColor: const Color(0xFFF43F5E),
                          title: 'Sign Out',
                          onTap: () {
                            Navigator.pop(ctx);
                            context.go('/login');
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOpButton({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String sub,
    required String route,
  }) {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        GoRouter.of(context).push(route);
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF4F9FF),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0A0F3478),
                    blurRadius: 10,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.ink900,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    sub,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.ink500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkspaceRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.ink900,
                ),
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                size: 18, color: AppTheme.ink500),
          ],
        ),
      ),
    );
  }

  /// Back gesture behaviour for the signed-in shell.
  ///
  /// On a phone the back button used to leave the app instantly from any tab,
  /// which on a shared counter terminal is one stray tap away from a lost sale
  /// in progress. The shell now unwinds to Home first, and only Home asks before
  /// closing the session.
  Future<void> _handleBack() async {
    final location = GoRouterState.of(context).uri.path;
    if (!location.startsWith('/home')) {
      context.go('/home');
      return;
    }

    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.rLg),
        ),
        title: const Text('Toka LIMS?'),
        content: const Text(
          'Utatolewa kwenye session hii na utahitaji kuingia tena kwa email na '
          'password yako.',
          style: TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Baki hapa'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Toka'),
          ),
        ],
      ),
    );

    if (leave != true || !mounted) return;
    ref.read(userRoleProvider.notifier).clearSession();
    if (!mounted) return;
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = _getCurrentIndex(context);

    return LiveDataLoader(
      child: SessionGuard(
        child: PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) => _handleBack(),
          child: _buildScaffold(context, currentIndex),
        ),
      ),
    );
  }

  Widget _buildScaffold(BuildContext context, int currentIndex) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FC),
      body: widget.child,

      // Floating Premium Bottom Navigation Dock (Icon-only, no text clutter)
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          height: 64,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
            boxShadow: const [
              BoxShadow(
                color: Color(0x120F3478),
                blurRadius: 28,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                icon: Icons.grid_view_rounded,
                tooltip: 'Nyumbani (Home)',
                isSelected: currentIndex == 0,
                onTap: () => context.go('/home'),
              ),
              _buildNavItem(
                icon: Icons.inventory_2_rounded,
                tooltip: 'Stoo ya Simu (Inventory)',
                isSelected: currentIndex == 1,
                onTap: () => context.go('/stock'),
              ),

              // Center Raised Quick Scanner Action
              InkWell(
                onTap: () => context.push('/scan'),
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1B6EF3), Color(0xFF0B4FCE)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1B6EF3).withValues(alpha: 0.38),
                        blurRadius: 14,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.qr_code_scanner_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ),

              _buildNavItem(
                icon: Icons.account_balance_wallet_rounded,
                tooltip: 'Mikopo & Marejesho (Loans)',
                isSelected: currentIndex == 3,
                onTap: () => context.go('/loans'),
              ),
              _buildNavItem(
                icon: Icons.tune_rounded,
                tooltip: 'Uendeshaji & Mipangilio (Operations)',
                isSelected: false,
                onTap: () => _openMoreSheet(context, ref),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String tooltip,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFE9F2FF) : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 23,
                color: isSelected
                    ? const Color(0xFF1B6EF3)
                    : const Color(0xFF64748B),
              ),
              const SizedBox(height: 3),
              AnimatedScale(
                scale: isSelected ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  width: 4,
                  height: 4,
                  decoration: const BoxDecoration(
                    color: Color(0xFF1B6EF3),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
