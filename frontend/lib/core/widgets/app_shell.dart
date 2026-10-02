import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';

class AppShell extends StatelessWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  int _getCurrentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    if (location.startsWith('/home')) return 0;
    if (location.startsWith('/stock')) return 1;
    if (location.startsWith('/scan')) return 2;
    if (location.startsWith('/loans')) return 3;
    return 0;
  }

  void _openMoreSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
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
              const Text(
                'Core branch workflows & management',
                style: TextStyle(
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
                children: [
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
                ],
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
              _buildWorkspaceRow(
                icon: Icons.shield_rounded,
                iconColor: const Color(0xFF0EA5E9),
                title: 'Kikagua IMEI, Knox & Waranti',
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
            const Icon(Icons.chevron_right_rounded, size: 18, color: AppTheme.ink500),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = _getCurrentIndex(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FC),
      body: child,

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
                onTap: () => _openMoreSheet(context),
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
                color: isSelected ? const Color(0xFF1B6EF3) : const Color(0xFF64748B),
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