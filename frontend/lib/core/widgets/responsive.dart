import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Breakpoints za LIMS — simu ndogo, simu kubwa, tablet, desktop/web.
class LimsBreakpoints {
  LimsBreakpoints._();
  static const double smallPhone = 360;
  static const double phone = 480;
  static const double tablet = 720;
  static const double desktop = 1024;

  /// Upana wa juu wa content katikati (tablet/desktop) ili isiendelee kunyoosha.
  static const double maxContentWidth = 640;
}

extension ResponsiveContext on BuildContext {
  double get screenWidth => MediaQuery.sizeOf(this).width;
  double get screenHeight => MediaQuery.sizeOf(this).height;

  bool get isSmallPhone => screenWidth < LimsBreakpoints.smallPhone;
  bool get isPhone => screenWidth < LimsBreakpoints.phone;
  bool get isTablet => screenWidth >= LimsBreakpoints.tablet;
  bool get isDesktop => screenWidth >= LimsBreakpoints.desktop;

  /// Padding ya ukurasa inayobadilika kulingana na upana — hakuna overflow
  /// kwenye simu ndogo (320dp), na nafasi nzuri kwenye tablet.
  EdgeInsets get pagePadding {
    if (isSmallPhone) {
      return const EdgeInsets.symmetric(horizontal: 12);
    }
    if (isTablet) {
      return const EdgeInsets.symmetric(horizontal: 28);
    }
    return const EdgeInsets.symmetric(horizontal: 18);
  }

  /// Idadi ya safu za grid kulingana na upana.
  int gridColumns({int phone = 2, int tablet = 3, int desktop = 4}) {
    if (isDesktop) return desktop;
    if (isTablet) return tablet;
    return phone;
  }
}

/// ScrollBehavior ya kimataifa:
/// - **Hakuna overscroll glow / bounce** (Clamping) — "kusiwe na overscrolls".
/// - Drag kwa mouse + touch (web/desktop).
class NoGlowScrollBehavior extends MaterialScrollBehavior {
  const NoGlowScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    // Rukia glow ya Android na bounce ya iOS — content isimame imara.
    return child;
  }

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const ClampingScrollPhysics();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}

/// Kifungashio cha ukurasa chenye mipaka salama:
/// SafeArea + constrained width (tablet) + padding responsive.
class ResponsivePage extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double? maxWidth;
  final bool safeBottom;

  const ResponsivePage({
    super.key,
    required this.child,
    this.padding,
    this.maxWidth,
    this.safeBottom = true,
  });

  @override
  Widget build(BuildContext context) {
    final pad = padding ?? context.pagePadding;
    return SafeArea(
      bottom: safeBottom,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: maxWidth ?? LimsBreakpoints.maxContentWidth,
          ),
          child: Padding(padding: pad, child: child),
        ),
      ),
    );
  }
}

/// Row salama: inafunga text na kuzuia `RenderFlex overflowed` kwenye
/// simu nyembamba kwa kutumia Flexible + ellipsis automatically.
class SafeRow extends StatelessWidget {
  final List<Widget> children;
  final double spacing;
  final CrossAxisAlignment crossAxisAlignment;
  final MainAxisAlignment mainAxisAlignment;

  const SafeRow({
    super.key,
    required this.children,
    this.spacing = 8,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.mainAxisAlignment = MainAxisAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    final spaced = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      spaced.add(Flexible(child: children[i]));
      if (i != children.length - 1) spaced.add(SizedBox(width: spacing));
    }
    return Row(
      crossAxisAlignment: crossAxisAlignment,
      mainAxisAlignment: mainAxisAlignment,
      children: spaced,
    );
  }
}

/// Title + trailing zinazoweza kubanwa bila overflow (k.m. notification rows).
class AdaptiveTitleRow extends StatelessWidget {
  final String title;
  final String? trailing;
  final TextStyle? titleStyle;
  final TextStyle? trailingStyle;
  final int titleMaxLines;

  const AdaptiveTitleRow({
    super.key,
    required this.title,
    this.trailing,
    this.titleStyle,
    this.trailingStyle,
    this.titleMaxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: titleMaxLines,
            overflow: TextOverflow.ellipsis,
            style: titleStyle ??
                const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              trailing!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: trailingStyle ??
                  const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8)),
            ),
          ),
        ],
      ],
    );
  }
}
