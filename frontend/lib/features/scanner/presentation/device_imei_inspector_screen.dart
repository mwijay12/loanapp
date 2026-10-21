import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/inventory_provider.dart';
import '../../../core/data/mock_lims_data.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../../core/l10n/strings.dart';
import '../../../core/data/product_art.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../loans/presentation/borrower_loan_details_screen.dart';

class DeviceImeiInspectorScreen extends ConsumerStatefulWidget {
  final String? initialImei;

  const DeviceImeiInspectorScreen({super.key, this.initialImei});

  @override
  ConsumerState<DeviceImeiInspectorScreen> createState() => _DeviceImeiInspectorScreenState();
}

class _DeviceImeiInspectorScreenState extends ConsumerState<DeviceImeiInspectorScreen> {
  Locale get _locale => ref.read(localeProvider);
  final TextEditingController _imeiController = TextEditingController();
  bool _isSearching = false;
  bool _hasSearched = false;

  // Inspected device data
  String _model = 'iPhone 15 Pro Max';
  String? _matchedArt;
  String _variant = '256GB · Natural Titanium';
  String _imei = '354928104829104';
  final String _serialNumber = 'F2LW9012MD67';
  String _status = 'ON_LOAN'; // 'ON_LOAN', 'CASH_SOLD', 'IN_STOCK', 'OVERDUE'
  String _borrowerName = 'Bakari Juma Mwambungu';
  String _borrowerPhone = '0754 892 314';
  String _borrowerNida = '19920415-14120-00002-18';
  int _totalLoanAmount = 4450000;
  final int _depositPaid = 1112500;
  int _remainingBalance = 2450000;
  String _nextDueDate = 'Ijumaa, 10 Oktoba 2026';
  int _warrantyDaysLeft = 248;
  final String _branch = 'Kariakoo Main Hub';
  String? _loanId = 'LIMS-LN-4891';

  @override
  void initState() {
    super.initState();
    if (widget.initialImei != null && widget.initialImei!.isNotEmpty) {
      _imeiController.text = widget.initialImei!;
      _performSearch(widget.initialImei!);
    } else {
      _imeiController.text = '354928104829104';
      _performSearch('354928104829104');
    }
  }

  @override
  void dispose() {
    _imeiController.dispose();
    super.dispose();
  }

  void _performSearch(String query) async {
    final cleanQuery = query.replaceAll(RegExp(r'\s+'), '').trim();
    if (cleanQuery.isEmpty) return;

    setState(() {
      _isSearching = true;
      _hasSearched = true;
    });

    await Future.delayed(const Duration(milliseconds: 400));

    // Match with current loans in Riverpod
    final loans = ref.read(loansProvider);
    LoanItem? matchedLoan;
    for (final l in loans) {
      if (l.imei.contains(cleanQuery) || cleanQuery.contains(l.imei) || l.id.toLowerCase().contains(cleanQuery.toLowerCase())) {
        matchedLoan = l;
        break;
      }
    }

    if (matchedLoan != null) {
      setState(() {
        _isSearching = false;
        _model = matchedLoan!.item;
        _imei = matchedLoan.imei;
        _variant = '256GB Dual SIM (Nano + eSIM)';
        _status = matchedLoan.status == 'overdue' ? 'OVERDUE' : 'ON_LOAN';
        _borrowerName = matchedLoan.name;
        _borrowerPhone = matchedLoan.phone;
        _borrowerNida = matchedLoan.nida;
        _totalLoanAmount = matchedLoan.amount;
        _remainingBalance = (matchedLoan.amount * (1 - (matchedLoan.paid / 100))).round();
        _nextDueDate = matchedLoan.due;
        _warrantyDaysLeft = 210;
        _loanId = matchedLoan.id;
      });
      return;
    }

    // Match with inventory
    final inventory = ref.read(inventoryProvider);
    ProductItem? matchedProduct;
    for (final p in inventory) {
      if ((p.imei1 != null && p.imei1!.contains(cleanQuery)) ||
          (p.sku.toLowerCase().contains(cleanQuery.toLowerCase())) ||
          (p.name.toLowerCase().contains(cleanQuery.toLowerCase()))) {
        matchedProduct = p;
        break;
      }
    }

    setState(() {
      _isSearching = false;
      if (matchedProduct != null) {
        _model = matchedProduct.name;
        _matchedArt = ProductArt.resolve(
          explicit: matchedProduct.imageAsset,
          brand: matchedProduct.brand,
          name: matchedProduct.name,
          category: matchedProduct.cat,
        );
        _variant = matchedProduct.variant;
        _imei = matchedProduct.imei1 ?? cleanQuery;
        _status = 'IN_STOCK';
        _borrowerName = '-';
        _borrowerPhone = '-';
        _borrowerNida = '-';
        _totalLoanAmount = matchedProduct.loanPrice ?? (matchedProduct.price * 1.2).round();
        _remainingBalance = 0;
        _nextDueDate = tr(_locale, 'insp.notFinanced');
        _warrantyDaysLeft = 365;
        _loanId = null;
      } else {
        // Fallback default lookup
        _imei = cleanQuery;
        if (cleanQuery.startsWith('86')) {
          _model = 'Redmi Note 13 Pro';
          _variant = '256GB / 8GB · Midnight Black';
          _status = 'OVERDUE';
          _borrowerName = 'Selemani Rashidi';
          _borrowerPhone = '0784 112 900';
          _remainingBalance = 380000;
          _nextDueDate = 'Imechelewa kwa siku 12';
          _warrantyDaysLeft = 145;
          _loanId = 'LIMS-LN-3104';
        } else {
          _model = 'Samsung Galaxy S24 Ultra';
          _variant = '256GB · Titanium Gray';
          _status = 'ON_LOAN';
          _borrowerName = 'Zawadi Hassan';
          _borrowerPhone = '0655 490 211';
          _remainingBalance = 1680000;
          _nextDueDate = 'Jumatano, 14 Oktoba 2026';
          _warrantyDaysLeft = 290;
          _loanId = 'LIMS-LN-5092';
        }
      }
    });
  }

  void _sendPaymentReminderSms() {
    LimsToast.show(
      context,
      'SMS ya kukumbusha rejesho la TZS ${LimsFormatters.formatNumber(_remainingBalance > 50000 ? 50000 : _remainingBalance)} imetumwa kwa $_borrowerName ($_borrowerPhone)',
      isSuccess: true,
    );
  }

  void _openBorrowerDossier() {
    if (_loanId != null) {
      final loans = ref.read(loansProvider);
      final matchedLoan = loans.firstWhere((l) => l.id == _loanId, orElse: () => loans.first);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (ctx) => BorrowerLoanDetailsScreen(loanId: _loanId!, initialLoan: matchedLoan),
        ),
      );
    } else {
      LimsToast.show(context, 'Hakuna mkopo unaoendelea kwenye kifaa hiki.');
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(localeProvider);
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.ink900),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Hardware Verification & IMEI Inspector',
          style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, color: AppTheme.ink900),
        ),
        actions: [
          IconButton(
            tooltip: 'Skani barcode / IMEI',
            icon: const Icon(Icons.qr_code_scanner_rounded, color: AppTheme.brand600),
            // This used to pick a sample IMEI by the second hand and announce it
            // as a scan. It now opens the camera, and the inspector opens without
            // a serial rather than guessing one.
            onPressed: () => context.push('/scanner'),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFE2E8F0), height: 1),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search Bar & Scanner Input
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: const [
                  BoxShadow(color: Color(0x0A0F3478), blurRadius: 14, offset: Offset(0, 3)),
                ],
              ),
              padding: const EdgeInsets.all(6),
              child: Row(
                children: [
                  const SizedBox(width: 10),
                  const Icon(Icons.search_rounded, color: AppTheme.ink500, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _imeiController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.ink900),
                      decoration: InputDecoration(
                        hintText: tr(_locale, 'insp.imeiHint'),
                        hintStyle: TextStyle(fontSize: 13, color: AppTheme.ink400, fontWeight: FontWeight.normal),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 10),
                      ),
                      onSubmitted: _performSearch,
                    ),
                  ),
                  if (_imeiController.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18, color: AppTheme.ink400),
                      onPressed: () {
                        _imeiController.clear();
                        setState(() {});
                      },
                    ),
                  ElevatedButton(
                    onPressed: () => _performSearch(_imeiController.text),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.brand600,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isSearching
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Kagua', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Quick Samples Chips
            Row(
              children: [
                const Text('Mifano:', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppTheme.ink500)),
                const SizedBox(width: 8),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildQuickImeiChip('354928104829104', 'iPhone 15 Pro (Mkopo)'),
                        const SizedBox(width: 6),
                        _buildQuickImeiChip('864920042819384', 'Redmi (Overdue Loan)'),
                        const SizedBox(width: 6),
                        _buildQuickImeiChip('358920112849102', 'Galaxy A15 (Stoo)'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            if (_hasSearched) ...[
              // Handset Overview Card
              _buildHandsetCard(),
              const SizedBox(height: 16),

              // Debt Follow-Up Action Card
              if (_status != 'IN_STOCK') ...[
                _buildDebtFollowUpActionCard(),
                const SizedBox(height: 16),
              ],

              // Ownership & Loan Balance Card (if applicable)
              if (_status != 'IN_STOCK') ...[
                _buildOwnershipAndCreditCard(),
                const SizedBox(height: 16),
              ],

              // Warranty & Hardware Diagnostics
              _buildWarrantyCard(),
              const SizedBox(height: 16),

              // Device Timeline & Audit Log
              _buildDeviceTimelineCard(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQuickImeiChip(String imei, String label) {
    return InkWell(
      onTap: () {
        _imeiController.text = imei;
        _performSearch(imei);
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.brand600),
        ),
      ),
    );
  }

  Widget _buildHandsetCard() {
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
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: _matchedArt == null
                      ? const Icon(Icons.phone_android_rounded,
                          color: AppTheme.brand600, size: 32)
                      : Image.asset(
                          _matchedArt!,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(
                              Icons.phone_android_rounded,
                              color: AppTheme.brand600,
                              size: 32),
                        ),
                ),
              ),
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
                            _model,
                            maxLines: 1,
                            style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, color: AppTheme.ink900),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(child: _buildStatusBadge()),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _variant,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: AppTheme.ink500, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Text(
                              'IMEI: $_imei',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.ink900),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.verified_rounded, size: 14, color: AppTheme.brand600),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 24, color: Color(0xFFF1F5F9)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildParamItem('Serial No.', _serialNumber),
              _buildParamItem(tr(_locale, 'insp.branch'), _branch),
              _buildParamItem('Thamani ya Mkopo', 'TZS ${LimsFormatters.formatNumber(_totalLoanAmount)}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge() {
    Color bg;
    Color text;
    String label;

    switch (_status) {
      case 'IN_STOCK':
        bg = const Color(0xFFE7F8F0);
        text = const Color(0xFF12B76A);
        label = tr(_locale, 'insp.inStock');
        break;
      case 'OVERDUE':
        bg = const Color(0xFFFFEDF1);
        text = AppTheme.errorColor;
        label = tr(_locale, 'insp.overdue');
        break;
      default:
        bg = const Color(0xFFE9F2FE);
        text = AppTheme.brand600;
        label = tr(_locale, 'insp.onLoan');
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: text),
      ),
    );
  }

  Widget _buildParamItem(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, color: AppTheme.ink500),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppTheme.ink900),
          ),
        ],
      ),
    );
  }

  Widget _buildDebtFollowUpActionCard() {
    final isOverdue = _status == 'OVERDUE';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: isOverdue ? const Color(0xFFFECDD3) : const Color(0xFFE2E8F0)),
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
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isOverdue ? const Color(0xFFFFEDF1) : const Color(0xFFE9F2FE),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isOverdue ? Icons.warning_amber_rounded : Icons.verified_user_rounded,
                        color: isOverdue ? AppTheme.errorColor : AppTheme.brand600,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Hire-Purchase Recovery & Actions',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: AppTheme.ink900),
                          ),
                          Text(
                            isOverdue ? tr(_locale, 'insp.overdueLine') : tr(_locale, 'insp.currentLine'),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11.5, color: isOverdue ? AppTheme.errorColor : AppTheme.ink500, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isOverdue ? const Color(0xFFFFEDF1) : const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isOverdue ? 'Overdue' : 'Active',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: isOverdue ? AppTheme.errorColor : const Color(0xFF027A48),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isOverdue ? const Color(0xFFFFF1F2) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isOverdue ? const Color(0xFFFFCCD5) : const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Icon(
                  isOverdue ? Icons.info_rounded : Icons.verified_rounded,
                  size: 18,
                  color: isOverdue ? AppTheme.errorColor : AppTheme.brand600,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isOverdue
                        ? trf(_locale, 'insp.overdueBody', {'n': _borrowerName})
                        : trf(_locale, 'insp.currentBody', {'d': _nextDueDate}),
                    style: TextStyle(fontSize: 11.5, color: isOverdue ? AppTheme.errorColor : AppTheme.ink700, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _sendPaymentReminderSms,
                  icon: const Icon(Icons.sms_outlined, size: 16),
                  label: const Text('Tuma SMS ya Rejesho', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.brand600,
                    side: const BorderSide(color: Color(0xFFCEE1FE)),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _openBorrowerDossier,
                  icon: const Icon(Icons.folder_shared_rounded, size: 16),
                  label: const Text('Jalada la Mkopaji', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.brand600,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOwnershipAndCreditCard() {
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
              Expanded(
                child: Text(
                  tr(_locale, 'insp.loanSection'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.ink900),
                ),
              ),
              if (_loanId != null)
                InkWell(
                  onTap: () {
                    final loans = ref.read(loansProvider);
                    final l = loans.firstWhere((x) => x.id == _loanId, orElse: () => loans.first);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BorrowerLoanDetailsScreen(loanId: l.id, initialLoan: l),
                      ),
                    );
                  },
                  child: const Row(
                    children: [
                      Text('Faili Kamili', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.brand600)),
                      Icon(Icons.chevron_right_rounded, size: 16, color: AppTheme.brand600),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [AppTheme.brand600, Color(0xFF7C5CFC)]),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    _borrowerName.isNotEmpty ? _borrowerName.substring(0, 1) : 'M',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _borrowerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.ink900),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Simu: $_borrowerPhone · NIDA: $_borrowerNida',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11.5, color: AppTheme.ink500),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 24, color: Color(0xFFF1F5F9)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Salio Lililobaki', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: AppTheme.ink500)),
                    const SizedBox(height: 2),
                    Text(
                      'TZS ${LimsFormatters.formatNumber(_remainingBalance)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppTheme.brand600),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Tarehe ya Rejesho', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: AppTheme.ink500)),
                    const SizedBox(height: 2),
                    Text(
                      _nextDueDate,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppTheme.ink900),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                context.push('/sell-loan?type=LOAN&model=$_model&imei=$_imei');
              },
              icon: const Icon(Icons.payments_rounded, size: 18),
              label: const Text('Pokea Rejesho (Record Payment)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
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
    );
  }

  Widget _buildWarrantyCard() {
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
              const Expanded(
                child: Text(
                  'Hali ya Waranti (Warranty)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.ink900),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: const Color(0xFFE7F8F0), borderRadius: BorderRadius.circular(8)),
                  child: Text(
                    'Siku $_warrantyDaysLeft zimebaki',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF12B76A)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text('Inajumuisha: Kioo cha Asili, Motherboard & Ufundi wa Mfumo chini ya LIMS Care Guarantee.', style: TextStyle(fontSize: 12, color: AppTheme.ink600)),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (_warrantyDaysLeft / 365).clamp(0.0, 1.0),
              backgroundColor: const Color(0xFFE2E8F0),
              valueColor: const AlwaysStoppedAnimation(Color(0xFF12B76A)),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceTimelineCard() {
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
          const Text('Device Audit Trail', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: AppTheme.ink900)),
          const SizedBox(height: 14),
          _buildAuditRow(Icons.inventory_2_rounded, 'Received into Warehouse', 'PO #4920 · Kariakoo Main Hub', '15 Sept 2026', AppTheme.brand600),
          _buildAuditRow(Icons.verified_user_rounded, 'Collateral Agreement Executed', 'IMEI $_imei mapped to loan contract (PDPA Compliant)', '16 Sept 2026', const Color(0xFF7C5CFC)),
          _buildAuditRow(Icons.assignment_ind_rounded, 'Loan Disbursed', 'Deposit TZS ${LimsFormatters.formatNumber(_depositPaid)} · $_borrowerName', '18 Sept 2026', const Color(0xFF12B76A)),
          _buildAuditRow(Icons.payments_rounded, 'Weekly Installment #1', 'TZS 150,000 via M-Pesa (MP891204)', '25 Sept 2026', const Color(0xFF0EA5E9), isLast: true),
        ],
      ),
    );
  }

  Widget _buildAuditRow(IconData icon, String title, String sub, String date, Color color, {bool isLast = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
              child: Icon(icon, size: 14, color: color),
            ),
            if (!isLast) Container(width: 2, height: 26, color: const Color(0xFFE2E8F0)),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppTheme.ink900),
              ),
              Text(
                sub,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: AppTheme.ink500),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            date,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppTheme.ink400),
          ),
        ),
      ],
    );
  }
}
