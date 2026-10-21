import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../../core/l10n/strings.dart';
import '../../../core/services/app_permissions_service.dart';
import '../../../core/services/imei_scan.dart';
import '../../../core/widgets/imei_scanner_view.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/data/mock_lims_data.dart';
import '../../../core/data/inventory_provider.dart';
import '../../../core/widgets/ui_kit.dart';

class ReceiveStockScreen extends ConsumerStatefulWidget {
  const ReceiveStockScreen({super.key});

  @override
  ConsumerState<ReceiveStockScreen> createState() => _ReceiveStockScreenState();
}

class _ReceiveStockScreenState extends ConsumerState<ReceiveStockScreen> {
  final List<String> _scannedImeis = [
    '358920112849102',
    '358920112849110',
    '864920042819384',
  ];

  final List<Map<String, dynamic>> _items = [
    {
      'id': 1,
      'name': 'iPhone 15 Pro Max',
      'qty': 10,
      'sku': 'IP15PM-256-NT',
      'verified': true,
      'grad': [AppTheme.brand600, AppTheme.brand700],
      'asset': 'assets/images/blue_iphones_duo.png',
      'url': null,
    },
    {
      'id': 2,
      'name': 'Galaxy S24 Ultra',
      'qty': 6,
      'sku': 'SGS24U-256-TG',
      'verified': true,
      'grad': [const Color(0xFF6366F1), const Color(0xFF4338CA)],
      'asset': 'assets/images/samsung_galaxy_ultra.png',
      'url': 'https://images.unsplash.com/photo-1610945265064-0e34e5519bbf?w=600&auto=format&fit=crop&q=80',
    },
    {
      'id': 3,
      'name': 'Redmi Note 13 Pro',
      'qty': 8,
      'sku': 'RN13P-256-MB',
      'verified': true,
      'grad': [const Color(0xFF0EA5E9), const Color(0xFF0369A1)],
      'asset': 'assets/images/redmi_note_13_pro.png',
      'url': 'https://images.unsplash.com/photo-1598327105666-5b89351aff97?w=600&auto=format&fit=crop&q=80',
    },
    {
      'id': 4,
      'name': 'TECNO Camon 30',
      'qty': 5,
      'sku': 'TC30-256-SV',
      'verified': false,
      'grad': [const Color(0xFF06B6D4), const Color(0xFF0E7490)],
      'asset': 'assets/images/tecno_camon_30.png',
      'url': 'https://images.unsplash.com/photo-1511707171634-5f897ff02560?w=600&auto=format&fit=crop&q=80',
    },
  ];

  bool _isReceived = false;

  /// Intake of one serial number, by camera or by hand.
  ///
  /// The dialog used to have a wand button that generated an IMEI from the clock
  /// and accepted it — so a receiving clerk could "verify" 24 units without
  /// touching a single box. The wand is gone. What is left is the camera and the
  /// keypad, and both go through the same check digit: a number that fails it is
  /// a misread, and accepting a misread is worse than asking for a second scan.
  void _showScanImeiDialog() {
    final locale = ref.read(localeProvider);
    final imeiController = TextEditingController();
    final cameraKey = GlobalKey<ImeiScannerViewState>();
    bool cameraOpen = false;

    void submit(BuildContext ctx, StateSetter setDialogState) {
      final raw = imeiController.text.trim();
      final imei = ImeiScan.parseImei(raw) ?? raw.replaceAll(RegExp(r'\D'), '');
      if (imei.length != 15) {
        LimsToast.show(
          context,
          trf(locale, 'stock.errLength', {'n': imei.length}),
          isError: true,
        );
        return;
      }
      if (!ImeiScan.isValid(imei)) {
        LimsToast.show(context, tr(locale, 'scan.invalid'), isError: true);
        return;
      }
      if (_scannedImeis.contains(imei)) {
        LimsToast.show(
          context,
          trf(locale, 'stock.errDuplicate', {'n': imei}),
          isError: true,
        );
        return;
      }
      setState(() {
        _scannedImeis.add(imei);
      });
      Navigator.pop(ctx);
      LimsToast.show(
        context,
        trf(locale, 'stock.okAdded', {'n': imei}),
        isSuccess: true,
      );
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.rXl)),
          title: Row(
            children: [
              const Icon(Icons.qr_code_scanner_rounded, color: AppTheme.brand600),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  tr(locale, 'stock.scanTitle'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr(locale, 'stock.scanHint'),
                  style: const TextStyle(fontSize: 12.5, color: AppTheme.ink500),
                ),
                const SizedBox(height: 12),
                if (cameraOpen) ...[
                  ImeiScannerView(
                    key: cameraKey,
                    locale: locale,
                    height: 200,
                    onImei: (imei) {
                      imeiController.text = imei;
                      setDialogState(() {});
                      submit(ctx, setDialogState);
                    },
                  ),
                  const SizedBox(height: 10),
                ],
                TextField(
                  controller: imeiController,
                  keyboardType: TextInputType.number,
                  maxLength: 20,
                  onChanged: (_) => setDialogState(() {}),
                  decoration: InputDecoration(
                    labelText: 'IMEI',
                    hintText: '35xxxxxxxxxxxxx',
                    prefixIcon: const Icon(Icons.dialpad_rounded, size: 20),
                    suffixIcon: ImeiScan.isValid(
                      imeiController.text.replaceAll(RegExp(r'\D'), ''),
                    )
                        ? const Icon(Icons.check_circle_rounded,
                            color: Color(0xFF10B981), size: 20)
                        : null,
                  ),
                ),
                const SizedBox(height: 4),
                ScanImeiButton(
                  locale: locale,
                  label: tr(locale, 'stock.scanWithCamera'),
                  onPressed: () {
                    setDialogState(() => cameraOpen = !cameraOpen);
                    if (cameraOpen) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        cameraKey.currentState?.start();
                      });
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(tr(locale, 'common.cancel')),
            ),
            ElevatedButton(
              onPressed: () => submit(ctx, setDialogState),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.brand600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.rSm)),
              ),
              child: Text(tr(locale, 'stock.verify')),
            ),
          ],
        ),
      ),
    );
  }

  void _showChangeItemPhotoModal(int index) {
    final item = _items[index];
    String? currentAsset = item['asset'] as String?;
    String? currentUrl = item['url'] as String?;

    final presetOptions = [
      {
        'title': 'iPhone 15 Pro Duo',
        'sub': 'Halisi (Assets)',
        'asset': 'assets/images/blue_iphones_duo.png',
        'url': null,
      },
      {
        'title': 'Galaxy S24 Ultra',
        'sub': 'Titanium Gray',
        'asset': null,
        'url': 'https://images.unsplash.com/photo-1610945265064-0e34e5519bbf?w=600&auto=format&fit=crop&q=80',
      },
      {
        'title': 'Redmi Note 13 Pro',
        'sub': 'Midnight Black',
        'asset': null,
        'url': 'https://images.unsplash.com/photo-1598327105666-5b89351aff97?w=600&auto=format&fit=crop&q=80',
      },
      {
        'title': 'Tecno Camon 30',
        'sub': 'Silver / Camon',
        'asset': null,
        'url': 'https://images.unsplash.com/photo-1511707171634-5f897ff02560?w=600&auto=format&fit=crop&q=80',
      },
      {
        'title': 'Galaxy S24 Ultra (Halisi)',
        'sub': 'Picha ya dukani · offline',
        'asset': 'assets/images/samsung_galaxy_ultra.png',
        'url': null,
      },
      {
        'title': 'Redmi Note 13 Pro (Halisi)',
        'sub': 'Picha ya dukani · offline',
        'asset': 'assets/images/redmi_note_13_pro.png',
        'url': null,
      },
      {
        'title': 'TECNO Camon 30 (Halisi)',
        'sub': 'Picha ya dukani · offline',
        'asset': 'assets/images/tecno_camon_30.png',
        'url': null,
      },
    ];

    LimsBottomSheet.show(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) {
          return LimsBottomSheet(
            title: tr(ref.read(localeProvider), 'stock.changePhoto'),
            subtitle: '${item['name']} · ${item['sku']}',
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppTheme.brand600, width: 2),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x140F3478),
                          blurRadius: 16,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: currentAsset != null && currentAsset!.isNotEmpty
                        ? Image.asset(currentAsset!, fit: BoxFit.contain)
                        : (currentUrl != null && currentUrl!.isNotEmpty
                            ? Image.network(
                                currentUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Center(
                                  child: Icon(Icons.smartphone_rounded, size: 40, color: AppTheme.brand600),
                                ),
                              )
                            : const Center(
                                child: Icon(Icons.smartphone_rounded, size: 40, color: AppTheme.brand600),
                              )),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final allowed = await AppPermissionsService.ensureCamera(context);
                          if (!mounted) return;
                          if (!allowed) {
                            LimsToast.show(context, tr(ref.read(localeProvider), 'stock.cameraNeeded'), isError: true);
                            return;
                          }
                          setModalState(() {
                            currentAsset = 'assets/images/blue_iphones_duo.png';
                            currentUrl = null;
                          });
                          LimsToast.show(context, tr(ref.read(localeProvider), 'stock.photoSaved'));
                        },
                        icon: const Icon(Icons.camera_alt_rounded, size: 16, color: AppTheme.brand600),
                        label: Text(tr(ref.read(localeProvider), 'stock.takePhoto'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.brand600)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFCEE1FE)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await AppPermissionsService.ensureStorage();
                          if (!mounted) return;
                          setModalState(() {
                            currentAsset = null;
                            currentUrl = 'https://images.unsplash.com/photo-1695048133142-1a20484d2569?w=600&auto=format&fit=crop&q=80';
                          });
                          LimsToast.show(context, tr(ref.read(localeProvider), 'stock.photoPicked'));
                        },
                        icon: const Icon(Icons.photo_library_rounded, size: 16, color: AppTheme.brand600),
                        label: Text(tr(ref.read(localeProvider), 'stock.gallery'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.brand600)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFCEE1FE)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.cloud_done_rounded, color: Color(0xFF16A34A), size: 16),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'WebP Compression · Auto-Sync to Supabase Storage (74KB)',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF15803D)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Presets za Picha Halisi:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.ink900),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 80,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: presetOptions.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, idx) {
                      final p = presetOptions[idx];
                      final isChosen = (p['asset'] != null && currentAsset == p['asset']) ||
                          (p['url'] != null && currentUrl == p['url']);
                      return InkWell(
                        onTap: () {
                          setModalState(() {
                            currentAsset = p['asset'];
                            currentUrl = p['url'];
                          });
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: 80,
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: isChosen ? const Color(0xFFEBF3FF) : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isChosen ? AppTheme.brand600 : const Color(0xFFE2E8F0),
                              width: isChosen ? 2 : 1,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: p['asset'] != null
                                    ? Image.asset(p['asset'] as String, fit: BoxFit.contain)
                                    : Image.network(p['url'] as String, fit: BoxFit.cover),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                p['title'] as String,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: isChosen ? AppTheme.brand600 : AppTheme.ink700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _items[index]['asset'] = currentAsset;
                        _items[index]['url'] = currentUrl;
                      });
                      Navigator.pop(ctx);
                      LimsToast.show(context, trf(ref.read(localeProvider), 'stock.photoUpdated', {'n': item['name']}));
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.brand600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(tr(ref.read(localeProvider), 'stock.confirmPhoto'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Applies the delivery to the live catalogue.
  ///
  /// The old version wrote to product ids 1–4, which are the ids of the demo rows
  /// this screen used to carry. Against the real database those rows do not
  /// exist, so `updateStock` found nothing and reported success anyway: stock
  /// never moved. Rows are now matched by SKU against what is actually loaded,
  /// and a shipment line that matches nothing is called out instead of being
  /// counted.
  void _confirmReceive() {
    final locale = ref.read(localeProvider);
    final inventory = ref.read(inventoryProvider);
    var units = 0;
    var matchedLines = 0;
    final unmatched = <String>[];

    for (final item in _items) {
      final sku = item['sku'] as String;
      final qty = item['qty'] as int;
      final match = inventory.where((p) => p.sku == sku).toList();
      if (match.isEmpty) {
        unmatched.add(sku);
        continue;
      }
      matchedLines++;
      units += qty;
      ref.read(inventoryProvider.notifier).updateStock(match.first.id, qty);
      if (item['asset'] != null || item['url'] != null) {
        ref.read(inventoryProvider.notifier).updateProductImage(
          match.first.id,
          imageAsset: item['asset'] as String?,
          imageUrl: item['url'] as String?,
        );
      }
    }

    setState(() => _isReceived = true);

    if (matchedLines == 0) {
      LimsToast.show(
        context,
        'No shipment line matched a product in the catalogue. Nothing was added.',
        isError: true,
      );
      setState(() => _isReceived = false);
      return;
    }

    ref.read(activitiesProvider.notifier).addActivity(
      ActivityItem(
        icon: Icons.archive_rounded,
        iconColor: AppTheme.brand600,
        bgColor: AppTheme.brand100,
        title: trf(locale, 'stock.activityTitle', {'n': units}),
        description: trf(locale, 'stock.receivedAt', {
          'branch': ref.read(activeBranchProvider),
          'scanned': _scannedImeis.length,
        }),
        time: tr(locale, 'common.justNow'),
      ),
    );

    LimsToast.show(
      context,
      trf(locale, 'stock.okReceived', {
        'n': units,
        'branch': ref.read(activeBranchProvider),
      }),
      isSuccess: true,
    );

    if (unmatched.isNotEmpty) {
      // A silent skip is how a delivery becomes a stock discrepancy three weeks
      // later. Say which line did not land.
      Future.delayed(const Duration(milliseconds: 400), () {
        if (!mounted) return;
        LimsToast.show(
          context,
          trf(locale, 'stock.unmatched', {'skus': unmatched.join(', ')}),
          isError: true,
        );
      });
    }

    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) context.pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final inventory = ref.watch(inventoryProvider);

    // Shipment totals are derived, not typed. The card used to read
    // "24 units · TZS 12.4M" no matter what the lines said, and a clerk had no way
    // to notice the figure was decoration.
    final totalUnits = _items.fold<int>(0, (n, i) => n + (i['qty'] as int));
    var totalValue = 0;
    for (final item in _items) {
      final sku = item['sku'] as String;
      final match = inventory.where((p) => p.sku == sku);
      if (match.isEmpty) continue;
      totalValue += match.first.price * (item['qty'] as int);
    }

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
          tr(ref.watch(localeProvider), 'stock.title'),
          style: const TextStyle(
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
            // Shipment Card
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
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppTheme.brand100,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.archive_rounded, color: AppTheme.brand600, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ref.watch(activeBranchProvider),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.ink900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          trf(locale, 'stock.lines', {'n': _items.length}),
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.ink500,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.brand100,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            totalValue > 0
                                ? trf(locale, 'stock.unitsValue', {
                                    'n': totalUnits,
                                    'value':
                                        LimsFormatters.formatNumber(totalValue),
                                  })
                                : trf(locale, 'stock.units', {'n': totalUnits}),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.brand600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Items List
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
                children: _items.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final item = entry.value;
                  final isLast = idx == _items.length - 1;

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      border: isLast ? null : const Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
                    ),
                    child: Row(
                      children: [
                        InkWell(
                          onTap: () => _showChangeItemPhotoModal(idx),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: item['asset'] != null
                                ? Image.asset(item['asset'] as String, fit: BoxFit.contain)
                                : (item['url'] != null
                                    ? Image.network(
                                        item['url'] as String,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Container(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: item['grad'] as List<Color>,
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                          ),
                                          child: const Icon(Icons.smartphone_rounded, color: Colors.white, size: 20),
                                        ),
                                      )
                                    : Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: item['grad'] as List<Color>,
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                        ),
                                        child: const Icon(Icons.smartphone_rounded, color: Colors.white, size: 20),
                                      )),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['name'] as String,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.ink900,
                                ),
                              ),
                              Text(
                                '${item['sku']} · ×${item['qty']}',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.ink500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.photo_camera_rounded, size: 18, color: AppTheme.brand600),
                          onPressed: () => _showChangeItemPhotoModal(idx),
                          tooltip: 'Badili Picha ya Mzigo',
                        ),
                        Container(
                          width: 28,
                          height: 28,
                          decoration: const BoxDecoration(
                            color: Color(0xFFE7F8F0),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.check_rounded, size: 16, color: Color(0xFF12B76A)),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 20),

            // Progress bar
            const ClipRRect(
              borderRadius: BorderRadius.all(Radius.circular(99)),
              child: LinearProgressIndicator(
                value: 1.0,
                minHeight: 6,
                backgroundColor: Color(0xFFE2E8F0),
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.brand600),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.verified_rounded, size: 14, color: AppTheme.successColor),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    trf(locale, 'stock.scannedLine', {
                      'n': totalUnits,
                      'scanned': _scannedImeis.length,
                    }),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.ink700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            OutlinedButton.icon(
              onPressed: _showScanImeiDialog,
              icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
              label: Text(tr(ref.watch(localeProvider), 'stock.scanTitle'), style: const TextStyle(fontWeight: FontWeight.w700)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.brand700,
                side: const BorderSide(color: AppTheme.border, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.rMd)),
              ),
            ),
            const SizedBox(height: 12),

            ElevatedButton(
              onPressed: _isReceived ? null : _confirmReceive,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.brand600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: Text(
                _isReceived
                    ? tr(ref.watch(localeProvider), 'stock.received')
                    : tr(ref.watch(localeProvider), 'stock.confirm'),
                style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
