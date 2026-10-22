import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/notifications_provider.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../../core/l10n/strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../home/presentation/dashboard_kit.dart';

/// Everything that needs attention, in one readable place.
///
/// Two complaints drove this rewrite. The list was five invented cards with a
/// "Mark all read" button that did nothing but raise a toast, and tapping one
/// opened a two-line summary on top of a small card — unreadable for a cashier
/// standing at the counter. Both are fixed: the feed comes from the database and
/// tapping opens the notice full screen.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final feed = ref.watch(notificationFeedProvider);
    final readIds = ref.watch(readNotificationsProvider);
    final unread = feed.where((n) => !readIds.contains(n.id)).length;

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
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: DashPageHeader(
                  title: tr(locale, 'notif.title'),
                  subtitle: unread == 0
                      ? tr(locale, 'notif.allRead')
                      : trf(locale, 'notif.unread', {'n': unread}),
                  onBack: () => context.pop(),
                  trailing: feed.isEmpty
                      ? null
                      : _MarkAllButton(
                          label: tr(locale, 'notif.markAll'),
                          onTap: () {
                            ref
                                .read(readNotificationsProvider.notifier)
                                .markAll(feed.map((n) => n.id));
                            LimsToast.show(
                              context,
                              tr(locale, 'notif.markedAll'),
                              isSuccess: true,
                            );
                          },
                        ),
                ),
              ),
              Expanded(
                child: feed.isEmpty
                    ? _EmptyState(locale: locale)
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 2, 20, 40),
                        itemCount: feed.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final n = feed[i];
                          return _NotificationCard(
                            notification: n,
                            locale: locale,
                            read: readIds.contains(n.id),
                            onTap: () {
                              // Reading it is what marks it read — not opening the list.
                              ref
                                  .read(readNotificationsProvider.notifier)
                                  .markRead(n.id);
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  fullscreenDialog: true,
                                  builder: (_) => NotificationDetailScreen(
                                    notificationId: n.id,
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MarkAllButton extends StatelessWidget {
  const _MarkAllButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Color(0x142F6BD6),
              blurRadius: 14,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: const SizedBox(
              width: 42,
              height: 42,
              child: Icon(
                Icons.done_all_rounded,
                size: 19,
                color: Color(0xFF1B6EF3),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.locale});

  final Locale locale;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: Color(0xFFECFDF5),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded,
                  size: 30, color: Color(0xFF027A48)),
            ),
            const SizedBox(height: 14),
            Text(
              tr(locale, 'notif.empty'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.ink500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.notification,
    required this.locale,
    required this.read,
    required this.onTap,
  });

  final AppNotification notification;
  final Locale locale;
  final bool read;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final swahili = locale.languageCode == 'sw';
    final urgent = notification.kind == NotificationKind.overdue;
    final tint = urgent ? const Color(0xFFD92D20) : const Color(0xFFEA580C);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: read ? const Color(0xFFE8EEF7) : tint.withValues(alpha: 0.35),
          width: read ? 1 : 1.4,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: tint.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    urgent
                        ? Icons.schedule_rounded
                        : Icons.inventory_2_outlined,
                    size: 20,
                    color: tint,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              notificationTitle(notification, swahili: swahili),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight:
                                    read ? FontWeight.w700 : FontWeight.w900,
                                color: AppTheme.ink900,
                              ),
                            ),
                          ),
                          if (!read)
                            Container(
                              width: 7,
                              height: 7,
                              margin: const EdgeInsets.only(left: 6),
                              decoration: BoxDecoration(
                                color: tint,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        notificationSummary(notification, swahili: swahili),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppTheme.ink500,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    size: 18, color: AppTheme.ink400),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The whole notice, full screen, at a size that can be read standing up.
class NotificationDetailScreen extends ConsumerWidget {
  const NotificationDetailScreen({super.key, required this.notificationId});

  final String notificationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final swahili = locale.languageCode == 'sw';
    final feed = ref.watch(notificationFeedProvider);
    final match = feed.where((n) => n.id == notificationId).toList();
    final n = match.isEmpty ? null : match.first;

    if (n == null) {
      // The condition cleared while the page was open — a real possibility when a
      // payment lands or stock arrives. Say so instead of showing a stale notice.
      return Scaffold(
        backgroundColor: AppTheme.canvas,
        appBar: AppBar(
          backgroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Text(
              tr(locale, 'notif.resolved'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppTheme.ink500),
            ),
          ),
        ),
      );
    }

    final urgent = n.kind == NotificationKind.overdue;
    final tint = urgent ? const Color(0xFFD92D20) : const Color(0xFFEA580C);

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: AppTheme.ink900),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          tr(locale, 'notif.detailTitle'),
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: AppTheme.ink900,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              ref.read(readNotificationsProvider.notifier).markUnread(n.id);
              Navigator.pop(context);
            },
            child: Text(
              tr(locale, 'notif.markUnread'),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE8EEF7)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: tint.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    urgent
                        ? Icons.schedule_rounded
                        : Icons.inventory_2_outlined,
                    color: tint,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  notificationTitle(n, swahili: swahili),
                  style: const TextStyle(
                    fontSize: 21,
                    height: 1.25,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.4,
                    color: AppTheme.ink900,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  notificationBody(n, swahili: swahili),
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.55,
                    color: AppTheme.ink700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 48,
            child: FilledButton.icon(
              onPressed: () {
                Navigator.pop(context);
                context.push(n.route);
              },
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: Text(tr(locale, 'notif.open')),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.brand600,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
