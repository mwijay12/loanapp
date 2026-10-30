import 'package:flutter/material.dart';

import '../constants/app_constants.dart';
import '../theme/app_theme.dart';

/// The LIMS mark.
///
/// Before this file the "logo" was a gradient square repeated in three places
/// (login, shell, account), each with its own radius, shadow and padding — so the
/// brand looked slightly different on every screen, and nowhere had a name beside
/// it. Two widgets now, one shape: everything that shows the brand shows the same
/// brand.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 42, this.radius});

  final double size;

  /// Defaults to a radius that keeps the tile a squircle at any size.
  final double? radius;

  @override
  Widget build(BuildContext context) {
    final r = radius ?? (size * 0.31);
    return Semantics(
      label: AppConstants.companyName,
      image: true,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: AppTheme.brandGradient,
          borderRadius: BorderRadius.circular(r),
          boxShadow: [
            BoxShadow(
              color: AppTheme.brand600.withValues(alpha: 0.28),
              blurRadius: size * 0.38,
              offset: Offset(0, size * 0.14),
            ),
          ],
        ),
        child: Stack(
          children: [
            // A single soft highlight across the top-left corner. It is what stops
            // the tile reading as a flat blue rectangle at 64px and above, and it
            // costs one gradient instead of a blur.
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(r),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.22),
                      Colors.white.withValues(alpha: 0.0),
                    ],
                    stops: const [0.0, 0.62],
                  ),
                ),
              ),
            ),
            Center(
              child: Icon(
                Icons.smartphone_rounded,
                color: Colors.white,
                size: size * 0.5,
              ),
            ),
            // The tick on the handset: inventory, not just a phone. Four pixels of
            // geometry that say what the shop actually does.
            Positioned(
              right: size * 0.22,
              bottom: size * 0.2,
              child: Container(
                width: size * 0.2,
                height: size * 0.2,
                decoration: BoxDecoration(
                  color: AppTheme.pastelMint,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.9),
                    width: size * 0.03,
                  ),
                ),
                child: Icon(
                  Icons.check_rounded,
                  size: size * 0.13,
                  color: AppTheme.brand700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Mark + wordmark, stacked or inline.
///
/// Used by the desktop sidebar, the phone login and the account screen, so the
/// brand reads the same at 32px in a rail as it does at 64px on a login page.
class BrandLockup extends StatelessWidget {
  const BrandLockup({
    super.key,
    this.size = 40,
    this.vertical = false,
    this.showTagline = false,
    this.onDark = false,
  });

  final double size;
  final bool vertical;
  final bool showTagline;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final title = Text(
      'LIMS',
      style: TextStyle(
        fontSize: size * 0.46,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.6,
        height: 1.05,
        color: onDark ? Colors.white : AppTheme.ink900,
      ),
    );
    final tagline = Text(
      AppConstants.appName,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: size * 0.26,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
        color: onDark ? Colors.white.withValues(alpha: 0.72) : AppTheme.ink500,
      ),
    );

    final mark = BrandMark(size: size);
    final text = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment:
          vertical ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [title, if (showTagline) tagline],
    );

    if (vertical) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          mark,
          SizedBox(height: size * 0.34),
          text,
        ],
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        SizedBox(width: size * 0.32),
        Flexible(child: text),
      ],
    );
  }
}
