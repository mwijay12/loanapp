import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/branch_provider.dart';
import '../../../core/data/inventory_provider.dart';
import '../../../core/data/mock_lims_data.dart';
import '../../../core/data/product_art.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../../core/l10n/strings.dart';
import '../../../core/services/imei_scan.dart';
import '../../../core/services/stock_receipts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/imei_scanner_view.dart';
import '../../../core/widgets/ui_kit.dart';

/// Receiving stock, with a record of where the stock came from.
///
/// The screen used to be a fixed mock: "PO #4521", four hand-written lines with
/// quantities 10/6/8/5, three pre-filled serials, and a confirm button that called
/// `updateStock(1..4)` on product ids that do not exist in the database. The count
/// on screen moved; the rows did not. Nothing recorded a supplier, an invoice, or
/// that some units arrived from another branch rather than from a purchase.
///
/// This version asks the three questions a storekeeper actually answers — where is
/// it from, what arrived, which serials — and writes every line to `products`.
class ReceiveStockScreen extends ConsumerStatefulWidget {
  const ReceiveStockScreen({super.key});

  @override
  ConsumerState<ReceiveStockScreen> createState() => _ReceiveStockScreenState();
}

class _ReceiveStockScreenState extends ConsumerState<ReceiveStockScreen> {
  StockSource _source = StockSource.supplier;
  final _supplier = TextEditingController();
  final _invoice = TextEditingController();
  final _note = TextEditingController();
  String? _fromBranch;

  final List<StockReceiptLine> _lines = [];
  final Set<String> _imeis = {};

  bool _busy = false;

  @override
  void dispose() {
    _supplier.dispose();
    _invoice.dispose();
    _note.dispose();
    super.dispose();
  }

  Locale get _locale => ref.read(localeProvider);
  String t(String key) => tr(_locale, key);
  String tf(String key, Map<String, String> args) => trf(_locale, key, args);

  int get _units => _lines.fold(0, (sum, l) => sum + l.qty);
  int get _value => _lines.fold(0, (sum, l) => sum + (l.qty * l.unitCost));

  void _addLine(ProductItem p) {
    if (_lines.any((l) => l.productId == p.id)) return;
    setState(() {
      _lines.add(StockReceiptLine(
        productId: p.id,
        name: p.name,
        sku: p.sku,
        qty: 1,
        unitCost: p.costPrice ?? p.price,
        imageAsset: p.imageAsset,
        imageUrl: p.imageUrl,
      ));
    });
  }

  void _changeQty(StockReceiptLine line, int delta) {
    final next = line.qty + delta;
    if (next < 1 || next > 500) return;
    setState(() {
      final i = _lines.indexWhere((l) => l.productId == line.productId);
      if (i == -1) return;
      _lines[i] = StockReceiptLine(
        productId: line.productId,
        name: line.name,
        sku: line.sku,
        qty: next,
        unitCost: line.unitCost,
        imageAsset: line.imageAsset,
        imageUrl: line.imageUrl,
      );
    });
  }

  Future<void> _pickProduct() async {
    final products = ref.read(inventoryProvider);
    if (products.isEmpty) {
      LimsToast.show(context, t('recv.noProducts'));
      return;
    }

    final chosen = await showModalBottomSheet<ProductItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.72,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      t('recv.pickModel'),
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                itemCount: products.length,
                itemBuilder: (_, i) {
                  final p = products[i];
                  final already = _lines.any((l) => l.productId == p.id);
                  return ListTile(
                    leading: SizedBox(
                      width: 40,
                      height: 44,
                      child: Image.asset(
                        ProductArt.resolve(
                          explicit: p.imageAsset,
                          brand: p.brand,
                          name: p.name,
                          category: p.cat,
                        ),
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(
                            Icons.phone_android_rounded,
                            color: AppTheme.brand600),
                      ),
                    ),
                    title: Text(p.name,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text('${p.sku} · ${p.stock} ${t('recv.inBranch')}'),
                    trailing: already
                        ? const Icon(Icons.check_circle_rounded,
                            color: Color(0xFF12B76A))
                        : const Icon(Icons.add_circle_outline_rounded),
                    onTap: already ? null : () => Navigator.pop(ctx, p),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );

    if (chosen != null) _addLine(chosen);
  }

  Future<void> _scanImei() async {
    final value = await showDialog<String>(
      context: context,
      builder: (_) => ImeiScanDialog(
        title: t('recv.scanTitle'),
        hint: t('recv.scanHint'),
        expected: _units,
        already: _imeis.length,
      ),
    );
    if (value == null || !mounted) return;
    if (_imeis.contains(value)) {
      LimsToast.show(context, tf('recv.alreadyScanned', {'n': value}));
      return;
    }
    setState(() => _imeis.add(value));
    LimsToast.show(context, tf('recv.added', {'n': value}), isSuccess: true);
  }

  Future<void> _confirm() async {
    final receipt = StockReceipt(
      branch: ref.read(activeBranchProvider),
      source: _source,
      lines: List.of(_lines),
      imeis: _imeis.toList(),
      supplierName: _supplier.text.trim(),
      invoiceNo: _invoice.text.trim(),
      fromBranch: _fromBranch,
      note: _note.text.trim(),
    );

    final problem = receipt.validate();
    if (problem != null) {
      LimsToast.show(context, t('recv.err_$problem'));
      return;
    }

    setState(() => _busy = true);
    final result = await ref.read(stockReceiptServiceProvider).receive(receipt);

    // The local list feeds every other screen, so it moves with the same truth.
    if (result.ok) {
      for (final line in receipt.lines) {
        ref
            .read(inventoryProvider.notifier)
            .updateStock(line.productId, line.qty);
      }
    }

    if (!mounted) return;
    setState(() => _busy = false);

    if (result.ok) {
      final scanned = receipt.imeis.length;
      final stored = result.unitsStored;
      final skipped = scanned - stored;

      final head = result.persisted
          ? tf('recv.ok', {'n': '${receipt.units}', 'b': receipt.branch})
          : tf('recv.okLocal', {'n': '${receipt.units}'});

      // Say plainly what happened to the serials. "29 units received" is true
      // even when not one IMEI was saved, and that gap is what the register is
      // meant to close.
      final String tail;
      if (!result.persisted) {
        tail = '';
      } else if (scanned == 0) {
        tail = t('recv.noSerials');
      } else if (stored == 0) {
        // Nothing landed and something was scanned: a missing table or a refused
        // write. Saying "skipped" here would blame the operator for a backend gap.
        tail = tf('recv.serialsFailed', {'n': '$scanned'});
      } else if (skipped > 0) {
        tail = tf('recv.serialsSkipped', {'n': '$skipped'});
      } else {
        tail = tf('recv.serialsStored', {'n': '$stored'});
      }

      LimsToast.show(
        context,
        tail.isEmpty ? head : '$head · $tail',
        isSuccess: stored > 0 || scanned == 0,
      );
      Navigator.pop(context, true);
      return;
    }

    LimsToast.show(
      context,
      result.persisted ? t('recv.failed') : t('recv.offline'),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(localeProvider);
    final products = ref.watch(inventoryProvider);
    final branch = ref.watch(activeBranchProvider);
    final branches = ref.watch(branchesProvider);

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          t('recv.title'),
          style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppTheme.ink900),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.ink900),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFE2E8F0), height: 1),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 130),
        children: [
          _branchCard(branch),
          const SizedBox(height: 14),
          _sourceCard(branches),
          const SizedBox(height: 16),
          _linesCard(products),
          const SizedBox(height: 14),
          _imeiCard(),
          const SizedBox(height: 14),
          TextField(
            controller: _note,
            maxLines: 2,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              labelText: t('recv.note'),
              labelStyle: const TextStyle(fontSize: 12.5),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
      bottomSheet: Container(
        color: Colors.white,
        padding: EdgeInsets.fromLTRB(
            16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
        child: SizedBox(
          height: 50,
          child: FilledButton(
            onPressed: _busy ? null : _confirm,
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.brand600,
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : Text(
                    t('recv.confirm'),
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w800),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _branchCard(String branch) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFE9F2FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.add_box_rounded, color: AppTheme.brand600),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(branch,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(
                  _lines.isEmpty
                      ? t('recv.noLines')
                      : tf('recv.linesSummary', {
                          'lines': '${_lines.length}',
                          'units': '$_units',
                          'value': LimsFormatters.formatNumber(_value),
                        }),
                  style:
                      const TextStyle(fontSize: 11.5, color: AppTheme.ink500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sourceCard(List<BranchRecord> branches) {
    Widget chip(StockSource s, String label, IconData icon) {
      final selected = _source == s;
      return Expanded(
        child: InkWell(
          onTap: () => setState(() => _source = s),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color:
                  selected ? const Color(0xFFE9F2FF) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? AppTheme.brand600 : const Color(0xFFE2E8F0),
                width: selected ? 1.4 : 1,
              ),
            ),
            child: Column(
              children: [
                Icon(icon,
                    size: 18,
                    color: selected ? AppTheme.brand600 : AppTheme.ink500),
                const SizedBox(height: 6),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.2,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: selected ? AppTheme.brand600 : AppTheme.ink700,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t('recv.sourceTitle'),
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Row(
            children: [
              chip(StockSource.supplier, t('recv.sourceSupplier'),
                  Icons.local_shipping_outlined),
              const SizedBox(width: 8),
              chip(StockSource.transfer, t('recv.sourceTransfer'),
                  Icons.swap_horiz_rounded),
              const SizedBox(width: 8),
              chip(StockSource.customerReturn, t('recv.sourceReturn'),
                  Icons.assignment_return_outlined),
            ],
          ),
          const SizedBox(height: 12),
          if (_source == StockSource.supplier) ...[
            TextField(
              controller: _supplier,
              textCapitalization: TextCapitalization.words,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                labelText: t('recv.supplierName'),
                hintText: t('recv.supplierHint'),
                labelStyle: const TextStyle(fontSize: 12.5),
                isDense: true,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _invoice,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                labelText: t('recv.invoice'),
                hintText: t('recv.invoiceHint'),
                labelStyle: const TextStyle(fontSize: 12.5),
                isDense: true,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
          if (_source == StockSource.transfer) ...[
            DropdownButtonFormField<String>(
              value: _fromBranch,
              isExpanded: true,
              style: const TextStyle(fontSize: 13, color: AppTheme.ink900),
              decoration: InputDecoration(
                labelText: t('recv.fromBranch'),
                labelStyle: const TextStyle(fontSize: 12.5),
                isDense: true,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              items: branches
                  .where((b) => b.name != ref.read(activeBranchProvider))
                  .map((b) => DropdownMenuItem(
                        value: b.name,
                        child: Text(b.name, overflow: TextOverflow.ellipsis),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _fromBranch = v),
            ),
            const SizedBox(height: 8),
            Text(
              t('recv.transferNote'),
              style: const TextStyle(fontSize: 11, color: AppTheme.ink500),
            ),
          ],
          if (_source == StockSource.customerReturn)
            Text(
              t('recv.returnNote'),
              style: const TextStyle(fontSize: 11.5, color: AppTheme.ink500),
            ),
        ],
      ),
    );
  }

  Widget _linesCard(List<ProductItem> products) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(t('recv.whatArrived'),
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w800)),
              ),
              TextButton.icon(
                onPressed: _pickProduct,
                icon: const Icon(Icons.add_rounded, size: 16),
                label: Text(t('recv.addLine'),
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          if (_lines.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Center(
                child: Text(
                  t('recv.emptyLines'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: AppTheme.ink500),
                ),
              ),
            )
          else
            for (final line in _lines) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 38,
                      height: 42,
                      child: Image.asset(
                        ProductArt.resolve(
                          explicit: line.imageAsset,
                          name: line.name,
                          category: 'phones',
                        ),
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(
                            Icons.phone_android_rounded,
                            size: 20,
                            color: AppTheme.brand600),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(line.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w700)),
                          Text(
                            '${line.sku} · ${LimsFormatters.formatNumber(line.unitCost)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 10.5, color: AppTheme.ink500),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline_rounded,
                          size: 20, color: AppTheme.ink500),
                      onPressed: () => _changeQty(line, -1),
                      visualDensity: VisualDensity.compact,
                    ),
                    Text('${line.qty}',
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w800)),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline_rounded,
                          size: 20, color: AppTheme.brand600),
                      onPressed: () => _changeQty(line, 1),
                      visualDensity: VisualDensity.compact,
                    ),
                    InkWell(
                      onTap: () => setState(() => _lines.remove(line)),
                      child: const Icon(Icons.close_rounded,
                          size: 16, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ),
            ],
          if (_lines.isNotEmpty) ...[
            const Divider(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  tf('recv.totals', {
                    'units': '$_units',
                    'value': LimsFormatters.formatNumber(_value),
                  }),
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w800),
                ),
                Text(
                  '${products.length} ${t('recv.catalogue')}',
                  style:
                      const TextStyle(fontSize: 10.5, color: AppTheme.ink500),
                ),
              ],
            ),
            const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }

  Widget _imeiCard() {
    final expected = _units;
    final scanned = _imeis.length;
    final complete = expected > 0 && scanned >= expected;
    final colour = complete
        ? const Color(0xFF12B76A)
        : (scanned == 0 ? AppTheme.ink500 : const Color(0xFFEA580C));

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                complete
                    ? Icons.verified_rounded
                    : Icons.qr_code_scanner_rounded,
                size: 18,
                color: colour,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  expected == 0
                      ? t('recv.scanFirst')
                      : tf('recv.scanProgress',
                          {'expected': '$expected', 'scanned': '$scanned'}),
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700, color: colour),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: expected == 0 ? 0 : (scanned / expected).clamp(0, 1),
              minHeight: 6,
              backgroundColor: const Color(0xFFF1F5F9),
              valueColor: AlwaysStoppedAnimation(colour),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton.icon(
              onPressed: expected == 0 ? null : _scanImei,
              icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
              label: Text(t('recv.scanButton'),
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.brand600,
                side: const BorderSide(color: Color(0xFFCEE1FE)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          if (_imeis.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _imeis
                  .map((i) => Chip(
                        label: Text(i,
                            style: const TextStyle(
                                fontSize: 9.5,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w600)),
                        visualDensity: VisualDensity.compact,
                        backgroundColor: const Color(0xFFF1F5F9),
                        side: BorderSide.none,
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

/// Camera or typed serial, with the GSMA check applied before it is accepted.
class ImeiScanDialog extends StatefulWidget {
  const ImeiScanDialog({
    super.key,
    required this.title,
    required this.hint,
    required this.expected,
    required this.already,
  });

  final String title;
  final String hint;
  final int expected;
  final int already;

  @override
  State<ImeiScanDialog> createState() => _ImeiScanDialogState();
}

class _ImeiScanDialogState extends State<ImeiScanDialog> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _accept(String raw) {
    final parsed = ImeiScan.parseImei(raw);
    if (parsed == null) {
      setState(() => _error = tr(Localizations.localeOf(context), 'recv.badImei'));
      return;
    }
    Navigator.pop(context, parsed);
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(widget.title,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w800)),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            Text(
              trf(locale, 'recv.scanProgress', {
                'expected': '${widget.expected}',
                'scanned': '${widget.already}',
              }),
              style: const TextStyle(fontSize: 11.5, color: AppTheme.ink500),
            ),
            const SizedBox(height: 12),
            SizedBox(height: 190, child: ImeiScannerView(onImei: _accept)),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: widget.hint,
                errorText: _error,
                isDense: true,
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onSubmitted: _accept,
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 44,
              width: double.infinity,
              child: FilledButton(
                onPressed: () => _accept(_controller.text),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.brand600,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(tr(locale, 'recv.useImei'),
                    style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
