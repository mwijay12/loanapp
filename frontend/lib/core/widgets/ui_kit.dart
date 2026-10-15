import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/app_theme.dart';

/// Shared premium surfaces.
///
/// Screens should compose from these instead of rebuilding `Container` +
/// `BoxDecoration` inline. Keeps depth, radius and spacing consistent, and
/// means a redesign is a one-file change.

/// Elevated white surface. The default building block for content.
class LimsCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Gradient? gradient;
  final Color? color;
  final Color? borderColor;
  final List<BoxShadow>? shadows;
  final double radius;
  final double? width;
  final double? height;
  final bool dense;

  const LimsCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppTheme.spaceMd),
    this.onTap,
    this.gradient,
    this.color,
    this.borderColor,
    this.shadows,
    this.radius = AppTheme.rLg,
    this.width,
    this.height,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    final BorderRadius br = BorderRadius.circular(radius);
    final Widget body = ink(
      DecoratedBox(
        decoration: BoxDecoration(
          gradient: gradient,
          color: gradient == null ? (color ?? AppTheme.surface) : null,
          borderRadius: br,
          border: Border.all(color: borderColor ?? AppTheme.border),
          boxShadow: shadows ?? AppTheme.shadowSm,
        ),
        child: Padding(
          padding: dense ? const EdgeInsets.all(AppTheme.spaceSm) : padding,
          child: child,
        ),
      ),
    );

    if (onTap == null) return body;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: br,
        splashColor: AppTheme.brand100.withAlpha(90),
        highlightColor: AppTheme.brand100.withAlpha(60),
        child: body,
      ),
    );
  }

  Widget ink(Widget w) => w;
}

/// Rounded icon container. `tone` picks a pastel bed + matching icon colour.
class IconBed extends StatelessWidget {
  final IconData icon;
  final double size;
  final Color background;
  final Color foreground;
  final double radius;

  const IconBed({
    super.key,
    required this.icon,
    this.size = 44,
    this.background = AppTheme.pastelMint,
    this.foreground = AppTheme.iconGreen,
    this.radius = AppTheme.rSm,
  });

  /// Convenience tones so callers do not pair pastel/icon colours by hand.
  const IconBed.mint({
    super.key,
    required this.icon,
    this.size = 44,
    this.radius = AppTheme.rSm,
  })  : background = AppTheme.pastelMint,
        foreground = AppTheme.iconGreen;

  const IconBed.blue({
    super.key,
    required this.icon,
    this.size = 44,
    this.radius = AppTheme.rSm,
  })  : background = AppTheme.pastelBlue,
        foreground = AppTheme.iconBlue;

  const IconBed.orange({
    super.key,
    required this.icon,
    this.size = 44,
    this.radius = AppTheme.rSm,
  })  : background = AppTheme.pastelOrange,
        foreground = AppTheme.iconOrange;

  const IconBed.red({
    super.key,
    required this.icon,
    this.size = 44,
    this.radius = AppTheme.rSm,
  })  : background = AppTheme.pastelRed,
        foreground = AppTheme.iconRed;

  const IconBed.navy({
    super.key,
    required this.icon,
    this.size = 44,
    this.radius = AppTheme.rSm,
  })  : background = AppTheme.pastelLavender,
        foreground = AppTheme.iconNavy;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Icon(icon, color: foreground, size: size * 0.5),
    );
  }
}

/// Section label with an optional trailing action.
class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                  letterSpacing: -0.2,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (actionLabel != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              actionLabel!,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.brand700,
              ),
            ),
          ),
      ],
    );
  }
}

/// Compact metric read-out.
class StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color background;
  final Color foreground;
  final String? delta;
  final bool deltaPositive;

  const StatTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.background = AppTheme.pastelMint,
    this.foreground = AppTheme.iconGreen,
    this.delta,
    this.deltaPositive = true,
  });

  @override
  Widget build(BuildContext context) {
    return LimsCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              IconBed(
                icon: icon,
                size: 32,
                radius: AppTheme.rXs,
                background: background,
                foreground: foreground,
              ),
              const Spacer(),
              if (delta != null)
                Row(
                  children: [
                    Icon(
                      deltaPositive
                          ? Icons.trending_up_rounded
                          : Icons.trending_down_rounded,
                      size: 13,
                      color: deltaPositive
                          ? AppTheme.successColor
                          : AppTheme.errorColor,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      delta!,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: deltaPositive
                            ? AppTheme.successColor
                            : AppTheme.errorColor,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Gradient call-to-action surface with a watermark glyph and a soft glow.
class GradientHero extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final IconData? watermark;
  final VoidCallback? onTap;
  final String? trailingLabel;
  final Gradient gradient;
  final double height;

  const GradientHero({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.watermark,
    this.onTap,
    this.trailingLabel,
    this.gradient = AppTheme.heroGradient,
    this.height = 148,
  });

  @override
  Widget build(BuildContext context) {
    final BorderRadius br = BorderRadius.circular(AppTheme.rXl);

    return SizedBox(
      width: double.infinity,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: br,
          boxShadow: AppTheme.shadowBrand,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: br,
            splashColor: Colors.white.withAlpha(38),
            highlightColor: Colors.white.withAlpha(20),
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                if (watermark != null)
                  Positioned(
                    right: -24,
                    bottom: -28,
                    child: Icon(
                      watermark,
                      size: 132,
                      color: Colors.white.withAlpha(22),
                    ),
                  ),
                // Specular highlight, top-left.
                Positioned(
                  left: -40,
                  top: -60,
                  child: Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withAlpha(18),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 18, 18),
                  child: Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(38),
                          borderRadius: BorderRadius.circular(AppTheme.rMd),
                          border: Border.all(color: Colors.white.withAlpha(56)),
                        ),
                        child: Icon(icon, color: Colors.white, size: 25),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: -0.35,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              subtitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12.5,
                                height: 1.35,
                                color: Colors.white.withAlpha(214),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(38),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withAlpha(56),
                              ),
                            ),
                            child: const Icon(
                              Icons.arrow_forward_rounded,
                              color: Colors.white,
                              size: 21,
                            ),
                          ),
                          if (trailingLabel != null) ...[
                            const SizedBox(height: 5),
                            Text(
                              trailingLabel!,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.4,
                                color: Colors.white.withAlpha(200),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Small status pill.
class StatusPill extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color foreground;
  final Color background;

  const StatusPill({
    super.key,
    required this.label,
    this.icon,
    this.foreground = AppTheme.brand800,
    this.background = AppTheme.brand100,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: foreground),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.15,
              color: foreground,
            ),
          ),
        ],
      ),
    );
  }
}

/// Square header action button with an optional unread dot.
class HeaderAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool showDot;
  final String? tooltip;

  const HeaderAction({
    super.key,
    required this.icon,
    required this.onTap,
    this.showDot = false,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final Widget button = Padding(
      padding: const EdgeInsets.only(left: AppTheme.spaceSm),
      child: Material(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.rSm),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.rSm),
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.rSm),
              border: Border.all(color: AppTheme.border),
              boxShadow: AppTheme.shadowXs,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(icon, size: 20, color: AppTheme.ink700),
                if (showDot)
                  Positioned(
                    right: 10,
                    top: 10,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: AppTheme.errorColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.surface, width: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}

/// Consistent empty / placeholder block.
class InfoBanner extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Color foreground;
  final Color background;

  const InfoBanner({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.foreground = AppTheme.brand800,
    this.background = AppTheme.brand50,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppTheme.rMd),
        border: Border.all(color: foreground.withAlpha(38)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: foreground),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: foreground,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.45,
                    color: foreground.withAlpha(220),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Standard bottom sheet container enforcing unified drag-handle, title, and styling.
class LimsBottomSheet extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final Widget child;
  final bool showClose;
  final EdgeInsetsGeometry padding;
  final Widget? trailing;

  const LimsBottomSheet({
    super.key,
    this.title,
    this.subtitle,
    required this.child,
    this.showClose = true,
    this.padding = const EdgeInsets.fromLTRB(20, 12, 20, 24),
    this.trailing,
  });

  static Future<T?> show<T>({
    required BuildContext context,
    WidgetBuilder? builder,
    String? title,
    String? subtitle,
    Widget? child,
    bool showClose = true,
    EdgeInsetsGeometry padding = const EdgeInsets.fromLTRB(20, 12, 20, 24),
    bool isScrollControlled = true,
    bool isDismissible = true,
    bool enableDrag = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      backgroundColor: Colors.transparent,
      elevation: 0,
      useSafeArea: true,
      // Tablet/desktop: sheet inabana katikati badala ya kunyoosha.
      constraints: const BoxConstraints(maxWidth: 640),
      builder: (ctx) {
        if (builder != null) return builder(ctx);
        return LimsBottomSheet(
          title: title,
          subtitle: subtitle,
          showClose: showClose,
          padding: padding,
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Sheet haivunji kamwe: content ndefu inascroll ndani (max 92% ya screen),
    // keyboard inapoinuka sheet inapanda (viewInsets), hakuna overflow.
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.rXl)),
          boxShadow: AppTheme.shadowLg,
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppTheme.sheetHandle,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              if (title != null) ...[
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                                color: AppTheme.ink900,
                              ),
                            ),
                            if (subtitle != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                subtitle!,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.ink500,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (trailing != null) ...[
                        const SizedBox(width: 8),
                        Flexible(child: trailing!),
                      ],
                      if (showClose)
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 20, color: AppTheme.ink500),
                          visualDensity: VisualDensity.compact,
                          onPressed: () => Navigator.pop(context),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                const Divider(height: 1, color: AppTheme.divider),
              ],
              Flexible(
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom,
                  ),
                  child: Padding(
                    padding: padding,
                    child: child,
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

/// Universal formatters across LIMS
class LimsFormatters {
  LimsFormatters._();

  static final NumberFormat _currencyFormat = NumberFormat.currency(
    symbol: 'TZS ',
    decimalDigits: 0,
    locale: 'en_US',
  );

  static String currency(num? amount) {
    if (amount == null) return 'TZS 0';
    return _currencyFormat.format(amount);
  }

  static String compact(num? amount) {
    if (amount == null) return '0';
    if (amount >= 1000000) {
      final val = (amount / 1000000).toStringAsFixed(1);
      return '${val.endsWith(".0") ? val.substring(0, val.length - 2) : val}M';
    }
    if (amount >= 1000) {
      final val = (amount / 1000).toStringAsFixed(1);
      return '${val.endsWith(".0") ? val.substring(0, val.length - 2) : val}K';
    }
    return amount.toString();
  }

  static String currencyCompact(num? amount) {
    return 'TZS ${compact(amount)}';
  }

  static String formatNumber(num? amount) {
    if (amount == null) return '0';
    final s = amount.round().toString();
    final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return s.replaceAllMapped(reg, (Match m) => '${m[1]},');
  }

  static String phone(String raw) {
    final cleaned = raw.replaceAll(RegExp(r'\D'), '');
    if (cleaned.startsWith('255') && cleaned.length == 12) {
      return '+255 ${cleaned.substring(3, 6)} ${cleaned.substring(6, 9)} ${cleaned.substring(9)}';
    }
    if (cleaned.startsWith('0') && cleaned.length == 10) {
      return '${cleaned.substring(0, 4)} ${cleaned.substring(4, 7)} ${cleaned.substring(7)}';
    }
    return raw;
  }
}

/// Strict validations conforming to GSMA & Tanzania regulatory specs.
class LimsValidators {
  LimsValidators._();

  /// GSMA 15-digit Luhn Algorithm validation for IMEI.
  static bool isValidImei(String? imei) {
    if (imei == null) return false;
    final clean = imei.replaceAll(RegExp(r'\s+'), '');
    if (clean.length != 15 || !RegExp(r'^\d{15}$').hasMatch(clean)) return false;

    int sum = 0;
    for (int i = 0; i < 15; i++) {
      int digit = int.parse(clean[i]);
      // In Luhn for 15 digits (odd total length):
      // digits at odd indices (1, 3, 5, 7, 9, 11, 13) are doubled
      if (i % 2 == 1) {
        digit *= 2;
        if (digit > 9) digit -= 9;
      }
      sum += digit;
    }
    return sum % 10 == 0;
  }

  static String? validateImei(String? value, {bool required = true}) {
    if (value == null || value.trim().isEmpty) {
      return required ? 'IMEI is required (15 digits)' : null;
    }
    final clean = value.trim();
    if (clean.length != 15 || !RegExp(r'^\d{15}$').hasMatch(clean)) {
      return 'IMEI must be exactly 15 digits (currently ${clean.length})';
    }
    if (!isValidImei(clean)) {
      return 'Invalid IMEI checksum (Luhn validation failed)';
    }
    return null;
  }

  /// Tanzania phone number: +255 6/7XXXXXXXX or 06/07XXXXXXXX
  static bool isValidTzPhone(String? phone) {
    if (phone == null) return false;
    final clean = phone.replaceAll(RegExp(r'[\s\-]'), '');
    return RegExp(r'^(?:\+255|0)[67]\d{8}$').hasMatch(clean);
  }

  static String? validateTzPhone(String? value, {bool required = true}) {
    if (value == null || value.trim().isEmpty) {
      return required ? 'Phone number is required' : null;
    }
    if (!isValidTzPhone(value)) {
      return 'Enter valid TZ phone (+2557... or 07.../06...)';
    }
    return null;
  }

  /// 20-digit Tanzania NIDA national ID
  static bool isValidNida(String? nida) {
    if (nida == null) return false;
    final clean = nida.replaceAll(RegExp(r'[\s\-]'), '');
    return RegExp(r'^\d{20}$').hasMatch(clean);
  }

  static String? validateNida(String? value, {bool required = true}) {
    if (value == null || value.trim().isEmpty) {
      return required ? 'NIDA ID is required (20 digits)' : null;
    }
    final clean = value.replaceAll(RegExp(r'[\s\-]'), '');
    if (clean.length != 20 || !RegExp(r'^\d{20}$').hasMatch(clean)) {
      return 'NIDA must be exactly 20 digits (currently ${clean.length})';
    }
    return null;
  }
}

/// Modern top-pinned floating toast notification
class LimsToast {
  LimsToast._();

  static OverlayEntry? _currentEntry;

  static void show(
    BuildContext context,
    String message, {
    bool isError = false,
    bool isSuccess = false,
    IconData? icon,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 4),
  }) {
    // Remove any active toast
    _currentEntry?.remove();
    _currentEntry = null;

    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;

    final topPadding = MediaQuery.of(context).padding.top;
    final bgColor = isError
        ? const Color(0xFFDC2626)
        : (isSuccess ? const Color(0xFF059669) : const Color(0xFF0F172A));

    final effectiveIcon = icon ??
        (isError
            ? Icons.error_outline_rounded
            : (isSuccess ? Icons.check_circle_rounded : Icons.notifications_active_rounded));

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => _TopToastWidget(
        topPadding: topPadding,
        message: message,
        bgColor: bgColor,
        icon: effectiveIcon,
        actionLabel: actionLabel,
        onAction: () {
          entry.remove();
          _currentEntry = null;
          onAction?.call();
        },
        onDismiss: () {
          entry.remove();
          if (_currentEntry == entry) _currentEntry = null;
        },
      ),
    );

    _currentEntry = entry;
    overlay.insert(entry);

    Future.delayed(duration, () {
      if (entry.mounted && _currentEntry == entry) {
        entry.remove();
        _currentEntry = null;
      }
    });
  }
}

class _TopToastWidget extends StatefulWidget {
  final double topPadding;
  final String message;
  final Color bgColor;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback onDismiss;

  const _TopToastWidget({
    required this.topPadding,
    required this.message,
    required this.bgColor,
    required this.icon,
    this.actionLabel,
    this.onAction,
    required this.onDismiss,
  });

  @override
  State<_TopToastWidget> createState() => _TopToastWidgetState();
}

class _TopToastWidgetState extends State<_TopToastWidget> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _offsetAnim;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _offsetAnim = Tween<Offset>(
      begin: const Offset(0, -0.6),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();
  }

  void _dismiss() async {
    await _controller.reverse();
    widget.onDismiss();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: widget.topPadding + 10,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _offsetAnim,
        child: FadeTransition(
          opacity: _fadeAnim,
          child: Material(
            color: Colors.transparent,
            child: GestureDetector(
              onTap: _dismiss,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: widget.bgColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x3D000000),
                      blurRadius: 20,
                      offset: Offset(0, 8),
                    ),
                  ],
                  border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(widget.icon, color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.message,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          height: 1.25,
                        ),
                      ),
                    ),
                    if (widget.actionLabel != null) ...[
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: widget.onAction,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.white.withValues(alpha: 0.25),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          minimumSize: Size.zero,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: Text(
                          widget.actionLabel!,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                        ),
                      ),
                    ],
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: _dismiss,
                      borderRadius: BorderRadius.circular(99),
                      child: Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: Icon(
                          Icons.close_rounded,
                          color: Colors.white.withValues(alpha: 0.8),
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}