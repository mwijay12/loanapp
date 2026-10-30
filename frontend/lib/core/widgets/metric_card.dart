import 'package:flutter/material.dart';

import '../motion/motion_widgets.dart';
import '../theme/app_theme.dart';
import 'ui_kit.dart';

/// Compact metric read-out used across the dashboards.
class MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;
  final Color? iconColor;
  final VoidCallback? onTap;

  /// The number behind [value], when the caller has one.
  ///
  /// Optional per call site on purpose: a card holding a date or a "3 of 5" stays
  /// plain text. A count-up needs a real number to travel toward - anything else is a
  /// decoration standing where a read-out should be.
  final num? numeric;
  final String Function(num value)? format;

  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.iconColor,
    this.onTap,
    this.numeric,
    this.format,
  });

  @override
  Widget build(BuildContext context) {
    final Color accent = iconColor ?? AppTheme.brand700;

    return LimsCard(
      onTap: onTap,
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            IconBed(
              icon: icon!,
              size: 34,
              radius: AppTheme.rXs,
              background: accent.withAlpha(26),
              foreground: accent,
            ),
            const SizedBox(height: 11),
          ],
          _Value(
            display: value,
            numeric: numeric,
            format: format ?? LimsFormatters.formatNumber,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11.5,
              height: 1.35,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// The figure in a [MetricCard].
///
/// One style for both states: a tile that animates and a tile that does not must be
/// the same text at the same size, or turning motion on becomes a layout change as
/// well as a motion change - and the user would find it even though a test would not.
class _Value extends StatelessWidget {
  const _Value({
    required this.display,
    required this.numeric,
    required this.format,
  });

  final String display;
  final num? numeric;
  final String Function(num value) format;

  static const _style = TextStyle(
    fontSize: 23,
    fontWeight: FontWeight.w800,
    color: AppTheme.textPrimary,
    letterSpacing: -0.5,
  );

  @override
  Widget build(BuildContext context) {
    final n = numeric;
    if (n == null) {
      return Text(
        display,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: _style,
      );
    }
    return MetricText(
        display: display, value: n, format: format, style: _style);
  }
}
