import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'inventory_provider.dart';

/// What the shop needs to know, derived from the rows it already has.
///
/// The old screen carried five hand-written cards — "Stock discrepancy detected
/// at Branch 12", "Juma Selemani · TZS 850,000" — none of which came from the
/// database, and a "Mark all read" button that only showed a toast. A notice that
/// cannot be wrong is not a notice.
///
/// This feed is computed: low stock from `products`, arrears from `loans`. If the
/// shop has nothing wrong, the list is empty and says so.
enum NotificationKind { lowStock, overdue }

class AppNotification {
  const AppNotification({
    required this.id,
    required this.kind,
    required this.count,
    required this.detail,
    required this.route,
    this.sampleName,
  });

  /// Stable across rebuilds, so a read flag survives a reload.
  final String id;
  final NotificationKind kind;
  final int count;

  /// Human detail: the model names, or the borrower and handset.
  final String detail;
  final String route;
  final String? sampleName;
}

final notificationFeedProvider = Provider<List<AppNotification>>((ref) {
  final out = <AppNotification>[];

  final low = ref
      .watch(inventoryProvider)
      .where((p) => p.status == 'low' || p.stock <= p.min)
      .toList();
  if (low.isNotEmpty) {
    out.add(AppNotification(
      id: 'low-stock',
      kind: NotificationKind.lowStock,
      count: low.length,
      detail: low.map((p) => '${p.name} (${p.stock})').join(', '),
      route: '/stock',
    ));
  }

  final overdue = ref
      .watch(loansProvider)
      .where((l) => l.status == 'overdue')
      .toList();
  if (overdue.isNotEmpty) {
    final first = overdue.first;
    out.add(AppNotification(
      id: 'overdue-loans',
      kind: NotificationKind.overdue,
      count: overdue.length,
      detail: '${first.name} · ${first.item}',
      route: '/loans',
      sampleName: first.name,
    ));
  }

  return out;
});

/// Which notices have been opened.
///
/// Persisted, because "read" that resets on reload is not a state a shift handover
/// can rely on.
class ReadNotifications extends StateNotifier<Set<String>> {
  ReadNotifications() : super(<String>{}) {
    _restore();
  }

  static const String _key = 'lims.notifications.read.v1';

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList(_key);
      if (saved != null) state = saved.toSet();
    } catch (_) {
      // Storage blocked: everything reads as unread, which is the safe direction.
    }
  }

  bool isRead(String id) => state.contains(id);

  Future<void> markRead(String id) async {
    if (state.contains(id)) return;
    state = {...state, id};
    await _save();
  }

  Future<void> markAll(Iterable<String> ids) async {
    state = {...state, ...ids};
    await _save();
  }

  Future<void> markUnread(String id) async {
    final next = {...state}..remove(id);
    state = next;
    await _save();
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_key, state.toList());
    } catch (_) {
      // Same reasoning as restore: the UI keeps working, it just forgets.
    }
  }
}

final readNotificationsProvider =
    StateNotifierProvider<ReadNotifications, Set<String>>((ref) {
  return ReadNotifications();
});

/// Unread count for the header badge.
final unreadNotificationsProvider = Provider<int>((ref) {
  final feed = ref.watch(notificationFeedProvider);
  final read = ref.watch(readNotificationsProvider);
  return feed.where((n) => !read.contains(n.id)).length;
});

/// One notice's long-form body. The list shows a summary; the detail page shows
/// the whole thing, so a cashier can read it without squinting at two lines.
String notificationBody(AppNotification n, {required bool swahili}) {
  switch (n.kind) {
    case NotificationKind.lowStock:
      return swahili
          ? 'Modeli ${n.count} ziko chini ya kiwango cha akiba. Orodha kamili:\n\n${n.detail}\n\nPokea stoo au hamisha units kutoka tawi lingine kabla ya kuuza.'
          : '${n.count} models are below their buffer level. Full list:\n\n${n.detail}\n\nReceive stock or transfer units from another branch before selling.';
    case NotificationKind.overdue:
      return swahili
          ? 'Mikopo ${n.count} imechelewa malipo. Ya kwanza: ${n.detail}.\n\nFungua orodha ya wakopaji kupiga simu kwa mdhamini na kurekodi malipo.'
          : '${n.count} loans are past their installment date. First: ${n.detail}.\n\nOpen the borrower list to call the guarantor and record a payment.';
  }
}

/// Icons and colours per kind, kept next to the data rather than in the widget.
int notificationSeverity(NotificationKind kind) =>
    kind == NotificationKind.overdue ? 2 : 1;

/// Kept for callers that want a plain title without the widget layer.
String notificationTitle(AppNotification n, {required bool swahili}) {
  switch (n.kind) {
    case NotificationKind.lowStock:
      return swahili
          ? 'Modeli ${n.count} zinahitaji kuongezewa'
          : '${n.count} models need restocking';
    case NotificationKind.overdue:
      return swahili
          ? 'Mikopo ${n.count} imechelewa'
          : '${n.count} loans are overdue';
  }
}

/// The item names alone, for a subtitle.
String notificationSummary(AppNotification n, {required bool swahili}) {
  switch (n.kind) {
    case NotificationKind.lowStock:
      return n.detail;
    case NotificationKind.overdue:
      return n.detail;
  }
}
