import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> with SingleTickerProviderStateMixin {
  late AnimationController _laserController;
  bool _isScanning = false;
  bool _hasResult = false;
  final TextEditingController _imeiCtrl = TextEditingController();

  String _deviceName = 'iPhone 15 Pro Max';
  String _deviceVariant = '256GB · Natural Titanium';
  String _imeiNumber = '354928104829104';
  int _cashPrice = 3850000;
  int _loanPrice = 4450000;
  int _daysInStock = 8;
  String _stockStatus = 'IN_STOCK'; // 'IN_STOCK', 'ON_LOAN', 'LOCKED'
  String _statusText = 'Align the IMEI barcode within the viewfinder';

  // Sample serialized handsets in stock
  final List<Map<String, dynamic>> _quickSamplePhones = const [
    {
      'model': 'Tecno Spark 20',
      'variant': '128GB / 4GB · Gravity Black',
      'imei': '358920112849102',
      'cash': 295000,
      'loan': 365000,
      'days': 4,
      'status': 'IN_STOCK',
    },
    {
      'model': 'Samsung Galaxy A15',
      'variant': '128GB / 6GB · Light Blue',
      'imei': '354928104829104',
      'cash': 380000,
      'loan': 460000,
      'days': 11,
      'status': 'IN_STOCK',
    },
    {
      'model': 'Redmi Note 13 Pro',
      'variant': '256GB / 8GB · Midnight Black',
      'imei': '864920042819384',
      'cash': 580000,
      'loan': 695000,
      'days': 58,
      'status': 'IN_STOCK',
    },
    {
      'model': 'Samsung Galaxy S24 Ultra',
      'variant': '256GB · Titanium Gray',
      'imei': '351982746201948',
      'cash': 2850000,
      'loan': 3350000,
      'days': 19,
      'status': 'ON_LOAN',
    },
  ];

  @override
  void initState() {
    super.initState();
    _laserController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _imeiCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _laserController.dispose();
    _imeiCtrl.dispose();
    super.dispose();
  }

  bool _isGsmValid(String imei) {
    final clean = imei.replaceAll(RegExp(r'\s+'), '');
    if (clean.length != 15 || !RegExp(r'^[0-9]+$').hasMatch(clean)) return false;
    // Luhn checksum algorithm
    int sum = 0;
    for (int i = 0; i < 15; i++) {
      int digit = int.parse(clean[i]);
      if (i % 2 == 1) {
        digit *= 2;
        if (digit > 9) digit -= 9;
      }
      sum += digit;
    }
    return sum % 10 == 0;
  }

  void _runScan() async {
    if (_isScanning) return;
    setState(() {
      _isScanning = true;
      _hasResult = false;
      _statusText = 'Scanning camera feed… detecting IMEI barcode';
    });

    await Future.delayed(const Duration(milliseconds: 1200));
    if (mounted) {
      _selectPhone(_quickSamplePhones[0]);
    }
  }

  void _selectPhone(Map<String, dynamic> phone) {
    setState(() {
      _isScanning = false;
      _hasResult = true;
      _deviceName = phone['model'] as String;
      _deviceVariant = phone['variant'] as String;
      _imeiNumber = phone['imei'] as String;
      _cashPrice = phone['cash'] as int;
      _loanPrice = phone['loan'] as int;
      _daysInStock = phone['days'] as int;
      _stockStatus = phone['status'] as String;
      _statusText = 'Physical handset resolved · Serialized & tracked';
      _imeiCtrl.text = _imeiNumber;
    });
  }

  void _lookupImei(String query) {
    final clean = query.replaceAll(RegExp(r'\s+'), '').trim();
    if (clean.isEmpty) return;

    // Check if in sample list
    final match = _quickSamplePhones.firstWhere(
      (p) => (p['imei'] as String).contains(clean) || (p['model'] as String).toLowerCase().contains(clean.toLowerCase()),
      orElse: () => {
        'model': clean.startsWith('86') ? 'Redmi Note 13 Pro' : 'Tecno Camon 30',
        'variant': '256GB Dual SIM (Global GSMA)',
        'imei': clean.length >= 15 ? clean : '${clean}000000000000000'.substring(0, 15),
        'cash': 450000,
        'loan': 540000,
        'days': 22,
        'status': 'IN_STOCK',
      },
    );

    _selectPhone(match);
  }

  void _resetScan() {
    setState(() {
      _hasResult = false;
      _isScanning = false;
      _imeiCtrl.clear();
      _statusText = 'Align the IMEI barcode within the viewfinder';
    });
  }

  String _formatNumber(int n) {
    final s = n.toString();
    final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return s.replaceAllMapped(reg, (Match m) => '${m[1]},');
  }

  @override
  Widget build(BuildContext context) {
    final gsmValid = _isGsmValid(_imeiCtrl.text);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FC),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 120),
          children: [
            // Top Navigation & Header Row
            Row(
              children: [
                // Prominent Back Button to prevent desktop/mobile lock-in
                InkWell(
                  onTap: () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/home');
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x080F172A),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.arrow_back_rounded, size: 20, color: AppTheme.ink900),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Serialized Stock Operations',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.ink500,
                        ),
                      ),
                      Text(
                        'Scan & Verify IMEI',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.4,
                          color: AppTheme.ink900,
                        ),
                      ),
                    ],
                  ),
                ),
                // Inspector Shortcut Button
                Tooltip(
                  message: 'Direct IMEI Inspector',
                  child: InkWell(
                    onTap: () => context.push('/imei-inspector?imei=$_imeiNumber'),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF5FE),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFCEE1FE)),
                      ),
                      child: const Icon(Icons.shield_outlined, size: 20, color: AppTheme.brand600),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Live Serial Search & GSMA Validation Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: gsmValid ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
                  width: gsmValid ? 1.5 : 1,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x080F3478),
                    blurRadius: 12,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    gsmValid ? Icons.check_circle_rounded : Icons.search_rounded,
                    size: 20,
                    color: gsmValid ? const Color(0xFF10B981) : AppTheme.ink400,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _imeiCtrl,
                      keyboardType: TextInputType.number,
                      onSubmitted: _lookupImei,
                      style: const TextStyle(
                        fontSize: 14,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w700,
                        color: AppTheme.ink900,
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Enter or paste 15-digit GSMA IMEI…',
                        hintStyle: TextStyle(
                          fontSize: 13,
                          fontFamily: 'system-ui',
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                  ),
                  if (_imeiCtrl.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18, color: AppTheme.ink400),
                      onPressed: () {
                        _imeiCtrl.clear();
                        setState(() {});
                      },
                    ),
                  ElevatedButton(
                    onPressed: () => _lookupImei(_imeiCtrl.text),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.brand600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    child: const Text('Lookup', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Quick Handset Testing Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  const Text(
                    'Quick Test: ',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                  ),
                  for (final phone in _quickSamplePhones) ...[
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: InkWell(
                        onTap: () => _selectPhone(phone),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _imeiNumber == phone['imei'] ? AppTheme.brand600 : const Color(0xFFCBD5E1),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                phone['model'] as String,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: _imeiNumber == phone['imei'] ? AppTheme.brand600 : const Color(0xFF334155),
                                ),
                              ),
                              if ((phone['days'] as int) > 30) ...[
                                const SizedBox(width: 3),
                                const Icon(Icons.warning_amber_rounded, size: 12, color: Color(0xFFEA580C)),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Camera Viewfinder Box
            Container(
              height: 220,
              decoration: BoxDecoration(
                color: const Color(0xFF0D1B34),
                borderRadius: BorderRadius.circular(22),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1F0F3478),
                    blurRadius: 24,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Grid lines pattern
                    Opacity(
                      opacity: 0.12,
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                        ),
                      ),
                    ),

                    // Center scan target frame
                    Container(
                      width: 180,
                      height: 120,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.5),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Stack(
                        children: [
                          // 4 Corner Brackets
                          Positioned(
                            top: -2,
                            left: -2,
                            child: Container(width: 16, height: 16, decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppTheme.brand400, width: 3), left: BorderSide(color: AppTheme.brand400, width: 3)))),
                          ),
                          Positioned(
                            top: -2,
                            right: -2,
                            child: Container(width: 16, height: 16, decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppTheme.brand400, width: 3), right: BorderSide(color: AppTheme.brand400, width: 3)))),
                          ),
                          Positioned(
                            bottom: -2,
                            left: -2,
                            child: Container(width: 16, height: 16, decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppTheme.brand400, width: 3), left: BorderSide(color: AppTheme.brand400, width: 3)))),
                          ),
                          Positioned(
                            bottom: -2,
                            right: -2,
                            child: Container(width: 16, height: 16, decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppTheme.brand400, width: 3), right: BorderSide(color: AppTheme.brand400, width: 3)))),
                          ),

                          // Animated Laser
                          AnimatedBuilder(
                            animation: _laserController,
                            builder: (context, child) {
                              return Positioned(
                                top: 110 * _laserController.value,
                                left: 6,
                                right: 6,
                                child: Container(
                                  height: 2,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF5B9EFA),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppTheme.brand400.withValues(alpha: 0.9),
                                        blurRadius: 8,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    // Status Pill at bottom of viewfinder
                    Positioned(
                      bottom: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                        ),
                        child: Text(
                          _statusText,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Scanned Result Card with Handset Ageing / Stock Velocity Intelligence
            if (_hasResult) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFCEE1FE)),
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            gradient: AppTheme.brandGradient,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(Icons.smartphone_rounded, color: Colors.white, size: 28),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _deviceName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: AppTheme.ink900,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _deviceVariant,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.ink500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'IMEI: $_imeiNumber',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.brand600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    const SizedBox(height: 12),

                    // Velocity & Ageing Intelligence Badges
                    Row(
                      children: [
                        // Ageing Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                          decoration: BoxDecoration(
                            color: _daysInStock > 30 ? const Color(0xFFFFF7ED) : const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _daysInStock > 30 ? const Color(0xFFFED7AA) : const Color(0xFFA7F3D0),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _daysInStock > 30 ? Icons.history_toggle_off_rounded : Icons.bolt_rounded,
                                size: 13,
                                color: _daysInStock > 30 ? const Color(0xFFC2410C) : const Color(0xFF047857),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _daysInStock > 30 ? '$_daysInStock Days in Stock (Ageing)' : '$_daysInStock Days in Stock (Fast Moving)',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: _daysInStock > 30 ? const Color(0xFFC2410C) : const Color(0xFF047857),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Stock Status Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                          decoration: BoxDecoration(
                            color: _stockStatus == 'IN_STOCK' ? const Color(0xFFEFF6FF) : const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _stockStatus == 'IN_STOCK' ? 'Available' : 'Assigned',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: _stockStatus == 'IN_STOCK' ? const Color(0xFF1D4ED8) : const Color(0xFFB91C1C),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Price Breakdown Preview
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Column(
                            children: [
                              const Text('Cash Price', style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                              const SizedBox(height: 2),
                              Text('TZS ${_formatNumber(_cashPrice)}', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppTheme.brand600)),
                            ],
                          ),
                          Container(width: 1, height: 26, color: const Color(0xFFCBD5E1)),
                          Column(
                            children: [
                              const Text('Loan Total', style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                              const SizedBox(height: 2),
                              Text('TZS ${_formatNumber(_loanPrice)}', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Color(0xFF7C5CFC))),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Action Buttons
              ElevatedButton.icon(
                onPressed: () {
                  context.push('/sell-loan?type=SELL&model=$_deviceName&imei=$_imeiNumber');
                },
                icon: const Icon(Icons.point_of_sale_rounded, size: 18),
                label: const Text('Sell via Cash / M-Pesa POS', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.brand600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: () {
                  context.push('/sell-loan?type=LOAN&model=$_deviceName&imei=$_imeiNumber');
                },
                icon: const Icon(Icons.assignment_ind_rounded, size: 18),
                label: const Text('Issue Phone Loan (KYC & Amortization)', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C5CFC),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () {
                  context.push('/imei-inspector?imei=$_imeiNumber');
                },
                icon: const Icon(Icons.shield_rounded, size: 18, color: AppTheme.brand600),
                label: const Text('Deep Knox & Warranty Inspection', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.brand600)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFCEE1FE)),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _resetScan,
                child: const Text(
                  'Scan another device',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.brand600),
                ),
              ),
            ] else ...[
              // Idle state controls
              ElevatedButton.icon(
                onPressed: _runScan,
                icon: _isScanning
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.qr_code_scanner_rounded, size: 20),
                label: Text(
                  _isScanning ? 'Detecting Handset…' : 'Simulate Camera Laser Scan',
                  style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.brand600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
