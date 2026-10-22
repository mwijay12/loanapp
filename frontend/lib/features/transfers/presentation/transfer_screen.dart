import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/branch_provider.dart';
import '../../../core/data/inventory_provider.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../../core/l10n/strings.dart';
import '../../../core/services/api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ui_kit.dart';

/// Moving handsets from one shop to another.
///
/// The old screen was a picture of a transfer: four hardcoded branches, three
/// hardcoded items with quantities of 2/3/4, "Available: 12" that came from
/// nowhere, a receipt number `TR-902` that was typed into the source, and a
/// confirm button that subtracted from `products.stock`. That last part is the
/// real bug: an internal transfer does not change how many phones the company
/// owns, so every "transfer" wrote stock off the business.
///
/// This version reads the branches the business actually has, lists the serials
/// physically at this branch, and moves those serials. `products.stock` is left
/// alone, because the phones did not leave the company - they changed address.
class TransferScreen extends ConsumerStatefulWidget {
  const TransferScreen({super.key});

  @override
  ConsumerState<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends ConsumerState<TransferScreen> {
  final _api = ApiService();

  String? _to;
  final Set<String> _selected = {};
  bool _loading = true;
  bool _sending = false;
  String? _error;

  List<Map<String, dynamic>> _units = [];

  Locale get _locale => ref.read(localeProvider);
  String t(String k) => tr(_locale, k);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final from = ref.read(activeBranchProvider);
    setState(() {
      _loading = true;
      _error = null;
    });
    final units = await _api.listStockUnits(from);
    if (!mounted) return;
    setState(() {
      _units = units;
      _loading = false;
      if (units.isEmpty && !_api.isConfigured) {
        _error = t('transfer.noDatabase');
      }
    });
  }

  /// Grouped by model, because a storekeeper moves "three Camon 30s", not a
  /// flattened list of serials.
  Map<String, List<Map<String, dynamic>>> get _byModel {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final u in _units) {
      final model = (u['model'] as String?)?.trim();
      final key = (model == null || model.isEmpty) ? t('transfer.unspecified') : model;
      grouped.putIfAbsent(key, () => []).add(u);
    }
    return grouped;
  }

  Future<void> _pickSerials(String model, List<Map<String, dynamic>> units) async {
    final picked = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final chosen = <String>{
          for (final u in units)
            if (_selected.contains(u['imei'])) u['imei'] as String,
        };
        return StatefulBuilder(
          builder: (ctx, setSheet) => Container(
            height: MediaQuery.of(ctx).size.height * 0.7,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
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
                  padding: const EdgeInsets.fromLTRB(20, 14, 12, 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(model,
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w800)),
                            Text(
                              '${units.length} ${t('transfer.atThisBranch')}',
                              style: const TextStyle(
                                  fontSize: 11.5, color: AppTheme.ink500),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setSheet(() {
                            if (chosen.length == units.length) {
                              chosen.clear();
                            } else {
                              chosen
                                ..clear()
                                ..addAll(units.map((u) => u['imei'] as String));
                            }
                          });
                        },
                        child: Text(
                          chosen.length == units.length
                              ? t('transfer.clear')
                              : t('transfer.all'),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.separated(
                    itemCount: units.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    itemBuilder: (_, i) {
                      final imei = units[i]['imei'] as String;
                      final on = chosen.contains(imei);
                      return CheckboxListTile(
                        value: on,
                        onChanged: (v) => setSheet(() {
                          if (v == true) {
                            chosen.add(imei);
                          } else {
                            chosen.remove(imei);
                          }
                        }),
                        title: Text(
                          '•••• ${imei.substring(imei.length - 4)}',
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          imei,
                          style: const TextStyle(
                              fontSize: 11, color: AppTheme.ink500),
                        ),
                        activeColor: AppTheme.brand600,
                        controlAffinity: ListTileControlAffinity.trailing,
                      );
                    },
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                    child: SizedBox(
                      height: 50,
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => Navigator.pop(ctx, chosen),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.brand600,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Text(
                          '${t('transfer.useSelection')} (${chosen.length})',
                          style: const TextStyle(
                              fontSize: 14.5, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (picked == null) return;
    setState(() {
      _selected.removeAll(units.map((u) => u['imei'] as String));
      _selected.addAll(picked);
    });
  }

  Future<void> _send() async {
    final from = ref.read(activeBranchProvider);
    final to = _to;
    if (to == null) {
      LimsToast.show(context, t('transfer.chooseDestination'));
      return;
    }
    if (_selected.isEmpty) {
      LimsToast.show(context, t('transfer.chooseUnits'));
      return;
    }

    setState(() => _sending = true);
    final receiptId = await _api.transferUnits(
      imeis: _selected.toList(),
      from: from,
      to: to,
    );
    if (!mounted) return;
    setState(() => _sending = false);

    if (receiptId == null) {
      LimsToast.show(context, t('transfer.failed'));
      return;
    }

    LimsToast.show(
      context,
      '${_selected.length} ${t('transfer.sent')} → $to '
      '(${t('transfer.reference')} #TR-$receiptId)',
      isSuccess: true,
    );
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(localeProvider);
    final from = ref.watch(activeBranchProvider);
    final branches = ref
        .watch(branchesProvider)
        .where((b) => b.name != from && b.active)
        .toList();

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
        title: Text(
          t('transfer.title'),
          style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppTheme.ink900),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFE2E8F0), height: 1),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 130),
          children: [
            _routeCard(from, branches),
            const SizedBox(height: 14),
            _unitsCard(),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!,
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.ink500, height: 1.4)),
            ],
          ],
        ),
      ),
      bottomSheet: Container(
        color: Colors.white,
        padding: EdgeInsets.fromLTRB(
            16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
        child: SizedBox(
          height: 52,
          child: FilledButton(
            onPressed: (_sending || _selected.isEmpty || _to == null)
                ? null
                : _send,
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.brand600,
              disabledBackgroundColor: const Color(0xFFCBD5E1),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: _sending
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : Text(
                    _selected.isEmpty
                        ? t('transfer.sendEmpty')
                        : '${t('transfer.send')} ${_selected.length} '
                            '${_selected.length == 1 ? t('transfer.unit') : t('transfer.units')}',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w800),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _routeCard(String from, List<BranchRecord> branches) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t('transfer.from'),
                        style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: AppTheme.ink500)),
                    const SizedBox(height: 3),
                    Text(from,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 14.5, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.arrow_forward_rounded,
                    size: 18, color: AppTheme.brand600),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t('transfer.to'),
                        style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: AppTheme.ink500)),
                    const SizedBox(height: 3),
                    Text(_to ?? '—',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 14.5, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (branches.isEmpty)
            Text(
              t('transfer.noBranches'),
              style: const TextStyle(
                  fontSize: 12, color: AppTheme.ink500, height: 1.4),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final b in branches)
                  GestureDetector(
                    onTap: () => setState(() => _to = b.name),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: _to == b.name ? AppTheme.brand600 : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _to == b.name
                              ? AppTheme.brand600
                              : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Text(
                        b.name.replaceAll(' Branch', ''),
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color:
                              _to == b.name ? Colors.white : AppTheme.ink700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _unitsCard() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    final grouped = _byModel;
    if (grouped.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t('transfer.noUnitsTitle'),
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(
              t('transfer.noUnitsBody'),
              style: const TextStyle(
                  fontSize: 12, color: AppTheme.ink500, height: 1.45),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t('transfer.devices'),
            style:
                const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            children: [
              for (final entry in grouped.entries)
                InkWell(
                  onTap: () => _pickSerials(entry.key, entry.value),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: AppTheme.brand50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.phone_iphone_rounded,
                              size: 20, color: AppTheme.brand600),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(entry.key,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700)),
                              const SizedBox(height: 2),
                              Text(
                                () {
                                  final picked = entry.value
                                      .where((u) =>
                                          _selected.contains(u['imei']))
                                      .length;
                                  final total = entry.value.length;
                                  return picked == 0
                                      ? '$total ${t('transfer.inStock')}'
                                      : '$picked / $total ${t('transfer.selected')}';
                                }(),
                                style: const TextStyle(
                                    fontSize: 11.5, color: AppTheme.ink500),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.chevron_right_rounded,
                            color: AppTheme.ink500),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          t('transfer.noteTotals'),
          style: const TextStyle(
              fontSize: 11, color: AppTheme.ink500, height: 1.4),
        ),
      ],
    );
  }
}
