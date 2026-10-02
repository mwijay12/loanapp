import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_localizations.dart';
import '../../../core/data/mock_lims_data.dart';
import '../../../core/data/inventory_provider.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../loans/presentation/borrower_loan_details_screen.dart';
import '../../loans/presentation/widgets/device_lockscreen_simulator_modal.dart';

class SellLoanScreen extends ConsumerStatefulWidget {
  final String? initialTransaction;
  final String? initialPhoneModel;
  final String? initialImei;

  const SellLoanScreen({
    super.key,
    this.initialTransaction,
    this.initialPhoneModel,
    this.initialImei,
  });

  @override
  ConsumerState<SellLoanScreen> createState() => _SellLoanScreenState();
}

class _SelectedPhone {
  final String model;
  final String variant;
  final String primaryImei;
  final String secondaryImei;
  final int cashPrice;
  final int loanPrice;
  final String condition;
  final Color badgeColor;

  const _SelectedPhone({
    required this.model,
    required this.variant,
    required this.primaryImei,
    required this.secondaryImei,
    required this.cashPrice,
    required this.loanPrice,
    required this.condition,
    required this.badgeColor,
  });
}

class _SellLoanScreenState extends ConsumerState<SellLoanScreen> {
  String _selectedTransaction = 'LOAN'; // 'SELL' or 'LOAN'
  final _formKey = GlobalKey<FormState>();

  // Available in-stock phones
  final List<_SelectedPhone> _availablePhones = const [
    _SelectedPhone(
      model: 'Samsung Galaxy A15',
      variant: '128GB / 6GB · Light Blue',
      primaryImei: '358920112849102',
      secondaryImei: '358920112849110',
      cashPrice: 380000,
      loanPrice: 460000,
      condition: 'Brand New Sealed',
      badgeColor: Color(0xFF1B6EF3),
    ),
    _SelectedPhone(
      model: 'Redmi Note 13 Pro',
      variant: '256GB / 8GB · Midnight Black',
      primaryImei: '864920042819384',
      secondaryImei: '864920042819392',
      cashPrice: 580000,
      loanPrice: 695000,
      condition: 'Brand New Sealed',
      badgeColor: Color(0xFF0EA5E9),
    ),
    _SelectedPhone(
      model: 'iPhone 15 Pro Max',
      variant: '256GB · Natural Titanium',
      primaryImei: '354928104829104',
      secondaryImei: '354928104829112',
      cashPrice: 3850000,
      loanPrice: 4450000,
      condition: 'Brand New Sealed',
      badgeColor: Color(0xFF7C5CFC),
    ),
    _SelectedPhone(
      model: 'Tecno Camon 30 Premier',
      variant: '256GB / 8GB · Iceland White',
      primaryImei: '352940182749102',
      secondaryImei: '352940182749110',
      cashPrice: 440000,
      loanPrice: 530000,
      condition: 'Brand New Sealed',
      badgeColor: Color(0xFF06B6D4),
    ),
  ];

  late _SelectedPhone _activePhone;

  // Borrower KYC Controllers
  final _nameController = TextEditingController(text: 'Bakari Juma Mwambungu');
  final _phoneController = TextEditingController(text: '0754 892 314');
  final _altPhoneController = TextEditingController(text: '0682 110 445');
  final _nidaController = TextEditingController(text: '19920415-14120-00002-18');
  final _residenceController = TextEditingController(text: 'Kariakoo, Mtaa wa Swahili / Kongo');
  final _occupationController = TextEditingController(text: 'Biashara ya Nguo (Duka la Kati)');

  // Guarantor Controllers
  final _guarantorNameController = TextEditingController(text: 'Hawa Rashidi Said');
  final _guarantorPhoneController = TextEditingController(text: '0713 452 980');
  final _guarantorRelationController = TextEditingController(text: 'Dada Mzazi (Kin)');
  final _guarantorNidaController = TextEditingController(text: '19890212-14120-00001-24');

  // Loan Financial Controllers
  late TextEditingController _loanAmountController;
  late TextEditingController _depositController;
  late TextEditingController _installmentController;
  final _dueDateController = TextEditingController(text: 'Ijumaa ijayo (Wiki ya 1)');
  final _supervisorPinController = TextEditingController();

  // Cash Sale Controllers
  String _cashPaymentChannel = 'M-Pesa Lipa Namba';
  final _receiptPhoneController = TextEditingController(text: '0754 892 314');

  int _installmentWeeks = 8;
  String _selectedSecurityMethod = 'Knox Guard OEM (Samsung & Transsion)';
  bool _contractSigned = true;
  bool _deviceLockAgreed = true;
  bool _isProcessing = false;
  String? _borrowerPassportPhoto = 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=300&auto=format&fit=crop&q=80';
  bool _isCameraCapturing = false;

  void _captureWebcamPassport() async {
    setState(() => _isCameraCapturing = true);
    await Future.delayed(const Duration(milliseconds: 900));
    if (mounted) {
      setState(() {
        _isCameraCapturing = false;
        _borrowerPassportPhoto = 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=300&auto=format&fit=crop&q=80';
      });
      LimsToast.show(context, 'Live passport photo captured & verified via office webcam!', isSuccess: true);
    }
  }

  void _uploadPassportPhoto() {
    setState(() {
      _borrowerPassportPhoto = 'https://images.unsplash.com/photo-1492562080023-ab3db95bfbce?w=300&auto=format&fit=crop&q=80';
    });
    LimsToast.show(context, 'Passport image uploaded & scanned successfully.', isSuccess: true);
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialTransaction != null) {
      final t = widget.initialTransaction!.toUpperCase();
      _selectedTransaction = (t == 'SELL' || t == 'CASH') ? 'SELL' : 'LOAN';
    }

    _activePhone = _availablePhones[0];
    if (widget.initialPhoneModel != null) {
      final found = _availablePhones.firstWhere(
        (p) =>
            p.model.toLowerCase().contains(widget.initialPhoneModel!.toLowerCase()) ||
            widget.initialPhoneModel!.toLowerCase().contains(p.model.toLowerCase()),
        orElse: () => _availablePhones[0],
      );
      _activePhone = found;
    }

    _loanAmountController = TextEditingController(text: _formatNumber(_activePhone.loanPrice));
    final defaultDeposit = (_activePhone.loanPrice * 0.25).round();
    _depositController = TextEditingController(text: _formatNumber(defaultDeposit));
    final balance = _activePhone.loanPrice - defaultDeposit;
    _installmentController = TextEditingController(text: _formatNumber((balance / _installmentWeeks).round()));
  }

  String _formatNumber(num val) {
    final s = val.round().toString();
    final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return s.replaceAllMapped(reg, (Match m) => '${m[1]},');
  }

  void _onPhoneChanged(_SelectedPhone phone) {
    setState(() {
      _activePhone = phone;
      _loanAmountController.text = _formatNumber(phone.loanPrice);
      final deposit = (phone.loanPrice * 0.25).round();
      _depositController.text = _formatNumber(deposit);
      final balance = phone.loanPrice - deposit;
      _installmentController.text = _formatNumber((balance / _installmentWeeks).round());
    });
  }

  void _recalcLoan() {
    final total = double.tryParse(_loanAmountController.text.replaceAll(',', '')) ?? _activePhone.loanPrice.toDouble();
    final deposit = double.tryParse(_depositController.text.replaceAll(',', '')) ?? (total * 0.25);
    final balance = total > deposit ? total - deposit : 0.0;
    _installmentController.text = _formatNumber((balance / _installmentWeeks).round());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _altPhoneController.dispose();
    _nidaController.dispose();
    _residenceController.dispose();
    _occupationController.dispose();
    _guarantorNameController.dispose();
    _guarantorPhoneController.dispose();
    _guarantorRelationController.dispose();
    _guarantorNidaController.dispose();
    _loanAmountController.dispose();
    _depositController.dispose();
    _installmentController.dispose();
    _dueDateController.dispose();
    _supervisorPinController.dispose();
    _receiptPhoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final requiresSupervisor = _selectedTransaction == 'LOAN' && _activePhone.loanPrice > 1000000;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          _selectedTransaction == 'LOAN' ? 'Issue Phone Loan' : 'POS Counter Sale',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppTheme.ink900),
        ),
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.ink900),
          onPressed: () => context.pop(),
        ),
        actions: [
          Tooltip(
            message: 'Duka: Kariakoo Main Hub',
            child: IconButton(
              icon: const Icon(Icons.storefront_rounded, color: AppTheme.brand600, size: 20),
              onPressed: () {
                LimsToast.show(context, 'Duka linalotumika: Kariakoo Main Hub');
              },
            ),
          ),
          const SizedBox(width: 6),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFE2E8F0), height: 1),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 120),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handset Selector Card
              _buildHandsetSelector(),
              const SizedBox(height: 16),

              // Transaction Mode Switcher (Sell vs Loan)
              _buildTransactionType(l10n),
              const SizedBox(height: 18),

              if (_selectedTransaction == 'SELL') ...[
                _buildCashSaleForm(),
              ] else ...[
                // Loan Form: KYC, Guarantor, Financials, Contract
                _buildBorrowerKycSection(),
                const SizedBox(height: 18),
                _buildGuarantorSection(),
                const SizedBox(height: 18),
                _buildLoanFinancialScheduleSection(),
                const SizedBox(height: 18),
                _buildContractAndSecuritySection(),

                if (requiresSupervisor) ...[
                  const SizedBox(height: 18),
                  _buildSupervisorApprovalCard(),
                ],
              ],

              const SizedBox(height: 28),
              _buildConfirmButton(context, l10n, requiresSupervisor),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------- Handset Selector
  Widget _buildHandsetSelector() {
    return Container(
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
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Selected Handset',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppTheme.ink500),
              ),
              InkWell(
                onTap: _showHandsetPickerSheet,
                child: const Row(
                  children: [
                    Text(
                      'Change Phone',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.brand600),
                    ),
                    SizedBox(width: 2),
                    Icon(Icons.swap_vert_rounded, size: 16, color: AppTheme.brand600),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_activePhone.badgeColor, _activePhone.badgeColor.withValues(alpha: 0.8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: _activePhone.badgeColor.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.phone_android_rounded, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _activePhone.model,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.ink900),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE7F8F0),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('In Stock', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF12B76A))),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _activePhone.variant,
                      style: const TextStyle(fontSize: 12, color: AppTheme.ink500, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            'IMEI 1: ${_activePhone.primaryImei}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.ink700),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF12B76A)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 22, color: Color(0xFFF1F5F9)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Cash Selling Price', style: TextStyle(fontSize: 11, color: AppTheme.ink500)),
                  Text(
                    'TZS ${_formatNumber(_activePhone.cashPrice)}',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.ink900),
                  ),
                ],
              ),
              Container(width: 1, height: 26, color: const Color(0xFFE2E8F0)),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Financed Loan Price', style: TextStyle(fontSize: 11, color: AppTheme.ink500)),
                  Text(
                    'TZS ${_formatNumber(_activePhone.loanPrice)}',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.brand600),
                  ),
                ],
              ),
              Container(width: 1, height: 26, color: const Color(0xFFE2E8F0)),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Min Deposit (25%)', style: TextStyle(fontSize: 11, color: AppTheme.ink500)),
                  Text(
                    'TZS ${_formatNumber((_activePhone.loanPrice * 0.25).round())}',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF12B76A)),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showHandsetPickerSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(color: const Color(0xFFD4E0F0), borderRadius: BorderRadius.circular(99)),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Select Handset for Checkout',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppTheme.ink900),
              ),
              const SizedBox(height: 14),
              ..._availablePhones.map((phone) {
                final isSelected = phone.model == _activePhone.model;
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFE9F2FE) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isSelected ? AppTheme.brand600 : const Color(0xFFE2E8F0)),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: phone.badgeColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.phone_android_rounded, color: phone.badgeColor, size: 22),
                    ),
                    title: Text(
                      phone.model,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.ink900),
                    ),
                    subtitle: Text(
                      '${phone.variant} · TZS ${_formatNumber(phone.cashPrice)}',
                      style: const TextStyle(fontSize: 11.5, color: AppTheme.ink500),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle_rounded, color: AppTheme.brand600)
                        : const Icon(Icons.chevron_right_rounded, color: Color(0xFFCBD5E1)),
                    onTap: () {
                      Navigator.pop(ctx);
                      _onPhoneChanged(phone);
                    },
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  // ------------------------------------------------------------- Transaction Type Selector
  Widget _buildTransactionType(AppLocalizations l10n) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFE9F0FA),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => setState(() => _selectedTransaction = 'SELL'),
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _selectedTransaction == 'SELL' ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: _selectedTransaction == 'SELL'
                      ? const [BoxShadow(color: Color(0x10000000), blurRadius: 8, offset: Offset(0, 2))]
                      : null,
                ),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.point_of_sale_rounded,
                        size: 18,
                        color: _selectedTransaction == 'SELL' ? AppTheme.brand600 : AppTheme.ink500,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Cash Sale (POS)',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: _selectedTransaction == 'SELL' ? AppTheme.brand600 : AppTheme.ink500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: () => setState(() => _selectedTransaction = 'LOAN'),
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _selectedTransaction == 'LOAN' ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: _selectedTransaction == 'LOAN'
                      ? const [BoxShadow(color: Color(0x10000000), blurRadius: 8, offset: Offset(0, 2))]
                      : null,
                ),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.assignment_ind_rounded,
                        size: 18,
                        color: _selectedTransaction == 'LOAN' ? const Color(0xFF7C5CFC) : AppTheme.ink500,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Phone Loan (Credit)',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: _selectedTransaction == 'LOAN' ? const Color(0xFF7C5CFC) : AppTheme.ink500,
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

  // ------------------------------------------------------------- Cash Sale Form
  Widget _buildCashSaleForm() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x0A0F3478), blurRadius: 18, offset: Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Cash Sale & Instant Payment',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.ink900),
          ),
          const SizedBox(height: 4),
          const Text(
            'Complete payment at Kariakoo counter and issue automated EFD receipt.',
            style: TextStyle(fontSize: 11.5, color: AppTheme.ink500),
          ),
          const SizedBox(height: 16),

          // Total payable
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF4F9FF),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFD6E6FE)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Amount Due (Cash Total)',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.ink700),
                ),
                Text(
                  'TZS ${_formatNumber(_activePhone.cashPrice)}',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppTheme.brand600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          const Text('Payment Channel', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppTheme.ink900)),
          const SizedBox(height: 8),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              'M-Pesa Lipa Namba',
              'Cash at Counter',
              'Airtel Money',
              'Tigo Pesa',
              'CRDB Bank Card',
            ].map((channel) {
              final isSelected = _cashPaymentChannel == channel;
              return ChoiceChip(
                label: Text(channel),
                selected: isSelected,
                selectedColor: AppTheme.brand600,
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.white : AppTheme.ink700,
                ),
                onSelected: (val) {
                  if (val) setState(() => _cashPaymentChannel = channel);
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _receiptPhoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Customer Phone (for SMS Receipt & TRA EFD)',
              prefixIcon: Icon(Icons.phone_iphone_rounded, size: 20),
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------- Borrower KYC
  Widget _buildBorrowerKycSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x0A0F3478), blurRadius: 18, offset: Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0EBFF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.person_pin_rounded, color: Color(0xFF7C5CFC), size: 18),
              ),
              const SizedBox(width: 10),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '1. Borrower KYC Verification',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.ink900),
                  ),
                  Text(
                    'Borrower Identity, Live Passport Photo & NIDA Verification',
                    style: TextStyle(fontSize: 11, color: AppTheme.ink500),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Live Office Passport Photo Capture / Upload Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.camera_front_rounded, size: 16, color: Color(0xFF1E60F2)),
                    SizedBox(width: 6),
                    Text(
                      'Live Office Passport Photo',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 68,
                      height: 80,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
                        image: _borrowerPassportPhoto != null
                            ? DecorationImage(
                                image: NetworkImage(_borrowerPassportPhoto!),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: _isCameraCapturing
                          ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
                          : (_borrowerPassportPhoto == null
                              ? const Center(child: Icon(Icons.person_rounded, size: 36, color: Color(0xFF94A3B8)))
                              : null),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              ElevatedButton.icon(
                                onPressed: _isCameraCapturing ? null : _captureWebcamPassport,
                                icon: const Icon(Icons.camera_alt_rounded, size: 14),
                                label: const Text('Live Capture', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1E60F2),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  minimumSize: Size.zero,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton.icon(
                                onPressed: _uploadPassportPhoto,
                                icon: const Icon(Icons.upload_file_rounded, size: 14),
                                label: const Text('Upload', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  minimumSize: Size.zero,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          const Row(
                            children: [
                              Icon(Icons.check_circle_rounded, size: 12, color: Color(0xFF10B981)),
                              SizedBox(width: 4),
                              Text(
                                'Kariakoo Terminal Webcam Match: 99.2%',
                                style: TextStyle(fontSize: 10, color: Color(0xFF059669), fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Borrower Legal Full Name',
              prefixIcon: Icon(Icons.badge_outlined, size: 20),
              border: OutlineInputBorder(),
            ),
            validator: (v) => (v == null || v.isEmpty) ? 'Please enter borrower legal name' : null,
          ),
          const SizedBox(height: 12),

          TextFormField(
            controller: _nidaController,
            decoration: const InputDecoration(
              labelText: 'National NIDA ID (20 Digits)',
              prefixIcon: Icon(Icons.fingerprint_rounded, size: 20),
              helperText: 'Validated against NIDA & Credit Reference Bureau',
              border: OutlineInputBorder(),
            ),
            validator: (v) => (v == null || v.length < 15) ? 'Enter valid 20-digit NIDA ID' : null,
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'M-Pesa Primary Phone',
                    prefixIcon: Icon(Icons.phone_rounded, size: 18),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.isEmpty) ? 'Enter primary phone' : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: _altPhoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'WhatsApp / Alt Phone',
                    prefixIcon: Icon(Icons.chat_bubble_outline_rounded, size: 18),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          TextFormField(
            controller: _residenceController,
            decoration: const InputDecoration(
              labelText: 'Residential Street / Ward (Dar es Salaam)',
              prefixIcon: Icon(Icons.location_on_outlined, size: 20),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),

          TextFormField(
            controller: _occupationController,
            decoration: const InputDecoration(
              labelText: 'Employment / Business Stand / Income Source',
              prefixIcon: Icon(Icons.work_outline_rounded, size: 20),
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------- Guarantor
  Widget _buildGuarantorSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x0A0F3478), blurRadius: 18, offset: Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3E4),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.supervisor_account_rounded, color: Color(0xFFF79009), size: 18),
              ),
              const SizedBox(width: 10),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '2. Guarantor Reference Verification',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.ink900),
                  ),
                  Text(
                    'Recognized guarantor details & collateral standing',
                    style: TextStyle(fontSize: 11, color: AppTheme.ink500),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextFormField(
                  controller: _guarantorNameController,
                  decoration: const InputDecoration(
                    labelText: 'Guarantor Full Legal Name',
                    prefixIcon: Icon(Icons.person_outline_rounded, size: 18),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: _guarantorRelationController,
                  decoration: const InputDecoration(
                    labelText: 'Relationship',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _guarantorPhoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Guarantor Phone Number',
                    prefixIcon: Icon(Icons.phone_android_rounded, size: 18),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: _guarantorNidaController,
                  decoration: const InputDecoration(
                    labelText: 'Guarantor NIDA ID',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------- Financial Schedule
  Widget _buildLoanFinancialScheduleSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x0A0F3478), blurRadius: 18, offset: Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFE7F8F0),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.calculate_rounded, color: Color(0xFF12B76A), size: 18),
              ),
              const SizedBox(width: 10),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '3. Loan Financial Terms & Repayment',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.ink900),
                  ),
                  Text(
                    'Initial deposit, repayment term, and financing breakdown',
                    style: TextStyle(fontSize: 11, color: AppTheme.ink500),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _loanAmountController,
                  keyboardType: TextInputType.number,
                  onChanged: (v) => _recalcLoan(),
                  decoration: const InputDecoration(
                    labelText: 'Total Loan Price',
                    prefixText: 'TZS ',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: _depositController,
                  keyboardType: TextInputType.number,
                  onChanged: (v) => _recalcLoan(),
                  decoration: const InputDecoration(
                    labelText: 'Initial Deposit',
                    prefixText: 'TZS ',
                    helperText: 'Recommended min 25%',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: _installmentWeeks,
                  decoration: const InputDecoration(
                    labelText: 'Repayment Term',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 4, child: Text('4 Weeks (1 Month)')),
                    DropdownMenuItem(value: 8, child: Text('8 Weeks (2 Months)')),
                    DropdownMenuItem(value: 12, child: Text('12 Weeks (3 Months)')),
                    DropdownMenuItem(value: 16, child: Text('16 Weeks (4 Months)')),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      setState(() {
                        _installmentWeeks = v;
                        _recalcLoan();
                      });
                    }
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: _installmentController,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'Rejesho kwa Wiki',
                    prefixText: 'TZS ',
                    helperText: 'Automated M-Pesa collection',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.event_repeat_rounded, size: 20, color: AppTheme.brand600),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Rejesho la Kwanza (First Due Date)',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppTheme.ink500),
                      ),
                      Text(
                        '${_dueDateController.text} · TZS ${_installmentController.text}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.ink900),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------- Contract & Security
  Widget _buildContractAndSecuritySection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x0A0F3478), blurRadius: 18, offset: Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '4. Loan Agreement & Device Protection',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.ink900),
              ),
              InkWell(
                onTap: _showContractModal,
                child: const Text(
                  'Soma Mkataba',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.brand600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Chagua jinsi simu hii inavyofuatiliwa na namba itakayoonekana kioo kikiwa kimefungwa.',
            style: TextStyle(fontSize: 11.5, color: AppTheme.ink500),
          ),
          const SizedBox(height: 14),

          // Security & Tracking Method Selector
          const Text(
            'Mfumo wa Kufunga & Kufuatilia Simu (Tracking Method)',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppTheme.ink900),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedSecurityMethod,
                isExpanded: true,
                icon: const Icon(Icons.security_rounded, color: AppTheme.brand600),
                items: const [
                  DropdownMenuItem(
                    value: 'Knox Guard OEM (Samsung & Transsion)',
                    child: Row(
                      children: [
                        Icon(Icons.verified_user_rounded, size: 16, color: AppTheme.brand600),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Knox Guard OEM (Samsung & Transsion Factory)',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'Android Device Owner MDM (Universal APK)',
                    child: Row(
                      children: [
                        Icon(Icons.android_rounded, size: 16, color: Color(0xFF10B981)),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Android Device Owner MDM (Universal Android)',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'Apple iOS Supervised MDM (iPhones)',
                    child: Row(
                      children: [
                        Icon(Icons.apple_rounded, size: 16, color: Colors.black87),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Apple iOS Supervised MDM (iPhones)',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'Dhamana & TCRA EIR Blacklist (Clean Phone)',
                    child: Row(
                      children: [
                        Icon(Icons.gavel_rounded, size: 16, color: Color(0xFFF59E0B)),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Collateral & TCRA EIR Verification (Non-Knox)',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _selectedSecurityMethod = val);
                },
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Default Lipa Namba on Lockscreen Card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.point_of_sale_rounded, size: 18, color: Color(0xFF16A34A)),
                    SizedBox(width: 8),
                    Text(
                      'Default Merchant Till Displayed on Customer Lockscreen',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF15803D)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'When locked, the handset displays: Vodacom M-Pesa Till: 552219 (LIMS Dealership) and customer loan account number. Automated carrier IPN unlocks device instantly upon settlement.',
                  style: TextStyle(fontSize: 11, color: Color(0xFF166534), height: 1.35),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      final amountDue = int.tryParse(_installmentController.text.replaceAll(',', '')) ?? 45000;
                      DeviceLockscreenSimulatorModal.show(
                        context,
                        deviceModel: _activePhone.model,
                        imei: _activePhone.primaryImei,
                        borrowerName: _nameController.text.isNotEmpty ? _nameController.text : 'New Borrower',
                        borrowerPhone: _phoneController.text,
                        overdueAmount: amountDue,
                        loanId: 'LIMS-LN-NEW',
                        initialIsLocked: true,
                      );
                    },
                    icon: const Icon(Icons.remove_red_eye_rounded, size: 16),
                    label: const Text(
                      'Preview Remote Lockscreen (Simulator)',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Knox Warning Banner
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFEDF1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFFD4DE)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lock_clock_rounded, size: 20, color: Color(0xFFF43F5E)),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ulinzi wa Kifaa (Device Lock Guardrail)',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF9F1239)),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Ikiwa marejesho yatachelewa zaidi ya saa 48 baada ya tarehe ya ahadi, amri ya kufunga (Remote Lock) itatumwa kiotomatiki kupitia mfumo uliochaguliwa.',
                        style: TextStyle(fontSize: 11, color: Color(0xFFBE123C)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _contractSigned,
            onChanged: (v) => setState(() => _contractSigned = v ?? false),
            title: const Text(
              'Mkopaji amesoma na kusaini mkataba wa mkopo kwa ukamilifu',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppTheme.ink900),
            ),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _deviceLockAgreed,
            onChanged: (v) => setState(() => _deviceLockAgreed = v ?? false),
            title: const Text(
              'Mkopaji anakubali masharti ya kufunga simu endapo atashindwa kulipa',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppTheme.ink900),
            ),
            controlAffinity: ListTileControlAffinity.leading,
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------- Supervisor Approval
  Widget _buildSupervisorApprovalCard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.security_rounded, size: 20, color: Color(0xFFD97706)),
              SizedBox(width: 8),
              Text(
                'Supervisor Approval Required (> TZS 1.0M)',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Color(0xFF92400E)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Kulingana na sera ya LIMS, mikopo inayozidi TZS 1,000,000 inahitaji kibali cha Msimamizi wa Tawi (Admin / Branch Manager PIN).',
            style: TextStyle(fontSize: 11.5, color: Color(0xFFB45309)),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _supervisorPinController,
            obscureText: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Supervisor Authorization PIN',
              hintText: 'Enter 4-digit manager PIN (e.g. 8821)',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }

  void _showContractModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(ctx).size.height * 0.85,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(color: const Color(0xFFD4E0F0), borderRadius: BorderRadius.circular(99)),
                ),
              ),
              const SizedBox(height: 16),
              const Row(
                children: [
                  Icon(Icons.gavel_rounded, color: AppTheme.brand600, size: 22),
                  SizedBox(width: 10),
                  Text(
                    'Mkataba wa Mauzo ya Mkopo',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppTheme.ink900),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Expanded(
                child: SingleChildScrollView(
                  child: Text(
                    'HIRE-PURCHASE SMARTPHONE LOAN AGREEMENT\n\n'
                    '1. Parties: Creditor (LIMS Phone Dealership Kariakoo) and Borrower (${_nameController.text}, NIDA: ${_nidaController.text}).\n\n'
                    '2. Financed Handset: ${_activePhone.model}, Serialized IMEI: ${_activePhone.primaryImei}, Variant: ${_activePhone.variant}.\n\n'
                    '3. Valuation & Down Payment: Loan price TZS ${_loanAmountController.text}. Initial deposit received: TZS ${_depositController.text}.\n\n'
                    '4. Repayment Schedule: Weekly installment of TZS ${_installmentController.text} for a duration of $_installmentWeeks weeks.\n\n'
                    '5. Remote Knox MDM Security: Handset ownership remains with dealership until full final payment is received. Handset will be locked remotely if arrears exceed 72 hours.\n\n'
                    '6. Guarantor: ${_guarantorNameController.text} (${_guarantorRelationController.text}, Phone: ${_guarantorPhoneController.text}) acknowledges legal joint obligation.\n',
                    style: const TextStyle(fontSize: 12.5, height: 1.5, color: AppTheme.ink700),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.brand600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('I Understand & Accept Terms', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ------------------------------------------------------------- Confirm Action
  Widget _buildConfirmButton(BuildContext context, AppLocalizations l10n, bool requiresSupervisor) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isProcessing
            ? null
            : () {
                if (_selectedTransaction == 'LOAN') {
                  final phoneErr = LimsValidators.validateTzPhone(_phoneController.text);
                  if (phoneErr != null) {
                    LimsToast.show(context, 'Borrower phone number: $phoneErr', isError: true);
                    return;
                  }

                  final nidaErr = LimsValidators.validateNida(_nidaController.text);
                  if (nidaErr != null) {
                    LimsToast.show(context, 'National NIDA ID: $nidaErr', isError: true);
                    return;
                  }

                  final deposit = int.tryParse(_depositController.text.replaceAll(',', '')) ?? 0;
                  final minDeposit = (_activePhone.loanPrice * 0.25).round();
                  if (deposit < minDeposit) {
                    LimsToast.show(
                      context,
                      'Deposit amount is below minimum! Must be at least 25% (TZS ${_formatNumber(minDeposit)})',
                      isError: true,
                    );
                    return;
                  }

                  if (!_contractSigned || !_deviceLockAgreed) {
                    LimsToast.show(
                      context,
                      'Please confirm contract signature and device security terms (Knox Security).',
                      isError: true,
                    );
                    return;
                  }

                  if (requiresSupervisor && _supervisorPinController.text.trim() != '8821') {
                    LimsToast.show(
                      context,
                      'Supervisor authorization PIN required for loans > 1M! Enter PIN: 8821',
                      isError: true,
                    );
                    return;
                  }

                  final newLoan = LoanItem(
                    id: 'LIMS-LN-${1000 + DateTime.now().millisecond % 9000}',
                    name: _nameController.text.trim().isEmpty ? 'Bakari Juma Mwambungu' : _nameController.text.trim(),
                    item: _activePhone.model,
                    amount: _activePhone.loanPrice,
                    paid: ((deposit / _activePhone.loanPrice) * 100).round().clamp(10, 100),
                    due: 'Due in 7 days',
                    status: 'current',
                    grad: const [AppTheme.brand600, Color(0xFF7C5CFC)],
                    phone: _phoneController.text.trim().isEmpty ? '0754 892 314' : _phoneController.text.trim(),
                    nida: _nidaController.text.trim().isEmpty ? '19920415-14120-00002-18' : _nidaController.text.trim(),
                    location: _residenceController.text.trim().isEmpty ? 'Kariakoo, Dar es Salaam' : _residenceController.text.trim(),
                    businessAddress: _occupationController.text.trim().isEmpty ? 'Biashara ya Duka' : _occupationController.text.trim(),
                    imei: _activePhone.primaryImei,
                    guarantorName: _guarantorNameController.text.trim().isEmpty ? 'Hawa Rashidi' : _guarantorNameController.text.trim(),
                    guarantorPhone: _guarantorPhoneController.text.trim().isEmpty ? '0713 452 980' : _guarantorPhoneController.text.trim(),
                    guarantorRelation: _guarantorRelationController.text.trim().isEmpty ? 'Dada Mzazi' : _guarantorRelationController.text.trim(),
                    isKnoxLocked: false,
                    totalDeposit: deposit.round(),
                    weeklyInstallment: int.tryParse(_installmentController.text.replaceAll(',', '')) ?? ((_activePhone.loanPrice - deposit) / _installmentWeeks).round(),
                    installmentWeeks: _installmentWeeks,
                  );

                  // Record Loan in Riverpod Store
                  ref.read(loansProvider.notifier).addLoan(newLoan);

                  // Deduct stock in inventory
                  final currentInventory = ref.read(inventoryProvider);
                  ProductItem? matchedItem;
                  for (final p in currentInventory) {
                    if (p.name.toLowerCase().contains(_activePhone.model.toLowerCase()) || _activePhone.model.toLowerCase().contains(p.name.toLowerCase())) {
                      matchedItem = p;
                      break;
                    }
                  }
                  if (matchedItem != null) {
                    ref.read(inventoryProvider.notifier).sellProduct(matchedItem.id, quantity: 1, isLoan: true);
                  }

                  // Add to Activity Feed
                  ref.read(activitiesProvider.notifier).addActivity(
                    ActivityItem(
                      icon: Icons.assignment_ind_rounded,
                      iconColor: const Color(0xFF7C5CFC),
                      bgColor: const Color(0xFFF0EBFF),
                      title: 'Loan Disbursed · ${_activePhone.model}',
                      description: 'TZS ${_depositController.text} deposit · ${_nameController.text.trim()}',
                      time: 'Just now',
                    ),
                  );
                } else {
                  // Cash Sale Activity & Stock decrement
                  final currentInventory = ref.read(inventoryProvider);
                  ProductItem? matchedItem;
                  for (final p in currentInventory) {
                    if (p.name.toLowerCase().contains(_activePhone.model.toLowerCase()) || _activePhone.model.toLowerCase().contains(p.name.toLowerCase())) {
                      matchedItem = p;
                      break;
                    }
                  }
                  if (matchedItem != null) {
                    ref.read(inventoryProvider.notifier).sellProduct(matchedItem.id, quantity: 1, isLoan: false);
                  }

                  ref.read(activitiesProvider.notifier).addActivity(
                    ActivityItem(
                      icon: Icons.point_of_sale_rounded,
                      iconColor: AppTheme.successColor,
                      bgColor: AppTheme.successLight,
                      title: 'Sale Completed · ${_activePhone.model}',
                      description: 'TZS ${_formatNumber(_activePhone.cashPrice)} · $_cashPaymentChannel',
                      time: 'Just now',
                    ),
                  );
                }

                setState(() => _isProcessing = true);
                Future.delayed(const Duration(milliseconds: 250), () {
                  if (mounted) {
                    setState(() => _isProcessing = false);
                    _showSuccess(this.context);
                  }
                });
              },
        style: ElevatedButton.styleFrom(
          backgroundColor: _selectedTransaction == 'LOAN' ? const Color(0xFF7C5CFC) : AppTheme.brand600,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 2,
        ),
        child: _isProcessing
            ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
            : Text(
                _selectedTransaction == 'LOAN'
                    ? 'Issue Loan · TZS ${_depositController.text} Deposit'
                    : 'Complete Cash Sale · TZS ${_formatNumber(_activePhone.cashPrice)}',
                style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800),
              ),
      ),
    );
  }

  void _showSuccess(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 68,
              height: 68,
              decoration: const BoxDecoration(
                color: Color(0xFFE7F8F0),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded, color: Color(0xFF12B76A), size: 44),
            ),
            const SizedBox(height: 16),
            Text(
              _selectedTransaction == 'LOAN' ? 'Phone Loan Disbursed Successfully!' : 'Cash POS Sale Completed!',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.ink900),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _selectedTransaction == 'LOAN'
                  ? 'Device registered to ${_nameController.text}.\nInitial deposit of TZS ${_depositController.text} received in cashier drawer.'
                  : 'Payment of TZS ${_formatNumber(_activePhone.cashPrice)} via $_cashPaymentChannel verified.',
              style: const TextStyle(fontSize: 12.5, color: AppTheme.ink500),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'IMEI: ${_activePhone.primaryImei} · TRA EFD #TZ-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.ink700),
              ),
            ),
            const SizedBox(height: 20),
            if (_selectedTransaction == 'LOAN') ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    final loans = ref.read(loansProvider);
                    final matchingLoan = loans.firstWhere(
                      (l) => l.name == _nameController.text.trim() || l.item == _activePhone.model,
                      orElse: () => loans.first,
                    );
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BorrowerLoanDetailsScreen(loanId: matchingLoan.id, initialLoan: matchingLoan),
                      ),
                    );
                  },
                  icon: const Icon(Icons.badge_rounded, size: 18),
                  label: const Text('Fungua Faili la Mkopaji (Knox Profile)', style: TextStyle(fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7C5CFC),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: Color(0xFF12B76A),
                          content: Text('Stakabadhi na mkataba vimetumwa kwa mteja kupitia WhatsApp na SMS!'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.share_rounded, size: 16, color: AppTheme.brand600),
                    label: const Text('Tuma SMS', style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.brand600, fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: AppTheme.ink900,
                          content: Text('Risiti ya EFD imechapishwa kupitia Bluetooth Printer!'),
                        ),
                      );
                      context.pop();
                    },
                    icon: const Icon(Icons.print_rounded, size: 16),
                    label: const Text('Print Risiti', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.brand600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                context.pop();
              },
              child: const Text('Rudi Nyumbani (Back to Home)', style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.ink500)),
            ),
          ],
        ),
      ),
    );
  }
}
