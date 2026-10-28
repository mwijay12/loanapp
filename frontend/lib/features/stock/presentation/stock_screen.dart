import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/data/mock_lims_data.dart';
import '../../../core/data/inventory_provider.dart';
import '../../../core/services/haptics.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../core/l10n/strings.dart';
import '../../../core/data/product_art.dart';
import '../../../core/services/cloudinary_service.dart';
import '../../../core/data/supabase_source.dart';
import '../../../core/widgets/view_toggle.dart';

class StockScreen extends ConsumerStatefulWidget {
  const StockScreen({super.key});

  @override
  ConsumerState<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends ConsumerState<StockScreen> {
  String _selectedFilter = 'all';
  String _searchQuery = '';
  /// Rows or cards. Held per visit: the stock list is a browsing surface, and a
  /// remembered preference is one more thing to explain when it disagrees with
  /// what the counter expects to see.
  CollectionView _view = CollectionView.list;
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
    final locale = ref.read(localeProvider);
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
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.photo_camera_rounded, size: 12, color: AppTheme.brand600),
                                    const SizedBox(width: 4),
                                    Text(
                                      tr(locale, 'stock.editPhoto'),
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
              const SizedBox(height: 18),

              // Stock Management Actions (Storekeeper / Manager / Admin)
              if (UserRoles.canManageStock(ref.read(userRoleProvider))) ...[
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          Navigator.pop(ctx);
                          _showAdjustStockModal(p, true);
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE7F8F0),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFBBF7D0)),
                          ),
                          child: const Column(
                            children: [
                              Icon(Icons.add_circle_outline_rounded,
                                  color: Color(0xFF12B76A), size: 20),
                              SizedBox(height: 4),
                              Text(
                                'Add Stock',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF027A48),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          Navigator.pop(ctx);
                          _showAdjustStockModal(p, false);
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF1F2),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFFECDD3)),
                          ),
                          child: const Column(
                            children: [
                              Icon(Icons.remove_circle_outline_rounded,
                                  color: Color(0xFFF43F5E), size: 20),
                              SizedBox(height: 4),
                              Text(
                                'Reduce Stock',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFFB91C1C),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
              ],

              _buildOfferSwitch(p, locale),
              const SizedBox(height: 16),

              Text(
                tr(locale, 'stock.inventoryHistory'),
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
                      label: Text(tr(locale, 'stock.sellCash'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
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
                      label: Text(tr(locale, 'stock.issueLoan'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
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
                      // This used to open the inspector on a hardcoded serial
                      // when the product had none on file, so the screen showed
                      // a full history for a handset nobody selected.
                      final serial = p.imei1;
                      if (serial == null || serial.isEmpty) {
                        LimsToast.show(context, tr(locale, 'stock.noSerialOnFile'));
                        return;
                      }
                      context.push('/imei-inspector?imei=$serial');
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

  /// The owner's switch: put this handset in front of the cashier.
  ///
  /// Reads the live product rather than the value captured when the sheet
  /// opened, so the switch shows what is actually stored — including a rollback
  /// when the write did not land.
  Widget _buildOfferSwitch(ProductItem p, Locale locale) {
    return Consumer(
      builder: (context, ref, _) {
        final current = ref
            .watch(inventoryProvider)
            .firstWhere((x) => x.id == p.id, orElse: () => p);
        return Container(
          padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBEB),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFDE68A)),
          ),
          child: Row(
            children: [
              const Icon(Icons.local_fire_department_rounded,
                  size: 20, color: Color(0xFFD97706)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr(locale, 'stock.onOffer'),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.ink900,
                      ),
                    ),
                    Text(
                      tr(locale, 'stock.onOfferSub'),
                      style: const TextStyle(
                        fontSize: 10.5,
                        height: 1.3,
                        color: AppTheme.ink500,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: current.onOffer,
                onChanged: (value) => _setOffer(ref, p, value),
                thumbColor: WidgetStatePropertyAll( const Color(0xFFD97706)),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Writes the flag, and puts the switch back if the write did not land.
  ///
  /// A switch that stays on after a failed write is the exact failure this
  /// project keeps finding: state on screen that the database never received.
  Future<void> _setOffer(WidgetRef ref, ProductItem p, bool value) async {
    final locale = ref.read(localeProvider);
    final previous = p.onOffer;
    ref.read(inventoryProvider.notifier).setOffer(p.id, value);

    final outcome = await SupabaseSource.setProductOffer(
      productId: p.id,
      onOffer: value,
    );
    if (!mounted) return;

    switch (outcome) {
      case OfferSaveOutcome.saved:
        LimsToast.show(context, tr(locale, 'stock.offerSaved'), isSuccess: true);
      case OfferSaveOutcome.notConfigured:
        // Demo and offline builds have no ledger. The choice holds for this
        // session and says so.
        LimsToast.show(context, tr(locale, 'stock.offerSession'));
      case OfferSaveOutcome.migrationMissing:
        ref.read(inventoryProvider.notifier).setOffer(p.id, previous);
        LimsToast.show(context, tr(locale, 'stock.offerMigration'), isError: true);
      case OfferSaveOutcome.failed:
        ref.read(inventoryProvider.notifier).setOffer(p.id, previous);
        LimsToast.show(context, tr(locale, 'stock.offerFailed'), isError: true);
    }
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
              color: iconColor.withOpacity(0.12),
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
    Color bgColor;
    Color textColor;
    String label;

    if (status == 'in') {
      bgColor = const Color(0xFFE8F9F0);
      textColor = const Color(0xFF12B76A);
      label = 'In Stock';
    } else if (status == 'low') {
      bgColor = const Color(0xFFFFFBEB);
      textColor = const Color(0xFFD97706);
      label = 'Low Stock';
    } else {
      bgColor = const Color(0xFFFFF1F2);
      textColor = const Color(0xFFF43F5E);
      label = 'Out of Stock';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        // The grid tile gives this badge less room than the label wants, so the
        // pill has to be able to give up width instead of pushing past its
        // parent. See the price row in [_buildProductTile].
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildQuickStockBtn(ProductItem p, bool isAdd) {
    return InkWell(
      onTap: () {
        Haptics.tap();
        _showAdjustStockModal(p, isAdd);
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isAdd ? const Color(0xFFE7F8F0) : const Color(0xFFFFF1F2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isAdd ? const Color(0xFFBBF7D0) : const Color(0xFFFECDD3),
          ),
        ),
        child: Icon(
          isAdd ? Icons.add_rounded : Icons.remove_rounded,
          size: 14,
          color: isAdd ? const Color(0xFF12B76A) : const Color(0xFFF43F5E),
        ),
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

  /// Product artwork for a stock row.
  ///
  /// Rows used to fall back to a generic glyph chosen by a coarse category, so
  /// a power bank rendered as headphones and a watch rendered as a laptop. They
  /// then fell back to one hero phone shot, which put an iPhone body on an itel
  /// Vision. `ProductArt` resolves the brand first, and the last resort is an
  /// unbranded handset rather than another brand's flagship.
  String _fallbackAsset(ProductItem p) => ProductArt.resolve(
        brand: p.brand,
        name: p.name,
        category: p.cat,
      );

  /// Take or choose a real product photo and upload it.
  ///
  /// Both buttons used to point at a bundled asset or a stock Unsplash link and
  /// then claim a photo had been taken or uploaded. Nothing was captured, nothing
  /// was uploaded, and every product ended up sharing one of two pictures. This
  /// picks a file, uploads it, and returns the URL - or null when the person
  /// cancelled or the upload failed, so the caller can say so instead of
  /// pretending.
  Future<String?> _pickAndUploadProductPhoto(ImageSource source) async {
    final XFile? picked;
    try {
      picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1400,
        imageQuality: 85,
      );
    } catch (e) {
      if (mounted) {
        LimsToast.show(context, 'Could not open the camera or gallery: $e',
            isError: true);
      }
      return null;
    }
    if (picked == null) return null;

    try {
      final bytes = await picked.readAsBytes();
      final url = await CloudinaryService().uploadImageBytes(
        bytes: bytes,
        fileName: picked.name,
        folder: 'products',
      );
      if (url == null && mounted) {
        LimsToast.show(context, 'Photo upload failed. Check the connection.',
            isError: true);
      }
      return url;
    } catch (e) {
      if (mounted) {
        LimsToast.show(context, 'Photo upload failed: $e', isError: true);
      }
      return null;
    }
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
        child: Padding(
          padding: EdgeInsets.all(size * 0.18),
          child: Image.asset(
            _fallbackAsset(p),
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Icon(
              Icons.devices_other_rounded,
              color: Colors.white,
              size: size,
            ),
          ),
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
        'title': 'Infinix Midnight',
        'sub': 'Halisi · offline (Assets)',
        'asset': ProductArt.infinix,
        'url': null,
      },
      {
        'title': 'itel Entry Teal',
        'sub': 'Halisi · offline (Assets)',
        'asset': ProductArt.itel,
        'url': null,
      },
      {
        'title': 'Generic Android',
        'sub': 'Brand haijulikani (Assets)',
        'asset': ProductArt.genericPhone,
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
            title: tr(ref.read(localeProvider), 'stock.editPhotoTitle'),
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
                        onPressed: () async {
                          final url = await _pickAndUploadProductPhoto(
                              ImageSource.camera);
                          if (url == null) return;
                          setModalState(() {
                            selectedAsset = null;
                            selectedUrl = url;
                            urlCtrl.text = url;
                          });
                          if (mounted) {
                            LimsToast.show(context, 'Product photo uploaded.',
                                isSuccess: true);
                          }
                        },
                        icon: const Icon(Icons.camera_alt_rounded, size: 16, color: AppTheme.brand600),
                        label: const Text('Take photo', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.brand600)),
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
                        onPressed: () async {
                          final url = await _pickAndUploadProductPhoto(
                              ImageSource.gallery);
                          if (url == null) return;
                          setModalState(() {
                            selectedAsset = null;
                            selectedUrl = url;
                            urlCtrl.text = url;
                          });
                          if (mounted) {
                            LimsToast.show(context, 'Product photo uploaded.',
                                isSuccess: true);
                          }
                        },
                        icon: const Icon(Icons.photo_library_rounded, size: 16, color: AppTheme.brand600),
                        label: const Text('Upload photo', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.brand600)),
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
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.cloud_done_rounded, color: Color(0xFF16A34A), size: 18),
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
                              tr(ref.read(localeProvider), 'stock.compressNote'),
                              style: TextStyle(fontSize: 11, color: Color(0xFF166534), height: 1.35),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                Text(
                  tr(ref.read(localeProvider), 'stock.presets'),
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
                Text(
                  tr(ref.read(localeProvider), 'stock.photoUrl'),
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
                      child: const Text('View', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                    ),
                  ],
                ),
                const SizedBox(height: 22),

                // Save Action Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      // Stored first. The toast used to promise "imesasishwa
                      // kikamilifu" for a change that only this device saw, and the
                      // old picture came back on the next load.
                      final write = await SupabaseSource.setProductImage(
                        productId: p.id,
                        imageAsset: selectedAsset,
                        imageUrl: selectedUrl,
                      );
                      if (!mounted || !ctx.mounted) return;

                      if (!write.saved) {
                        LimsToast.show(
                          context,
                          write.error ??
                              'Picha haijahifadhiwa. Jaribu tena.',
                          isError: true,
                        );
                        return;
                      }

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
                    label: Text(tr(ref.read(localeProvider), 'stock.savePhoto'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
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
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.6,
                          color: AppTheme.ink900,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (UserRoles.canManageStock(ref.read(userRoleProvider)))
                  ElevatedButton.icon(
                    onPressed: _showAddPhoneModal,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Add Phone',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.brand600,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 40),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 18),

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
                                  color: AppTheme.brand600.withOpacity(0.3),
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

            // Counter text and the list / grid switch
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${products.length} models · $totalUnits units',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF9AA8BF),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ViewToggle(
                  view: _view,
                  locale: ref.watch(localeProvider),
                  onChanged: (v) => setState(() => _view = v),
                ),
              ],
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
            else if (_view == CollectionView.grid)
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(vertical: 16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: 0.78,
                ),
                itemCount: products.length,
                itemBuilder: (_, i) => _buildProductTile(products[i]),
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
          onTap: () {
            Haptics.tap();
            _showProductDetail(p);
          },
          onLongPress: () {
            Haptics.longPress();
            _showQuickActions(p);
          },
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Thumbnail / Real Phone Photo
                Container(
                  width: 52,
                  height: 52,
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
                  child: _buildProductThumbnail(p, iconSize: 24),
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
                      if (p.onOffer) ...[
                        const SizedBox(height: 3),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF7E6),
                            borderRadius: BorderRadius.circular(6),
                            border:
                                Border.all(color: const Color(0xFFFDE68A)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.local_fire_department_rounded,
                                  size: 11, color: Color(0xFFD97706)),
                              const SizedBox(width: 3),
                              Text(
                                tr(ref.read(localeProvider), 'deals.onOffer'),
                                style: const TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFFB45309),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Stock Management Quick Buttons (Storekeeper / Manager)
                if (UserRoles.canManageStock(ref.read(userRoleProvider)))
                  Row(
                    children: [
                      _buildQuickStockBtn(p, false),
                      const SizedBox(width: 4),
                      _buildQuickStockBtn(p, true),
                    ],
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

  /// One card in the two-column grid.
  Widget _buildProductTile(ProductItem p) {
    final locale = ref.read(localeProvider);
    final userRole = ref.watch(userRoleProvider);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0x0F0F3478),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            Haptics.tap();
            _showProductDetail(p);
          },
          onLongPress: () {
            Haptics.longPress();
            _showQuickActions(p);
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. IMAGE SECTION
              Expanded(
                flex: 13,
                child: ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(20)),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _buildHeroImage(p),

                      // ON OFFER Badge (Premium floating style)
                      if (p.onOffer)
                        Positioned(
                          top: 10,
                          left: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 9, vertical: 5),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      const Color(0xFFD97706).withOpacity(0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.bolt_rounded,
                                    size: 13, color: Colors.white),
                                const SizedBox(width: 3),
                                Text(
                                  tr(locale, 'deals.onOffer').toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      // Quick Stock Buttons for Managers
                      if (UserRoles.canManageStock(userRole))
                        Positioned(
                          bottom: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.08),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildQuickStockBtn(p, false),
                                const SizedBox(width: 6),
                                _buildQuickStockBtn(p, true),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // 2. INFO SECTION
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.name,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.ink900,
                        letterSpacing: -0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${p.sku} · ${p.stock} units',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.ink500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 10),
                    // Both children shrink, with the price getting the wider
                    // share. A grid cell on a narrow phone is ~144px wide and
                    // the two labels together want more than that (a wide
                    // 14.5px price plus an "Out of Stock" pill), so neither can
                    // be left inflexible: giving only the price a Flexible would
                    // still overflow, because the pill alone is already wider
                    // than the cell. The 2:1 split keeps the price legible —
                    // that is the number a shopkeeper is scanning for — and lets
                    // the status pill take the ellipsis when space runs out.
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          flex: 2,
                          child: Text(
                            p.shortPrice,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w900,
                              color: AppTheme.brand600,
                            ),
                          ),
                        ),
                        Flexible(
                          flex: 1,
                          child: _buildStatusBadge(p.status),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroImage(ProductItem p) {
    // Premium e-commerce feel: Prefer filling the area, unless it's a transparent product asset
    final isTransparentAsset = p.imageAsset != null && p.imageAsset!.isNotEmpty;
    
    return Container(
      color: const Color(0xFFF8FAFC),
      padding: isTransparentAsset ? const EdgeInsets.all(12) : EdgeInsets.zero,
      child: p.imageUrl != null && p.imageUrl!.isNotEmpty
          ? CachedNetworkImage(
              imageUrl: p.imageUrl!,
              fit: BoxFit.cover,
              placeholder: (context, url) =>
                  Container(color: const Color(0xFFF1F5F9)),
              errorWidget: (context, url, error) => _buildImageErrorFallback(),
            )
          : (p.imageAsset != null && p.imageAsset!.isNotEmpty
              ? Image.asset(p.imageAsset!, fit: BoxFit.contain)
              : _buildImageErrorFallback()),
    );
  }

  Widget _buildImageErrorFallback() {
    return Container(
      color: const Color(0xFFF5F6FA),
      child: const Center(
        child: Icon(
          Icons.image_not_supported_outlined,
          size: 40,
          color: Colors.grey,
        ),
      ),
    );
  }

  /// What a long press on a stock row opens.
  ///
  /// Only things the screen can really do: the detail sheet, and the same offer
  /// flag the owner sets in it. No invented "delete" or "edit" that would land
  /// in a table that does not exist.
  void _showQuickActions(ProductItem p) {
    final locale = ref.read(localeProvider);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 16),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _buildProductThumbnail(p, iconSize: 20),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.ink900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${p.sku} · ${p.stock} in stock',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.ink500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _quickActionRow(
                icon: Icons.open_in_new_rounded,
                label: tr(locale, 'action.openDetails'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showProductDetail(p);
                },
              ),
              _quickActionRow(
                icon: p.onOffer
                    ? Icons.local_fire_department_rounded
                    : Icons.local_fire_department_outlined,
                label: tr(
                    locale, p.onOffer ? 'stock.clearOffer' : 'stock.markOffer'),
                onTap: () {
                  Navigator.pop(ctx);
                  _setOffer(ref, p, !p.onOffer);
                },
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(tr(locale, 'common.close')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _quickActionRow({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: () {
        Haptics.tap();
        onTap();
      },
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 19, color: AppTheme.ink700),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.ink900,
                ),
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                size: 18, color: Color(0xFFCBD5E1)),
          ],
        ),
      ),
    );
  }

  void _showAddPhoneModal() {
    // The form used to open pre-filled with a Galaxy A15, two serial numbers and
    // three prices. Tapping "Save" without touching anything wrote a handset with
    // a made-up IMEI into stock. It now starts empty; the model chips below fill
    // it only when someone picks one.
    final nameCtrl = TextEditingController();
    final imei1Ctrl = TextEditingController();
    final imei2Ctrl = TextEditingController();
    final buyingCtrl = TextEditingController();
    final cashPriceCtrl = TextEditingController();
    final loanPriceCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '1');
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
        'asset': ProductArt.tecno,
        'url': null,
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
        'asset': ProductArt.xiaomi,
        'url': null,
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
        'asset': ProductArt.infinix,
        'url': null,
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
                                'Quick setup presets:',
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
                                  LimsToast.show(context, '${preset['name']} details filled in.');
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
                                        Text(
                                          tr(ref.read(localeProvider), 'stock.photoHint'),
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
                                                onTap: () async {
                                                  final url = await _pickAndUploadProductPhoto(
                                                      ImageSource.camera);
                                                  if (url == null) return;
                                                  setModalState(() {
                                                    selectedAsset = null;
                                                    selectedImageUrl = url;
                                                  });
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
                                                        'Take photo',
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
                                                onTap: () async {
                                                  final url = await _pickAndUploadProductPhoto(
                                                      ImageSource.gallery);
                                                  if (url == null) return;
                                                  setModalState(() {
                                                    selectedAsset = null;
                                                    selectedImageUrl = url;
                                                  });
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
                                                        'Upload photo',
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
                                value: brand,
                                decoration: const InputDecoration(
                                  labelText: 'Brand',
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                                items: ['Samsung', 'Apple', 'Xiaomi', 'Tecno', 'Infinix', 'itel', 'Oppo']
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
                                value: storage,
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
                                value: ram,
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
                          value: condition,
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
                                      'IMEI ya Kila Kifaa',
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
                                decoration: const InputDecoration(
                                  labelText: 'Primary IMEI 1 (15 digits)',
                                  prefixIcon: Icon(Icons.qr_code_scanner_rounded, size: 20, color: AppTheme.brand600),
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  // There used to be a button here that wrote a
                                  // serial built from the current timestamp into
                                  // the field. A serial identifies one physical
                                  // handset; a generated one identifies nothing and
                                  // still passed the Luhn check. Scan or type it.
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
                      onPressed: () async {
                        final imei1 = imei1Ctrl.text.trim();
                        if (imei1.isNotEmpty && !LimsValidators.isValidImei(imei1)) {
                          LimsToast.show(
                            context,
                            'IMEI 1 is invalid ($imei1). Must be 15 digits passing GSMA Luhn checksum.',
                            isError: true,
                          );
                          return;
                        }

                        // These used to fall back to TZS 380,000, 5 units and
                        // TZS 300,000 when the fields were blank, so an empty form
                        // saved a priced handset. Now a blank field stops the save.
                        final price = int.tryParse(cashPriceCtrl.text.replaceAll(',', ''));
                        final qty = int.tryParse(qtyCtrl.text);
                        final cost = int.tryParse(buyingCtrl.text.replaceAll(',', ''));
                        final loanP = int.tryParse(loanPriceCtrl.text.replaceAll(',', ''));
                        if (nameCtrl.text.trim().isEmpty ||
                            price == null ||
                            price <= 0 ||
                            qty == null ||
                            qty <= 0) {
                          LimsToast.show(
                            context,
                            'Enter the model name, the cash price and how many units arrived.',
                            isError: true,
                          );
                          return;
                        }

                        // Unknown brands get brand-matched artwork instead of
                        // a random stock photo of some other manufacturer's phone.
                        // A photo the staff member picked wins; otherwise the
                        // brand decides, so an unlabelled handset never borrows
                        // another manufacturer's body.
                        final brandAsset = ProductArt.resolve(
                          brand: brand,
                          name: nameCtrl.text,
                          category: 'phones',
                        );
                        final pickedUrl = selectedImageUrl ?? '';
                        final hasPickedUrl = pickedUrl.isNotEmpty;
                        final resolvedAsset =
                            selectedAsset ?? (hasPickedUrl ? null : brandAsset);
                        final resolvedUrl = resolvedAsset == null ? pickedUrl : null;

                        final newItem = ProductItem(
                          // Postgres owns the id. It used to be
                          // `millisecondsSinceEpoch % 10000`, which both invented a
                          // number that could collide with a real row and let the
                          // form believe it had saved something: the item went into
                          // the provider list only, so the catalogue stayed at its
                          // twelve rows and a refresh erased the intake. The draft's
                          // id is now ignored — `products.id` is a sequence and the
                          // stored row comes back with the real one.
                          id: 0,
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

                        // The database answers before the shelf moves. Every toast
                        // from here on describes a row that exists in `products`.
                        final write = await SupabaseSource.createProduct(newItem);
                        // Both contexts: this State may have been popped, and the
                        // sheet's own `ctx` is what Navigator.pop is called on.
                        if (!mounted || !ctx.mounted) return;

                        final stored = write.product;
                        if (!write.storedSomewhere || stored == null) {
                          // Leave the sheet open: the form still holds what the
                          // person typed, and the number on the shelf has not moved.
                          LimsToast.show(
                            context,
                            write.message ??
                                'The database did not take this product. Nothing was added — try again, and if it keeps failing the change is not saved anywhere.',
                            isError: true,
                          );
                          return;
                        }

                        // mergeRow, not addProduct: the Realtime INSERT for this row
                        // can arrive around the same moment, and a second copy would
                        // show the handset twice and count its stock twice.
                        ref.read(inventoryProvider.notifier).mergeRow(stored);
                        ref.read(activitiesProvider.notifier).addActivity(
                          ActivityItem(
                            icon: Icons.inventory_2_rounded,
                            iconColor: AppTheme.brand600,
                            bgColor: AppTheme.brand100,
                            title: 'Stock Intake: ${stored.name}',
                            description: '$qty units received · ${LimsFormatters.currency(stored.price)}',
                            time: 'Just now',
                          ),
                        );

                        Navigator.pop(ctx);
                        LimsToast.show(
                          context,
                          write.restocked
                              ? '${stored.name} was already on file under SKU ${stored.sku} — $qty units added, now ${stored.stock} in stock.'
                              : '${stored.name} ($qty units) added to ${ref.read(activeBranchProvider)} stock.',
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

  void _showAdjustStockModal(ProductItem p, bool isAdding) {
    final qtyCtrl = TextEditingController(text: '1');
    final reasonCtrl = TextEditingController();
    // Delta or absolute. A count is not an adjustment: the shelf already holds the
    // truth and the database is the one that is wrong. `asCount` used to be absent,
    // so the only way to record "I counted 143" was to guess a +/- that landed there.
    var countMode = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 14,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: StatefulBuilder(
          builder: (sheetCtx, setSheetState) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              countMode
                  ? 'Count Stock'
                  : (isAdding ? 'Add Stock' : 'Reduce Stock'),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppTheme.ink900,
              ),
            ),
            Row(
              children: [
                Checkbox(
                  value: countMode,
                  onChanged: (v) => setSheetState(() => countMode = v ?? false),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setSheetState(() => countMode = !countMode),
                    child: const Text(
                      'I have counted the shelf - set this exact number',
                      style: TextStyle(fontSize: 12, color: AppTheme.ink700),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              p.name,
              style: const TextStyle(fontSize: 13, color: AppTheme.ink500),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: qtyCtrl,
                    keyboardType: TextInputType.number,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: countMode ? 'Counted quantity' : 'Quantity',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                hintText: 'e.g. Supplier intake, Correction, Damaged...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final qty = int.tryParse(qtyCtrl.text) ?? 0;
                  if (qty <= 0) {
                    LimsToast.show(context, 'Enter a valid quantity', isError: true);
                    return;
                  }
                  if (!countMode && !isAdding && qty > p.stock) {
                    LimsToast.show(context, 'Cannot reduce more than current stock',
                        isError: true);
                    return;
                  }

                  // What changed, not what the total should be. The call before this
                  // one passed `p.stock + qty` into a parameter that was then *added*
                  // again, so adding 1 to 24 units showed 49 on the till.
                  final reason = reasonCtrl.text.trim();
                  final delta = isAdding ? qty : -qty;
                  // The reason box used to be decoration: it reached the activity
                  // list on this device and nowhere else. It is now sent with the
                  // movement and lands in product_history beside the before/after.
                  final write = countMode
                      ? await SupabaseSource.setStockCount(
                          productId: p.id,
                          stock: qty,
                          reason: reason.isEmpty ? 'Physical count' : reason,
                        )
                      : await SupabaseSource.adjustStock(
                          productId: p.id,
                          delta: delta,
                          reason: reason.isEmpty ? null : reason,
                        );
                  if (!mounted || !ctx.mounted) return;

                  if (!write.saved) {
                    // Nothing on the shelf moves. The old code reported success for a
                    // change that never left the device.
                    LimsToast.show(
                      context,
                      write.error ??
                          'The stock change was not saved. The number you see is still the old one.',
                      isError: true,
                    );
                    return;
                  }

                  final newStock = write.stock ?? (countMode ? qty : p.stock + delta);
                  ref.read(inventoryProvider.notifier).setStockTotal(p.id, newStock);

                  ref.read(activitiesProvider.notifier).addActivity(
                        ActivityItem(
                          icon: isAdding
                              ? Icons.add_circle_rounded
                              : Icons.remove_circle_rounded,
                          iconColor: isAdding
                              ? const Color(0xFF12B76A)
                              : const Color(0xFFF43F5E),
                          bgColor: isAdding
                              ? const Color(0xFFE7F8F0)
                              : const Color(0xFFFFF1F2),
                          title: isAdding ? 'Stock Added' : 'Stock Reduced',
                          description:
                              '${isAdding ? "+" : "-"}$qty units of ${p.name} · ${reasonCtrl.text.isEmpty ? (isAdding ? "Manual add" : "Manual reduction") : reasonCtrl.text}',
                          time: 'Just now',
                        ),
                      );

                  Navigator.pop(ctx);
                  LimsToast.show(
                    context,
                    countMode
                        ? 'Counted: ${p.name} is now $newStock units on the shelf'
                        : 'Stock updated: ${p.name} is now $newStock units',
                    isSuccess: true,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      isAdding ? const Color(0xFF12B76A) : const Color(0xFFF43F5E),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(
                  countMode
                      ? 'Confirm Count'
                      : (isAdding ? 'Confirm Add' : 'Confirm Reduction'),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }
}
