import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/strings.dart';
import '../../../core/widgets/person_avatar.dart';

/// The shared vocabulary for the role home screens.
///
/// The storekeeper home set the look: a soft blue page, one white card that
/// carries the day's real figure, a violet AI card, and a two-column action grid
/// with a tinted icon square on each tile. Building the other roles from the
/// same widgets keeps them feeling like one product instead of five branches of
/// a codebase — and means a future tweak to the radius or the shadow lands
/// everywhere at once.
///
/// Nothing here decides what a number means. Every figure is passed in by the
/// screen, read from a ledger, so a quiet morning shows zero.
class DashPalette {
  DashPalette._();

  static const Color ink = Color(0xFF10213F);
  static const Color muted = Color(0xFF7184A7);
  static const Color faint = Color(0xFFA9BAD6);
  static const Color hairline = Color(0xFFE6EEFB);
  static const Color page = Color(0xFFF5F9FF);

  static const List<Color> pageGradient = [
    Color(0xFFCFE3FF),
    Color(0xFFE9F2FF),
    Color(0xFFF8FBFF),
  ];
  static const List<double> pageStops = [0.0, 0.34, 0.74];
}

/// Page chrome: gradient, safe area and the scroll padding every role shares.
class DashPage extends StatelessWidget {
  const DashPage({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DashPalette.page,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: DashPalette.pageGradient,
            stops: DashPalette.pageStops,
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 118),
            children: children,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- profile row

class DashProfileRow extends StatelessWidget {
  const DashProfileRow({
    super.key,
    required this.name,
    required this.asset,
    required this.grad,
    required this.unread,
    required this.onAvatarTap,
    required this.onBellTap,
  });

  final String name;
  final String? asset;
  final List<Color> grad;
  final int unread;
  final VoidCallback onAvatarTap;
  final VoidCallback onBellTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        InkWell(
          onTap: onAvatarTap,
          borderRadius: BorderRadius.circular(99),
          child: Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1A2F6BD6),
                  blurRadius: 14,
                  offset: Offset(0, 4),
                ),
              ],
              gradient: LinearGradient(
                colors: grad,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: PersonAvatar(
              name: name,
              asset: asset,
              size: 50,
              grad: grad,
            ),
          ),
        ),
        const Spacer(),
        InkWell(
          onTap: onBellTap,
          borderRadius: BorderRadius.circular(99),
          child: Container(
            width: 46,
            height: 46,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Color(0x142F6BD6),
                  blurRadius: 18,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Icon(Icons.notifications_none_rounded,
                    size: 23, color: DashPalette.ink),
                if (unread > 0)
                  Positioned(
                    right: 11,
                    top: 10,
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF04438),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------------- greeting

/// Two lines, two weights: the salutation is light, the role is the emphasis.
class DashGreeting extends StatelessWidget {
  const DashGreeting({
    super.key,
    required this.locale,
    required this.roleLabel,
  });

  final Locale locale;
  final String roleLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr(locale, 'skdash.welcome'),
          style: const TextStyle(
            fontSize: 32,
            height: 1.14,
            fontWeight: FontWeight.w400,
            letterSpacing: -0.6,
            color: DashPalette.ink,
          ),
        ),
        Text(
          roleLabel,
          style: const TextStyle(
            fontSize: 32,
            height: 1.14,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.6,
            color: DashPalette.ink,
          ),
        ),
      ],
    );
  }
}

// --------------------------------------------------------------- section head

class DashSectionHeader extends StatelessWidget {
  const DashSectionHeader({super.key, required this.title, this.pill});

  final String title;

  /// The role or count chip that sits to the right of the heading, as in the
  /// reference: "Counter POS Actions · Counter Cashier".
  final String? pill;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
              color: DashPalette.ink,
            ),
          ),
        ),
        if (pill != null && pill!.isNotEmpty) ...[
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFE9F2FE),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                pill!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E60F2),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------- pill button

/// The round, gradient call to action. White-on-gradient when it sits inside a
/// coloured card, brand-blue when it sits on white.
class DashPillButton extends StatelessWidget {
  const DashPillButton({
    super.key,
    required this.label,
    required this.onTap,
    this.onGradient = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool onGradient;

  @override
  Widget build(BuildContext context) {
    final bg = onGradient ? Colors.white : null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: bg,
          gradient: onGradient
              ? null
              : const LinearGradient(
                  colors: [Color(0xFF246BFD), Color(0xFF5AA5FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: onGradient
                ? Colors.white.withValues(alpha: 0.55)
                : Colors.white.withValues(alpha: 0.18),
          ),
          boxShadow: [
            BoxShadow(
              color: onGradient
                  ? const Color(0x2E0B2C6B)
                  : const Color(0xFF246BFD).withValues(alpha: 0.34),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.35),
              blurRadius: 1,
              offset: const Offset(0, -1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: onGradient ? DashPalette.ink : Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.arrow_forward_rounded,
              size: 16,
              color: onGradient ? DashPalette.ink : Colors.white,
            ),
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------------------------- feature card

/// The one card per role that carries the day's headline figure.
///
/// `art` is a 3D render on a transparent background: it sits on the right, on a
/// soft radial glow, and the text column is padded so a long caption never runs
/// under it.
class DashFeatureCard extends StatelessWidget {
  const DashFeatureCard({
    super.key,
    required this.eyebrow,
    required this.value,
    required this.caption,
    required this.art,
    required this.gradient,
    this.icon,
    this.ctaLabel,
    this.onCta,
    this.footnote,
  });

  final String eyebrow;
  final String value;
  final String caption;
  final String art;
  final List<Color> gradient;
  final IconData? icon;
  final String? ctaLabel;
  final VoidCallback? onCta;

  /// A second, quieter line under the caption — used for an honest caveat such
  /// as "0 receipts recorded today".
  final String? footnote;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: gradient.first.withValues(alpha: 0.32),
            blurRadius: 26,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Stack(
          children: [
            Positioned(
              right: -18,
              top: -18,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.10),
                ),
              ),
            ),
            Positioned(
              right: 6,
              bottom: 2,
              child: SizedBox(
                width: 116,
                height: 116,
                child: Image.asset(
                  art,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.medium,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 96),
                    child: Row(
                      children: [
                        if (icon != null) ...[
                          Icon(icon, size: 15, color: Colors.white),
                          const SizedBox(width: 6),
                        ],
                        Flexible(
                          child: Text(
                            eyebrow,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.88),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.only(right: 84),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        value,
                        maxLines: 1,
                        style: const TextStyle(
                          fontSize: 30,
                          height: 1.1,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.9,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.only(right: 76),
                    child: Text(
                      caption,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.3,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.80),
                      ),
                    ),
                  ),
                  if (footnote != null) ...[
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.only(right: 76),
                      child: Text(
                        footnote!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          height: 1.3,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.62),
                        ),
                      ),
                    ),
                  ],
                  if (ctaLabel != null && onCta != null) ...[
                    const SizedBox(height: 16),
                    DashPillButton(
                      label: ctaLabel!,
                      onTap: onCta!,
                      onGradient: true,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ AI card

/// The AI shortcut, identical on every role: the violet orb artwork with the
/// headline on the dark left half, so white text stays legible at any width.
class DashAiCard extends StatelessWidget {
  const DashAiCard({
    super.key,
    required this.locale,
    required this.onTap,
    this.title,
    this.subtitle,
  });

  final Locale locale;
  final VoidCallback onTap;
  final String? title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(26),
      child: Container(
        height: 118,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          gradient: const LinearGradient(
            colors: [Color(0xFF7757F8), Color(0xFF5B3BD6)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7757F8).withValues(alpha: 0.30),
              blurRadius: 22,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                'assets/images/ai_orb_card.jpg',
                fit: BoxFit.cover,
                alignment: Alignment.centerRight,
                filterQuality: FilterQuality.medium,
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xE65B3BD6), Color(0x005B3BD6)],
                    stops: [0.34, 0.78],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 60, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title ?? tr(locale, 'skdash.aiTitle'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle ?? tr(locale, 'skdash.aiSub'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.78),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 14,
                right: 14,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.20),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.38),
                    ),
                  ),
                  child: const Icon(Icons.arrow_forward_rounded,
                      size: 16, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --------------------------------------------------------------- action grid

/// One tile in a [DashActionGrid]. `route` is pushed through go_router so the
/// back button returns to the home screen the user came from.
class DashAction {
  const DashAction({
    required this.icon,
    required this.tint,
    required this.iconColor,
    required this.title,
    required this.sub,
    this.route,
    this.onTap,
  });

  final IconData icon;
  final Color tint;
  final Color iconColor;
  final String title;
  final String sub;
  final String? route;
  final VoidCallback? onTap;
}

class DashActionGrid extends StatelessWidget {
  const DashActionGrid({super.key, required this.actions});

  final List<DashAction> actions;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.92,
      padding: EdgeInsets.zero,
      children: actions
          .map((a) => _DashActionTile(
                action: a,
                onTap: a.onTap ??
                    (a.route == null
                        ? null
                        : () => GoRouter.of(context).push(a.route!)),
              ))
          .toList(),
    );
  }
}

class _DashActionTile extends StatelessWidget {
  const _DashActionTile({required this.action, this.onTap});

  final DashAction action;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: DashPalette.hairline),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0F2F6BD6),
              blurRadius: 16,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: action.tint,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(action.icon, size: 19, color: action.iconColor),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    action.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.2,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                      color: DashPalette.ink,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    action.sub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10.5,
                      height: 1.2,
                      fontWeight: FontWeight.w500,
                      color: DashPalette.muted,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                size: 17, color: DashPalette.faint),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------ workspace list

/// The quieter, full-width destinations: one white card, one row per entry.
class DashWorkspaceList extends StatelessWidget {
  const DashWorkspaceList({super.key, required this.items});

  final List<DashAction> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: DashPalette.hairline),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F2F6BD6),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0)
              const Divider(
                height: 1,
                thickness: 1,
                color: Color(0xFFF1F6FE),
              ),
            InkWell(
              onTap: items[i].onTap ??
                  (items[i].route == null
                      ? null
                      : () => GoRouter.of(context).push(items[i].route!)),
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: items[i].tint,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(items[i].icon,
                          size: 19, color: items[i].iconColor),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        items[i].title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                          color: DashPalette.ink,
                        ),
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded,
                        size: 19, color: DashPalette.faint),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// -------------------------------------------------------------- list & notes

/// A row inside a white card: title, optional subtitle, optional right figure.
class DashListRow extends StatelessWidget {
  const DashListRow({
    super.key,
    required this.title,
    required this.sub,
    this.trailing,
    this.tint,
    this.icon,
    this.iconColor,
    this.onTap,
  });

  final String title;
  final String sub;
  final String? trailing;
  final Color? tint;
  final IconData? icon;
  final Color? iconColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            if (icon != null) ...[
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: tint ?? const Color(0xFFEAF2FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon,
                    size: 18, color: iconColor ?? const Color(0xFF347FF5)),
              ),
              const SizedBox(width: 11),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                      color: DashPalette.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: DashPalette.muted,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              Text(
                trailing!,
                maxLines: 1,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                  color: DashPalette.ink,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A white card of [DashListRow]s with an honest empty state.
class DashListCard extends StatelessWidget {
  const DashListCard({
    super.key,
    required this.children,
    required this.emptyText,
    required this.emptyIcon,
  });

  /// Already-built rows. Empty means [emptyText] is shown instead.
  final List<Widget> children;
  final String emptyText;
  final IconData emptyIcon;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: DashPalette.hairline),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F2F6BD6),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      padding: EdgeInsets.symmetric(
        horizontal: 14,
        vertical: children.isEmpty ? 22 : 6,
      ),
      child: children.isEmpty
          ? Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF5FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child:
                      Icon(emptyIcon, size: 19, color: const Color(0xFF7A93B8)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    emptyText,
                    style: const TextStyle(
                      fontSize: 12.5,
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                      color: DashPalette.muted,
                    ),
                  ),
                ),
              ],
            )
          : Column(children: children),
    );
  }
}

/// One compact, tappable line: an icon, a headline figure and a reason to tap.
///
/// This exists because a dashboard is a launch pad, not a report. Five borrower
/// rows on the loan officer's home pushed the actions a screen and a half down,
/// so the officer scrolled past the thing they were hired to do in order to read
/// a list they could already open. The same figure in one row keeps the fact and
/// gives the screen its scroll back.
class DashAlertRow extends StatelessWidget {
  const DashAlertRow({
    super.key,
    required this.icon,
    required this.title,
    required this.sub,
    required this.tint,
    required this.iconColor,
    required this.onTap,
    this.count,
  });

  final IconData icon;
  final String title;
  final String sub;
  final Color tint;
  final Color iconColor;
  final VoidCallback onTap;

  /// Optional tally shown before the chevron. Omitted when there is nothing to
  /// count, so an empty state does not read "0".
  final String? count;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: DashPalette.hairline),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F2F6BD6),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: tint,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(icon, size: 20, color: iconColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                          color: DashPalette.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        sub,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: DashPalette.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (count != null && count!.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: tint,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      count!,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: iconColor,
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right_rounded,
                    size: 19, color: DashPalette.faint),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A two-line statement card. Used where the honest answer is a sentence rather
/// than a figure.
class DashNoteCard extends StatelessWidget {
  const DashNoteCard({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.tint = const Color(0xFFEFF5FF),
    this.iconColor = const Color(0xFF347FF5),
  });

  final IconData icon;
  final String title;
  final String body;
  final Color tint;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: DashPalette.hairline),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F2F6BD6),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: tint,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 19, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                    color: DashPalette.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.45,
                    fontWeight: FontWeight.w500,
                    color: DashPalette.muted,
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

/// Two small white stat cards, for a pair of figures that matter but are not the
/// headline. Both values are passed in already formatted.
class DashStatPair extends StatelessWidget {
  const DashStatPair({
    super.key,
    required this.leftIcon,
    required this.leftLabel,
    required this.leftValue,
    required this.leftTint,
    required this.leftColor,
    this.onLeftTap,
    required this.rightIcon,
    required this.rightLabel,
    required this.rightValue,
    required this.rightTint,
    required this.rightColor,
    this.onRightTap,
  });

  final IconData leftIcon;
  final String leftLabel;
  final String leftValue;
  final Color leftTint;
  final Color leftColor;
  final VoidCallback? onLeftTap;

  final IconData rightIcon;
  final String rightLabel;
  final String rightValue;
  final Color rightTint;
  final Color rightColor;
  final VoidCallback? onRightTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _stat(
            icon: leftIcon,
            label: leftLabel,
            value: leftValue,
            tint: leftTint,
            color: leftColor,
            onTap: onLeftTap,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _stat(
            icon: rightIcon,
            label: rightLabel,
            value: rightValue,
            tint: rightTint,
            color: rightColor,
            onTap: onRightTap,
          ),
        ),
      ],
    );
  }

  Widget _stat({
    required IconData icon,
    required String label,
    required String value,
    required Color tint,
    required Color color,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: DashPalette.hairline),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0F2F6BD6),
              blurRadius: 16,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: tint,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, size: 17, color: color),
            ),
            const SizedBox(height: 10),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                maxLines: 1,
                style: const TextStyle(
                  fontSize: 19,
                  height: 1.1,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: DashPalette.ink,
                ),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                height: 1.25,
                fontWeight: FontWeight.w500,
                color: DashPalette.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
