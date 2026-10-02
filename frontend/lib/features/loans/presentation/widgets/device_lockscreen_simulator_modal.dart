import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data/inventory_provider.dart';
import '../../../../core/data/mock_lims_data.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/ui_kit.dart';

class DeviceLockscreenSimulatorModal extends ConsumerStatefulWidget {
  final String deviceModel;
  final String imei;
  final String borrowerName;
  final String borrowerPhone;
  final int overdueAmount;
  final String loanId;
  final bool initialIsLocked;
  final VoidCallback? onStateChanged;

  const DeviceLockscreenSimulatorModal({
    super.key,
    required this.deviceModel,
    required this.imei,
    required this.borrowerName,
    required this.borrowerPhone,
    required this.overdueAmount,
    required this.loanId,
    this.initialIsLocked = true,
    this.onStateChanged,
  });

  static void show(
    BuildContext context, {
    required String deviceModel,
    required String imei,
    required String borrowerName,
    required String borrowerPhone,
    required int overdueAmount,
    required String loanId,
    bool initialIsLocked = true,
    VoidCallback? onStateChanged,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DeviceLockscreenSimulatorModal(
        deviceModel: deviceModel,
        imei: imei,
        borrowerName: borrowerName,
        borrowerPhone: borrowerPhone,
        overdueAmount: overdueAmount,
        loanId: loanId,
        initialIsLocked: initialIsLocked,
        onStateChanged: onStateChanged,
      ),
    );
  }

  @override
  ConsumerState<DeviceLockscreenSimulatorModal> createState() => _DeviceLockscreenSimulatorModalState();
}

class _DeviceLockscreenSimulatorModalState extends ConsumerState<DeviceLockscreenSimulatorModal> {
  late bool _isLocked;
  bool _isProcessingPayment = false;
  bool _justUnlocked = false;

  // Default store settings
  final String _storeLipaNamba = '552219';
  final String _storeOperator = 'Vodacom M-Pesa';
  final String _storeHotline = '0754 892 314';
  final String _storeName = 'LIMS Phones Kariakoo Hub';

  @override
  void initState() {
    super.initState();
    _isLocked = widget.initialIsLocked;
  }

  void _simulateMpesaPayment() async {
    setState(() => _isProcessingPayment = true);

    await Future.delayed(const Duration(milliseconds: 1400));

    if (!mounted) return;

    // Toggle local state
    setState(() {
      _isProcessingPayment = false;
      _isLocked = false;
      _justUnlocked = true;
    });

    // Update global state if loan exists
    if (widget.loanId.isNotEmpty) {
      ref.read(loansProvider.notifier).toggleKnoxLock(widget.loanId, false);
      ref.read(loansProvider.notifier).recordPayment(widget.loanId, widget.overdueAmount);
    }

    ref.read(activitiesProvider.notifier).addActivity(
      ActivityItem(
        icon: Icons.lock_open_rounded,
        iconColor: AppTheme.successColor,
        bgColor: const Color(0xFFE7F8F0),
        title: 'Auto-Unlock M-Pesa · ${widget.deviceModel}',
        description: 'M-Pesa Webhook: TZS ${LimsFormatters.formatNumber(widget.overdueAmount)} imepokelewa. Knox imeondoa lock.',
        time: 'Sasa hivi',
      ),
    );

    widget.onStateChanged?.call();
  }

  void _toggleLock() {
    final next = !_isLocked;
    setState(() {
      _isLocked = next;
      _justUnlocked = false;
    });

    if (widget.loanId.isNotEmpty) {
      ref.read(loansProvider.notifier).toggleKnoxLock(widget.loanId, next);
    }

    widget.onStateChanged?.call();

    LimsToast.show(
      context,
      next ? 'Simu imefungwa tena kwa mbali kupitia Knox/MDM!' : 'Simu imefunguliwa na mteja anatumia kama kawaida.',
      isSuccess: !next,
      isError: next,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.94,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A), // Dark obsidian shell
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Header handle & title
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: _isLocked ? const Color(0xFFE11D48) : const Color(0xFF10B981),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _isLocked ? Icons.phonelink_lock_rounded : Icons.lock_open_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Kielelezo cha Kioo cha Simu (Simulator)',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          _isLocked ? 'Muonekano wa mteja simu ikiwa imefungwa' : 'Muonekano wa kawaida baada ya malipo',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFF1E293B)),

          // Scrollable phone preview body
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                children: [
                  // Real Smartphone Mockup Container
                  Center(
                    child: Container(
                      width: 320,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(42),
                        border: Border.all(color: const Color(0xFF334155), width: 6),
                        boxShadow: [
                          BoxShadow(
                            color: (_isLocked ? const Color(0xFFE11D48) : const Color(0xFF10B981)).withValues(alpha: 0.25),
                            blurRadius: 36,
                            spreadRadius: 2,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(36),
                        child: Container(
                          color: _isLocked ? const Color(0xFF090D16) : const Color(0xFF0C192E),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Top Notch / Dynamic Island & Status Bar
                              _buildPhoneStatusBar(),

                              // Screen Content depending on lock status
                              if (_isLocked)
                                _buildLockedScreenBody()
                              else
                                _buildUnlockedScreenBody(),

                              // Home Indicator bar
                              Container(
                                margin: const EdgeInsets.only(top: 14, bottom: 8),
                                width: 110,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.4),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Controls & Architecture Explanation for Staff
                  _buildStaffActionControls(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------- Phone Status Bar
  Widget _buildPhoneStatusBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            '09:41',
            style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700),
          ),
          // Dynamic Island
          Container(
            width: 72,
            height: 18,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: Container(
                width: 9,
                height: 9,
                decoration: const BoxDecoration(
                  color: Color(0xFF1E293B),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          const Row(
            children: [
              Icon(Icons.signal_cellular_4_bar_rounded, color: Colors.white, size: 12),
              SizedBox(width: 4),
              Icon(Icons.wifi_rounded, color: Colors.white, size: 12),
              SizedBox(width: 4),
              Icon(Icons.battery_5_bar_rounded, color: Colors.white, size: 14),
            ],
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------- Locked Screen UI
  Widget _buildLockedScreenBody() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        children: [
          // Flashing Lock Icon
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              gradient: const RadialGradient(
                colors: [Color(0xFFE11D48), Color(0xFF881337)],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFE11D48).withValues(alpha: 0.5),
                  blurRadius: 18,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(Icons.phonelink_lock_rounded, color: Colors.white, size: 30),
          ),
          const SizedBox(height: 12),

          const Text(
            'SIMU HII IMEFUNGIWA KWA MUDA',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFFFF4D4D),
              fontSize: 13,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Rejesho la mkopo limechelewa. Kifaa hiki kitafunguliwa kiotomatiki sekunde chache baada ya malipo kupokelewa.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 10, height: 1.4),
          ),

          const SizedBox(height: 14),

          // Payment Box showing Default Lipa Namba
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE11D48).withValues(alpha: 0.6)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Rejesho Linalodaiwa:',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 10.5),
                    ),
                    Text(
                      'TZS ${LimsFormatters.formatNumber(widget.overdueAmount)}',
                      style: const TextStyle(color: Color(0xFFFACC15), fontSize: 14, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
                const Divider(height: 16, color: Color(0xFF334155)),
                _lockInfoRow('Lipa Namba (Till):', '$_storeLipaNamba ($_storeOperator)'),
                const SizedBox(height: 4),
                _lockInfoRow('Jina la Duka:', _storeName),
                const SizedBox(height: 4),
                _lockInfoRow('Kumbukumbu Namba:', widget.loanId.isNotEmpty ? widget.loanId : widget.imei.substring(0, 10)),
                const SizedBox(height: 4),
                _lockInfoRow('Mkopaji:', widget.borrowerName),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // USSD Push Instruction
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.dialpad_rounded, color: Color(0xFF38BDF8), size: 14),
                const SizedBox(width: 6),
                Text(
                  'Piga *150*00# Chagua 4 (Lipa kwa M-Pesa)',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 9.5, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Emergency & Support Buttons on phone
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF334155),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.headset_mic_rounded, color: Colors.white, size: 13),
                      const SizedBox(width: 5),
                      Text(
                        'Piga Dukani\n$_storeHotline',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.w700, height: 1.2),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF475569)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.emergency_rounded, color: Color(0xFFF43F5E), size: 13),
                      SizedBox(width: 5),
                      Text(
                        'Dharura\n(112 / Polisi)',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70, fontSize: 8.5, fontWeight: FontWeight.w700, height: 1.2),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------- Unlocked Screen UI
  Widget _buildUnlockedScreenBody() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        children: [
          // Celebration / Status badge
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFF059669),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF10B981).withValues(alpha: 0.5),
                  blurRadius: 18,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 32),
          ),
          const SizedBox(height: 12),

          Text(
            _justUnlocked ? 'KIMEPOKELEWA! IMEFUNGULIWA' : 'KIFAA KINA FANYA KAZI (UNLOCKED)',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF34D399),
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _justUnlocked
                ? 'Malipo ya TZS ${LimsFormatters.formatNumber(widget.overdueAmount)} yamethibitishwa kupitia M-Pesa. Kizuizi cha Knox kimeondolewa OTA!'
                : 'Mkopaji anatumia apps, simu na intaneti kawaida bila kizuizi chochote cha kiusalama.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 10, height: 1.4),
          ),

          const SizedBox(height: 18),

          // Mini Mock App Grid
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _miniAppIcon(Icons.phone_rounded, 'Phone', const Color(0xFF10B981)),
                    _miniAppIcon(Icons.chat_bubble_rounded, 'WhatsApp', const Color(0xFF22C55E)),
                    _miniAppIcon(Icons.camera_alt_rounded, 'Camera', const Color(0xFF3B82F6)),
                    _miniAppIcon(Icons.account_balance_wallet_rounded, 'M-Pesa', const Color(0xFFEF4444)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _miniAppIcon(Icons.public_rounded, 'Chrome', const Color(0xFFF59E0B)),
                    _miniAppIcon(Icons.music_note_rounded, 'Music', const Color(0xFFEC4899)),
                    _miniAppIcon(Icons.settings_rounded, 'Settings', const Color(0xFF64748B)),
                    _miniAppIcon(Icons.shield_rounded, 'LIMS Guard', AppTheme.brand600),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Active protection pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF064E3B),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.security_rounded, color: Color(0xFF34D399), size: 12),
                SizedBox(width: 5),
                Text(
                  'LIMS Knox Active Monitoring · OTA Connected',
                  style: TextStyle(color: Color(0xFFA7F3D0), fontSize: 9.5, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniAppIcon(IconData icon, String name, Color bg) {
    return Column(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
        const SizedBox(height: 4),
        Text(
          name,
          style: const TextStyle(color: Colors.white70, fontSize: 8.5),
        ),
      ],
    );
  }

  Widget _lockInfoRow(String label, String val) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10)),
        Flexible(
          child: Text(
            val,
            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------- Staff Actions Card
  Widget _buildStaffActionControls() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.brand600,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.tune_rounded, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 10),
              const Text(
                'Vitendo vya Mfanyakazi / Cashier Testing',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Unaweza kujaribu mzunguko mzima wa malipo ya M-Pesa. Pindi mteja anapolipa, M-Pesa callback inatumwa kwa sekunde 2 kisha mfumo unaondoa kizuizi mara moja bila mteja kuja dukani.',
            style: TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8), height: 1.4),
          ),
          const SizedBox(height: 16),

          // Primary Simulator Button: M-Pesa Auto Unlock
          if (_isLocked) ...[
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                onPressed: _isProcessingPayment ? null : _simulateMpesaPayment,
                icon: _isProcessingPayment
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.bolt_rounded, size: 20),
                label: Text(
                  _isProcessingPayment
                      ? 'Inachakata M-Pesa Webhook Callback...'
                      : '⚡ Jaribu Kupokea Malipo ya M-Pesa (Auto-Unlock)',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
              ),
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                onPressed: _toggleLock,
                icon: const Icon(Icons.phonelink_lock_rounded, size: 20),
                label: const Text(
                  'Funga Kifaa Hiki Tena (Jaribu Lockscreen)',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE11D48),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
              ),
            ),
          ],

          const SizedBox(height: 10),

          // Secondary: Push SMS Warning
          SizedBox(
            width: double.infinity,
            height: 42,
            child: OutlinedButton.icon(
              onPressed: () {
                LimsToast.show(
                  context,
                  'SMS ya ukumbusho na namba ya malipo imetumwa kwa ${widget.borrowerPhone}!',
                  isSuccess: true,
                );
              },
              icon: const Icon(Icons.sms_rounded, size: 16),
              label: const Text('Tuma SMS ya Lipa Namba & Mkataba kwa Mteja', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF38BDF8),
                side: const BorderSide(color: Color(0xFF0284C7)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
