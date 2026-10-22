import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// The card and the carousel viewport that holds it are the same height.
/// Keeping it in one place stops the page view from clipping the card when the
/// card is retuned.
const double kDealCardHeight = 158;

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
class FeaturedPhoneDealCard extends StatelessWidget {
  final FeaturedPhoneDeal deal;
  final double scale;

  const FeaturedPhoneDealCard({
    super.key,
    required this.deal,
    this.scale = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scale: scale,
      child: GestureDetector(
        onTap: deal.onTap,
        child: Container(
          // 158, down from 168 and from 190 before that. The two stacked spec
          // chips are gone, and the line they became now sits under the handset
          // instead of in the text column, which let the whole card lose another
          // 10px without dropping the ROM, the colour or the piece count.
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
                color: deal.glowColor.withValues(alpha: 0.32),
                blurRadius: 22,
                offset: const Offset(0, 10),
                spreadRadius: -2,
              ),
              const BoxShadow(
                color: Color(0x140F172A),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              // Ambient radial glow behind handset
              Positioned(
                right: -20,
                bottom: -20,
                child: Container(
                  width: 170,
                  height: 170,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.28),
                        Colors.white.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),

              // Decorative subtle background lines / contour rings
              Positioned(
                right: 30,
                top: -35,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                      width: 1.5,
                    ),
                  ),
                ),
              ),

              // Main Card Content: name and deposit on the left, handset on the
              // right, and one foot line that carries the ROM, the colour and how
              // many pieces are on the shelf.
              //
              // The foot line sits under the handset, at the right edge, which is
              // the corner that used to be empty. It owns the whole right half
              // rather than sharing it with the action, so "256GB · Stardust
              // Silver · 27 units" fits on one line at 360 px instead of
              // ellipsizing the colour away. The action pill takes the left end
              // of the same strip, under the title it belongs to.
              Padding(
                padding: const EdgeInsets.fromLTRB(15, 11, 13, 9),
                child: Column(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          // Left info section
                          Expanded(
                            flex: 13,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Top Promotion Badge
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3.5),
                                  decoration: BoxDecoration(
                                    color: deal.badgeBg,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.25),
                                      width: 1,
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
                                      const SizedBox(width: 5),
                                      Text(
                                        deal.badge,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.3,
                                          color: deal.badgeTextColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 5),

                                // Device Title
                                Text(
                                  deal.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.3,
                                    color: Colors.white,
                                    height: 1.14,
                                  ),
                                ),
                                const SizedBox(height: 2),

                                // Subtitle (deposit and weekly figure)
                                Text(
                                  deal.subtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white.withValues(alpha: 0.9),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(width: 6),

                          // Product art is transparent, so it sits straight on
                          // the card. It used to be wrapped in a white tile,
                          // which read as a photo pasted onto the gradient.
                          Expanded(
                            flex: 9,
                            child: Center(
                              child: SizedBox(
                                height: 98,
                                width: 92,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Container(
                                      width: 86,
                                      height: 86,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: RadialGradient(
                                          colors: [
                                            deal.glowColor
                                                .withValues(alpha: 0.45),
                                            deal.glowColor
                                                .withValues(alpha: 0.0),
                                          ],
                                        ),
                                      ),
                                    ),
                                    deal.imageAsset != null &&
                                            deal.imageAsset!.isNotEmpty
                                        ? Image.asset(
                                            deal.imageAsset!,
                                            fit: BoxFit.contain,
                                            errorBuilder: (_, __, ___) =>
                                                _buildFramedDevice(deal),
                                          )
                                        : _buildFramedDevice(deal),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Foot strip: action at the left end, spec under the handset.
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 11, vertical: 5.5),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x1F000000),
                                blurRadius: 8,
                                offset: Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Flexible + ellipsis: the label used to size
                              // itself and pushed this row past the card edge
                              // on a narrow phone.
                              Flexible(
                                child: Text(
                                  deal.actionLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.ink900,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.arrow_forward_rounded,
                                size: 13,
                                color: AppTheme.ink900,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        // One line: ROM, colour and piece count. Right aligned so
                        // it hangs directly under the picture.
                        Expanded(
                          child: Text(
                            deal.specLine,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              height: 1.2,
                              color: Colors.white.withValues(alpha: 0.86),
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

  Widget _buildFramedDevice(FeaturedPhoneDeal deal) {
    return Container(
      width: 86,
      height: 130,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.35),
          width: 2.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
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
                margin: const EdgeInsets.only(top: 5),
                width: 28,
                height: 6,
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
                    Colors.white.withValues(alpha: 0.15),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.2),
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
          Icon(Icons.phone_android_rounded, color: Colors.white.withValues(alpha: 0.9), size: 30),
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
          height: kDealCardHeight,
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

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      child: FeaturedPhoneDealCard(
                        deal: deal,
                        scale: scale,
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 10),

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
