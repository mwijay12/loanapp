import 'dart:async' show Completer, Future, Timer, unawaited;
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// One row change as the app understands it, independent of the transport.
///
/// The bridge deliberately does not hand out `PostgresChangePayload`: that type
/// belongs to the realtime client, and a screen or a provider that has to import
/// it cannot be tested without a socket. [LiveChange] is the seam.
enum LiveEventKind { inserted, updated, deleted }

class LiveChange {
  const LiveChange({
    required this.table,
    required this.kind,
    required this.record,
    this.oldRecord = const {},
    this.committedAt,
  });

  final String table;
  final LiveEventKind kind;

  /// After the row. Empty for a delete, where [oldRecord] carries the key.
  final Map<String, dynamic> record;
  final Map<String, dynamic> oldRecord;
  final DateTime? committedAt;

  /// The primary key. Every published table has a single-column `id` — verified
  /// against `pg_index.indisprimary` before this was written, which is what makes
  /// an id-only merge enough.
  ///
  /// Returns null when the payload has no usable key. That is not an edge case to
  /// paper over: without a key the app cannot tell an update from a new row, so
  /// the caller must refetch instead of guessing.
  String? get rowKey {
    final raw = kind == LiveEventKind.deleted
        ? (oldRecord['id'] ?? record['id'])
        : (record['id'] ?? oldRecord['id']);
    final s = raw?.toString().trim();
    return (s == null || s.isEmpty) ? null : s;
  }

  @override
  String toString() => 'LiveChange($table ${kind.name} id=${rowKey ?? '—'})';
}

/// Tables the app subscribes to, because the root loader can actually put their
/// rows into a provider the screens are watching.
///
/// Deliberately narrower than the database publication. `product_units`,
/// `stock_receipts` and `stock_receipt_lines` are published server-side but have
/// no provider to write into — every read of them is an imperative `ApiService`
/// call made by whichever screen is open, so a subscription to them would receive
/// rows and throw them away. Their visible effect does still arrive: receiving a
/// receipt updates `products.stock`, and `products` is on this list.
const List<String> kLiveTables = <String>[
  'sales',
  'products',
  'loans',
  'staff',
  'branches',
  'activities',
];

/// Published in `supabase_realtime` but not subscribed to yet, with the reason.
/// These join the list above when a provider exists to hold their rows.
const List<String> kLivePublishedButUnsubscribed = <String>[
  'product_units',
  'stock_receipts',
  'stock_receipt_lines',
];

/// Tables that must never be subscribed to from a client, whatever the database
/// says. `petty_cash` is the reason this list exists: its only SELECT policy is
/// `to public using (true)`, and Realtime applies RLS per subscriber, so a live
/// subscription to it would push the shop's cash expenses to any browser holding
/// the publishable key — which is shipped inside every build. `profiles` holds
/// staff identities scoped per person.
///
/// Removing a name from this list requires closing its SELECT policy first
/// (remediation plan P2) and updating
/// backend/supabase/tests/realtime_assertions.sql.
const List<String> kLiveRefusedTables = <String>['petty_cash', 'profiles'];

/// Connection seam. [SupabaseLiveSocket] is the real one; tests use a fake that
/// can drop, reconnect and deliver a payload with no key in it.
abstract class LiveSocket {
  /// Starts listening. [onRow] fires for each change on [tables];
  /// [onAvailability] reports whether events can be expected right now.
  Future<void> open({
    required List<String> tables,
    required void Function(LiveChange change) onRow,
    required void Function(bool live) onAvailability,
  });

  Future<void> close();
}

/// Applies row changes as soon as Postgres emits them.
///
/// This is the piece the app never had. Before it, `LiveDataLoader` fetched once
/// behind `if (_started) return;` and nothing else ever touched the providers, so
/// a sale recorded on a Branch Manager's phone stayed off the admin's screen
/// until someone reloaded. The database could not have told them either way: the
/// `supabase_realtime` publication held zero tables until migration
/// 2026_10_27_01.
///
/// Two rules shape this class:
///
/// 1. **A dropped socket is a data-loss event, not a cosmetic one.** Messages
///    published while the websocket is down are gone — Postgres changes are not
///    queued and replayed. So losing the connection marks a refetch as owed, and
///    the refetch runs when it returns. `Live · Supabase` shown over a dead
///    socket is how a till sells a handset twice.
/// 2. **One bad row must not kill the feed.** Rows are applied one at a time in
///    arrival order, each inside a try/catch. Order matters because every event
///    carries a whole row: applied concurrently, an older update that finishes
///    later would overwrite a newer one and the screen would settle on a value
///    the database no longer holds. A row that throws — synchronously or after
///    an `await` — is counted and turns into a refetch rather than an exception on
///    the socket's own call stack.
class RealtimeBridge {
  RealtimeBridge({
    required this.socket,
    required this.onRow,
    required this.onResync,
    this.tables = kLiveTables,
    this.resyncDebounce = const Duration(milliseconds: 400),
    this.quietReconcileAfter = const Duration(seconds: 60),
  });

  final LiveSocket socket;

  /// Applies one row. Must be idempotent: Postgres can deliver the same update
  /// twice, and a rejoin can redeliver the tail of a burst. Awaiting it is what
  /// lets a failure be seen — see [_drain].
  final Future<void> Function(LiveChange change) onRow;

  /// Refetches from REST. Called after a gap, never for a row that applied fine.
  final Future<void> Function() onResync;

  final List<String> tables;
  final Duration resyncDebounce;

  /// Ceiling on how long a socket that claims to be live may go without either a
  /// frame or a completed re-read before the app stops trusting the claim.
  ///
  /// Not hypothetical. On 2026-10-31 this project sat in exactly this
  /// state: `pg_publication_tables` listed all nine tables, the Phoenix join answered
  /// `ok`, `pg_stat_replication` showed `realtime_replication_connection` streaming —
  /// and yet a subscriber received nothing whatsoever, for any write. The fix was
  /// server-side (re-registering the tables in `supabase_realtime`; see
  /// `backend/supabase/maintenance/realtime_publication_refresh.sql`), but nothing in
  /// a client can know that from the inside, because every signal it gets says
  /// healthy. `realtime_client` documents the mode in its own source: *"a channel that
  /// reports `subscribed` yet delivers nothing"*.
  ///
  /// A silent feed is the worst failure this feature can have, because it is
  /// indistinguishable from a quiet shop: the pill reads `Live` and the numbers simply
  /// never move — the exact complaint that started this work. The watchdog cannot
  /// repair the feed. What it can do is refuse to let the screen be less trustworthy
  /// than a manual reload.
  final Duration quietReconcileAfter;

  /// How many unapplied rows the queue may hold before it is abandoned in favour
  /// of a reload. Generous: a 40-line stock receipt is normal traffic, and a
  /// queue this long means the merge path itself has stopped making progress.
  static const int _pendingCeiling = 512;

  bool _started = false;
  bool _stopping = false;
  bool _live = false;
  bool _everSubscribed = false;
  bool _resyncOwed = false;
  Future<void>? _inFlight;
  Timer? _resyncTimer;
  Timer? _watchdog;
  final List<LiveChange> _pending = <LiveChange>[];
  bool _applying = false;
  int _applied = 0;
  int _dropped = 0;
  int _resyncs = 0;
  DateTime? _lastEventAt;

  /// The last moment the feed proved it was carrying data: a frame delivered, or a
  /// re-read completed. A quiet shop and a dead feed look identical from the pill, so
  /// this is the only thing that tells them apart.
  DateTime? _lastProofAt;
  int _quietReconciles = 0;

  /// True while events can be expected. Drives the header pill.
  bool get isLive => _live;
  DateTime? get lastEventAt => _lastEventAt;
  int get eventsApplied => _applied;
  int get eventsDropped => _dropped;
  int get resyncCount => _resyncs;

  /// How many times the app re-read the tables because a "live" socket went quiet.
  int get quietReconcileCount => _quietReconciles;
  DateTime? get lastProofAt => _lastProofAt;
  bool get isStarted => _started;

  /// Subscribes to every allowed table. Returns false when the socket refused to
  /// start at all — the caller keeps its snapshot and says so in the UI.
  Future<bool> start() async {
    if (_started) return _live;
    _started = true;

    final allowed = <String>[];
    for (final t in tables) {
      if (kLiveRefusedTables.contains(t)) {
        // Loud on purpose: silently skipping a table is how a subscription to
        // petty_cash would look like it works in review.
        debugPrint('LIMS realtime: refusing to subscribe to `$t` — its SELECT '
            'policy is not closed (see kLiveRefusedTables).');
        continue;
      }
      allowed.add(t);
    }
    if (allowed.isEmpty) {
      debugPrint('LIMS realtime: no subscribable tables, staying on snapshot.');
      return false;
    }

    try {
      await socket.open(
        tables: allowed,
        onRow: _handleRow,
        onAvailability: _handleAvailability,
      );
    } catch (e) {
      _live = false;
      debugPrint('LIMS realtime: could not subscribe -> $e');
      return false;
    }
    // The host has just loaded the snapshot this subscription continues from, so
    // "now" counts as proof and the first reconcile cannot fire before a full quiet
    // interval has actually passed.
    _lastProofAt = DateTime.now();
    _startWatchdog();
    return _live;
  }

  /// Re-reads the tables when a live feed has gone quiet.
  ///
  /// Deliberately narrow, in three ways. It does nothing while the socket is down:
  /// that path already recovers in [_handleAvailability], and polling a network that
  /// is off is how three devices in a shop end up hammering a database that cannot
  /// answer. It does nothing when a re-read is already owed or in flight, so a quiet
  /// hour costs one read per interval and never a pile-up. And it does nothing while
  /// frames are arriving, because a delivered row is better evidence than a timer.
  void _startWatchdog() {
    _watchdog?.cancel();
    if (quietReconcileAfter <= Duration.zero) return;
    _watchdog = Timer.periodic(quietReconcileAfter, (_) {
      if (!_live || _stopping) return;
      if (_resyncOwed || _inFlight != null) return;
      final last = _lastProofAt;
      if (last != null &&
          DateTime.now().difference(last) < quietReconcileAfter) {
        return;
      }
      _quietReconciles++;
      if (_quietReconciles == 1 && _applied == 0) {
        // The signature of the 2026-10-31 failure: subscribed, never delivered one
        // row. Worth one line in the log, and only one.
        debugPrint('LIMS realtime: subscribed but not one frame in '
            '${quietReconcileAfter.inSeconds}s — falling back to periodic reads.');
      }
      scheduleResync();
    });
  }

  Future<void> stop() async {
    if (_stopping) return;
    _stopping = true;
    _resyncTimer?.cancel();
    _resyncTimer = null;
    _watchdog?.cancel();
    _watchdog = null;
    _live = false;
    // Rows that never got applied are not "dropped" in the sense the pill warns
    // about — this host is going away, and the next one loads a fresh snapshot.
    _pending.clear();
    try {
      await socket.close();
    } catch (e) {
      debugPrint('LIMS realtime: error while closing -> $e');
    }
    _started = false;
    _everSubscribed = false;
    _resyncOwed = false;
  }

  /// Called by the host when the app comes back to the foreground.
  ///
  /// supabase_flutter rejoins the channel on resume, but the rows that changed
  /// while the app was backgrounded were published to nobody. The refetch is what
  /// closes that gap; the pill would otherwise read `Live` over stale numbers.
  Future<void> resume() async {
    if (!_started) return;
    await refreshNow();
  }

  /// Drops the debounce and refetches immediately, for an explicit "sync now".
  ///
  /// A person who pressed the button is asking a question about *now*; making them
  /// wait out a 400 ms coalescing window — or worse, returning while the fetch is
  /// still in flight — would let the app answer "synced" before it has any new
  /// rows. Returns without refetching when the feed never started, so the caller
  /// can fall back to a plain REST reload.
  Future<void> refreshNow() async {
    if (!_started) return;
    _resyncTimer?.cancel();
    _resyncTimer = null;
    _resyncOwed = true;
    // Two passes at most. If a read was already in the air when the button was
    // pressed, that read began earlier and `await` on it returns its rows, not
    // newer ones — so ask for a second pass and only then let the UI answer.
    for (var pass = 0; pass < 2; pass++) {
      await _runResync();
      if (!_resyncOwed) break;
    }
  }

  void _handleAvailability(bool live) {
    if (live == _live) return;
    _live = live;
    if (live) {
      // A reconnect is a gap: whatever changed while the socket was down was
      // published to nobody. The very first subscribe is not a gap, because the
      // host has just fetched the snapshot this subscription continues from.
      //
      // Refetch immediately instead of through `scheduleResync()`. That method
      // exists to coalesce a burst of individual rows; here the loss is already
      // known and bounded, and waiting out a debounce window keeps wrong numbers on
      // the counter for another 400 ms after the network is already back.
      if (_everSubscribed) {
        _resyncOwed = true;
        unawaited(_runResync());
      }
      _everSubscribed = true;
      return;
    }
    // Down. Anything published from here until the next `true` is lost, so a
    // reload is owed the moment the socket returns.
    _resyncOwed = true;
  }

  void _handleRow(LiveChange change) {
    _lastEventAt = change.committedAt ?? DateTime.now();
    _lastProofAt = DateTime.now();

    final key = change.rowKey;
    if (key == null) {
      // No key means no merge. Counting it and refetching beats inventing a row
      // id or, worse, dropping the change in silence.
      _dropped++;
      debugPrint('LIMS realtime: ${change.table} ${change.kind.name} arrived '
          'without a primary key — refetching instead of guessing.');
      scheduleResync();
      return;
    }

    // Queued, not applied inline: the socket's own callback has to return
    // immediately, and two rows landing on the same handset must not race.
    _pending.add(change);
    if (_pending.length > _pendingCeiling) {
      // The app cannot merge faster than the database is writing (a bulk stock
      // receipt while the UI is stalled, for instance). The queue is no longer a
      // record of anything useful at that point — drop it and read the tables.
      _dropped += _pending.length;
      _pending.clear();
      debugPrint('LIMS realtime: row backlog passed $_pendingCeiling — '
          'discarding the queue and refetching.');
      scheduleResync();
      return;
    }
    if (!_applying) unawaited(_drain());
  }

  /// Applies queued rows one at a time, in arrival order.
  ///
  /// `await` is the point of this method. With a `void` callback the try/catch
  /// could only see synchronous throws, so a provider that failed partway through
  /// an async merge counted as applied, left a half-written row on screen, and
  /// nothing ever corrected it.
  Future<void> _drain() async {
    _applying = true;
    try {
      while (_pending.isNotEmpty) {
        final change = _pending.removeAt(0);
        try {
          await onRow(change);
          _applied++;
        } catch (e) {
          _dropped++;
          debugPrint('LIMS realtime: applying $change failed -> $e');
          scheduleResync();
        }
      }
    } finally {
      _applying = false;
    }
  }

  /// Coalesces bursts. A stock receipt with 40 lines arrives as 40 line events
  /// plus a receipt event; refetching 41 times would put more load on the
  /// database than the subscription was meant to remove.
  void scheduleResync() {
    _resyncOwed = true;
    _resyncTimer?.cancel();
    _resyncTimer = Timer(resyncDebounce, () {
      _resyncTimer = null;
      unawaited(_runResync());
    });
  }

  /// Runs a refetch, joining one that is already in the air.
  ///
  /// Returning early while a read is in flight — which is what this did first — is
  /// how a `Live` label can be painted from a fetch that started before the change
  /// you are looking at. Callers that need *current* rows get a second pass from
  /// [refreshNow]; callers that merely want the gap closed share the read.
  Future<void> _runResync() {
    final running = _inFlight;
    if (running != null) return running;
    if (!_resyncOwed) return Future<void>.value();
    _resyncOwed = false;
    final work = _doResync();
    _inFlight = work;
    return work.whenComplete(() => _inFlight = null);
  }

  Future<void> _doResync() async {
    try {
      await onResync();
      _resyncs++;
      _lastProofAt = DateTime.now();
    } catch (e) {
      // The snapshot on screen is now known-stale. Try once more rather than
      // leaving a wrong number that looks authoritative.
      _resyncOwed = true;
      debugPrint('LIMS realtime: refetch failed -> $e');
    }
    if (_resyncOwed && !_stopping) scheduleResync();
  }
}

/// The production [LiveSocket], on top of the Postgres logical replication
/// stream Supabase runs for the tables in the `supabase_realtime` publication.
class SupabaseLiveSocket implements LiveSocket {
  SupabaseLiveSocket({this.channelName = 'lims-live', this.client});

  /// One channel for all tables: one join message, one round trip, and the
  /// server applies the RLS check for the authenticated user once per subscription.
  final String channelName;
  final SupabaseClient? client;

  RealtimeChannel? _channel;

  SupabaseClient get _client => client ?? Supabase.instance.client;

  @override
  Future<void> open({
    required List<String> tables,
    required void Function(LiveChange change) onRow,
    required void Function(bool live) onAvailability,
  }) async {
    final client = _client;

    // The socket, not the channel, is what actually goes away on a dropped
    // network. `onClose`/`onError` are the only honest source for "no events are
    // arriving right now".
    client.realtime.onClose((_) => onAvailability(false));
    client.realtime.onError((_) => onAvailability(false));
    client.realtime.onOpen(() => onAvailability(true));

    final channel = client.channel(channelName);
    _channel = channel;
    for (final table in tables) {
      channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: table,
        callback: (payload) {
          onAvailability(true);
          onRow(
            LiveChange(
              table: payload.table,
              kind: switch (payload.eventType) {
                PostgresChangeEvent.insert => LiveEventKind.inserted,
                PostgresChangeEvent.update => LiveEventKind.updated,
                PostgresChangeEvent.delete => LiveEventKind.deleted,
                PostgresChangeEvent.all => LiveEventKind.updated,
              },
              record: payload.newRecord,
              oldRecord: payload.oldRecord,
              committedAt: payload.commitTimestamp,
            ),
          );
        },
      );
    }

    final joined = Completer<bool>();
    channel.subscribe((status, error) {
      switch (status) {
        case RealtimeSubscribeStatus.subscribed:
          onAvailability(true);
          if (!joined.isCompleted) joined.complete(true);
        case RealtimeSubscribeStatus.channelError:
        case RealtimeSubscribeStatus.timedOut:
        case RealtimeSubscribeStatus.closed:
          debugPrint('LIMS realtime: $channelName $status ${error ?? ''}');
          onAvailability(false);
          if (!joined.isCompleted) joined.complete(false);
      }
    });
    await joined.future;
  }

  @override
  Future<void> close() async {
    final channel = _channel;
    _channel = null;
    if (channel == null) return;
    await _client.realtime.removeChannel(channel);
  }
}
