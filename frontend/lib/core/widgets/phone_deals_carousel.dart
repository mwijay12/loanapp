import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

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
  final String tag1;
  final String tag2;
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
    required this.tag1,
    required this.tag2,
    required this.cashPrice,
    required this.monthlyDue,
    this.actionLabel = 'Issue Loan',
    required this.onTap,
  });
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
          height: 195,
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

              // Main Card Content (Split Layout: Left Text & CTA, Right Device Photo)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
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
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
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
                          const SizedBox(height: 6),

                          // Device Title
                          Text(
                            deal.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.3,
                              color: Colors.white,
                              height: 1.15,
                            ),
                          ),
                          const SizedBox(height: 3),

                          // Subtitle (Deposit & Monthly info)
                          Text(
                            deal.subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                          const SizedBox(height: 6),

                          // Feature tags row
                          Wrap(
                            spacing: 5,
                            runSpacing: 4,
                            children: [
                              _buildGlassTag(deal.tag1),
                              _buildGlassTag(deal.tag2),
                            ],
                          ),
                          const Spacer(),

                          // Quick Action CTA Button
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6.5),
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
                                Text(
                                  deal.actionLabel,
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.ink900,
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
                        ],
                      ),
                    ),

                    // Right floating smartphone image
                    Expanded(
                      flex: 7,
                      child: Center(
                        child: Container(
                          height: 145,
                          decoration: const BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                color: Color(0x26000000),
                                blurRadius: 16,
                                offset: Offset(0, 8),
                              ),
                            ],
                          ),
                          child: deal.imageAsset != null && deal.imageAsset!.isNotEmpty
                              ? Image.asset(
                                  deal.imageAsset!,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => _buildFallbackDevice(),
                                )
                              : (deal.imageUrl != null && deal.imageUrl!.isNotEmpty
                                  ? Image.network(
                                      deal.imageUrl!,
                                      fit: BoxFit.contain,
                                      errorBuilder: (_, __, ___) => _buildFallbackDevice(),
                                    )
                                  : _buildFallbackDevice()),
                        ),
                      ),
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

  Widget _buildGlassTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.22),
          width: 0.8,
        ),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildFallbackDevice() {
    return const Center(
      child: Icon(
        Icons.smartphone_rounded,
        size: 58,
        color: Colors.white,
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
          height: 195,
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
        const SizedBox(height: 12),

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
