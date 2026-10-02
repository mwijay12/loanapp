import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  String _selectedRole = 'branch'; // 'branch' or 'admin'
  bool _rememberMe = true;
  bool _isLoading = false;
  final TextEditingController _phoneCtrl = TextEditingController(text: '+255 754 221 008');
  final TextEditingController _passCtrl = TextEditingController(text: 'demo1234');

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  void _doLogin() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 700));
    if (mounted) {
      setState(() => _isLoading = false);
      if (_selectedRole == 'admin') {
        context.go('/admin');
      } else {
        context.go('/home');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppTheme.ink900,
          content: Text(_selectedRole == 'admin' ? 'Welcome to Admin Console' : 'Welcome back, Neema'),
        ),
      );
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

                const Text(
                  'Welcome back',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: AppTheme.ink900,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Sign in to continue to your branch workspace.',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.ink500,
                  ),
                ),
                const SizedBox(height: 22),

                // Role Pills
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
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
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() => _selectedRole = 'branch'),
                          borderRadius: BorderRadius.circular(11),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: _selectedRole == 'branch' ? AppTheme.brand600 : Colors.transparent,
                              borderRadius: BorderRadius.circular(11),
                              boxShadow: _selectedRole == 'branch'
                                  ? [
                                      BoxShadow(
                                        color: AppTheme.brand600.withValues(alpha: 0.3),
                                        blurRadius: 10,
                                        offset: const Offset(0, 3),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Text(
                              'Branch Staff',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: _selectedRole == 'branch' ? Colors.white : AppTheme.ink500,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() => _selectedRole = 'admin'),
                          borderRadius: BorderRadius.circular(11),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: _selectedRole == 'admin' ? AppTheme.brand600 : Colors.transparent,
                              borderRadius: BorderRadius.circular(11),
                              boxShadow: _selectedRole == 'admin'
                                  ? [
                                      BoxShadow(
                                        color: AppTheme.brand600.withValues(alpha: 0.3),
                                        blurRadius: 10,
                                        offset: const Offset(0, 3),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Text(
                              'Admin',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: _selectedRole == 'admin' ? Colors.white : AppTheme.ink500,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Phone Field
                _buildInputField(
                  controller: _phoneCtrl,
                  icon: Icons.phone_android_rounded,
                  hint: 'Phone number',
                ),
                const SizedBox(height: 12),

                // Password Field
                _buildInputField(
                  controller: _passCtrl,
                  icon: Icons.lock_outline_rounded,
                  hint: 'Password',
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
                        const Text(
                          'Remember me',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.ink500,
                          ),
                        ),
                      ],
                    ),
                    TextButton(
                      onPressed: () {},
                      child: const Text(
                        'Forgot password?',
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
                        : Text(
                            _selectedRole == 'admin' ? 'Log in to Admin Console' : 'Log in to Branch App',
                            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
                          ),
                  ),
                ),
                const SizedBox(height: 14),

                // Face ID button
                Center(
                  child: TextButton.icon(
                    onPressed: _doLogin,
                    icon: const Icon(Icons.fingerprint_rounded, color: AppTheme.brand600, size: 20),
                    label: const Text(
                      'Sign in with Face ID / Biometrics',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.brand600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Demo Note
                const Center(
                  child: Text(
                    'Demo build — tap Log in to enter the app',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF9AA8BF),
                    ),
                  ),
                ),
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
