import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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

  void _showScanImeiDialog() {
    final imeiController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.rXl)),
        title: const Row(
          children: [
            Icon(Icons.qr_code_scanner_rounded, color: AppTheme.brand600),
            SizedBox(width: 8),
            Text('Scan / Intake IMEI', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter or scan GSMA 15-digit IMEI for intake verification:',
              style: TextStyle(fontSize: 12.5, color: AppTheme.ink500),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: imeiController,
              keyboardType: TextInputType.number,
              maxLength: 15,
              decoration: InputDecoration(
                labelText: 'IMEI (15 digits)',
                hintText: '35xxxxxxxxxxxxx',
                prefixIcon: const Icon(Icons.dialpad_rounded, size: 20),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.auto_fix_high_rounded, color: AppTheme.brand600, size: 18),
                  tooltip: 'Generate valid demo IMEI',
                  onPressed: () {
                    imeiController.text = '35${DateTime.now().millisecondsSinceEpoch.toString().padRight(13, '0').substring(0, 13)}';
                  },
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final raw = imeiController.text.trim();
              if (raw.length != 15) {
                LimsToast.show(context, 'IMEI lazima iwe tarakimu 15 kamili (ina ${raw.length})', isError: true);
                return;
              }
              if (_scannedImeis.contains(raw)) {
                LimsToast.show(context, 'IMEI hii ($raw) tayari imeshakaguliwa kwenye mzigo huu!', isError: true);
                return;
              }
              setState(() {
                _scannedImeis.add(raw);
              });
              Navigator.pop(ctx);
              LimsToast.show(context, 'IMEI $raw imehakikiwa na kuongezwa!', isSuccess: true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.brand600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.rSm)),
            ),
            child: const Text('Verify & Add'),
          ),
        ],
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
            title: 'Badili Picha ya Mzigo',
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
                        onPressed: () {
                          setModalState(() {
                            currentAsset = 'assets/images/blue_iphones_duo.png';
                            currentUrl = null;
                          });
                          LimsToast.show(context, 'Picha ya kamera imepigwa na kubanwa kwa WebP (74 KB)!');
                        },
                        icon: const Icon(Icons.camera_alt_rounded, size: 16, color: AppTheme.brand600),
                        label: const Text('Piga Kamera', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.brand600)),
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
                        onPressed: () {
                          setModalState(() {
                            currentAsset = null;
                            currentUrl = 'https://images.unsplash.com/photo-1695048133142-1a20484d2569?w=600&auto=format&fit=crop&q=80';
                          });
                          LimsToast.show(context, 'Picha imechaguliwa kutoka Galari ya simu na kubanwa!');
                        },
                        icon: const Icon(Icons.photo_library_rounded, size: 16, color: AppTheme.brand600),
                        label: const Text('Pakia Galari', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.brand600)),
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
                      LimsToast.show(context, 'Picha ya ${item['name']} imesasishwa!');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.brand600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Thibitisha Picha Mpya', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _confirmReceive() {
    setState(() => _isReceived = true);

    // Update Riverpod inventory stock & image
    for (final item in _items) {
      final id = item['id'] as int;
      final qty = item['qty'] as int;
      ref.read(inventoryProvider.notifier).updateStock(id, qty);
      if (item['asset'] != null || item['url'] != null) {
        ref.read(inventoryProvider.notifier).updateProductImage(
          id,
          imageAsset: item['asset'] as String?,
          imageUrl: item['url'] as String?,
        );
      }
    }

    // Add PO Activity
    ref.read(activitiesProvider.notifier).addActivity(
      ActivityItem(
        icon: Icons.archive_rounded,
        iconColor: AppTheme.brand600,
        bgColor: AppTheme.brand100,
        title: 'Stock Received · PO #4521 (24 units)',
        description: 'From Dar es Salaam Hub · TZS 12.4M',
        time: 'Just now',
      ),
    );

    LimsToast.show(
      context,
      'Stock received & 24 units added to Kariakoo inventory!',
      isSuccess: true,
    );

    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) context.pop();
    });
  }

  @override
  Widget build(BuildContext context) {
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
        title: const Text(
          'Receive Stock',
          style: TextStyle(
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
                        const Text(
                          'Dar es Salaam Hub',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.ink900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'PO #4521 · Arrived 8:30 AM',
                          style: TextStyle(
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
                          child: const Text(
                            '24 units · TZS 12.4M',
                            style: TextStyle(
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
              children: [
                const Icon(Icons.verified_rounded, size: 14, color: AppTheme.successColor),
                const SizedBox(width: 4),
                Text(
                  '24 units in PO · ${_scannedImeis.length} IMEIs scanned & verified',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.ink700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            OutlinedButton.icon(
              onPressed: _showScanImeiDialog,
              icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
              label: const Text('Scan / Add Serial IMEI', style: TextStyle(fontWeight: FontWeight.w700)),
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
                _isReceived ? 'Received & Stored in Inventory' : 'Confirm Receive & Update Stock',
                style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
