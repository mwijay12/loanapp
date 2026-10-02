import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../account/presentation/account_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String _selectedBranch = 'Kariakoo Branch';
  bool _biometricsEnabled = true;
  bool _smsAlerts = true;
  bool _autoReceipts = true;
  bool _offlineCache = true;
  String _loanDownPayment = '25%';
  String _mpesaTillNumber = '552219';
  String _tigoPesaNumber = '884102';
  String _supportHotline = '0754 892 314';
  String _paymentGracePeriod = 'Siku 3 (Grace Period)';
  String _escalationPolicy = 'SMS & Piga Simu kwa Mdhamini';

  final List<String> _branches = [
    'Kariakoo Branch',
    'Mbezi Branch',
    'Mwanza Branch',
    'Arusha Branch',
    'Dodoma Branch',
    'Zanzibar Branch',
  ];

  @override
  Widget build(BuildContext context) {
    final currentLocale = ref.watch(localeProvider);

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.ink900),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Settings & Profile',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppTheme.ink900,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFE2E8F0), height: 1),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            // Profile Card
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
              child: Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.brand600.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text(
                        'DJ',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'David Julius',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.ink900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Store Manager · ID: LIMS-EMP-042',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.ink500,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE7F8F0),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Active · Kariakoo',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF12B76A),
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

            // Branch Assignment
            const Text(
              'Branch Assignment',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: AppTheme.ink900,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0A0F3478),
                    blurRadius: 16,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedBranch,
                  isExpanded: true,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.brand600),
                  items: _branches.map((b) {
                    return DropdownMenuItem(
                      value: b,
                      child: Row(
                        children: [
                          const Icon(Icons.location_on_outlined, size: 18, color: AppTheme.brand600),
                          const SizedBox(width: 10),
                          Text(
                            b,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.ink900,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedBranch = val);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          behavior: SnackBarBehavior.floating,
                          content: Text('Switched active branch to $val'),
                        ),
                      );
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Language & Localization
            const Text(
              'Language / Lugha',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: AppTheme.ink900,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
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
                      onTap: () {
                        ref.read(localeProvider.notifier).state = const Locale('en');
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            behavior: SnackBarBehavior.floating,
                            content: Text('Language set to English'),
                          ),
                        );
                      },
                      borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: currentLocale.languageCode == 'en'
                              ? AppTheme.brand600
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          'English (EN)',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: currentLocale.languageCode == 'en'
                                ? Colors.white
                                : AppTheme.ink700,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        ref.read(localeProvider.notifier).state = const Locale('sw');
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            behavior: SnackBarBehavior.floating,
                            content: Text('Lugha imebadilishwa kuwa Kiswahili'),
                          ),
                        );
                      },
                      borderRadius: const BorderRadius.horizontal(right: Radius.circular(16)),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: currentLocale.languageCode == 'sw'
                              ? AppTheme.brand600
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          'Kiswahili (SW)',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: currentLocale.languageCode == 'sw'
                                ? Colors.white
                                : AppTheme.ink700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Store Operations & Loan Configuration
            const Text(
              'Loan & Store Defaults',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: AppTheme.ink900,
              ),
            ),
            const SizedBox(height: 10),
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
                children: [
                  _buildToggleTile(
                    title: 'Auto-Generate Digital Receipts',
                    subtitle: 'Create instant SMS receipt on cash and loan deals',
                    value: _autoReceipts,
                    onChanged: (v) => setState(() => _autoReceipts = v),
                  ),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  _buildToggleTile(
                    title: 'Offline Sync Cache',
                    subtitle: 'Store counter transactions locally when offline',
                    value: _offlineCache,
                    onChanged: (v) => setState(() => _offlineCache = v),
                  ),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Default Down-Payment',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.ink900,
                              ),
                            ),
                            Text(
                              'Standard customer deposit for phone financing',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.ink500,
                              ),
                            ),
                          ],
                        ),
                        DropdownButton<String>(
                          value: _loanDownPayment,
                          underline: const SizedBox(),
                          items: ['20%', '25%', '30%'].map((val) {
                            return DropdownMenuItem(
                              value: val,
                              child: Text(
                                val,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.brand600,
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _loanDownPayment = val);
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Payment Channels & Collections Policy Configuration
            const Text(
              'Payment Channels & Collections Policy',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: AppTheme.ink900,
              ),
            ),
            const SizedBox(height: 10),
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
                children: [
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFEDF1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.point_of_sale_rounded, color: Color(0xFFE11900), size: 20),
                    ),
                    title: const Text(
                      'Default Lipa Namba (Vodacom M-Pesa)',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.ink900),
                    ),
                    subtitle: Text(
                      'Till: $_mpesaTillNumber · Namba kuu ya makusanyo ya marejesho',
                      style: const TextStyle(fontSize: 11, color: AppTheme.ink500),
                    ),
                    trailing: TextButton(
                      onPressed: () {
                        final ctrl = TextEditingController(text: _mpesaTillNumber);
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Badili M-Pesa Till', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                            content: TextField(
                              controller: ctrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'M-Pesa Till Number', border: OutlineInputBorder()),
                            ),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Ghairi')),
                              ElevatedButton(
                                onPressed: () {
                                  setState(() => _mpesaTillNumber = ctrl.text);
                                  Navigator.pop(ctx);
                                  LimsToast.show(context, 'Lipa Namba ya duka imesasishwa kwa mafanikio!');
                                },
                                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.brand600, foregroundColor: Colors.white),
                                child: const Text('Hifadhi'),
                              ),
                            ],
                          ),
                        );
                      },
                      child: const Text('Badili', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.sim_card_rounded, color: Color(0xFF0033A0), size: 20),
                    ),
                    title: const Text(
                      'Lipa Namba ya Pili (Tigo Pesa)',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.ink900),
                    ),
                    subtitle: Text(
                      'Till: $_tigoPesaNumber · Namba mbadala ya malipo',
                      style: const TextStyle(fontSize: 11, color: AppTheme.ink500),
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEBF3FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.support_agent_rounded, color: AppTheme.brand600, size: 20),
                    ),
                    title: const Text(
                      'Namba ya Msaada ya Duka (Hotline)',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.ink900),
                    ),
                    subtitle: Text(
                      '$_supportHotline · Mawasiliano rasmi ya mikopo na marejesho',
                      style: const TextStyle(fontSize: 11, color: AppTheme.ink500),
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Payment Grace Period',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.ink900),
                            ),
                            Text(
                              'Muda wa msamaha kabla ya hatua za madai kuanza',
                              style: TextStyle(fontSize: 11, color: AppTheme.ink500),
                            ),
                          ],
                        ),
                        DropdownButton<String>(
                          value: _paymentGracePeriod,
                          underline: const SizedBox(),
                          items: ['Siku 1', 'Siku 3 (Grace Period)', 'Siku 5', 'Siku 7'].map((val) {
                            return DropdownMenuItem(
                              value: val,
                              child: Text(
                                val,
                                style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.brand600, fontSize: 12),
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _paymentGracePeriod = val);
                          },
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Arrears Escalation Policy',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.ink900),
                            ),
                            Text(
                              'Hatua za kisheria kwa mujibu wa PDPA & Mkopo',
                              style: TextStyle(fontSize: 11, color: AppTheme.ink500),
                            ),
                          ],
                        ),
                        DropdownButton<String>(
                          value: _escalationPolicy,
                          underline: const SizedBox(),
                          items: [
                            'SMS & Piga Simu kwa Mdhamini',
                            'Notisi Rasmi ya Madai (Legal Notice)',
                            'Kufuatilia Handset kwa Makubaliano',
                          ].map((val) {
                            return DropdownMenuItem(
                              value: val,
                              child: Text(
                                val,
                                style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.brand600, fontSize: 12),
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _escalationPolicy = val);
                          },
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          LimsToast.show(
                            context,
                            'Kiolezo cha SMS ya kukumbusha rejesho kimetumwa (Mfano: "Ndugu Mteja, rejesho lako la TZS ... linatakiwa kulipwa...")',
                            isSuccess: true,
                          );
                        },
                        icon: const Icon(Icons.sms_outlined, size: 16),
                        label: const Text(
                          'Jaribu Kiolezo cha SMS ya Marejesho (Test Payment Reminder)',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF0F172A),
                          backgroundColor: const Color(0xFFF8FAFC),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Hardware & Security
            const Text(
              'Security & Hardware',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: AppTheme.ink900,
              ),
            ),
            const SizedBox(height: 10),
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
                children: [
                  _buildToggleTile(
                    title: 'Face ID / Biometric Lock',
                    subtitle: 'Require biometric authentication on counter startup',
                    value: _biometricsEnabled,
                    onChanged: (v) => setState(() => _biometricsEnabled = v),
                  ),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  _buildToggleTile(
                    title: 'SMS Overdue Alerts',
                    subtitle: 'Notify manager daily at 09:00 AM on delayed loans',
                    value: _smsAlerts,
                    onChanged: (v) => setState(() => _smsAlerts = v),
                  ),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  ListTile(
                    leading: const Icon(Icons.print_rounded, color: AppTheme.brand600),
                    title: const Text(
                      'Bluetooth Thermal Printer',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.ink900),
                    ),
                    subtitle: const Text(
                      'Sunmi V2 Pro 58mm · Paired & Ready',
                      style: TextStyle(fontSize: 11, color: Color(0xFF12B76A), fontWeight: FontWeight.w600),
                    ),
                    trailing: const Icon(Icons.check_circle_rounded, color: Color(0xFF12B76A), size: 20),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          behavior: SnackBarBehavior.floating,
                          content: Text('Printer test: Connection verified with Sunmi 58mm'),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Sign out button
            OutlinedButton.icon(
              onPressed: () => context.go('/login'),
              icon: const Icon(Icons.logout_rounded, color: Color(0xFFF43F5E), size: 18),
              label: const Text(
                'Sign Out from Terminal',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFF43F5E),
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFFFD2DC)),
                backgroundColor: const Color(0xFFFFEDF1),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 12),
            const Center(
              child: Text(
                'LIMS Build 2.4 · Branch Terminal v2026.10',
                style: TextStyle(fontSize: 11, color: Color(0xFF9AA8BF), fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.ink900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.ink500,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: AppTheme.brand600,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
