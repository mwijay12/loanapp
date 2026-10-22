import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/inventory_provider.dart';
import '../../../core/data/mock_lims_data.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../../core/l10n/strings.dart';
import '../../../core/data/product_art.dart';
import '../../../core/services/api_service.dart';
import '../../../core/data/supabase_source.dart';
import '../../../core/services/imei_scan.dart';
import 'package:url_launcher/url_launcher.dart';
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

  // Inspected device data. Every one of these is written by _performSearch from
  // the row that actually answered; none of them carries a starting value. They
  // used to open pre-filled with an iPhone 15 Pro Max, a borrower named Bakari
  // Juma Mwambungu, a TZS 2,450,000 balance and a serial that did not exist —
  // which meant the first screen a shopkeeper saw described a handset nobody had
  // looked up.
  String _model = '—';
  String? _matchedArt;
  String _variant = '—';
  String _imei = '';
  /// Read from the answering row, never invented. These used to be `final`
  /// constants, so every handset in the shop reported the same serial number,
  /// the same branch and the same deposit.
  String _serialNumber = '—';
  String _status = 'UNKNOWN'; // 'ON_LOAN', 'CASH_SOLD', 'IN_STOCK', 'OVERDUE', 'UNKNOWN', 'INVALID'
  String _borrowerName = '—';
  String _borrowerPhone = '—';
  String _borrowerNida = '—';
  int _totalLoanAmount = 0;
  int _depositPaid = 0;
  int _remainingBalance = 0;
  String _nextDueDate = '—';
  int _warrantyDaysLeft = 0;
  String _branch = '—';
  String? _loanId;
  /// The rows that actually answered the lookup. The audit trail is built
  /// from these, so a movement row only appears when the database has one.
  LoanItem? _answeredLoan;
  ProductItem? _answeredProduct;

  @override
  void initState() {
    super.initState();
    // Opening this screen used to run a search for a made-up serial, so the
    // first thing a shopkeeper saw was a device they had not scanned - complete
    // with a borrower, a deposit and four fabricated movement rows. The field
    // now starts empty and the screen waits to be told which handset to check.
    if (widget.initialImei != null && widget.initialImei!.isNotEmpty) {
      _imeiController.text = widget.initialImei!;
      _performSearch(widget.initialImei!);
    }
  }

  @override
  void dispose() {
    _imeiController.dispose();
    super.dispose();
  }

  /// Looks the serial up. Never invents one.
  ///
  /// This screen is used to decide whether a handset in someone's hand belongs to
  /// the shop, and whether it is paid for. It used to answer with a fabricated
  /// borrower whenever the serial was not found — "Selemani Rashidi", TZS 380,000,
  /// "Imechelewa kwa siku 12" — chosen by whether the IMEI started with 86. A
  /// verification tool that invents its verdict is worse than no tool.
  ///
  /// Three real answers now: on a contract, in stock, or not registered here.
  Future<void> _performSearch(String query) async {
    final cleanQuery = query.replaceAll(RegExp(r'\s+'), '').trim();
    if (cleanQuery.isEmpty) return;

    setState(() {
      _isSearching = true;
      _hasSearched = true;
    });

    // The GSMA check digit, before anything is looked up: a serial that fails it
    // cannot belong to a real handset, so there is nothing to search for.
    final digits = ImeiScan.parseImei(cleanQuery) ?? cleanQuery;
    final looksValid = ImeiScan.isValid(digits);

    // Local rows first — they are already in memory and cover the demo branch.
    LoanItem? matchedLoan;
    for (final l in ref.read(loansProvider)) {
      if (l.imei.isNotEmpty &&
          (l.imei.contains(cleanQuery) ||
              cleanQuery.contains(l.imei) ||
              l.id.toLowerCase() == cleanQuery.toLowerCase())) {
        matchedLoan = l;
        break;
      }
    }

    ProductItem? matchedProduct;
    if (matchedLoan == null) {
      for (final p in ref.read(inventoryProvider)) {
        if ((p.imei1 != null && p.imei1!.isNotEmpty && p.imei1!.contains(cleanQuery)) ||
            p.sku.toLowerCase() == cleanQuery.toLowerCase()) {
          matchedProduct = p;
          break;
        }
      }
    }

    // Then ask the database, which is what a real counter does.
    ImeiLookup? remote;
    if (matchedLoan == null && matchedProduct == null) {
      remote = await ref.read(apiServiceProvider).findUnitByImei(digits);
    }

    if (!mounted) return;

    setState(() {
      _isSearching = false;
      _imei = digits;
      _serialNumber = '—';
      _depositPaid = 0;
      _branch = ref.read(activeBranchProvider);
      _answeredLoan = null;
      _answeredProduct = null;

      if (matchedLoan != null) {
        _answeredLoan = matchedLoan;
        _serialNumber = digits;
        _model = matchedLoan.item;
        _variant = '';
        _status = matchedLoan.status == 'overdue' ? 'OVERDUE' : 'ON_LOAN';
        _borrowerName = matchedLoan.name;
        _borrowerPhone = matchedLoan.phone;
        _borrowerNida = matchedLoan.nida;
        _totalLoanAmount = matchedLoan.amount;
        _remainingBalance =
            (matchedLoan.amount * (1 - (matchedLoan.paid / 100))).round();
        _nextDueDate = matchedLoan.due;
        _warrantyDaysLeft = 0;
        _loanId = matchedLoan.id;
        _depositPaid = matchedLoan.totalDeposit;
        _branch = matchedLoan.location.trim().isEmpty
            ? ref.read(activeBranchProvider)
            : matchedLoan.location;
        _matchedArt = ProductArt.resolve(
          brand: null,
          name: matchedLoan.item,
          category: 'phones',
        );
        return;
      }

      if (matchedProduct != null) {
        _answeredProduct = matchedProduct;
        _model = matchedProduct.name;
        _variant = matchedProduct.variant;
        _status = 'IN_STOCK';
        _borrowerName = '—';
        _borrowerPhone = '—';
        _borrowerNida = '—';
        _totalLoanAmount = matchedProduct.loanPrice ?? matchedProduct.price;
        _remainingBalance = 0;
        _nextDueDate = tr(_locale, 'insp.notFinanced');
        _warrantyDaysLeft = 0;
        _loanId = null;
        _serialNumber = matchedProduct.imei1 ?? '—';
        _branch = ref.read(activeBranchProvider);
        _matchedArt = ProductArt.resolve(
          explicit: matchedProduct.imageAsset,
          brand: matchedProduct.brand,
          name: matchedProduct.name,
          category: matchedProduct.cat,
        );
        return;
      }

      if (remote != null && remote.isKnown) {
        final row = remote.row ?? const <String, dynamic>{};
        _model = remote.model;
        _variant = (row['variant'] ?? '').toString();
        _borrowerName = (row['borrower_name'] ?? row['customer_name'] ?? '—').toString();
        _borrowerPhone = (row['phone'] ?? row['customer_phone'] ?? '—').toString();
        _borrowerNida = (row['nida'] ?? '—').toString();
        _totalLoanAmount = SupabaseSource.parseMoney(row['amount'] ?? row['total']);
        _remainingBalance = SupabaseSource.parseMoney(row['balance']);
        _nextDueDate = (row['due_info'] ?? '—').toString();
        _warrantyDaysLeft = 0;
        _loanId = remote.status == 'on_loan' ? (row['id'] ?? '').toString() : null;
        _serialNumber = (row['serial_no'] ?? row['serial'] ?? '—').toString();
        _depositPaid = SupabaseSource.parseMoney(row['deposit'] ?? row['total_deposit']);
        _branch = (row['branch_name'] ?? row['branch'] ?? ref.read(activeBranchProvider))
            .toString();
        _status = remote.status == 'on_loan'
            ? ((row['status'] ?? '') == 'overdue' ? 'OVERDUE' : 'ON_LOAN')
            : 'IN_STOCK';
        _matchedArt = ProductArt.resolve(
          explicit: row['image_asset']?.toString(),
          brand: row['brand']?.toString(),
          name: _model,
          category: (row['category'] ?? 'phones').toString(),
        );
        return;
      }

      // Nothing owns this serial: not on a contract, not in stock, not in the
      // database. Say exactly that.
      _model = tr(_locale, 'insp.unknownModel');
      _variant = '';
      _status = looksValid ? 'UNKNOWN' : 'INVALID';
      _borrowerName = '—';
      _borrowerPhone = '—';
      _borrowerNida = '—';
      _totalLoanAmount = 0;
      _remainingBalance = 0;
      _nextDueDate = '—';
      _warrantyDaysLeft = 0;
      _loanId = null;
      _matchedArt = null;
    });
  }

  Future<void> _sendPaymentReminderSms() async {
    // No number on the contract means no message. The old code would have
    // opened the messaging app against a fallback number the row never held.
    if (_borrowerPhone.replaceAll(RegExp(r'[^0-9+]'), '').length < 9) {
      if (!mounted) return;
      LimsToast.show(context, tr(_locale, 'insp.noPhoneOnFile'));
      return;
    }
    final amount = LimsFormatters.formatNumber(
        _remainingBalance > 50000 ? 50000 : _remainingBalance);
    final body = trf(_locale, 'insp.reminderSms', {
      'name': _borrowerName,
      'amount': amount,
    });

    // There is no SMS gateway in this build, and the old toast said one had been
    // sent. Opening the phone's own messaging app does send it — by the person
    // holding the phone.
    final uri = Uri(
      scheme: 'sms',
      path: _borrowerPhone.replaceAll(RegExp(r'[^0-9+]'), ''),
      queryParameters: {'body': body},
    );
    final opened = await launchUrl(uri);
    if (!mounted) return;
    LimsToast.show(
      context,
      opened
          ? trf(_locale, 'insp.reminderOpened', {'phone': _borrowerPhone})
          : tr(_locale, 'insp.reminderFailed'),
      isSuccess: opened,
    );
  }

  void _openBorrowerDossier() {
    if (_loanId != null) {
      final loans = ref.read(loansProvider);
      final matches = loans.where((l) => l.id == _loanId);
      if (matches.isEmpty) {
        // The contract is no longer in the list the screen was built from.
        LimsToast.show(context, tr(_locale, 'insp.dossierMissing'));
        return;
      }
      final matchedLoan = matches.first;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (ctx) => BorrowerLoanDetailsScreen(loanId: _loanId!, initialLoan: matchedLoan),
        ),
      );
    } else {
      LimsToast.show(context, tr(_locale, 'insp.noActiveLoan'));
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
        title: Text(
          tr(_locale, 'insp.screenTitle'),
          style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, color: AppTheme.ink900),
        ),
        actions: [
          IconButton(
            tooltip: tr(_locale, 'insp.scanTooltip'),
            icon: const Icon(Icons.qr_code_scanner_rounded, color: AppTheme.brand600),
            // This used to pick a sample IMEI by the second hand and announce it
            // as a scan. It now opens the camera, and the inspector opens without
            // a serial rather than guessing one.
            onPressed: () => context.push('/scan'),
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
                        hintStyle: const TextStyle(fontSize: 13, color: AppTheme.ink400, fontWeight: FontWeight.normal),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
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
                        : Text(tr(_locale, 'insp.search'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Real serials already on the shelf. This row used to offer three
            // invented IMEIs labelled "Mifano" (iPhone 15 Pro, Redmi, Galaxy A15)
            // and tapping one produced a full inspection of a handset that did not
            // exist. It now offers serials that are actually recorded in stock, and
            // shows nothing at all when no unit has a serial on file.
            if (_serialsOnFile.isNotEmpty) ...[
              Row(
                children: [
                  Text(tr(_locale, 'insp.serialsOnFile'),
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppTheme.ink500)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (var i = 0; i < _serialsOnFile.length; i++) ...[
                            if (i > 0) const SizedBox(width: 6),
                            _buildQuickImeiChip(_serialsOnFile[i].$1, _serialsOnFile[i].$2),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],

            if (_hasSearched) ...[
              // Handset Overview Card
              _buildHandsetCard(),
              const SizedBox(height: 16),

              // Debt Follow-Up Action Card
              if (_status == 'ON_LOAN' || _status == 'OVERDUE') ...[
                _buildDebtFollowUpActionCard(),
                const SizedBox(height: 16),
              ],

              // Ownership & Loan Balance Card (if applicable)
              if (_status == 'ON_LOAN' || _status == 'OVERDUE') ...[
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

  /// Serials that a real row in stock carries. Empty is the normal answer when
  /// nobody has keyed serials in yet, and an empty list hides the row instead of
  /// filling it with sample numbers.
  List<(String, String)> get _serialsOnFile {
    final out = <(String, String)>[];
    for (final p in ref.watch(inventoryProvider)) {
      final imei = p.imei1;
      if (imei == null || imei.isEmpty) continue;
      out.add((imei, p.name));
      if (out.length == 4) break;
    }
    return out;
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
              _buildParamItem(tr(_locale, 'insp.serialNo'), _serialNumber),
              _buildParamItem(tr(_locale, 'insp.branch'), _branch),
              _buildParamItem(tr(_locale, 'insp.loanValue'), 'TZS ${LimsFormatters.formatNumber(_totalLoanAmount)}'),
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
      case 'UNKNOWN':
        bg = const Color(0xFFF1F5F9);
        text = AppTheme.ink700;
        label = tr(_locale, 'insp.unknownStatus');
        break;
      case 'INVALID':
        bg = const Color(0xFFFFF7E6);
        text = const Color(0xFFB54708);
        label = tr(_locale, 'insp.invalidStatus');
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
                          Text(
                            tr(_locale, 'insp.recoveryTitle'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: AppTheme.ink900),
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
                  isOverdue ? tr(_locale, 'insp.overdueTag') : tr(_locale, 'insp.activeTag'),
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
                  label: Text(tr(_locale, 'insp.sendSms'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
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
                  label: Text(tr(_locale, 'insp.borrowerDossier'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
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
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.ink900),
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
                  child: Row(
                    children: [
                      Text(tr(_locale, 'insp.fullFile'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.brand600)),
                      const Icon(Icons.chevron_right_rounded, size: 16, color: AppTheme.brand600),
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
                      trf(_locale, 'insp.phoneNida', {'phone': _borrowerPhone, 'nida': _borrowerNida}),
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
                    Text(tr(_locale, 'insp.remainingBalance'), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: AppTheme.ink500)),
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
                    Text(tr(_locale, 'insp.dueDate'), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: AppTheme.ink500)),
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
              label: Text(tr(_locale, 'insp.recordPayment'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
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
              Expanded(
                child: Text(
                  tr(_locale, 'insp.warrantyTitle'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.ink900),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: const Color(0xFFE7F8F0), borderRadius: BorderRadius.circular(8)),
                  child: Text(
                    '$_warrantyDaysLeft days left',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF12B76A)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(tr(_locale, 'insp.warrantyIncludes'), style: const TextStyle(fontSize: 12, color: AppTheme.ink600)),
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
    final audit = _auditEntries;
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
          Text(tr(_locale, 'insp.auditTitle'), style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: AppTheme.ink900)),
          const SizedBox(height: 14),
          // These four rows used to be typed into the widget: a made-up purchase
          // order at "Kariakoo Main Hub", a signature on a date, a disbursement
          // and an "Installment #1" of TZS 150,000 through an M-Pesa code that
          // never existed. Every handset in the shop showed the same history. The
          // rows below are the payments that are actually on the contract, or an
          // empty state that says nothing has been recorded.
          if (audit.isEmpty)
            Text(
              tr(_locale, 'insp.auditEmpty'),
              style: const TextStyle(fontSize: 12, color: AppTheme.ink500, height: 1.5),
            )
          else
            for (var i = 0; i < audit.length; i++)
              _buildAuditRow(
                audit[i].icon,
                audit[i].title,
                audit[i].sub,
                audit[i].date,
                audit[i].color,
                isLast: i == audit.length - 1,
              ),
        ],
      ),
    );
  }

  /// Real movement for the handset in hand, newest first, built only from rows
  /// that exist: the contract itself and the instalments recorded against it.
  List<_AuditEntry> get _auditEntries {
    final out = <_AuditEntry>[];

    final loan = _answeredLoan;
    if (loan != null) {
      final payments = [...loan.payments]
        ..sort((a, b) => b.date.compareTo(a.date));
      for (final pay in payments.take(4)) {
        out.add(_AuditEntry(
          Icons.payments_rounded,
          tr(_locale, 'insp.auditInstallment'),
          '${pay.formattedAmount} · ${pay.channel} · ${pay.refNumber}',
          pay.date,
          const Color(0xFF0EA5E9),
        ));
      }
      out.add(_AuditEntry(
        Icons.assignment_ind_rounded,
        trf(_locale, 'insp.auditContract', {'id': loan.id}),
        _depositPaid > 0
            ? trf(_locale, 'insp.auditContractDeposit',
                {'name': _borrowerName, 'deposit': LimsFormatters.formatNumber(_depositPaid)})
            : trf(_locale, 'insp.auditContractNoDeposit', {'name': _borrowerName}),
        '—',
        const Color(0xFF12B76A),
      ));
    }

    final product = _answeredProduct;
    if (product != null) {
      out.add(_AuditEntry(
        Icons.inventory_2_rounded,
        tr(_locale, 'insp.auditInStock'),
        trf(_locale, 'insp.auditInStockSub', {
          'sku': product.sku,
          'branch': _branch,
          'stock': '${product.stock}',
        }),
        '—',
        AppTheme.brand600,
      ));
    }

    if (loan == null && product == null && _status != 'UNKNOWN' && _status != 'INVALID') {
      out.add(_AuditEntry(
        Icons.verified_user_rounded,
        tr(_locale, 'insp.auditRemoteMatch'),
        trf(_locale, 'insp.auditRemoteMatchSub', {'serial': _serialNumber}),
        '—',
        const Color(0xFF7C5CFC),
      ));
    }

    return out;
  }

  Widget _buildAuditRow(IconData icon, String title, String sub, String date, Color color, {bool isLast = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
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

/// One line of the device audit trail. Nothing is stored that a query did not
/// return, which is why [date] is '—' for rows whose timestamp the schema does
/// not carry.
class _AuditEntry {
  final IconData icon;
  final String title;
  final String sub;
  final String date;
  final Color color;

  const _AuditEntry(this.icon, this.title, this.sub, this.date, this.color);
}
