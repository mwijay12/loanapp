import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/pdf_labels.dart';
import '../../../core/services/pdf_report_service.dart';
import '../../../core/services/app_permissions_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_localizations.dart';
import '../../../core/data/mock_lims_data.dart';
import '../../../core/data/product_art.dart';
import '../../../core/data/inventory_provider.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../../core/l10n/strings.dart';
import '../../../core/data/lims_repository.dart';
import '../../../core/data/sale_ledger.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../loans/presentation/borrower_loan_details_screen.dart';

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

class _SellLoanScreenState extends ConsumerState<SellLoanScreen> {
  String _selectedTransaction = 'LOAN'; // 'SELL' (Cash) or 'LOAN'
  final _formKey = GlobalKey<FormState>();

  // P0: supervisor PIN is NOT hardcoded. Injected at build time
  // (--dart-define=SUPERVISOR_PIN=...). Empty means high-value loans are
  // blocked fail-closed until a server-side approval (P1/P2) exists.
  static const String _supervisorPin = String.fromEnvironment('SUPERVISOR_PIN');

  int? _selectedHandsetId;

  // Borrower KYC Controllers
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _altPhoneController = TextEditingController();
  final _nidaController = TextEditingController();
  final _residenceController = TextEditingController();
  final _occupationController = TextEditingController();

  // Guarantor Controllers
  final _guarantorNameController = TextEditingController();
  final _guarantorPhoneController = TextEditingController();
  final _guarantorRelationController = TextEditingController();
  final _guarantorNidaController = TextEditingController();

  // Loan Financial Controllers
  late TextEditingController _depositController;
  final _supervisorPinController = TextEditingController();

  // Cash Sale Controllers
  /// Stored as a code, not as a label.
  ///
  /// The channel used to hold the translated text, so a sale rung up in Swahili
  /// was written to the database as "Fedha kaunta" and one rung up in English as
  /// "Cash at counter" — the same channel, two values, and a report that splits
  /// them. The label is now rendered from the code at display time.
  String _cashPaymentChannel = 'cash';
  final _receiptPhoneController = TextEditingController();

  int _installmentWeeks = 8;
  // Unchecked on purpose. A pre-ticked signature box is not consent, and a
  // hire-purchase agreement that records consent nobody gave is worse than no
  // record at all.
  bool _contractSigned = false;
  bool _borrowerConsentAgreed = false;
  bool _showSchedulePreview = false;
  bool _isProcessing = false;
  /// Refuses a second submission while the first is still being written.
  ///
  /// UI-level protection only, in one client. The migrations declare
  /// `sales.receipt_no` as `text unique not null`, but each attempt mints a new
  /// receipt number, so a second device ringing up the same sale writes a second
  /// row that no constraint will refuse.
  final SaleSubmitGuard _submitGuard = SaleSubmitGuard();
  /// The bytes the counter actually captured, if any.
  ///
  /// This used to be an Unsplash URL: pressing "capture" waited 700 ms and then
  /// displayed a photograph of a man who has never been in the shop, labelled as
  /// the borrower's KYC portrait. A file picked here is shown from memory, and
  /// nothing is claimed when the counter has not taken one.
  Uint8List? _borrowerPassportBytes;

  Future<void> _pickPassportPhoto({required ImageSource source}) async {
    final locale = _locale;
    if (source == ImageSource.camera) {
      final allowed = await AppPermissionsService.ensureCamera(context);
      if (!allowed) {
        if (mounted) {
          LimsToast.show(context, tr(locale, 'sell.cameraNeeded'), isError: true);
        }
        return;
      }
    }
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: source,
      maxWidth: 900,
      imageQuality: 72,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    setState(() => _borrowerPassportBytes = bytes);
    LimsToast.show(context, tr(locale, 'sell.photoAttached'), isSuccess: true);
  }
  @override
  void initState() {
    super.initState();
    if (widget.initialTransaction != null) {
      final t = widget.initialTransaction!.toUpperCase();
      _selectedTransaction = (t == 'SELL' || t == 'CASH') ? 'SELL' : 'LOAN';
    }
    _depositController = TextEditingController();
  }

  String _formatNumber(num val) {
    final s = val.round().toString();
    final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return s.replaceAllMapped(reg, (Match m) => '${m[1]},');
  }

  ProductItem? _resolveActivePhone(List<ProductItem> availablePhones) {
    if (availablePhones.isEmpty) return null;
    if (_selectedHandsetId != null) {
      final match = availablePhones.where((p) => p.id == _selectedHandsetId).toList();
      if (match.isNotEmpty) return match.first;
    }
    if (widget.initialPhoneModel != null) {
      final match = availablePhones.where(
        (p) =>
            p.name.toLowerCase().contains(widget.initialPhoneModel!.toLowerCase()) ||
            widget.initialPhoneModel!.toLowerCase().contains(p.name.toLowerCase()),
      ).toList();
      if (match.isNotEmpty) return match.first;
    }
    return availablePhones.first;
  }

  void _ensureDepositInitialized(ProductItem phone) {
    final loanPrice = phone.loanPrice ?? (phone.price * 1.20).round();
    final defaultDeposit = (loanPrice * 0.25).round();
    if (_depositController.text.isEmpty) {
      _depositController.text = _formatNumber(defaultDeposit);
    }
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
    _depositController.dispose();
    _supervisorPinController.dispose();
    _receiptPhoneController.dispose();
    super.dispose();
  }

  Locale get _locale => ref.read(localeProvider);

  /// Codes are stored, labels are shown, so a receipt printed in Kiswahili and
  /// one printed in English still reconcile to the same channel.
  String _paymentChannelLabel(String code) {
    switch (code) {
      case 'cash':
        return tr(_locale, 'sell.cashAtCounter');
      case 'mpesa':
        return tr(_locale, 'sell.mpesa');
      case 'airtel':
        return tr(_locale, 'sell.airtel');
      case 'tigopesa':
        return tr(_locale, 'sell.tigopesa');
      case 'card':
        return tr(_locale, 'sell.card');
      default:
        return code;
    }
  }

  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Watched, not read: a language change has to rebuild the whole form, and
    // every helper below resolves strings through the same locale.
    ref.watch(localeProvider);
    final repository = ref.watch(limsRepositoryProvider);
    final activeBranch = ref.watch(activeBranchProvider);
    // The loan book only finances handsets; a cash sale may sell anything in
    // stock. Asking for the phone-only list in cash mode is why a power bank
    // could not be sold at the counter.
    final availableHandsets = repository.getAvailableHandsets(
      ref,
      branch: activeBranch,
      phonesOnly: _selectedTransaction == 'LOAN',
    );

    if (availableHandsets.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFFF4F7FC),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.ink900),
            onPressed: () => context.pop(),
          ),
          title: Text(tr(_locale, 'sell.eyebrow'), style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppTheme.ink900)),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: const BoxDecoration(
                    color: Color(0xFFEFF6FF),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.inventory_2_outlined, color: AppTheme.brand600, size: 40),
                ),
                SizedBox(height: 16),
                Text(
                  tr(_locale, 'sell.noStock'),
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.ink900),
                ),
                SizedBox(height: 8),
                Text(
                  'Branch "$activeBranch" currently has 0 available serialized handsets. Please receive stock or transfer units from another branch before initiating checkout.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: AppTheme.ink500),
                ),
                SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => context.push('/receive-stock'),
                  icon: const Icon(Icons.add_box_rounded, size: 18),
                  label: Text(tr(_locale, 'stock.title')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.brand600,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final activePhone = _resolveActivePhone(availableHandsets)!;
    _ensureDepositInitialized(activePhone);

    final loanPrice = activePhone.loanPrice ?? (activePhone.price * 1.20).round();
    final requiresSupervisor = _selectedTransaction == 'LOAN' && loanPrice > 1000000;

    final depositInt = int.tryParse(_depositController.text.replaceAll(',', '')) ?? (loanPrice * 0.25).round();
    final quote = LoanQuote.calculate(
      cashPrice: activePhone.price,
      customLoanPrice: loanPrice,
      downPayment: depositInt,
      tenureWeeks: _installmentWeeks,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          _selectedTransaction == 'LOAN' ? tr(_locale, 'sell.loanTitle') : tr(_locale, 'sell.cashTitle'),
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppTheme.ink900),
        ),
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.ink900),
          onPressed: () => context.pop(),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: Row(
              children: [
                const Icon(Icons.storefront_rounded, color: AppTheme.brand600, size: 15),
                const SizedBox(width: 5),
                Text(
                  activeBranch,
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppTheme.brand600),
                ),
              ],
            ),
          ),
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
              _buildHandsetSelector(activePhone, availableHandsets),
              const SizedBox(height: 16),

              // Transaction Mode Switcher (Sell vs Loan)
              _buildTransactionType(l10n),
              const SizedBox(height: 18),

              if (_selectedTransaction == 'SELL') ...[
                _buildCashSaleForm(activePhone),
              ] else ...[
                // Loan Form: KYC, Guarantor, Financials, Terms & Agreement
                _buildBorrowerKycSection(),
                const SizedBox(height: 18),
                _buildGuarantorSection(),
                const SizedBox(height: 18),
                _buildLoanFinancialScheduleSection(activePhone, quote),
                const SizedBox(height: 18),
                _buildContractAndAgreementSection(),

                if (requiresSupervisor) ...[
                  const SizedBox(height: 18),
                  _buildSupervisorApprovalCard(),
                ],
              ],

              const SizedBox(height: 28),
              _buildConfirmButton(context, activePhone, quote, requiresSupervisor),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------- Handset Selector
  Widget _buildHandsetSelector(ProductItem phone, List<ProductItem> allAvailable) {
    final loanPrice = phone.loanPrice ?? (phone.price * 1.20).round();
    final primaryImei = phone.imei1 ?? phone.sku;

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
              Text(
                tr(_locale, 'sell.selectedHandset'),
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppTheme.ink500),
              ),
              InkWell(
                onTap: () => _showHandsetPickerSheet(allAvailable),
                child: Row(
                  children: [
                    Text(
                      tr(_locale, 'sell.changePhone'),
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
              // The handset's own picture, so the cashier sees the device they
              // are about to hand over rather than a generic phone glyph.
              _HandsetPhoto(phone: phone),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            phone.name,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.ink900),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE7F8F0),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Stock: ${phone.stock} in branch',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF12B76A)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      phone.variant,
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
                            'IMEI 1: $primaryImei',
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
          Divider(height: 22, color: Color(0xFFF1F5F9)),
          LayoutBuilder(
            builder: (ctx, constraints) {
              final priceStats = [
                (tr(_locale, 'sell.cashPrice'), 'TZS ${_formatNumber(phone.price)}', AppTheme.ink900),
                (tr(_locale, 'sell.financed'), 'TZS ${_formatNumber(loanPrice)}', const Color(0xFF7C5CFC)),
                (tr(_locale, 'sell.minDeposit'), 'TZS ${_formatNumber((loanPrice * 0.25).round())}', const Color(0xFF12B76A)),
              ];
              // Simu nyembamba (<400dp): stats zinapangwa wima — hakuna overflow.
              if (constraints.maxWidth < 400) {
                return Column(
                  children: [
                    for (var i = 0; i < priceStats.length; i++) ...[
                      if (i > 0) const Divider(height: 14, color: Color(0xFFF1F5F9)),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(priceStats[i].$1, style: const TextStyle(fontSize: 11, color: AppTheme.ink500)),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              priceStats[i].$2,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.right,
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: priceStats[i].$3),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                );
              }
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (var i = 0; i < priceStats.length; i++) ...[
                    if (i > 0) Container(width: 1, height: 26, color: const Color(0xFFE2E8F0)),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(priceStats[i].$1, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: AppTheme.ink500)),
                          Text(
                            priceStats[i].$2,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: priceStats[i].$3),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  void _showHandsetPickerSheet(List<ProductItem> availablePhones) {
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
              SizedBox(height: 16),
              Text(
                tr(
                  _locale,
                  _selectedTransaction == 'LOAN'
                      ? 'sell.selectHandset'
                      : 'sell.selectProduct',
                ),
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppTheme.ink900),
              ),
              const SizedBox(height: 14),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: availablePhones.length,
                  itemBuilder: (context, index) {
                    final phone = availablePhones[index];
                    final isSelected = phone.id == _selectedHandsetId || (_selectedHandsetId == null && index == 0);
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
                            color: AppTheme.brand600.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            phone.cat == 'phones'
                                ? Icons.phone_android_rounded
                                : Icons.devices_other_rounded,
                            color: AppTheme.brand600,
                            size: 22,
                          ),
                        ),
                        title: Text(
                          phone.name,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.ink900),
                        ),
                        subtitle: Text(
                          '${phone.variant} · Cash: TZS ${_formatNumber(phone.price)}',
                          style: const TextStyle(fontSize: 11.5, color: AppTheme.ink500),
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle_rounded, color: AppTheme.brand600)
                            : const Icon(Icons.chevron_right_rounded, color: Color(0xFFCBD5E1)),
                        onTap: () {
                          Navigator.pop(ctx);
                          setState(() {
                            _selectedHandsetId = phone.id;
                            final loanPrice = phone.loanPrice ?? (phone.price * 1.20).round();
                            final deposit = (loanPrice * 0.25).round();
                            _depositController.text = _formatNumber(deposit);
                          });
                        },
                      ),
                    );
                  },
                ),
              ),
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
                        'Phone Loan (Financed)',
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
  Widget _buildCashSaleForm(ProductItem phone) {
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
          Text(
            tr(_locale, 'sell.cashSale'),
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.ink900),
          ),
          const SizedBox(height: 4),
          Text(
            tr(_locale, 'sell.cashIntro'),
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
            child: LayoutBuilder(
              builder: (ctx, constraints) {
                final label = Text(
                  tr(_locale, 'sell.amountDue'),
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.ink700),
                );
                final amount = Text(
                  'TZS ${_formatNumber(phone.price)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: constraints.maxWidth < 300 ? TextAlign.left : TextAlign.right,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppTheme.brand600),
                );
                // Simu nyembamba: lebo juu, kiasi chini — hakuna overflow.
                if (constraints.maxWidth < 300) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [label, const SizedBox(height: 4), amount],
                  );
                }
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(child: label),
                    const SizedBox(width: 10),
                    Flexible(child: amount),
                  ],
                );
              },
            ),
          ),
          SizedBox(height: 16),

          Text(tr(_locale, 'sell.paymentChannel'), style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppTheme.ink900)),
          SizedBox(height: 8),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              'cash',
              'mpesa',
              'airtel',
              'tigopesa',
              'card',
            ].map((channel) {
              final isSelected = _cashPaymentChannel == channel;
              return ChoiceChip(
                label: Text(_paymentChannelLabel(channel)),
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
          SizedBox(height: 16),

          TextFormField(
            controller: _receiptPhoneController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: tr(_locale, 'sell.customerPhone'),
              prefixIcon: Icon(Icons.phone_iphone_rounded, size: 20),
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            validator: (v) => (v == null || v.trim().isEmpty) ? tr(_locale, 'sell.errPhone') : null,
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr(_locale, 'sell.step1'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.ink900),
                    ),
                    Text(
                      tr(_locale, 'sell.kycSection'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: AppTheme.ink500),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Counter Passport Photo Capture / Upload Card
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
                Row(
                  children: [
                    Icon(Icons.camera_front_rounded, size: 16, color: Color(0xFF1E60F2)),
                    SizedBox(width: 6),
                    Text(
                      tr(_locale, 'sell.passportPhoto'),
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 96,
                      height: 116,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
                        image: _borrowerPassportBytes != null
                            ? DecorationImage(
                                image: MemoryImage(_borrowerPassportBytes!),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: _borrowerPassportBytes == null
                          ? const Center(child: Icon(Icons.person_rounded, size: 36, color: Color(0xFF94A3B8)))
                          : null,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ElevatedButton.icon(
                                onPressed: () => _pickPassportPhoto(source: ImageSource.camera),
                                icon: const Icon(Icons.camera_alt_rounded, size: 17),
                                label: Text(tr(_locale, 'sell.capturePhoto'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1E60F2),
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(0, 44),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                              OutlinedButton.icon(
                                onPressed: () => _pickPassportPhoto(source: ImageSource.gallery),
                                icon: const Icon(Icons.upload_file_rounded, size: 17),
                                label: Text(tr(_locale, 'sell.upload'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(0, 44),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                _borrowerPassportBytes == null
                                    ? Icons.info_outline_rounded
                                    : Icons.check_circle_rounded,
                                size: 13,
                                color: _borrowerPassportBytes == null
                                    ? const Color(0xFF94A3B8)
                                    : const Color(0xFF10B981),
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  tr(
                                    _locale,
                                    _borrowerPassportBytes == null
                                        ? 'sell.kycMissing'
                                        : 'sell.kycAttached',
                                  ),
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    color: _borrowerPassportBytes == null
                                        ? const Color(0xFF94A3B8)
                                        : const Color(0xFF059669),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
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
          SizedBox(height: 14),

          TextFormField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: tr(_locale, 'sell.customerName'),
              prefixIcon: Icon(Icons.badge_outlined, size: 20),
              border: OutlineInputBorder(),
            ),
            validator: (v) => (v == null || v.trim().isEmpty) ? tr(_locale, 'sell.errName') : null,
          ),
          SizedBox(height: 12),

          TextFormField(
            controller: _nidaController,
            decoration: InputDecoration(
              labelText: tr(_locale, 'sell.nida'),
              prefixIcon: Icon(Icons.fingerprint_rounded, size: 20),
              helperText: tr(_locale, 'sell.nidaHint'),
              border: OutlineInputBorder(),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Please enter NIDA ID number';
              if (v.trim().length < 15) return tr(_locale, 'sell.errNida');
              return null;
            },
          ),
          SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Primary Repayment Phone',
                    prefixIcon: Icon(Icons.phone_rounded, size: 18),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter primary phone' : null,
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: _altPhoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Alternative Contact Phone',
                    prefixIcon: Icon(Icons.chat_bubble_outline_rounded, size: 18),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),

          TextFormField(
            controller: _residenceController,
            decoration: InputDecoration(
              labelText: tr(_locale, 'sell.address'),
              prefixIcon: Icon(Icons.location_on_outlined, size: 20),
              border: OutlineInputBorder(),
            ),
            validator: (v) => (v == null || v.trim().isEmpty) ? tr(_locale, 'sell.errAddress') : null,
          ),
          const SizedBox(height: 12),

          TextFormField(
            controller: _occupationController,
            decoration: const InputDecoration(
              labelText: 'Business Stand / Employer / Income Source',
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
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr(_locale, 'sell.step2'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.ink900),
                    ),
                    Text(
                      'Required guarantor contact for debt follow-up if payment is overdue',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: AppTheme.ink500),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextFormField(
                  controller: _guarantorNameController,
                  decoration: InputDecoration(
                    labelText: tr(_locale, 'sell.guarantorName'),
                    prefixIcon: Icon(Icons.person_outline_rounded, size: 18),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter guarantor name' : null,
                ),
              ),
              SizedBox(width: 10),
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
          SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _guarantorPhoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: tr(_locale, 'sell.guarantorPhone'),
                    prefixIcon: Icon(Icons.phone_android_rounded, size: 18),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter guarantor phone' : null,
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: _guarantorNidaController,
                  decoration: InputDecoration(
                    labelText: tr(_locale, 'sell.guarantorNida'),
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
  Widget _buildLoanFinancialScheduleSection(ProductItem phone, LoanQuote quote) {
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr(_locale, 'sell.step3'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.ink900),
                    ),
                    Text(
                      'Itemized pricing, down payment, and installment calendar',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: AppTheme.ink500),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Transparent pricing summary banner
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                _buildFinancialRow(tr(_locale, 'sell.cashPrice'), 'TZS ${_formatNumber(quote.cashPrice)}'),
                SizedBox(height: 6),
                _buildFinancialRow(tr(_locale, 'sell.financeFeePct'), '+ TZS ${_formatNumber(quote.financeFee)}', isPositive: true),
                Divider(height: 16, color: Color(0xFFE2E8F0)),
                _buildFinancialRow(tr(_locale, 'sell.repayable'), 'TZS ${_formatNumber(quote.loanPrice)}', isBold: true, highlightColor: const Color(0xFF7C5CFC)),
                SizedBox(height: 6),
                _buildFinancialRow(tr(_locale, 'sell.minRequired'), 'TZS ${_formatNumber(quote.minimumDeposit)}', isSecondary: true),
              ],
            ),
          ),
          SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _depositController,
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: tr(_locale, 'sell.deposit'),
                    prefixText: 'TZS ',
                    helperText: 'Min 25%: TZS ${_formatNumber(quote.minimumDeposit)}',
                    border: const OutlineInputBorder(),
                  ),
                  validator: (v) {
                    final entered = int.tryParse((v ?? '').replaceAll(',', '')) ?? 0;
                    if (entered < quote.minimumDeposit) {
                      return trf(_locale, 'sell.mustBeAtLeast', {
                        'n': _formatNumber(quote.minimumDeposit),
                      });
                    }
                    if (entered >= quote.loanPrice) {
                      return tr(_locale, 'sell.errDeposit');
                    }
                    return null;
                  },
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: _installmentWeeks,
                  decoration: InputDecoration(
                    labelText: tr(_locale, 'sell.term'),
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 4, child: Text('4 Weeks (1 Month)')),
                    DropdownMenuItem(value: 8, child: Text('8 Weeks (2 Months)')),
                    DropdownMenuItem(value: 12, child: Text('12 Weeks (3 Months)')),
                    DropdownMenuItem(value: 16, child: Text('16 Weeks (4 Months)')),
                    DropdownMenuItem(value: 24, child: Text('24 Weeks (6 Months)')),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      setState(() => _installmentWeeks = v);
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Rejesho Highlight Box
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F3FF),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFDDD6FE)),
            ),
            child: LayoutBuilder(
              builder: (ctx, constraints) {
                final amount = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tr(_locale, 'sell.weekly'), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: Color(0xFF6D28D9), fontWeight: FontWeight.w600)),
                    Text(
                      trf(_locale, 'sell.perWeek', {
                        'n': _formatNumber(quote.weeklyInstallment),
                      }),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF6D28D9)),
                    ),
                  ],
                );
                final toggle = TextButton.icon(
                  onPressed: () => setState(() => _showSchedulePreview = !_showSchedulePreview),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: Icon(_showSchedulePreview ? Icons.expand_less_rounded : Icons.calendar_month_rounded, size: 16, color: const Color(0xFF6D28D9)),
                  label: Text(
                    _showSchedulePreview
                        ? tr(_locale, 'sell.hideSchedule')
                        : trf(_locale, 'sell.viewSchedule', {'n': quote.schedule.length}),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF6D28D9)),
                  ),
                );
                // Simu nyembamba: amount juu, toggle chini — hakuna overflow.
                if (constraints.maxWidth < 340) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [amount, const SizedBox(height: 6), toggle],
                  );
                }
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: amount),
                    const SizedBox(width: 8),
                    Flexible(child: toggle),
                  ],
                );
              },
            ),
          ),

          if (_showSchedulePreview) ...[
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr(_locale, 'sell.schedule'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppTheme.ink900)),
                  const SizedBox(height: 8),
                  ...quote.schedule.map((item) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'Week ${item.installmentNumber} · Due: ${item.formattedDueDate}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12, color: AppTheme.ink700),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'TZS ${_formatNumber(item.amount)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.right,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.ink900),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFinancialRow(String title, String value, {bool isPositive = false, bool isBold = false, bool isSecondary = false, Color? highlightColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: isSecondary ? 11.5 : 12.5,
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w500,
              color: isSecondary ? AppTheme.ink500 : AppTheme.ink700,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: isBold ? 14.5 : 12.5,
              fontWeight: isBold ? FontWeight.w900 : FontWeight.w700,
              color: highlightColor ?? (isPositive ? const Color(0xFF10B981) : AppTheme.ink900),
            ),
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------- Contract & Legal Agreement Section
  Widget _buildContractAndAgreementSection() {
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
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.gavel_rounded, color: AppTheme.brand600, size: 18),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr(_locale, 'sell.step4'),
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.ink900),
                  ),
                  Text(
                    'Legal hire-purchase declaration and customer debt commitment',
                    style: TextStyle(fontSize: 11, color: AppTheme.ink500),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Legal Terms Box
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr(_locale, 'sell.agreementTitle'),
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppTheme.ink900),
                ),
                SizedBox(height: 4),
                Text(
                  '• Customer retains possession of the serialized handset while title remains with dealership until full loan liquidation.\n• Installments are payable weekly via official store Till or at cashier counter.\n• A 3-day grace period is granted before formal arrears follow-up is initiated with borrower and verified guarantor.',
                  style: TextStyle(fontSize: 11.5, color: AppTheme.ink600, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          CheckboxListTile(
            value: _contractSigned,
            onChanged: (v) => setState(() => _contractSigned = v ?? false),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            activeColor: const Color(0xFF7C5CFC),
            title: Text(
              tr(_locale, 'sell.contractTitle'),
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.ink900),
            ),
            subtitle: const Text(
              'Customer has signed the hardcopy credit agreement filed in store archives.',
              style: TextStyle(fontSize: 11, color: AppTheme.ink500),
            ),
          ),

          CheckboxListTile(
            value: _borrowerConsentAgreed,
            onChanged: (v) => setState(() => _borrowerConsentAgreed = v ?? false),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            activeColor: const Color(0xFF7C5CFC),
            title: Text(
              tr(_locale, 'sell.pdpa'),
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.ink900),
            ),
            subtitle: const Text(
              'Borrower consents to SMS payment reminders and lawful follow-up with the designated guarantor.',
              style: TextStyle(fontSize: 11, color: AppTheme.ink500),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------- Supervisor Approval Card
  Widget _buildSupervisorApprovalCard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.shield_outlined, color: Color(0xFFD97706), size: 20),
              SizedBox(width: 8),
              Text(
                tr(_locale, 'sell.supervisorTitle'),
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Color(0xFF92400E)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'High-value financing (> TZS 1,000,000) mandates supervisor authorization PIN before disbursement.',
            style: TextStyle(fontSize: 11.5, color: Color(0xFFB45309)),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _supervisorPinController,
            obscureText: true,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: tr(_locale, 'sell.supervisorPin'),
              prefixIcon: Icon(Icons.lock_outline_rounded, size: 18),
              border: OutlineInputBorder(),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------- Confirm Button
  Widget _buildConfirmButton(BuildContext context, ProductItem phone, LoanQuote quote, bool requiresSupervisor) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _isProcessing || _submitGuard.isInFlight
            ? null
            : () {
                if (!_formKey.currentState!.validate()) {
                  LimsToast.show(context, tr(_locale, 'sell.errResolve'), isError: true);
                  return;
                }

                if (_selectedTransaction == 'LOAN') {
                  if (!_contractSigned || !_borrowerConsentAgreed) {
                    LimsToast.show(context, 'Please confirm contract signature and customer consent.', isError: true);
                    return;
                  }

                  if (requiresSupervisor && (_supervisorPin.isEmpty || _supervisorPinController.text.trim() != _supervisorPin)) {
                    LimsToast.show(
                      context,
                      _supervisorPin.isEmpty
                          ? 'High-value loans need supervisor approval, which is not configured. Contact your administrator.'
                          : 'Supervisor PIN required for loans > 1M.',
                      isError: true,
                    );
                    return;
                  }
                }

                _showOrderReviewDialog(context, phone, quote);
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
                    ? 'Review Loan · TZS ${_formatNumber(quote.downPayment)} Deposit'
                    : 'Review Cash Sale · TZS ${_formatNumber(phone.price)}',
                style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800),
              ),
      ),
    );
  }

  // ------------------------------------------------------------- Order Review Dialog
  void _showOrderReviewDialog(BuildContext context, ProductItem phone, LoanQuote quote) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          ),
          padding: EdgeInsets.fromLTRB(22, 16, 22, MediaQuery.of(context).viewInsets.bottom + 28),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.92,
            ),
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      _selectedTransaction == 'LOAN' ? tr(_locale, 'sell.reviewDisbursement') : tr(_locale, 'sell.reviewCashTitle'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppTheme.ink900),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _selectedTransaction == 'LOAN' ? const Color(0xFFF5F3FF) : const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _selectedTransaction == 'LOAN' ? tr(_locale, 'sell.creditSale') : tr(_locale, 'sell.cashSale'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: _selectedTransaction == 'LOAN' ? const Color(0xFF7C5CFC) : const Color(0xFF059669),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Handset and IMEI confirmation
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    _buildFinancialRow('Handset Model', phone.name, isBold: true),
                    SizedBox(height: 4),
                    _buildFinancialRow(tr(_locale, 'sell.imei1'), phone.imei1 ?? phone.sku),
                    if (_selectedTransaction == 'LOAN') ...[
                      Divider(height: 14, color: Color(0xFFE2E8F0)),
                      _buildFinancialRow('Borrower Full Name', _nameController.text.trim()),
                      SizedBox(height: 4),
                      _buildFinancialRow('Borrower NIDA ID', _nidaController.text.trim()),
                      SizedBox(height: 4),
                      _buildFinancialRow(tr(_locale, 'sell.guarantor'), '${_guarantorNameController.text.trim()} (${_guarantorPhoneController.text.trim()})'),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Financial settlement summary
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _selectedTransaction == 'LOAN' ? const Color(0xFFF5F3FF) : const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _selectedTransaction == 'LOAN' ? const Color(0xFFDDD6FE) : const Color(0xFFBBF7D0)),
                ),
                child: Column(
                  children: [
                    if (_selectedTransaction == 'LOAN') ...[
                      _buildFinancialRow(tr(_locale, 'sell.totalFinanced'), 'TZS ${_formatNumber(quote.loanPrice)}'),
                      SizedBox(height: 4),
                      _buildFinancialRow(tr(_locale, 'sell.initialDeposit'), 'TZS ${_formatNumber(quote.downPayment)}', isBold: true, highlightColor: const Color(0xFF10B981)),
                      SizedBox(height: 4),
                      _buildFinancialRow(tr(_locale, 'sell.remainingPrincipal'), 'TZS ${_formatNumber(quote.financedAmount)}'),
                      SizedBox(height: 4),
                      _buildFinancialRow(
                        trf(_locale, 'sell.weeklyRepayment', {'n': quote.tenureWeeks}),
                        trf(_locale, 'sell.perWeek', {'n': _formatNumber(quote.weeklyInstallment)}),
                        isBold: true,
                        highlightColor: const Color(0xFF7C5CFC),
                      ),
                    ] else ...[
                      _buildFinancialRow(tr(_locale, 'sell.paymentChannel'), _paymentChannelLabel(_cashPaymentChannel)),
                      SizedBox(height: 4),
                      _buildFinancialRow(tr(_locale, 'sell.customerContact'), _receiptPhoneController.text.trim()),
                      const Divider(height: 12, color: Color(0xFFBBF7D0)),
                      _buildFinancialRow(tr(_locale, 'sell.totalCollected'), 'TZS ${_formatNumber(phone.price)}', isBold: true, highlightColor: const Color(0xFF059669)),
                    ],
                  ],
                ),
              ),
              SizedBox(height: 18),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isProcessing
                      ? null
                      : () async {
                          Navigator.pop(ctx);
                          await _executeTransaction(phone, quote);
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _selectedTransaction == 'LOAN' ? const Color(0xFF7C5CFC) : AppTheme.brand600,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(
                    tr(_locale, 'sell.confirmHandover'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ------------------------------------------------------------- Execute Transaction
  Future<void> _executeTransaction(ProductItem phone, LoanQuote quote) async {
    // The review sheet closes itself before this runs, so for a moment the only
    // thing under the finger is the primary button again. A spinner is one
    // rebuild away and cannot win that race; this latch refuses the second
    // submission outright.
    if (!_submitGuard.tryBegin()) return;
    setState(() => _isProcessing = true);
    final repository = ref.read(limsRepositoryProvider);

    POSSaleResult? result;
    Object? failure;
    try {
      if (_selectedTransaction == 'LOAN') {
        result = await repository.executeLoanDisbursement(
          ref: ref,
          phone: phone,
          customerName: _nameController.text.trim(),
          customerPhone: _phoneController.text.trim(),
          customerNida: _nidaController.text.trim(),
          residence: _residenceController.text.trim(),
          guarantorName: _guarantorNameController.text.trim(),
          guarantorPhone: _guarantorPhoneController.text.trim(),
          quote: quote,
          paymentChannel: tr(_locale, 'sell.drawerChannel'),
        );
      } else {
        result = await repository.executeCashSale(
          ref: ref,
          phone: phone,
          customerName: 'Cash Customer (${_receiptPhoneController.text.trim()})',
          customerPhone: _receiptPhoneController.text.trim(),
          paymentChannel: _cashPaymentChannel,
        );
      }
    } catch (e) {
      // A throw here is not a completed sale. It must not reach the success
      // dialog or the printer.
      failure = e;
    } finally {
      _submitGuard.release();
    }

    if (!mounted) return;
    setState(() => _isProcessing = false);

    if (result == null) {
      LimsToast.show(
        context,
        trf(_locale, 'sell.saveFailed', {'reason': '${failure ?? 'unknown error'}'}),
        isError: true,
        duration: const Duration(seconds: 8),
      );
      return;
    }

    if (result.success) {
      _showSuccessDialog(result);
    } else {
      _showSaleFailure(result);
    }
  }

  /// The counter is told what happened, not what we hoped happened.
  void _showSaleFailure(POSSaleResult result) {
    final message = result.isUnconfirmed
        ? trf(_locale, 'sell.saveUnconfirmed', {'n': result.receiptId})
        : trf(_locale, 'sell.saveFailed', {
            'reason': result.errorMessage ?? tr(_locale, 'sell.saveUnknownReason'),
          });
    LimsToast.show(
      context,
      message,
      isError: true,
      duration: const Duration(seconds: 10),
    );
  }

  /// The loan this sale created, or null when the book does not hold it.
  LoanItem? _findLoanFor(POSSaleResult result) {
    for (final loan in ref.read(loansProvider)) {
      if (loan.name == result.customerName && loan.item == result.phoneModel) {
        return loan;
      }
    }
    return null;
  }

  /// Opens the receipt for printing, then closes the dialog and the till.
  ///
  /// The button used to promise an SMS and print nothing. It now generates the
  /// roll-80 receipt for the sale that just completed, and the message describes
  /// only what actually happened.
  Future<void> _printReceipt(POSSaleResult result, BuildContext dialogContext) async {
    // A receipt is a claim that the shop holds a record of this sale, so the
    // gate is `isSaved` — a confirmed row in `public.sales` — not `success`.
    // `success` also covers a demo build with no database, where the counter
    // may finish the sale locally but has nothing to point a customer at.
    if (!result.isSaved) return;
    final dialogNavigator = Navigator.of(dialogContext, rootNavigator: true);
    final issued = await PdfReportService.generateAndDownloadSaleReceipt(
      lang: _locale.languageCode == 'sw' ? PdfLang.sw : PdfLang.en,
      sale: result,
      branchName: ref.read(activeBranchProvider),
      servedBy: ref.read(activeStaffMemberProvider).name,
    );
    if (!mounted || !issued) return;
    dialogNavigator.pop();
    LimsToast.show(
      context,
      'Risiti ${result.receiptId} imefunguliwa — tayari kwa print.',
      isSuccess: true,
    );
    context.pop();
  }

  // ------------------------------------------------------------- Success Dialog
  void _showSuccessDialog(POSSaleResult result) {
    // The dossier button used to fall back to `loans.first`, which threw a
    // StateError on an empty book and could have opened a stranger's file. If
    // the borrower cannot be found, the button is simply not offered.
    final loan = result.transactionType == 'LOAN' ? _findLoanFor(result) : null;

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
            SizedBox(height: 16),
            Text(
              result.transactionType == 'LOAN' ? tr(_locale, 'sell.loanDone') : tr(_locale, 'sell.cashDone'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.ink900),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              result.transactionType == 'LOAN'
                  ? 'Handset registered to ${result.customerName}.\nDown payment of TZS ${_formatNumber(result.amountPaid)} received in drawer.'
                  : 'Payment of TZS ${_formatNumber(result.totalAmount)} via ${result.paymentChannel} completed.',
              style: const TextStyle(fontSize: 12.5, color: AppTheme.ink500),
              textAlign: TextAlign.center,
            ),
            if (!result.isSaved) ...[
              const SizedBox(height: 10),
              Text(
                tr(_locale, 'sell.demoNote'),
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.ink500),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  Text(
                    'Receipt ID: ${result.receiptId}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppTheme.ink900),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Handset IMEI: ${result.primaryImei}',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.ink600),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),
            if (loan != null) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BorrowerLoanDetailsScreen(loanId: loan.id, initialLoan: loan),
                      ),
                    );
                  },
                  icon: const Icon(Icons.badge_rounded, size: 18),
                  label: Text(tr(_locale, 'loans.viewDossier'), style: TextStyle(fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7C5CFC),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              SizedBox(height: 8),
            ],
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      context.pop();
                    },
                    icon: const Icon(Icons.arrow_back_rounded, size: 16),
                    label: Text(tr(_locale, 'sell.backHome')),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  // Nothing was stored in a demo build, so there is nothing to
                  // print: the button is offered but dead rather than absent,
                  // so the cashier can see the option exists and why it does
                  // not apply (the note above the receipt block says it).
                  child: ElevatedButton.icon(
                    onPressed: result.isSaved ? () => _printReceipt(result, ctx) : null,
                    icon: const Icon(Icons.receipt_long_rounded, size: 16),
                    label: Text(tr(_locale, 'sell.printReceipt')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.brand600,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}


/// The handset picture on the checkout card.
class _HandsetPhoto extends StatelessWidget {
  const _HandsetPhoto({required this.phone});

  final ProductItem phone;

  @override
  Widget build(BuildContext context) {
    final asset = ProductArt.resolve(
      explicit: phone.imageAsset,
      brand: phone.brand,
      name: phone.name,
      category: phone.cat,
    );
    final url = phone.imageUrl;

    Widget fallback = Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: phone.grad.isNotEmpty
              ? phone.grad
              : [AppTheme.brand600, const Color(0xFF7C5CFC)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Icon(Icons.phone_android_rounded,
          color: Colors.white, size: 28),
    );

    return Container(
      width: 76,
      height: 88,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      clipBehavior: Clip.antiAlias,
      child: url != null && url.isNotEmpty
          ? Image.network(
              url,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Image.asset(
                asset,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => fallback,
              ),
            )
          : Image.asset(
              asset,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => fallback,
            ),
    );
  }
}
