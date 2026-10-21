import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../../core/l10n/strings.dart';
import '../../../core/data/inventory_provider.dart';
import '../../../core/services/app_permissions_service.dart';
import '../../../core/services/api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ui_kit.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _rememberMe = true;
  bool _isLoading = false;
  // P0: no prefilled demo credentials.
  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _passCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Mtumiaji akiruka onboarding, ruhusa zinaombwa hapa (kimya, bila sheet)
    // ili zisiwakatishe baadaye wakiwa kazini.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      AppPermissionsService.requestEarlyPermissions(
        context,
        showRationale: false,
      );
    });
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  // P0: role comes from the server profile only. The client never picks
  // a role — it only hydrates the read-only projection after a successful
  // login, then routes on that server role.
  void _doLogin() async {
    setState(() => _isLoading = true);
    try {
      final user = await ApiService().login(_phoneCtrl.text, _passCtrl.text);
      if (!mounted) return;
      // The server returns the canonical role. Normalise anyway so a legacy
      // row cannot slip through, and never invent one.
      final rawRole = user['role'];
      final role = UserRoles.normalize(rawRole is String ? rawRole : null);
      final nameValue = user['name'];
      final name = nameValue is String && nameValue.isNotEmpty ? nameValue : 'User';
      if (role == null || role == UserRoles.pending) {
        throw StateError('Server returned no usable role. Access denied.');
      }
      ref.read(userRoleProvider.notifier).hydrateFromSession(role);
      // Routing is on the canonical role, not on a substring of the label.
      // The old `role.toLowerCase().contains('admin')` test sent a Branch
      // Manager to /home and would have sent an 'Auditor' anywhere it liked.
      final landsOnAdmin = role == UserRoles.superAdmin ||
          role == UserRoles.branchManager;
      if (landsOnAdmin) {
        context.go('/admin');
      } else {
        context.go('/home');
      }
      LimsToast.show(
        context,
        landsOnAdmin ? 'Welcome to Admin Console, $name' : 'Welcome back, $name',
        isSuccess: true,
      );
    } catch (e) {
      if (!mounted) return;
      final msg = e is StateError ? e.message : 'Login failed. Check connection and try again.';
      LimsToast.show(context, msg, isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.canvas,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Brand Row
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        gradient: AppTheme.brandGradient,
                        borderRadius: BorderRadius.circular(13),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x331B6EF3),
                            blurRadius: 16,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.smartphone_rounded, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'LIMS',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: AppTheme.ink900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                Text(
                  tr(ref.watch(localeProvider), 'login.welcome'),
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: AppTheme.ink900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  tr(ref.watch(localeProvider), 'login.subtitle'),
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.ink500,
                  ),
                ),
                const SizedBox(height: 22),

                // P0: role pills removed — role is server-owned, never user-picked.

                // Showcase only. Lists the demo identities so a visitor can get
                // in without being handed credentials out of band. Compiled out
                // when DEMO_MODE is not true, so a production build never shows
                // this card.
                if (AppConstants.demoMode) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${tr(ref.watch(localeProvider), 'login.demoHint')} · ${AppConstants.demoPassword}',
                          maxLines: 2,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.ink900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        for (final entry in AppConstants.demoAccounts.entries)
                          InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () {
                              _phoneCtrl.text = entry.key;
                              _passCtrl.text = AppConstants.demoPassword;
                            },
                            child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 5,
                                  child: Text(
                                    entry.value['role'] ?? '',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.ink700,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 7,
                                  child: Text(
                                    entry.key,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      color: AppTheme.ink500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // Email Field.
                //
                // Was labelled "Phone number". Staff are provisioned with a
                // work email that doubles as the username (a driver without a
                // personal address still gets e.g. driver01@mbagala.lims.co.tz),
                // and Supabase Auth signs in by email.
                _buildInputField(
                  controller: _phoneCtrl,
                  icon: Icons.alternate_email_rounded,
                  hint: tr(ref.watch(localeProvider), 'login.email'),
                ),
                const SizedBox(height: 12),

                // Password Field
                _buildInputField(
                  controller: _passCtrl,
                  icon: Icons.lock_outline_rounded,
                  hint: tr(ref.watch(localeProvider), 'login.password'),
                  obscure: true,
                ),
                const SizedBox(height: 14),

                // Remember Me & Forgot Password Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Checkbox(
                          value: _rememberMe,
                          onChanged: (v) => setState(() => _rememberMe = v ?? true),
                          activeColor: AppTheme.brand600,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        ),
                        Text(
                          tr(ref.watch(localeProvider), 'login.remember'),
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.ink500,
                          ),
                        ),
                      ],
                    ),
                    TextButton(
                      onPressed: () => LimsToast.show(
                        context,
                        'Contact your administrator to reset your password.',
                      ),
                      child: Text(
                        tr(ref.watch(localeProvider), 'login.forgot'),
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.brand600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Primary Submit Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _doLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.brand600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                          )
                        : const Text(
                            'Log in',
                            style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
                          ),
                  ),
                ),
                const SizedBox(height: 14),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    bool obscure = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F3478),
            blurRadius: 16,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, size: 19, color: AppTheme.ink500),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              obscureText: obscure,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.ink900),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: hint,
                hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF9AA8BF)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
