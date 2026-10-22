import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/inventory_provider.dart';
import '../../../core/data/notifications_provider.dart';
import '../../../core/data/store_activity.dart';
import '../../../core/data/store_movement.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../../core/l10n/strings.dart';
import '../../../core/widgets/person_avatar.dart';
import '../../../core/widgets/ui_kit.dart';

/// The storekeeper's home.
///
/// Layout follows the supplied reference: profile row, two-line greeting, pill
/// search, blue low-stock banner, one large white activity card, a row of service
/// shortcuts and recent movement cards. Everything numeric is read from the
/// ledger — `storeDayCountsProvider`, `totalPhonesCountProvider` and
/// `lowStockCountProvider` — so an empty morning reads zero instead of last
/// week's figure.
class StorekeeperDashboard extends ConsumerWidget {
  const StorekeeperDashboard({
    super.key,
    required this.onLowStockTap,
  });

  /// Opens the existing low-stock sheet in HomeScreen. Passed in rather than
  /// rebuilt here so the branch filter and the row layout stay in one place.
  final VoidCallback onLowStockTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final staff = ref.watch(activeStaffMemberProvider);
    final unread = ref.watch(unreadNotificationsProvider);
    final lowStock = ref.watch(lowStockCountProvider);
    final handsets = ref.watch(totalPhonesCountProvider);
    final days = ref.watch(storeDayCountsProvider);
    final movements = ref.watch(recentStoreMovementsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F9FF),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFCFE3FF), Color(0xFFE9F2FF), Color(0xFFF8FBFF)],
            stops: [0.0, 0.34, 0.74],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 118),
            children: [
              _ProfileRow(
                name: staff.name,
                asset: staff.avatarAsset,
                grad: staff.grad,
                unread: unread,
                onAvatarTap: () => context.push('/settings'),
                onBellTap: () => context.push('/notifications'),
              ),
              const SizedBox(height: 18),
              _Greeting(
                locale: locale,
                roleLabel: tr(locale, 'role.storekeeper'),
              ),
              const SizedBox(height: 18),
              _SearchField(locale: locale, onFilterTap: onLowStockTap),
              const SizedBox(height: 18),
              _LowStockBanner(
                locale: locale,
                count: lowStock,
                onTap: onLowStockTap,
              ),
              const SizedBox(height: 16),
              _StockSummaryCard(
                locale: locale,
                handsets: handsets,
                day: days,
                onViewInventory: () => context.go('/stock'),
              ),
              const SizedBox(height: 14),
              _AiAssistantCard(
                locale: locale,
                onTap: () => context.push('/ai'),
              ),
              const SizedBox(height: 22),
              _SectionTitle(tr(locale, 'skdash.services')),
              const SizedBox(height: 12),
              _ServiceRow(locale: locale),
              const SizedBox(height: 22),
              _SectionTitle(tr(locale, 'skdash.recentActivity')),
              const SizedBox(height: 12),
              _RecentActivity(
                locale: locale,
                movements: movements,
                onRetry: () => ref.invalidate(recentStoreMovementsProvider),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- profile row

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
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
                    size: 23, color: Color(0xFF10213F)),
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

class _Greeting extends StatelessWidget {
  const _Greeting({required this.locale, required this.roleLabel});

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
            color: Color(0xFF10213F),
          ),
        ),
        Text(
          roleLabel,
          style: const TextStyle(
            fontSize: 32,
            height: 1.14,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.6,
            color: Color(0xFF10213F),
          ),
        ),
      ],
    );
  }
}

// --------------------------------------------------------------------- search

class _SearchField extends StatefulWidget {
  const _SearchField({required this.locale, required this.onFilterTap});

  final Locale locale;
  final VoidCallback onFilterTap;

  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  /// A serial opens the inspector that already exists. Anything shorter is not
  /// a serial, so the field says so instead of searching for nothing.
  void _submit(String raw) {
    final q = raw.trim();
    if (q.length < 6) {
      LimsToast.show(context, tr(widget.locale, 'skdash.searchEmpty'));
      return;
    }
    final digits = q.replaceAll(RegExp(r'[^0-9]'), '');
    final serial = digits.length >= 6 ? digits : q;
    context.push('/imei-inspector?imei=$serial');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.only(left: 18, right: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F2F6BD6),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, size: 23, color: Color(0xFF10213F)),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _ctrl,
              textInputAction: TextInputAction.search,
              onSubmitted: _submit,
              style: const TextStyle(fontSize: 15, color: Color(0xFF10213F)),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: tr(widget.locale, 'skdash.searchHint'),
                hintStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF7184A7),
                ),
              ),
            ),
          ),
          InkWell(
            onTap: widget.onFilterTap,
            borderRadius: BorderRadius.circular(99),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFEAF2FF),
                borderRadius: BorderRadius.circular(99),
              ),
              child: const Icon(Icons.tune_rounded,
                  size: 20, color: Color(0xFF347FF5)),
            ),
          ),
        ],
      ),
    );
  }
}

// --------------------------------------------------------------- low stock bar

class _LowStockBanner extends StatelessWidget {
  const _LowStockBanner({
    required this.locale,
    required this.count,
    required this.onTap,
  });

  final Locale locale;
  final int count;
  final VoidCallback onTap;

  String get _label {
    if (count == 0) return tr(locale, 'skdash.alertsNone');
    if (count == 1) return tr(locale, 'skdash.alertsOne');
    return trf(locale, 'skdash.alertsMany', {'n': count});
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        height: 78,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF2678FF), Color(0xFF42C8F5)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
              color: Color(0x332D7BF7),
              blurRadius: 22,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.receipt_long_rounded,
                  size: 22, color: Color(0xFF347FF5)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
            const Icon(Icons.arrow_forward_rounded,
                size: 22, color: Colors.white),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------ stock summary

class _StockSummaryCard extends StatelessWidget {
  const _StockSummaryCard({
    required this.locale,
    required this.handsets,
    required this.day,
    required this.onViewInventory,
  });

  final Locale locale;
  final int handsets;
  final AsyncValue<StoreDayCounts> day;
  final VoidCallback onViewInventory;

  @override
  Widget build(BuildContext context) {
    final counts = day.valueOrNull;
    final subtitle = counts == null || !counts.available
        ? tr(locale, 'skdash.notConnected')
        : trf(locale, 'skdash.addedPos', {
            'imeis': counts.serialsAdded,
            'pos': counts.purchaseOrders,
          });

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: const [
          BoxShadow(
            color: Color(0x142F6BD6),
            blurRadius: 26,
            offset: Offset(0, 12),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 12, 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr(locale, 'skdash.todayActivity'),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    color: Color(0xFF10213F),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF7184A7),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$handsets',
                      style: const TextStyle(
                        fontSize: 38,
                        height: 1,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1.2,
                        color: Color(0xFF10213F),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Text(
                          tr(locale, 'skdash.handsetsInStock'),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF5B7194),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _ViewInventoryButton(
                  label: tr(locale, 'skdash.viewInventory'),
                  onTap: onViewInventory,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 126,
            height: 156,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 108,
                  height: 108,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [Color(0xFFEAF3FF), Color(0x00EAF3FF)],
                    ),
                  ),
                ),
                Image.asset(
                  'assets/images/blue_iphones_duo.png',
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.medium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ViewInventoryButton extends StatelessWidget {
  const _ViewInventoryButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF246BFD), Color(0xFF5AA5FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF246BFD).withValues(alpha: 0.34),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.55),
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
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.arrow_forward_rounded,
                size: 16, color: Colors.white),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------- AI shortcut

/// The AI assistant is the one card that is allowed to look like a product.
///
/// The artwork is a violet plane with a glass orb, so the headline sits on the
/// dark left half and stays readable; the orb never overlaps the text. The tap
/// target is the existing `/ai` route — no new screen, no placeholder action.
class _AiAssistantCard extends StatelessWidget {
  const _AiAssistantCard({required this.locale, required this.onTap});

  final Locale locale;
  final VoidCallback onTap;

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
              // Keeps the left half dark enough for white text on any screen
              // width, without dimming the orb.
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xE65B3BD6), Color(0x005B3BD6)],
                    stops: [0.34, 0.78],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 16, 18),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            tr(locale, 'skdash.aiTitle'),
                            style: const TextStyle(
                              fontSize: 16.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            tr(locale, 'skdash.aiSub'),
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withValues(alpha: 0.78),
                            ),
                          ),
                        ],
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

// ------------------------------------------------------------------- services

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.3,
        color: Color(0xFF10213F),
      ),
    );
  }
}

class _ServiceRow extends StatelessWidget {
  const _ServiceRow({required this.locale});

  final Locale locale;

  @override
  Widget build(BuildContext context) {
    // Destinations are the routes that already exist. There is no stock-issue
    // screen in this build, so the row offers the real workflows rather than a
    // button wired to nothing.
    final items = <_ServiceItem>[
      _ServiceItem(
        label: tr(locale, 'skdash.receiveStock'),
        art: 'assets/images/icon_box_3d.png',
        tint: const Color(0xFFEAF2FF),
        route: '/receive',
      ),
      _ServiceItem(
        label: tr(locale, 'skdash.dispatch'),
        art: 'assets/images/icon_truck_3d.png',
        tint: const Color(0xFFE7F9EF),
        route: '/transfer',
      ),
      _ServiceItem(
        label: tr(locale, 'skdash.scanImei'),
        art: 'assets/images/icon_scanner_3d.png',
        tint: const Color(0xFFF1EBFF),
        route: '/scan',
      ),
      _ServiceItem(
        label: tr(locale, 'skdash.reports'),
        art: 'assets/images/icon_chart_3d.png',
        tint: const Color(0xFFFFF3E8),
        route: '/reports',
      ),
    ];

    return SizedBox(
      height: 104,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (ctx, i) {
          final item = items[i];
          return InkWell(
            onTap: () => context.push(item.route),
            borderRadius: BorderRadius.circular(22),
            child: Container(
              width: 118,
              padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
              decoration: BoxDecoration(
                color: item.tint,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Image.asset(
                    item.art,
                    width: 46,
                    height: 46,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.medium,
                  ),
                  Text(
                    item.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      height: 1.15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF10213F),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ServiceItem {
  const _ServiceItem({
    required this.label,
    required this.art,
    required this.tint,
    required this.route,
  });

  final String label;

  /// 3D render on a transparent background. One per shortcut, so the row reads
  /// as a set rather than four unrelated glyphs.
  final String art;
  final Color tint;
  final String route;
}

// ---------------------------------------------------------- recent activity

class _RecentActivity extends StatelessWidget {
  const _RecentActivity({
    required this.locale,
    required this.movements,
    required this.onRetry,
  });

  final Locale locale;
  final AsyncValue<List<StockMovement>> movements;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return movements.when(
      loading: () => const SizedBox(
        height: 128,
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          ),
        ),
      ),
      error: (_, __) => _ActivityPlaceholder(
        icon: Icons.cloud_off_rounded,
        text: tr(locale, 'skdash.mvError'),
        action: TextButton(
          onPressed: onRetry,
          child: Text(tr(locale, 'skdash.retry')),
        ),
      ),
      data: (list) {
        if (list.isEmpty) {
          return _ActivityPlaceholder(
            icon: Icons.inventory_2_outlined,
            text: tr(locale, 'skdash.mvEmpty'),
          );
        }
        return SizedBox(
          height: 132,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (ctx, i) => _MovementCard(
              movement: list[i],
              locale: locale,
              onTap: () => context.go('/stock'),
            ),
          ),
        );
      },
    );
  }
}

class _ActivityPlaceholder extends StatelessWidget {
  const _ActivityPlaceholder({
    required this.icon,
    required this.text,
    this.action,
  });

  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF5FF),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Icon(icon, size: 22, color: const Color(0xFF7A93B8)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: Color(0xFF5B7194),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}

class _MovementCard extends StatelessWidget {
  const _MovementCard({
    required this.movement,
    required this.locale,
    required this.onTap,
  });

  final StockMovement movement;
  final Locale locale;
  final VoidCallback onTap;

  ({IconData icon, String title, Color iconColor}) get _face {
    switch (movement.source) {
      case 'transfer':
        return (
          icon: Icons.local_shipping_rounded,
          title: tr(locale, 'skdash.mvTransfer'),
          iconColor: const Color(0xFF347FF5),
        );
      case 'return':
        return (
          icon: Icons.assignment_return_rounded,
          title: tr(locale, 'skdash.mvReturn'),
          iconColor: const Color(0xFF7C5CFC),
        );
      default:
        return (
          icon: Icons.inventory_2_rounded,
          title: tr(locale, 'skdash.mvSupplier'),
          iconColor: const Color(0xFF347FF5),
        );
    }
  }

  String get _detail {
    if (movement.source == 'transfer' &&
        (movement.fromBranch ?? '').trim().isNotEmpty) {
      return '${movement.fromBranch} → ${movement.branch}';
    }
    if (movement.lines.isNotEmpty) {
      final l = movement.lines.first;
      return '${l.name} · ${trf(locale, 'skdash.mvUnits', {'n': l.qty})}';
    }
    if ((movement.supplierName ?? '').trim().isNotEmpty) {
      return '${movement.supplierName} · '
          '${trf(locale, 'skdash.mvUnits', {'n': movement.units})}';
    }
    return trf(locale, 'skdash.mvUnits', {'n': movement.units});
  }

  @override
  Widget build(BuildContext context) {
    final face = _face;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: 246,
        padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFF7FBFF), Color(0xFFD9E9FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFE4EDFB)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(face.icon, size: 18, color: face.iconColor),
                  ),
                  const Spacer(),
                  Text(
                    face.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF10213F),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _detail,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.25,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF7184A7),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(top: 44),
              child: Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_forward_rounded,
                    size: 15, color: Color(0xFF347FF5)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
