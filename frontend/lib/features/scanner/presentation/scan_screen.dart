import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/locale_provider.dart';
import '../../../core/l10n/strings.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/imei_scan.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/imei_scanner_view.dart';
import '../../../core/widgets/ui_kit.dart';

/// Scan a handset label and ask the database what it is.
///
/// The previous version had a button called "Simulate Camera Laser Scan": it ran
/// a 1.2-second animation and then opened the first row of a hardcoded list of
/// four phones, whatever the camera was pointed at. A storekeeper could point it
/// at the wall and be told a Tecno Spark 20 was in stock.
///
/// Everything below is real. The camera decodes a barcode, [ImeiScan] checks the
/// GSMA digit, and the answer comes from `products` or `loans`. When the IMEI is
/// not on file the screen says exactly that — an unregistered handset is a
/// finding, not a failure to paper over.
class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({super.key});

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen> {
  final TextEditingController _imeiCtrl = TextEditingController();
  final GlobalKey<ImeiScannerViewState> _cameraKey = GlobalKey();

  ImeiLookup? _result;
  String? _error;
  bool _looking = false;

  @override
  void initState() {
    super.initState();
    _imeiCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _imeiCtrl.dispose();
    super.dispose();
  }

  Locale get _locale => ref.read(localeProvider);

  Future<void> _lookUp(String raw) async {
    final locale = _locale;
    final imei = ImeiScan.parseImei(raw) ?? raw.replaceAll(RegExp(r'\D'), '');

    if (!ImeiScan.isValid(imei)) {
      setState(() {
        _result = null;
        _error = tr(locale, 'scan.invalid');
      });
      return;
    }

    setState(() {
      _looking = true;
      _error = null;
      _result = null;
    });

    final lookup = await ref.read(apiServiceProvider).findUnitByImei(imei);
    if (!mounted) return;

    setState(() {
      _looking = false;
      _result = lookup;
      _imeiCtrl.text = imei;
    });

    // Let the viewfinder accept the next label once this one has been resolved.
    _cameraKey.currentState?.resume();
  }

  void _onCameraImei(String imei) {
    _imeiCtrl.text = imei;
    _lookUp(imei);
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final typed = _imeiCtrl.text.replaceAll(RegExp(r'\D'), '');
    final typedValid = ImeiScan.isValid(typed);

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 120),
          children: [
            _buildHeader(locale),
            const SizedBox(height: 16),
            ImeiScannerView(
              key: _cameraKey,
              locale: locale,
              onImei: _onCameraImei,
            ),
            const SizedBox(height: 16),
            _buildManualEntry(locale, typed, typedValid),
            const SizedBox(height: 16),
            if (_looking)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              )
            else if (_error != null)
              _buildMessage(_error!, isError: true)
            else if (_result != null)
              _buildResult(locale, _result!)
            else
              _buildMessage(tr(locale, 'scan.looking')),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(Locale locale) {
    return Row(
      children: [
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
            ),
            child: const Icon(Icons.arrow_back_rounded,
                size: 20, color: AppTheme.ink900),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr(locale, 'scan.eyebrow'),
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.ink500,
                ),
              ),
              Text(
                tr(locale, 'scan.title'),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.4,
                  color: AppTheme.ink900,
                ),
              ),
            ],
          ),
        ),
        if (_result != null)
          IconButton(
            tooltip: tr(locale, 'scan.inspector'),
            onPressed: () => context.push('/imei-inspector?imei=${_result!.imei}'),
            icon: const Icon(Icons.shield_outlined, color: AppTheme.brand600),
          ),
      ],
    );
  }

  Widget _buildManualEntry(Locale locale, String typed, bool valid) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 6, 8, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: typed.isEmpty
              ? const Color(0xFFE2E8F0)
              : (valid ? const Color(0xFF10B981) : const Color(0xFFFECDD3)),
          width: typed.isEmpty ? 1 : 1.5,
        ),
      ),
      child: Row(
        children: [
          Icon(
            valid ? Icons.check_circle_rounded : Icons.dialpad_rounded,
            size: 20,
            color: valid ? const Color(0xFF10B981) : AppTheme.ink400,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _imeiCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9 \-]')),
                LengthLimitingTextInputFormatter(20),
              ],
              onSubmitted: _lookUp,
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: tr(locale, 'scan.searchHint'),
                hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF9AA8BF)),
              ),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: AppTheme.ink900,
              ),
            ),
          ),
          TextButton(
            onPressed: typed.isEmpty ? null : () => _lookUp(typed),
            child: Text(tr(locale, 'common.retry')),
          ),
        ],
      ),
    );
  }

  Widget _buildMessage(String text, {bool isError = false}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isError ? const Color(0xFFFFF1F3) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isError ? const Color(0xFFFECDD3) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isError ? Icons.error_outline_rounded : Icons.info_outline_rounded,
            size: 18,
            color: isError ? AppTheme.errorColor : AppTheme.ink500,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: isError ? AppTheme.errorColor : AppTheme.ink500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResult(Locale locale, ImeiLookup lookup) {
    if (!lookup.isKnown) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMessage(
            trf(locale, 'scan.notFound', {'n': lookup.imei}),
            isError: true,
          ),
          const SizedBox(height: 10),
          _buildRow(
            label: 'TAC',
            value: ImeiScan.tac(lookup.imei) ?? '—',
          ),
          _buildRow(label: 'IMEI', value: lookup.imei),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _lookUp(lookup.imei),
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: Text(tr(locale, 'common.retry')),
          ),
        ],
      );
    }

    final row = lookup.row ?? const {};
    final inStock = lookup.status == 'in_stock';
    final cash = _money(row['price']);
    final loan = _money(row['loan_price']);
    final borrower = (row['borrower_name'] ?? '') as String;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: inStock ? const Color(0xFFBBF7D0) : const Color(0xFFFDE68A),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: inStock
                      ? const Color(0xFFECFDF5)
                      : const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  tr(locale, inStock ? 'scan.inStock' : 'scan.onLoan'),
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: inStock
                        ? const Color(0xFF027A48)
                        : const Color(0xFFB45309),
                  ),
                ),
              ),
              const Spacer(),
              Text(
                lookup.imei,
                style: const TextStyle(
                  fontSize: 11,
                  letterSpacing: 0.5,
                  color: AppTheme.ink400,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            lookup.model.isEmpty ? '—' : lookup.model,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: AppTheme.ink900,
            ),
          ),
          const SizedBox(height: 10),
          if (cash != null)
            _buildRow(
              label: tr(locale, 'scan.cashPrice'),
              value: 'TZS ${_format(cash)}',
            ),
          if (loan != null)
            _buildRow(
              label: tr(locale, 'scan.loanPrice'),
              value: 'TZS ${_format(loan)}',
            ),
          if (!inStock && borrower.isNotEmpty)
            _buildRow(label: 'Borrower', value: borrower),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _lookUp(lookup.imei),
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: Text(tr(locale, 'scan.scanAgain')),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: lookup.imei));
                    LimsToast.show(context, tr(locale, 'scan.copied'));
                  },
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: Text(tr(locale, 'scan.inspector')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRow({required String label, required String value}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: AppTheme.ink500),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: AppTheme.ink900,
            ),
          ),
        ],
      ),
    );
  }

  double? _money(Object? value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    final cleaned = '$value'.replaceAll(RegExp(r'[^0-9.]'), '');
    return double.tryParse(cleaned);
  }

  String _format(double value) {
    final whole = value.round().toString();
    final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return whole.replaceAllMapped(reg, (m) => '${m[1]},');
  }
}
