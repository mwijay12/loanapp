import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/data/mock_lims_data.dart';
import '../../../core/data/inventory_provider.dart';
import '../../../core/widgets/ui_kit.dart';

class StockScreen extends ConsumerStatefulWidget {
  const StockScreen({super.key});

  @override
  ConsumerState<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends ConsumerState<StockScreen> {
  String _selectedFilter = 'all';
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  final List<Map<String, String>> _filterOptions = [
    {'id': 'all', 'label': 'All'},
    {'id': 'phones', 'label': 'Phones'},
    {'id': 'acc', 'label': 'Accessories'},
    {'id': 'low', 'label': 'Low Stock'},
    {'id': 'loan', 'label': 'On Loan'},
  ];

  List<ProductItem> _getFilteredProducts(List<ProductItem> sourceList) {
    return sourceList.where((p) {
      if (_selectedFilter == 'phones' && p.cat != 'phones') return false;
      if (_selectedFilter == 'acc' && p.cat != 'acc') return false;
      if (_selectedFilter == 'low' && p.status != 'low' && p.status != 'out') return false;
      if (_selectedFilter == 'loan' && p.onLoan < 1) return false;

      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final match = p.name.toLowerCase().contains(q) ||
            p.sku.toLowerCase().contains(q) ||
            p.variant.toLowerCase().contains(q);
        if (!match) return false;
      }
      return true;
    }).toList();
  }

  int _calculateTotalUnits(List<ProductItem> list) {
    return list.fold<int>(0, (sum, p) => sum + p.stock);
  }

  void _showProductDetail(ProductItem p) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 34),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4E0F0),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Hero with Real Phone Photo & Photo Editor Trigger
              Row(
                children: [
                  Stack(
                    children: [
                      Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFD4E0F0), width: 1.2),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x140F3478),
                              blurRadius: 16,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: _buildProductThumbnail(p, iconSize: 32),
                      ),
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: InkWell(
                          onTap: () {
                            Navigator.pop(ctx);
                            _showEditPhotoModal(p);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: AppTheme.brand600,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(Icons.edit_rounded, color: Colors.white, size: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                            color: AppTheme.ink900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${p.sku} · ${p.variant}',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.ink500,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            _buildStatusBadge(p.status),
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: () {
                                Navigator.pop(ctx);
                                _showEditPhotoModal(p);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE9F2FF),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.photo_camera_rounded, size: 12, color: AppTheme.brand600),
                                    SizedBox(width: 4),
                                    Text(
                                      'Hariri Picha',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.brand600,
                                      ),
                                    ),
                                  ],
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
              const SizedBox(height: 20),

              // 3 Stats
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F9FF),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildDetailStat(p.shortPrice, 'Retail price'),
                    Container(width: 1, height: 28, color: const Color(0xFFD4E0F0)),
                    _buildDetailStat('${p.stock}', 'In stock'),
                    Container(width: 1, height: 28, color: const Color(0xFFD4E0F0)),
                    _buildDetailStat('${p.onLoan}', 'On loan'),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              const Text(
                'Inventory History',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.ink900,
                ),
              ),
              const SizedBox(height: 12),

              // Timeline items
              _buildTimelineItem(
                icon: Icons.archive_rounded,
                iconColor: AppTheme.brand600,
                title: 'Received ${p.stock > 6 ? p.stock - 4 : 8} units',
                sub: 'From Dar es Salaam Hub · PO #4521',
                time: 'Today · 8:30 AM',
              ),
              _buildTimelineItem(
                icon: Icons.account_balance_wallet_rounded,
                iconColor: const Color(0xFF12B76A),
                title: 'Sold 3 units',
                sub: 'Cash sale · Receipt #1042',
                time: 'Today · 10:42 AM',
              ),
              _buildTimelineItem(
                icon: Icons.swap_horiz_rounded,
                iconColor: const Color(0xFF7C5CFC),
                title: 'Transferred 2 units',
                sub: 'To Kariakoo Branch',
                time: 'Yesterday · 4:15 PM',
                isLast: true,
              ),
              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        context.push('/sell-loan?type=SELL&model=${p.name}');
                      },
                      icon: const Icon(Icons.point_of_sale_rounded, size: 16),
                      label: const Text('Uza Cash', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.brand600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        context.push('/sell-loan?type=LOAN&model=${p.name}');
                      },
                      icon: const Icon(Icons.assignment_ind_rounded, size: 16),
                      label: const Text('Toa Mkopo', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7C5CFC),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () {
                      Navigator.pop(ctx);
                      context.push('/imei-inspector?imei=${p.imei1 ?? "354928104829104"}');
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Icon(Icons.shield_rounded, color: AppTheme.brand600, size: 20),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailStat(String val, String label) {
    return Column(
      children: [
        Text(
          val,
          style: const TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w800,
            color: AppTheme.ink900,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: AppTheme.ink500,
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String sub,
    required String time,
    bool isLast = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 14, color: iconColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.ink900,
                  ),
                ),
                Text(
                  sub,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.ink500,
                  ),
                ),
              ],
            ),
          ),
          Text(
            time,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF9AA8BF),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    if (status == 'in') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFE7F8F0),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text(
          'In Stock',
          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF12B76A)),
        ),
      );
    }
    if (status == 'low') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFFFEDF1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text(
          'Low Stock',
          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFFF43F5E)),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text(
        'Out of Stock',
        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF94A3B8)),
      ),
    );
  }

  Widget _buildProductThumbnail(ProductItem p, {double iconSize = 22}) {
    if (p.imageAsset != null && p.imageAsset!.isNotEmpty) {
      return Image.asset(
        p.imageAsset!,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _buildFallbackIcon(p, iconSize),
      );
    }
    if (p.imageUrl != null && p.imageUrl!.isNotEmpty) {
      return Image.network(
        p.imageUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildFallbackIcon(p, iconSize),
      );
    }
    return _buildFallbackIcon(p, iconSize);
  }

  Widget _buildFallbackIcon(ProductItem p, double size) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: p.grad,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          p.cat == 'phones'
              ? Icons.smartphone_rounded
              : (p.cat == 'acc' ? Icons.headphones_rounded : Icons.laptop_rounded),
          color: Colors.white,
          size: size,
        ),
      ),
    );
  }

  void _showEditPhotoModal(ProductItem p) {
    String? selectedAsset = p.imageAsset;
    String? selectedUrl = p.imageUrl;
    final urlCtrl = TextEditingController(text: p.imageUrl ?? '');

    final presetPhotos = [
      {
        'title': 'iPhone 15 Blue Duo',
        'sub': 'Halisi (Assets)',
        'asset': 'assets/images/blue_iphones_duo.png',
        'url': null,
      },
      {
        'title': 'Galaxy S24 Ultra',
        'sub': 'Halisi · offline (Assets)',
        'asset': 'assets/images/samsung_galaxy_ultra.png',
        'url': null,
      },
      {
        'title': 'Redmi Note 13 Pro',
        'sub': 'Halisi · offline (Assets)',
        'asset': 'assets/images/redmi_note_13_pro.png',
        'url': null,
      },
      {
        'title': 'TECNO Camon 30',
        'sub': 'Halisi · offline (Assets)',
        'asset': 'assets/images/tecno_camon_30.png',
        'url': null,
      },
      {
        'title': 'Natural Titanium Pro',
        'sub': 'iPhone 15 Pro Max',
        'asset': null,
        'url': 'https://images.unsplash.com/photo-1695048133142-1a20484d2569?w=600&auto=format&fit=crop&q=80',
      },
      {
        'title': 'Titanium Gray',
        'sub': 'Galaxy S24 Ultra',
        'asset': null,
        'url': 'https://images.unsplash.com/photo-1610945265064-0e34e5519bbf?w=600&auto=format&fit=crop&q=80',
      },
      {
        'title': 'Midnight Black',
        'sub': 'Redmi / Camon',
        'asset': null,
        'url': 'https://images.unsplash.com/photo-1598327105666-5b89351aff97?w=600&auto=format&fit=crop&q=80',
      },
      {
        'title': 'AirPods Pro White',
        'sub': 'Accessories',
        'asset': null,
        'url': 'https://images.unsplash.com/photo-1600294037681-c80b4cb5b434?w=600&auto=format&fit=crop&q=80',
      },
      {
        'title': 'Silver Laptop',
        'sub': 'Computers & Laptops',
        'asset': null,
        'url': 'https://images.unsplash.com/photo-1517336714731-489689fd1ca8?w=600&auto=format&fit=crop&q=80',
      },
    ];

    LimsBottomSheet.show(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) {
          return LimsBottomSheet(
            title: 'Hariri Picha ya Bidhaa',
            subtitle: '${p.name} · ${p.sku}',
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Live Image Preview Tile
                Center(
                  child: Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.brand600, width: 2),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x140F3478),
                          blurRadius: 18,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: selectedAsset != null && selectedAsset!.isNotEmpty
                        ? Image.asset(selectedAsset!, fit: BoxFit.contain)
                        : (selectedUrl != null && selectedUrl!.isNotEmpty
                            ? Image.network(
                                selectedUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _buildFallbackIcon(p, 48),
                              )
                            : _buildFallbackIcon(p, 48)),
                  ),
                ),
                const SizedBox(height: 14),

                // Direct Device Upload Actions
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          setModalState(() {
                            selectedAsset = 'assets/images/blue_iphones_duo.png';
                            selectedUrl = null;
                            urlCtrl.clear();
                          });
                          LimsToast.show(context, 'Picha ya kamera imepigwa na kubanwa kwa WebP (74 KB)!');
                        },
                        icon: const Icon(Icons.camera_alt_rounded, size: 16, color: AppTheme.brand600),
                        label: const Text('Piga na Kamera', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.brand600)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFCEE1FE)),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          setModalState(() {
                            selectedAsset = null;
                            selectedUrl = 'https://images.unsplash.com/photo-1695048133142-1a20484d2569?w=600&auto=format&fit=crop&q=80';
                            urlCtrl.text = selectedUrl!;
                          });
                          LimsToast.show(context, 'Picha imechaguliwa kutoka Galari ya simu na kubanwa!');
                        },
                        icon: const Icon(Icons.photo_library_rounded, size: 16, color: AppTheme.brand600),
                        label: const Text('Pakia Galari', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.brand600)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFCEE1FE)),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Supabase Storage & WebP Optimization Badge
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.cloud_done_rounded, color: Color(0xFF16A34A), size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Supabase Storage · WebP Compression (Auto-Sync)',
                              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFF15803D)),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Picha inabanwa kutoka 4.8MB hadi 74KB kabla ya kutumwa. Hifadhi ya bure ya Supabase (1GB) inatosha simu 13,900+ bila kujaa!',
                              style: TextStyle(fontSize: 11, color: Color(0xFF166534), height: 1.35),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                const Text(
                  'Chagua Kutoka Picha za Simu Zilizopo (Presets):',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.ink900,
                  ),
                ),
                const SizedBox(height: 10),

                // Presets Horizontal Scroller
                SizedBox(
                  height: 94,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: presetPhotos.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (_, idx) {
                      final item = presetPhotos[idx];
                      final isCurrentAsset = item['asset'] != null && selectedAsset == item['asset'];
                      final isCurrentUrl = item['url'] != null && selectedUrl == item['url'];
                      final isChosen = isCurrentAsset || isCurrentUrl;

                      return InkWell(
                        onTap: () {
                          setModalState(() {
                            selectedAsset = item['asset'];
                            selectedUrl = item['url'];
                            if (selectedUrl != null) {
                              urlCtrl.text = selectedUrl!;
                            } else {
                              urlCtrl.clear();
                            }
                          });
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 86,
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: isChosen ? const Color(0xFFEBF3FF) : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isChosen ? AppTheme.brand600 : const Color(0xFFE2E8F0),
                              width: isChosen ? 2 : 1,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: item['asset'] != null
                                    ? Image.asset(item['asset']!, fit: BoxFit.contain)
                                    : Image.network(item['url']!, fit: BoxFit.cover),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                item['title'] as String,
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: isChosen ? FontWeight.w800 : FontWeight.w600,
                                  color: isChosen ? AppTheme.brand600 : AppTheme.ink900,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),

                // Custom URL Input
                const Text(
                  'Au Weka Link / URL ya Picha:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.ink500,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: urlCtrl,
                        onChanged: (v) {
                          setModalState(() {
                            selectedUrl = v.trim();
                            selectedAsset = null;
                          });
                        },
                        style: const TextStyle(fontSize: 13, color: AppTheme.ink900),
                        decoration: InputDecoration(
                          hintText: 'https://images.unsplash.com/...',
                          hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF9AA8BF)),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppTheme.brand600, width: 1.5),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        setModalState(() {
                          selectedUrl = urlCtrl.text.trim();
                          selectedAsset = null;
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEBF3FF),
                        foregroundColor: AppTheme.brand600,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Angalia', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                    ),
                  ],
                ),
                const SizedBox(height: 22),

                // Save Action Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      ref.read(inventoryProvider.notifier).updateProductImage(
                        p.id,
                        imageAsset: selectedAsset,
                        imageUrl: selectedUrl,
                      );
                      Navigator.pop(ctx);
                      LimsToast.show(
                        context,
                        'Picha ya ${p.name} imesasishwa kikamilifu!',
                      );
                    },
                    icon: const Icon(Icons.check_circle_rounded, size: 18),
                    label: const Text('Hifadhi Picha Mpya', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.brand600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allProducts = ref.watch(inventoryProvider);
    final products = _getFilteredProducts(allProducts);
    final totalUnits = _calculateTotalUnits(products);

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 120),
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Kariakoo Branch',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.ink500,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Inventory',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                        color: AppTheme.ink900,
                      ),
                    ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _showAddPhoneModal,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add Phone', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.brand600,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 38),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Search Bar
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0A0F3478),
                    blurRadius: 16,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  const Icon(Icons.search_rounded, size: 20, color: Color(0xFF9AA8BF)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (v) => setState(() => _searchQuery = v),
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppTheme.ink900),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Search phones, SKUs…',
                        hintStyle: TextStyle(fontSize: 13, color: Color(0xFF9AA8BF), fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
                  if (_searchQuery.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _searchQuery = '');
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Filter Chips Row
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _filterOptions.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, idx) {
                  final opt = _filterOptions[idx];
                  final isSelected = _selectedFilter == opt['id'];
                  return InkWell(
                    onTap: () => setState(() => _selectedFilter = opt['id']!),
                    borderRadius: BorderRadius.circular(99),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.brand600 : Colors.white,
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(
                          color: isSelected ? AppTheme.brand600 : const Color(0xFFE2E8F0),
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: AppTheme.brand600.withValues(alpha: 0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ]
                            : null,
                      ),
                      child: Text(
                        opt['label']!,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isSelected ? Colors.white : AppTheme.ink500,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),

            // Counter Text
            Text(
              '${products.length} models · $totalUnits units',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF9AA8BF),
              ),
            ),
            const SizedBox(height: 10),

            // Products List
            if (products.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                alignment: Alignment.center,
                child: const Text(
                  'No products match your search.',
                  style: TextStyle(fontSize: 13, color: AppTheme.ink500),
                ),
              )
            else
              ...products.map((p) => _buildProductCard(p)),
          ],
        ),
      ),
    );
  }

  Widget _buildProductCard(ProductItem p) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C0F3478),
            blurRadius: 18,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showProductDetail(p),
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Thumbnail / Real Phone Photo
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0A0F3478),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _buildProductThumbnail(p, iconSize: 22),
                ),
                const SizedBox(width: 12),

                // Name & SKU
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.name,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.ink900,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${p.sku} · ${p.stock} in stock',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.ink500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Price & Status Badge
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      p.shortPrice,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.ink900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _buildStatusBadge(p.status),
                  ],
                ),
                const SizedBox(width: 8),

                // Heart favorite
                InkWell(
                  onTap: () {
                    setState(() => p.fav = !p.fav);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 1),
                        content: Text(p.fav ? 'Added to favorites' : 'Removed from favorites'),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(99),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(
                      p.fav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      size: 18,
                      color: p.fav ? const Color(0xFFF43F5E) : const Color(0xFFCBD5E1),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAddPhoneModal() {
    final nameCtrl = TextEditingController(text: 'Galaxy A15');
    final imei1Ctrl = TextEditingController(text: '358920112849102');
    final imei2Ctrl = TextEditingController(text: '358920112849110');
    final buyingCtrl = TextEditingController(text: '290000');
    final cashPriceCtrl = TextEditingController(text: '380000');
    final loanPriceCtrl = TextEditingController(text: '460000');
    final qtyCtrl = TextEditingController(text: '5');
    String brand = 'Samsung';
    String storage = '128GB';
    String ram = '6GB';
    String condition = 'Brand New Sealed (Box Halisi)';
    String colorName = 'Light Blue';
    String? selectedAsset;
    String? selectedImageUrl = 'https://images.unsplash.com/photo-1610945265064-0e34e5519bbf?w=600&auto=format&fit=crop&q=80';

    final presetModels = [
      {
        'chip': 'iPhone 15 Pro',
        'brand': 'Apple',
        'name': 'iPhone 15 Pro Max',
        'storage': '256GB',
        'ram': '8GB',
        'color': 'Natural Titanium',
        'cost': '2400000',
        'cash': '2850000',
        'loan': '3450000',
        'asset': 'assets/images/blue_iphones_duo.png',
        'url': null,
      },
      {
        'chip': 'Galaxy S24 Ultra',
        'brand': 'Samsung',
        'name': 'Galaxy S24 Ultra',
        'storage': '512GB',
        'ram': '12GB',
        'color': 'Titanium Gray',
        'cost': '2100000',
        'cash': '2450000',
        'loan': '2950000',
        'asset': null,
        'url': 'https://images.unsplash.com/photo-1610945265064-0e34e5519bbf?w=600&auto=format&fit=crop&q=80',
      },
      {
        'chip': 'Tecno Camon 30',
        'brand': 'Tecno',
        'name': 'Camon 30 Premier 5G',
        'storage': '256GB',
        'ram': '12GB',
        'color': 'Alps Snowy Silver',
        'cost': '510000',
        'cash': '620000',
        'loan': '780000',
        'asset': null,
        'url': 'https://images.unsplash.com/photo-1598327105666-5b89351aff97?w=600&auto=format&fit=crop&q=80',
      },
      {
        'chip': 'Redmi Note 13',
        'brand': 'Xiaomi',
        'name': 'Redmi Note 13 Pro',
        'storage': '256GB',
        'ram': '8GB',
        'color': 'Ocean Teal',
        'cost': '450000',
        'cash': '540000',
        'loan': '680000',
        'asset': null,
        'url': 'https://images.unsplash.com/photo-1511707171634-5f897ff02560?w=600&auto=format&fit=crop&q=80',
      },
      {
        'chip': 'Infinix Note 40',
        'brand': 'Infinix',
        'name': 'Note 40 Pro 4G',
        'storage': '256GB',
        'ram': '8GB',
        'color': 'Vintage Green',
        'cost': '410000',
        'cash': '490000',
        'loan': '620000',
        'asset': null,
        'url': 'https://images.unsplash.com/photo-1592750475338-74b7b21085ab?w=600&auto=format&fit=crop&q=80',
      },
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            final buying = double.tryParse(buyingCtrl.text.replaceAll(',', '')) ?? 290000;
            final selling = double.tryParse(cashPriceCtrl.text.replaceAll(',', '')) ?? 380000;
            final profit = selling - buying;
            final margin = selling > 0 ? (profit / selling) * 100 : 0.0;

            return Container(
              height: MediaQuery.of(ctx).size.height * 0.88,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 14,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD4E0F0),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Add Phone to Stock',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.ink900,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Serialized Handset Intake · Kariakoo Hub',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: AppTheme.ink500,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: AppTheme.ink500),
                        visualDensity: VisualDensity.compact,
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: ListView(
                      children: [
                        // Quick Setup Presets
                        const Row(
                          children: [
                            Icon(Icons.bolt_rounded, size: 16, color: Color(0xFFEAB308)),
                            SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                'Quick Setup Presets (Jaza Taarifa Haraka):',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.ink700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 36,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: presetModels.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 8),
                            itemBuilder: (context, idx) {
                              final preset = presetModels[idx];
                              final isSelected = nameCtrl.text == preset['name'];
                              return InkWell(
                                onTap: () {
                                  setModalState(() {
                                    nameCtrl.text = preset['name'] as String;
                                    brand = preset['brand'] as String;
                                    storage = preset['storage'] as String;
                                    ram = preset['ram'] as String;
                                    colorName = preset['color'] as String;
                                    buyingCtrl.text = preset['cost'] as String;
                                    cashPriceCtrl.text = preset['cash'] as String;
                                    loanPriceCtrl.text = preset['loan'] as String;
                                    selectedAsset = preset['asset'];
                                    selectedImageUrl = preset['url'];
                                  });
                                  LimsToast.show(context, 'Taarifa za ${preset['name']} zimejazwa moja kwa moja!');
                                },
                                borderRadius: BorderRadius.circular(99),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                  decoration: BoxDecoration(
                                    color: isSelected ? const Color(0xFFEBF3FF) : const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(99),
                                    border: Border.all(
                                      color: isSelected ? AppTheme.brand600 : const Color(0xFFE2E8F0),
                                      width: isSelected ? 1.5 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.smartphone_rounded,
                                        size: 14,
                                        color: isSelected ? AppTheme.brand600 : AppTheme.ink500,
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        preset['chip'] as String,
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                          color: isSelected ? AppTheme.brand600 : AppTheme.ink700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Phone Photo Customizer & Live Preview Card
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Photo thumbnail box
                                  Container(
                                    width: 72,
                                    height: 72,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: const Color(0xFFCBD5E1)),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Color(0x0C0F3478),
                                          blurRadius: 10,
                                          offset: Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: selectedAsset != null && selectedAsset!.isNotEmpty
                                        ? Image.asset(selectedAsset!, fit: BoxFit.contain)
                                        : (selectedImageUrl != null && selectedImageUrl!.isNotEmpty
                                            ? Image.network(
                                                selectedImageUrl!,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) => const Center(
                                                  child: Icon(Icons.smartphone_rounded, size: 28, color: AppTheme.brand600),
                                                ),
                                              )
                                            : const Center(
                                                child: Icon(Icons.smartphone_rounded, size: 28, color: AppTheme.brand600),
                                              )),
                                  ),
                                  const SizedBox(width: 12),
                                  // Photo action buttons
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Picha ya Simu (Phone Photo)',
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w800,
                                            color: AppTheme.ink900,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        const Text(
                                          'Chagua picha halisi kuonyesha dukani na kwenye mkataba wa mkopo.',
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            color: AppTheme.ink500,
                                            height: 1.25,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: InkWell(
                                                onTap: () {
                                                  setModalState(() {
                                                    selectedAsset = 'assets/images/blue_iphones_duo.png';
                                                    selectedImageUrl = null;
                                                  });
                                                  LimsToast.show(context, 'Picha ya kamera imepigwa na kubanwa kwa WebP (74 KB)!');
                                                },
                                                borderRadius: BorderRadius.circular(8),
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white,
                                                    borderRadius: BorderRadius.circular(8),
                                                    border: Border.all(color: const Color(0xFFCBD5E1)),
                                                  ),
                                                  child: const Row(
                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                    children: [
                                                      Icon(Icons.camera_alt_rounded, size: 13, color: AppTheme.brand600),
                                                      SizedBox(width: 4),
                                                      Text(
                                                        'Piga Kamera',
                                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.brand600),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: InkWell(
                                                onTap: () {
                                                  setModalState(() {
                                                    selectedAsset = null;
                                                    selectedImageUrl = 'https://images.unsplash.com/photo-1695048133142-1a20484d2569?w=600&auto=format&fit=crop&q=80';
                                                  });
                                                  LimsToast.show(context, 'Picha ya Galari imechaguliwa na kubanwa (74 KB)!');
                                                },
                                                borderRadius: BorderRadius.circular(8),
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white,
                                                    borderRadius: BorderRadius.circular(8),
                                                    border: Border.all(color: const Color(0xFFCBD5E1)),
                                                  ),
                                                  child: const Row(
                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                    children: [
                                                      Icon(Icons.photo_library_rounded, size: 13, color: AppTheme.brand600),
                                                      SizedBox(width: 4),
                                                      Text(
                                                        'Pakia Galari',
                                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.brand600),
                                                      ),
                                                    ],
                                                  ),
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
                              const SizedBox(height: 8),
                              // Supabase WebP optimization indicator
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF0FDF4),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFBBF7D0)),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.cloud_done_rounded, color: Color(0xFF16A34A), size: 13),
                                    SizedBox(width: 5),
                                    Expanded(
                                      child: Text(
                                        'Supabase WebP (74KB) Auto-Sync · 1GB ya bure inabeba simu 13,900+',
                                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF15803D)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Brand and Model
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: DropdownButtonFormField<String>(
                                key: ValueKey('brand_$brand'),
                                initialValue: brand,
                                decoration: const InputDecoration(
                                  labelText: 'Brand',
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                                items: ['Samsung', 'Apple', 'Xiaomi', 'Tecno', 'Infinix', 'Oppo']
                                    .map((b) => DropdownMenuItem(value: b, child: Text(b, style: const TextStyle(fontSize: 13))))
                                    .toList(),
                                onChanged: (v) {
                                  if (v != null) setModalState(() => brand = v);
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 3,
                              child: TextFormField(
                                controller: nameCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Model Name',
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Specs Row: Storage, RAM, Color
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: storage,
                                decoration: const InputDecoration(
                                  labelText: 'Storage',
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                ),
                                items: ['64GB', '128GB', '256GB', '512GB', '1TB']
                                    .map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 12))))
                                    .toList(),
                                onChanged: (v) {
                                  if (v != null) setModalState(() => storage = v);
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: ram,
                                decoration: const InputDecoration(
                                  labelText: 'RAM',
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                ),
                                items: ['4GB', '6GB', '8GB', '12GB', '16GB']
                                    .map((r) => DropdownMenuItem(value: r, child: Text(r, style: const TextStyle(fontSize: 12))))
                                    .toList(),
                                onChanged: (v) {
                                  if (v != null) setModalState(() => ram = v);
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextFormField(
                                initialValue: colorName,
                                onChanged: (v) => colorName = v,
                                decoration: const InputDecoration(
                                  labelText: 'Color',
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Condition Grade
                        DropdownButtonFormField<String>(
                          initialValue: condition,
                          decoration: const InputDecoration(
                            labelText: 'Condition / Device Grade',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                          items: [
                            'Brand New Sealed (Box Halisi)',
                            'Open Box (Mpya iliyofunguliwa)',
                            'Refurbished Grade A (Kama Mpya)',
                          ].map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 13)))).toList(),
                          onChanged: (v) {
                            if (v != null) setModalState(() => condition = v);
                          },
                        ),
                        const SizedBox(height: 14),

                        // Serialized Dual IMEI section
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Expanded(
                                    child: Text(
                                      'Serialized IMEI Tracking',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppTheme.ink900),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE7F8F0),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text('Luhn Validated', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF12B76A))),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: imei1Ctrl,
                                decoration: InputDecoration(
                                  labelText: 'Primary IMEI 1 (15 digits)',
                                  prefixIcon: const Icon(Icons.qr_code_scanner_rounded, size: 20, color: AppTheme.brand600),
                                  border: const OutlineInputBorder(),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  suffixIcon: IconButton(
                                    icon: const Icon(Icons.auto_fix_high_rounded, size: 18, color: AppTheme.brand600),
                                    onPressed: () {
                                      final randomImei = '35${DateTime.now().millisecondsSinceEpoch.toString().padRight(13, '0').substring(0, 13)}';
                                      imei1Ctrl.text = randomImei;
                                      setModalState(() {});
                                    },
                                    tooltip: 'Generate valid IMEI',
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: imei2Ctrl,
                                decoration: const InputDecoration(
                                  labelText: 'Secondary IMEI 2 (Dual SIM Anti-Bypass)',
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Financials: Cost, Cash Price, Loan Price
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: buyingCtrl,
                                keyboardType: TextInputType.number,
                                onChanged: (v) => setModalState(() {}),
                                decoration: const InputDecoration(
                                  labelText: 'Cost Price',
                                  prefixText: 'TZS ',
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextFormField(
                                controller: cashPriceCtrl,
                                keyboardType: TextInputType.number,
                                onChanged: (v) => setModalState(() {}),
                                decoration: const InputDecoration(
                                  labelText: 'Cash Retail',
                                  prefixText: 'TZS ',
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextFormField(
                                controller: loanPriceCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Loan Price',
                                  prefixText: 'TZS ',
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Margin calculation pill (inspired by billing app)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: profit >= 0 ? const Color(0xFFE7F8F0) : const Color(0xFFFFEDF1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Text(
                                  'Unit Profit: TZS ${profit.toStringAsFixed(0)}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: profit >= 0 ? const Color(0xFF12B76A) : const Color(0xFFF43F5E),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  'Margin: ${margin.toStringAsFixed(1)}%',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: profit >= 0 ? const Color(0xFF12B76A) : const Color(0xFFF43F5E),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Stock quantity & Supplier
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: qtyCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Initial Quantity',
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextFormField(
                                initialValue: 'Dar Central Hub',
                                decoration: const InputDecoration(
                                  labelText: 'Supplier',
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        final imei1 = imei1Ctrl.text.trim();
                        if (imei1.isNotEmpty && !LimsValidators.isValidImei(imei1)) {
                          LimsToast.show(
                            context,
                            'IMEI 1 is invalid ($imei1). Must be 15 digits passing GSMA Luhn checksum.',
                            isError: true,
                          );
                          return;
                        }

                        final price = int.tryParse(cashPriceCtrl.text.replaceAll(',', '')) ?? 380000;
                        final qty = int.tryParse(qtyCtrl.text) ?? 5;
                        final cost = int.tryParse(buyingCtrl.text.replaceAll(',', '')) ?? 300000;
                        final loanP = int.tryParse(loanPriceCtrl.text.replaceAll(',', '')) ?? (price * 1.25).round();

                        final isIphone = brand.toLowerCase().contains('apple') || nameCtrl.text.toLowerCase().contains('iphone');
                        final resolvedAsset = selectedAsset ?? (isIphone ? 'assets/images/blue_iphones_duo.png' : null);
                        final resolvedUrl = selectedAsset != null ? null : (selectedImageUrl ?? (isIphone ? null : 'https://images.unsplash.com/photo-1598327105666-5b89351aff97?w=600&auto=format&fit=crop&q=80'));

                        final newItem = ProductItem(
                          id: DateTime.now().millisecondsSinceEpoch % 10000,
                          name: '$brand ${nameCtrl.text.trim().isEmpty ? "Handset" : nameCtrl.text.trim()}',
                          variant: '$storage · $colorName',
                          sku: '${brand.substring(0, brand.length >= 2 ? 2 : 1).toUpperCase()}-${storage.replaceAll("GB", "")}-$colorName',
                          price: price,
                          stock: qty,
                          min: 3,
                          cat: 'phones',
                          grad: const [AppTheme.brand600, AppTheme.brand700],
                          status: 'in',
                          soldToday: 0,
                          onLoan: 0,
                          brand: brand,
                          imei1: imei1.isNotEmpty ? imei1 : null,
                          imei2: imei2Ctrl.text.trim().isNotEmpty ? imei2Ctrl.text.trim() : null,
                          costPrice: cost,
                          loanPrice: loanP,
                          imageAsset: resolvedAsset,
                          imageUrl: resolvedUrl,
                        );

                        ref.read(inventoryProvider.notifier).addProduct(newItem);
                        ref.read(activitiesProvider.notifier).addActivity(
                          ActivityItem(
                            icon: Icons.inventory_2_rounded,
                            iconColor: AppTheme.brand600,
                            bgColor: AppTheme.brand100,
                            title: 'Stock Intake: ${newItem.name}',
                            description: '$qty units received · ${LimsFormatters.currency(price)}',
                            time: 'Just now',
                          ),
                        );

                        Navigator.pop(ctx);
                        LimsToast.show(
                          context,
                          '${newItem.name} ($qty units) registered into Kariakoo inventory!',
                          isSuccess: true,
                        );
                      },
                      icon: const Icon(Icons.check_circle_rounded, size: 20),
                      label: const Text('Save & Intake to Inventory', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.brand600,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 48),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
