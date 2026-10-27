import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../data/inventory_provider.dart';
import '../data/mock_lims_data.dart';
import '../services/haptics.dart';
import '../constants/app_constants.dart';
import '../data/inventory_provider.dart';
import 'ui_kit.dart';

/// Card height, in one place, so the carousel viewport cannot clip the card.
/// Not the same number as [kCarouselHeight] — the viewport is taller on purpose
/// to leave room for the shadow and the scale transform.
const double kDealCardHeight = 186;
const double kCarouselHeight = 226; // Added extra space for shadows and scaling transform

/// Model representing a high-impact featured smartphone promotion / loan offer.
class FeaturedPhoneDeal {
  final String id;
  final String title;
  final String subtitle;
  final String badge;
  final Color badgeBg;
  final Color badgeTextColor;
  final List<Color> gradient;
  final Color glowColor;
  final String? imageAsset;
  final String? imageUrl;
  final ProductItem? product;
  /// ROM and colour as one string, e.g. `256GB · Stardust Silver`.
  final String spec;

  /// How many pieces are on the shelf, e.g. `27 units`.
  final String units;
  final String cashPrice;
  final String monthlyDue;
  final String actionLabel;
  final VoidCallback onTap;

  const FeaturedPhoneDeal({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.badgeBg,
    required this.badgeTextColor,
    required this.gradient,
    required this.glowColor,
    this.imageAsset,
    this.imageUrl,
    this.product,
    required this.spec,
    required this.units,
    required this.cashPrice,
    required this.monthlyDue,
    this.actionLabel = 'Issue Loan',
    required this.onTap,
  });

  /// The single line under the handset: spec first, then the unit count.
  ///
  /// Either half may be empty — a model with no variant on file still has to
  /// read cleanly — so the separator is only drawn when both sides exist.
  String get specLine {
    if (spec.isEmpty) return units;
    if (units.isEmpty) return spec;
    return '$spec · $units';
  }
}

/// Ultra-modern 3D-feel gradient card with rich lighting, floating device imagery, and glassmorphic badges.
class FeaturedPhoneDealCard extends ConsumerWidget {
  final FeaturedPhoneDeal deal;
  final double scale;

  const FeaturedPhoneDealCard({
    super.key,
    required this.deal,
    this.scale = 1.0,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canManage = deal.product != null && 
        UserRoles.canManageStock(ref.watch(userRoleProvider));

    return Transform.scale(
      scale: scale,
      child: GestureDetector(
        onTap: deal.onTap,
        child: Container(
          height: kDealCardHeight,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              colors: deal.gradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: deal.glowColor.withOpacity(0.35),
                blurRadius: 24,
                offset: const Offset(0, 12),
                spreadRadius: -4,
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              // Ambient radial glow behind handset
              Positioned(
                right: -30,
                bottom: -30,
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Colors.white.withOpacity(0.3),
                        Colors.white.withOpacity(0.0),
                      ],
                    ),
                  ),
                ),
              ),

              // Decorative subtle background lines
              Positioned(
                right: 20,
                top: -40,
                child: Container(
                  width: 130,
                  height: 130,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withOpacity(0.15),
                      width: 1.5,
                    ),
                  ),
                ),
              ),

              // Main Content
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 12, 12),
                child: Column(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          // Left: Info
                          Expanded(
                            flex: 11,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 9, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.35),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: BoxDecoration(
                                          color: deal.badgeTextColor,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      // Flexible, not bare. The row sits in the
                                      // card's left column, which is only ~91px
                                      // wide on a 360px phone, and the label is
                                      // translated — "MUDA MFUPI" and friends can
                                      // be longer than the column. With the dot
                                      // and the gap taking 12px, an unshrinkable
                                      // label overflowed by a fraction of a pixel
                                      // and that overflow failed the whole
                                      // role_dashboards_test.dart file, because
                                      // the cashier home mounts this carousel.
                                      Flexible(
                                        child: Text(
                                          deal.badge.toUpperCase(),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w900,
                                            color: deal.badgeTextColor,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  deal.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    height: 1.1,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  deal.subtitle,
                                  // Bounded on purpose. The subtitle carries two
                                  // facts ("Deposit … · …/wk") and had no maxLines,
                                  // so in the ~150px left column it wrapped to three
                                  // lines and pushed the column past the card's
                                  // height — a RenderFlex overflow that failed the
                                  // whole deal_card_test.dart file, not just the
                                  // assertion that caused it. Two lines keeps both
                                  // facts reachable; ellipsis, because a clipped
                                  // number is still better than a torn layout.
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white.withOpacity(0.95),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(width: 8),

                          // Right: Prominent Image
                          Expanded(
                            flex: 12,
                            child: Center(
                              child: Stack(
                                alignment: Alignment.center,
                                clipBehavior: Clip.none, // Allow overflow if needed
                                children: [
                                  // Glow disk
                                  Container(
                                    width: 115,
                                    height: 115,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: RadialGradient(
                                        colors: [
                                          deal.glowColor.withOpacity(0.45),
                                          deal.glowColor.withOpacity(0.0),
                                        ],
                                      ),
                                    ),
                                  ),
                                  
                                  // Image or Frame
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 5),
                                    child: SizedBox(
                                      height: 135,
                                      width: 110,
                                      child: deal.imageAsset != null &&
                                              deal.imageAsset!.isNotEmpty
                                          ? Image.asset(
                                              deal.imageAsset!,
                                              fit: BoxFit.contain,
                                              alignment: Alignment.center,
                                              errorBuilder: (_, __, ___) =>
                                                  _buildFramedDevice(deal),
                                            )
                                          : _buildFramedDevice(deal),
                                    ),
                                  ),
                                  
                                  // Stock Adjustment Buttons (Overlay)
                                  if (canManage)
                                    Positioned(
                                      right: -4,
                                      bottom: 0,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          _buildStockBtn(
                                            context, 
                                            ref, 
                                            deal.product!, 
                                            false
                                          ),
                                          const SizedBox(width: 8),
                                          _buildStockBtn(
                                            context, 
                                            ref, 
                                            deal.product!, 
                                            true
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Bottom: Action & Spec
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                deal.actionLabel,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w900,
                                  color: AppTheme.ink900,
                                ),
                              ),
                              const SizedBox(width: 5),
                              const Icon(
                                Icons.arrow_forward_rounded,
                                size: 14,
                                color: AppTheme.ink900,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            deal.specLine,
                            textAlign: TextAlign.right,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.white.withOpacity(0.9),
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
        ),
      ),
    );
  }

  Widget _buildStockBtn(BuildContext context, WidgetRef ref, ProductItem p, bool isAdd) {
    return GestureDetector(
      onTap: () {
        Haptics.tap();
        _showAdjustStock(context, ref, p, isAdd);
      },
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          isAdd ? Icons.add_rounded : Icons.remove_rounded,
          size: 16,
          color: isAdd ? const Color(0xFF12B76A) : const Color(0xFFF43F5E),
        ),
      ),
    );
  }

  void _showAdjustStock(BuildContext context, WidgetRef ref, ProductItem p, bool isAdd) {
    final qtyCtrl = TextEditingController(text: '1');
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isAdd ? 'Add Stock' : 'Reduce Stock',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: qtyCtrl,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Quantity', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final qty = int.tryParse(qtyCtrl.text) ?? 0;
                  if (qty <= 0) return;
                  final newStock = isAdd ? p.stock + qty : p.stock - qty;
                  if (newStock < 0) return;
                  ref.read(inventoryProvider.notifier).updateStock(p.id, newStock);
                  ref.read(activitiesProvider.notifier).addActivity(
                    ActivityItem(
                      icon: isAdd ? Icons.add_circle_rounded : Icons.remove_circle_rounded,
                      iconColor: isAdd ? const Color(0xFF12B76A) : const Color(0xFFF43F5E),
                      bgColor: isAdd ? const Color(0xFFE7F8F0) : const Color(0xFFFFF1F2),
                      title: isAdd ? 'Stock Added' : 'Stock Reduced',
                      description: '${isAdd ? "+" : "-"}$qty units of ${p.name}',
                      time: 'Just now',
                    ),
                  );
                  Navigator.pop(ctx);
                  LimsToast.show(context, 'Stock updated: ${p.name} is now $newStock units', isSuccess: true);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isAdd ? const Color(0xFF12B76A) : const Color(0xFFF43F5E),
                  foregroundColor: Colors.white,
                ),
                child: Text(isAdd ? 'Confirm Add' : 'Confirm Reduction'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFramedDevice(FeaturedPhoneDeal deal) {
    return Container(
      width: 82,
      height: 124,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.4),
          width: 2.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Screen wallpaper or photo
            if (deal.imageUrl != null && deal.imageUrl!.isNotEmpty)
              Image.network(
                deal.imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildScreenWallpaper(deal),
              )
            else
              _buildScreenWallpaper(deal),

            // Top Dynamic Island / speaker slit
            Align(
              alignment: Alignment.topCenter,
              child: Container(
                margin: const EdgeInsets.only(top: 4),
                width: 26,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),

            // Subtle glass glare reflection overlay
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.18),
                    Colors.transparent,
                    Colors.black.withOpacity(0.25),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScreenWallpaper(FeaturedPhoneDeal deal) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [deal.gradient.last, deal.gradient.first],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.phone_android_rounded, color: Colors.white.withOpacity(0.9), size: 30),
          const SizedBox(height: 4),
          Text(
            deal.cashPrice,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

}

/// Interactive Viewport-fraction Smartphone Deals & Promotions Carousel
/// Features:
/// - Smooth 3D scale interpolation on active card
/// - Auto-scrolling timer with pause on touch
/// - Animated Dot Capsule Page Indicators
class PhoneDealsCarousel extends StatefulWidget {
  final List<FeaturedPhoneDeal> deals;
  final double viewportFraction;
  final Duration autoScrollDuration;

  const PhoneDealsCarousel({
    super.key,
    required this.deals,
    this.viewportFraction = 0.87,
    this.autoScrollDuration = const Duration(seconds: 5),
  });

  @override
  State<PhoneDealsCarousel> createState() => _PhoneDealsCarouselState();
}

class _PhoneDealsCarouselState extends State<PhoneDealsCarousel> {
  late final PageController _pageController;
  int _currentPage = 0;
  Timer? _autoPlayTimer;
  bool _isInteracting = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      initialPage: 0,
      viewportFraction: widget.viewportFraction,
    );
    _startAutoPlay();
  }

  void _startAutoPlay() {
    _autoPlayTimer?.cancel();
    if (widget.deals.length <= 1) return;

    _autoPlayTimer = Timer.periodic(widget.autoScrollDuration, (_) {
      if (!mounted || _isInteracting) return;
      if (_pageController.hasClients) {
        final nextPage = (_currentPage + 1) % widget.deals.length;
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 650),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  void _stopAutoPlay() {
    _autoPlayTimer?.cancel();
  }

  @override
  void dispose() {
    _autoPlayTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.deals.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        // Carousel Slider
        SizedBox(
          height: kCarouselHeight,
          child: Listener(
            onPointerDown: (_) {
              _isInteracting = true;
              _stopAutoPlay();
            },
            onPointerUp: (_) {
              _isInteracting = false;
              _startAutoPlay();
            },
            child: PageView.builder(
              controller: _pageController,
              itemCount: widget.deals.length,
              onPageChanged: (idx) {
                setState(() => _currentPage = idx);
              },
              itemBuilder: (context, idx) {
                final deal = widget.deals[idx];

                return AnimatedBuilder(
                  animation: _pageController,
                  builder: (context, child) {
                    double scale = 1.0;
                    if (_pageController.position.haveDimensions) {
                      final page = _pageController.page ?? _currentPage.toDouble();
                      final diff = (page - idx).abs();
                      scale = (1.0 - (diff * 0.10)).clamp(0.90, 1.0);
                    } else {
                      scale = (idx == _currentPage) ? 1.0 : 0.90;
                    }

                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        child: FeaturedPhoneDealCard(
                          deal: deal,
                          scale: scale,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 5),

        // Animated Capsule Indicators
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(widget.deals.length, (idx) {
            final isSelected = idx == _currentPage;
            final deal = widget.deals[idx];

            return GestureDetector(
              onTap: () {
                _pageController.animateToPage(
                  idx,
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeInOut,
                );
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 3.5),
                height: 6,
                width: isSelected ? 24 : 7,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(99),
                  color: isSelected
                      ? deal.gradient.first
                      : const Color(0xFFCBD5E1),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}
