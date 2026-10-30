import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A colourful backdrop for the console-style screens.
///
/// Painted from soft radial gradients rather than a bitmap: it stays sharp at any
/// size, weighs nothing, and cannot arrive broken on a slow connection.
///
/// It does not animate. An earlier version drifted the blobs on a 28-second loop
/// and that was a mistake for three reasons: it repaints every frame forever on a
/// phone that is supposed to run a shop, it made `pumpAndSettle` hang so twelve
/// widget tests could never finish, and the movement added nothing a still frame
/// does not already say.
class AuroraBackdrop extends StatelessWidget {
  const AuroraBackdrop({
    super.key,
    required this.child,
    this.palette = AuroraPalette.console,
  });

  final Widget child;
  final AuroraPalette palette;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(color: palette.base),
          ),
        ),
        Positioned.fill(
          child: CustomPaint(painter: _AuroraPainter(palette: palette)),
        ),
        Positioned.fill(child: child),
      ],
    );
  }
}

enum AuroraPalette {
  /// Blue / violet / cyan / rose — the admin console.
  console,

  /// Blue / teal / amber / indigo — the storekeeper floor.
  floor;

  /// Opaque, so the page has a definite colour before a single blob is drawn.
  Color get base => switch (this) {
        AuroraPalette.console => const Color(0xFFF3F7FF),
        AuroraPalette.floor => const Color(0xFFF1F8FF),
      };

  List<Color> get baseGradient => switch (this) {
        AuroraPalette.console => const [
            Color(0xFFEAF1FF),
            Color(0xFFF7F4FF),
            Color(0xFFEAF8FF),
          ],
        AuroraPalette.floor => const [
            Color(0xFFE8F1FF),
            Color(0xFFF2FAF7),
            Color(0xFFEDF6FF),
          ],
      };

  List<Color> get blobs => switch (this) {
        AuroraPalette.console => const [
            Color(0xFF3B82F6),
            Color(0xFF8B5CF6),
            Color(0xFF22D3EE),
            Color(0xFFF472B6),
          ],
        AuroraPalette.floor => const [
            Color(0xFF2563EB),
            Color(0xFF14B8A6),
            Color(0xFFF59E0B),
            Color(0xFF6366F1),
          ],
      };
}

class _AuroraPainter extends CustomPainter {
  _AuroraPainter({required this.palette});

  final AuroraPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // Opaque pastel base: whatever happens above it, the page stays light.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: palette.baseGradient,
        ).createShader(rect),
    );

    final shortest = math.min(size.width, size.height);
    final blobs = <List<double>>[
      // colourIndex, fraction of width, fraction of height, radius share
      [0, 0.10, 0.02, 0.62],
      [1, 0.92, 0.16, 0.54],
      [2, 0.86, 0.96, 0.50],
      [3, 0.06, 0.90, 0.44],
    ];

    for (final b in blobs) {
      final colour = palette.blobs[b[0].toInt()];
      final centre = Offset(b[1] * size.width, b[2] * size.height);
      final radius = math.max(shortest * b[3], 120.0);

      canvas.drawCircle(
        centre,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [
              colour.withValues(alpha: 0.40),
              colour.withValues(alpha: 0.14),
              colour.withValues(alpha: 0),
            ],
            stops: const [0, 0.52, 1],
          ).createShader(Rect.fromCircle(center: centre, radius: radius)),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _AuroraPainter old) => old.palette != palette;
}

/// A 3D icon on a raised pedestal.
///
/// The art is the shop's existing isometric icon set; the pedestal is what makes
/// it sit on the card instead of floating in it: a tinted gradient, a coloured
/// drop shadow underneath and a light rim along the top edge, which is how a real
/// object reads as lit from above.
class Clay3DIcon extends StatelessWidget {
  const Clay3DIcon({
    super.key,
    required this.asset,
    required this.tint,
    this.size = 44,
    this.padding = 0.16,
  });

  final String asset;
  final Color tint;
  final double size;

  /// Share of the box the artwork leaves as breathing room.
  final double padding;

  @override
  Widget build(BuildContext context) {
    final radius = size * 0.32;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(tint, Colors.white, 0.86)!,
            Color.lerp(tint, Colors.white, 0.62)!,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: tint.withValues(alpha: 0.34),
            blurRadius: size * 0.34,
            offset: Offset(0, size * 0.14),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.9),
            blurRadius: 2,
            offset: Offset(0, -1),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Stack(
        children: [
          // Rim light along the top-left edge.
          Positioned(
            left: 2,
            top: 2,
            right: size * 0.42,
            height: size * 0.30,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(radius),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.75),
                    Colors.white.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(size * padding),
            child: Image.asset(
              asset,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
              errorBuilder: (_, __, ___) => Icon(
                Icons.widgets_rounded,
                size: size * 0.46,
                color: tint,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
