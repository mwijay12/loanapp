import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/data/inventory_provider.dart';
import '../../../core/theme/app_localizations.dart';

final localeProvider = StateProvider<Locale>((ref) => const Locale('en'));

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final currentLocale = ref.watch(localeProvider);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.account,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 20),
            _buildProfileSection(context, ref, l10n),
            const SizedBox(height: 20),
            _buildSettingsSection(context, ref, l10n, currentLocale),
            const SizedBox(height: 20),
            _buildMenuSection(context, ref, l10n),
          ],
        ),
      ),
    );
  }

  /// Renders the REAL signed-in identity.
  ///
  /// This used to read `AppConstants.employeeName` / `employeeRole`, which were
  /// hardcoded strings ("John" / "Branch Manager"). Every user therefore saw the
  /// same name and a role they might not hold. The values now come from the
  /// session: the role is whatever the server granted, and the staff profile is
  /// resolved from it. An unresolved session renders the locked-out placeholder
  /// rather than an elevated identity.
  Widget _buildProfileSection(BuildContext context, WidgetRef ref, AppLocalizations l10n) {
    final staff = ref.watch(activeStaffMemberProvider);
    final rawRole = ref.watch(userRoleProvider);
    final role = UserRoles.normalize(rawRole);
    final hasSession = role != null && role != UserRoles.noSession;
    final roleLabel = hasSession ? UserRoles.label(role) : 'Not signed in';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppTheme.primaryLight,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                hasSession ? Icons.person_rounded : Icons.person_off_rounded,
                color: AppTheme.primaryColor,
                size: 32,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    staff.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    roleLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hasSession && staff.branch.isNotEmpty
                        ? '${staff.branch} · ${staff.staffCode}'
                        : l10n.branch_name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textTertiary,
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

  Widget _buildSettingsSection(BuildContext context, WidgetRef ref, AppLocalizations l10n, Locale currentLocale) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.settings,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.pastelLavender,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.language_rounded,
                    color: AppTheme.iconNavy,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.language,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        currentLocale.languageCode == 'en' ? l10n.english : l10n.swahili,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                DropdownButton<Locale>(
                  value: currentLocale,
                  underline: const SizedBox.shrink(),
                  items: [
                    DropdownMenuItem(
                      value: const Locale('en'),
                      child: Text(l10n.english),
                    ),
                    DropdownMenuItem(
                      value: const Locale('sw'),
                      child: Text(l10n.swahili),
                    ),
                  ],
                  onChanged: (Locale? newLocale) {
                    if (newLocale != null) {
                      ref.read(localeProvider.notifier).state = newLocale;
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuSection(BuildContext context, WidgetRef ref, AppLocalizations l10n) {
    final role = UserRoles.normalize(ref.watch(userRoleProvider));
    // Only roles that actually administer people see the admin entry point.
    // Hiding it is presentation only — the route guard and RLS are the real
    // enforcement — but showing an admin door to a cashier is misleading.
    final showAdmin = role == UserRoles.superAdmin || role == UserRoles.branchManager;

    return Card(
      child: Column(
        children: [
          _MenuItem(
            icon: Icons.fingerprint_rounded,
            label: l10n.attendance,
            onTap: () => context.push('/attendance'),
          ),
          const Divider(height: 1),
          _MenuItem(
            icon: Icons.notifications_rounded,
            label: l10n.notifications,
            onTap: () => context.push('/notifications'),
          ),
          if (showAdmin) ...[
            const Divider(height: 1),
            _MenuItem(
              icon: Icons.admin_panel_settings_rounded,
              label: l10n.admin_dashboard,
              onTap: () => context.push('/admin'),
            ),
          ],
          const Divider(height: 1),
          _MenuItem(
            icon: Icons.store_rounded,
            label: l10n.branch_performance,
            onTap: () => context.push('/branch-performance'),
          ),
          const Divider(height: 1),
          _MenuItem(
            icon: Icons.logout_rounded,
            label: l10n.sign_out,
            onTap: () {
              // Drop the local session before leaving. Without this the next
              // screen can still read the previous user's role.
              ref.read(userRoleProvider.notifier).clearSession();
              context.go('/login');
            },
            isDestructive: true,
          ),
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        icon,
        color: isDestructive ? AppTheme.errorColor : AppTheme.textSecondary,
      ),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: isDestructive ? AppTheme.errorColor : AppTheme.textPrimary,
        ),
      ),
      trailing: const Icon(Icons.chevron_right_rounded, color: AppTheme.textTertiary),
      onTap: onTap,
    );
  }
}
