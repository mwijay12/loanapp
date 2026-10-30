import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../l10n/locale_provider.dart';
import '../l10n/strings.dart';
import '../constants/app_constants.dart';
import '../data/inventory_provider.dart';
import '../motion/motion.dart';
import '../motion/motion_widgets.dart';
import '../theme/app_theme.dart';
import '../services/live_data.dart';
import 'brand_mark.dart';
import 'responsive.dart';
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
    // '/stock-room' before '/stock' on purpose: the prefix test is a bare
    // startsWith, so the newer route would otherwise be claimed by the Stock
    // tab and the highlight would sit under the wrong icon all day.
    if (location.startsWith('/stock-room')) return 3;
    if (location.startsWith('/stock')) return 1;
    if (location.startsWith('/scan')) return 2;
    if (location.startsWith('/loans')) return 3;
    // Sidebar-only doors (5, 6). The phone dock has five slots and does not use
    // these; they exist so the desktop nav can highlight a screen it actually
    // offers. Returning 0 for /reports is why the sidebar used to sit on "Home"
    // while the header said "Financial Reports".
    if (location.startsWith('/reports')) return 5;
    if (location.startsWith('/admin')) return 6;
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
                        // The console, scoped by role. "Staff Roles &
                        // Credentials" used to be shown to a Branch Manager and
                        // pushed /admin?tab=staff, which dumped them on the
                        // network console under a menu label promising staff
                        // administration. Role and permission changes stay with
                        // the Super Admin, so the row is only rendered for one.
                        if (isSuperAdmin) ...[
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
                        ] else if (isBranchManager)
                          _buildWorkspaceRow(
                            icon: Icons.admin_panel_settings_outlined,
                            iconColor: AppTheme.brand600,
                            title: 'Branch Console',
                            onTap: () {
                              Navigator.pop(ctx);
                              context.push('/admin');
                            },
                          ),
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
                color: iconColor.withOpacity(0.1),
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
        title: Text(tr(ref.read(localeProvider), 'shell.signOutTitle')),
        content: Text(
          tr(ref.read(localeProvider), 'shell.signOutBody'),
          style: const TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(tr(ref.read(localeProvider), 'shell.stay')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(tr(ref.read(localeProvider), 'shell.signOut')),
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
    // Which fourth door this role may open at all. See UserRoles.loanViewers:
    // the database, not this line, is what actually protects borrower PII.
    final canSeeLoans = UserRoles.canViewLoans(ref.watch(userRoleProvider));

    // The tabs of this app are siblings, not a stack. The theme's push transition
    // is right for going *into* a till or a borrower, and wrong for moving sideways
    // between Home and Stock - it says "you have gone deeper" when nothing got
    // deeper. Keyed on the path so a rebuild of the same tab (a Realtime row
    // landing, a language switch) does not replay the transition.
    final page = FadeSwap(
      child: KeyedSubtree(
        key: ValueKey<String>(GoRouterState.of(context).uri.path),
        child: widget.child,
      ),
    );

    // Desktop: a sidebar and the window's real width. Below 900px the floating
    // dock stays, because a rail on a 700px tablet takes width the content needs.
    // A bottom dock on a 1920px screen was the clearest tell that this was a phone
    // build wearing a bigger window.
    if (MediaQuery.sizeOf(context).width >= LimsBreakpoints.rail) {
      return Scaffold(
        backgroundColor: const Color(0xFFF4F7FC),
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ShellSidebar(
              locale: ref.watch(localeProvider),
              role: ref.watch(userRoleProvider),
              currentIndex: currentIndex,
              canSeeLoans: canSeeLoans,
              onHome: () => context.go('/home'),
              onStock: () => context.go('/stock'),
              onScan: () => context.push('/scan'),
              onFourth: () =>
                  context.go(canSeeLoans ? '/loans' : '/stock-room'),
              onMore: () => _openMoreSheet(context, ref),
              onReports: () => context.go('/reports'),
              onAdmin: () => context.go('/admin'),
              canSeeAdmin:
                  ref.watch(userRoleProvider) == UserRoles.branchManager ||
                      ref.watch(userRoleProvider) == UserRoles.superAdmin,
            ),
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: LimsBreakpoints.maxContentWidth,
                  ),
                  child: page,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FC),
      body: page,

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
                tooltip: tr(ref.watch(localeProvider), 'nav.home'),
                isSelected: currentIndex == 0,
                onTap: () => context.go('/home'),
              ),
              _buildNavItem(
                icon: Icons.inventory_2_rounded,
                tooltip: tr(ref.watch(localeProvider), 'nav.inventory'),
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
                        color: const Color(0xFF1B6EF3).withOpacity(0.38),
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

              // The fourth door is the one a role cannot open. A Storekeeper is
              // refused by loans_read, so handing him a Borrowers icon would be
              // handing him an empty table; he gets the shelf his role can read.
              _buildNavItem(
                icon: canSeeLoans
                    ? Icons.account_balance_wallet_rounded
                    : Icons.inventory_2_rounded,
                tooltip: tr(
                  ref.watch(localeProvider),
                  canSeeLoans ? 'nav.loans' : 'nav.stockroom',
                ),
                isSelected: currentIndex == 3,
                onTap: () => context.go(canSeeLoans ? '/loans' : '/stock-room'),
              ),
              _buildNavItem(
                icon: Icons.tune_rounded,
                tooltip: tr(ref.watch(localeProvider), 'nav.operations'),
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
          duration: Motion.d(context, Motion.state),
          curve: Motion.standard,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFE9F2FF) : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // The selected glyph grows a little. Colour alone is easy to miss on
              // a bright shop floor under glass; size is not.
              AnimatedScale(
                scale: isSelected ? 1.08 : 1.0,
                duration: Motion.d(context, Motion.state),
                curve: Motion.emphasized,
                child: Icon(
                  icon,
                  size: 23,
                  color: isSelected
                      ? const Color(0xFF1B6EF3)
                      : const Color(0xFF64748B),
                ),
              ),

              AnimatedScale(
                scale: isSelected ? 1.0 : 0.0,
                duration: Motion.d(context, Motion.state),
                curve: Motion.emphasized,
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

/// The desktop navigation surface.
///
/// Same five doors as the phone dock, with labels — a desktop has the room, and
/// an icon-only rail at 1440px is a phone dock turned sideways. Hover is
/// honoured because a mouse user expects it: the pointer is a cursor there, not
/// a thumb.
class _ShellSidebar extends StatelessWidget {
  const _ShellSidebar({
    required this.locale,
    required this.role,
    required this.currentIndex,
    required this.canSeeLoans,
    required this.onHome,
    required this.onStock,
    required this.onScan,
    required this.onFourth,
    required this.onMore,
    required this.onReports,
    required this.onAdmin,
    required this.canSeeAdmin,
  });

  final Locale locale;
  final String role;
  final int currentIndex;
  final bool canSeeLoans;
  final VoidCallback onHome;
  final VoidCallback onStock;
  final VoidCallback onScan;
  final VoidCallback onFourth;
  final VoidCallback onMore;
  final VoidCallback onReports;
  final VoidCallback onAdmin;
  final bool canSeeAdmin;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: LimsBreakpoints.railWidth,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Color(0xFFE6ECF5))),
      ),
      child: SafeArea(
        right: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 22, 20, 20),
              child: BrandLockup(size: 38, showTagline: true),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Divider(height: 1, color: Color(0xFFEDF2F9)),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
                children: [
                  _SideItem(
                    icon: Icons.grid_view_rounded,
                    label: tr(locale, 'nav.home'),
                    selected: currentIndex == 0,
                    onTap: onHome,
                  ),
                  _SideItem(
                    icon: Icons.inventory_2_rounded,
                    label: tr(locale, 'nav.inventory'),
                    selected: currentIndex == 1,
                    onTap: onStock,
                  ),
                  // The fourth door is the one a role cannot open. A Storekeeper
                  // is refused by loans_read, so handing him a Borrowers entry
                  // would be handing him an empty table.
                  _SideItem(
                    icon: canSeeLoans
                        ? Icons.account_balance_wallet_rounded
                        : Icons.inventory_2_rounded,
                    label:
                        tr(locale, canSeeLoans ? 'nav.loans' : 'nav.stockroom'),
                    selected: currentIndex == 3,
                    onTap: onFourth,
                  ),
                  _SideItem(
                    icon: Icons.assessment_rounded,
                    label: tr(locale, 'nav.reports'),
                    selected: currentIndex == 5,
                    onTap: onReports,
                  ),
                  // Role-gated: a Cashier opening the Branch Console would be
                  // refused by the database anyway, and an entry that only ever
                  // says "no" is worse than an entry that is not there.
                  if (canSeeAdmin)
                    _SideItem(
                      icon: Icons.insights_rounded,
                      label: tr(locale, 'nav.console'),
                      selected: currentIndex == 6,
                      onTap: onAdmin,
                    ),
                  _SideItem(
                    icon: Icons.tune_rounded,
                    label: tr(locale, 'nav.operations'),
                    selected: false,
                    onTap: onMore,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: _SideScanButton(label: tr(locale, 'scan.title')),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEFF4FD),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.verified_user_rounded,
                        size: 16, color: AppTheme.brand700),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      role,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
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
    );
  }
}

class _SideItem extends StatefulWidget {
  const _SideItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_SideItem> createState() => _SideItemState();
}

class _SideItemState extends State<_SideItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: Semantics(
          button: true,
          selected: selected,
          label: widget.label,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(12),
            child: AnimatedContainer(
              duration: Motion.d(context, Motion.state),
              curve: Motion.standard,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              decoration: BoxDecoration(
                color: selected
                    ? AppTheme.brand600.withValues(alpha: 0.10)
                    : (_hover ? const Color(0xFFF4F7FC) : Colors.transparent),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    widget.icon,
                    size: 20,
                    color: selected ? AppTheme.brand700 : AppTheme.ink500,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w600,
                        color: selected ? AppTheme.brand700 : AppTheme.ink700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SideScanButton extends StatefulWidget {
  const _SideScanButton({required this.label});

  final String label;

  @override
  State<_SideScanButton> createState() => _SideScanButtonState();
}

class _SideScanButtonState extends State<_SideScanButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: () => context.push('/scan'),
        child: AnimatedContainer(
          duration: Motion.d(context, Motion.state),
          curve: Motion.standard,
          height: 44,
          decoration: BoxDecoration(
            gradient: AppTheme.brandGradient,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color:
                    AppTheme.brand600.withValues(alpha: _hover ? 0.42 : 0.26),
                blurRadius: _hover ? 18 : 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.qr_code_scanner_rounded,
                  color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
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
