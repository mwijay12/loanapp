import 'dart:async' show unawaited;

// Only the pieces this file needs: it is a loader with one build method, not a
// screen, and pulling all of material into a core service makes the dependency
// look heavier than it is.
import 'package:flutter/widgets.dart'
    show
        AppLifecycleState,
        BuildContext,
        Color,
        Widget,
        WidgetsBinding,
        WidgetsBindingObserver,
        debugPrint;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_constants.dart';
import '../data/branch_provider.dart';
import '../data/inventory_provider.dart';
import '../data/sales_provider.dart';
import '../data/petty_cash_provider.dart';
import '../data/supabase_source.dart';
import 'api_service.dart';
import 'realtime_bridge.dart';

/// Where the rows on screen came from.
///
/// The app shipped with mock data and a Supabase client that nobody called, so
/// "connected" was never true or false — it was unknown. This state makes it
/// explicit, and the home header reports it instead of a permanent "Live Sync"
/// that meant nothing.
enum DataSourceKind { demo, live, failed }

/// Whether the row-level feed is currently running.
///
/// Separate from [DataSourceKind] on purpose: a screen can hold good rows from a
/// REST snapshot while the socket is down, and that is a different warning to show
/// than "there is no backend". Collapsing the two is how a stale number ends up
/// under a green tick.
enum LiveConnection { off, live, down }

class DataSourceState {
  const DataSourceState({
    required this.kind,
    this.loadedAt,
    this.error,
    this.counts = const {},
    this.connection = LiveConnection.off,
    this.lastEventAt,
  });

  final DataSourceKind kind;
  final DateTime? loadedAt;
  final String? error;
  final Map<String, int> counts;
  final LiveConnection connection;
  final DateTime? lastEventAt;

  bool get isLoading => kind == DataSourceKind.demo && loadedAt == null;

  /// Rows are arriving right now, as opposed to sitting here from an old read.
  ///
  /// Every green pixel in the UI is supposed to come from this getter, so that
  /// "connected" means one thing across the app instead of one thing per screen.
  bool get delivering =>
      kind == DataSourceKind.live && connection == LiveConnection.live;

  /// How long ago the snapshot was taken, or null while nothing has loaded.
  ///
  /// Measured when asked rather than pushed by a timer on purpose: a ticking
  /// `Timer.periodic` in a header widget makes every widget test in the tree wait
  /// for it and time out.
  Duration? get age =>
      loadedAt == null ? null : DateTime.now().difference(loadedAt!);

  DataSourceState copyWith({
    DataSourceKind? kind,
    DateTime? loadedAt,
    String? error,
    Map<String, int>? counts,
    LiveConnection? connection,
    DateTime? lastEventAt,
  }) {
    return DataSourceState(
      kind: kind ?? this.kind,
      loadedAt: loadedAt ?? this.loadedAt,
      error: error,
      counts: counts ?? this.counts,
      connection: connection ?? this.connection,
      lastEventAt: lastEventAt ?? this.lastEventAt,
    );
  }
}

final dataSourceProvider = StateProvider<DataSourceState>((ref) {
  return const DataSourceState(kind: DataSourceKind.demo);
});

/// The running feed, for anything that needs to force a refresh through it.
final realtimeBridgeProvider = StateProvider<RealtimeBridge?>((ref) => null);

/// Fetches every live table and writes it into the providers the screens watch.
///
/// Returns the state to show rather than setting it, so both the launch loader and
/// a pull-from-the-top refresh report the same truth.
///
/// `replaceAll` is correct here because this function *is* the snapshot path.
/// Between snapshots, single rows arrive through [RealtimeBridge] and are merged
/// one at a time.
Future<DataSourceState> fetchAndApplyLiveRows(WidgetRef ref) async {
  const source = SupabaseSource();
  if (!source.isConfigured) {
    return const DataSourceState(
      kind: DataSourceKind.failed,
      error: 'Supabase URL na key hazijawepo kwenye build.',
    );
  }

  try {
    final snapshot = await source.load();

    if (snapshot.isEmpty) {
      return DataSourceState(
        kind: DataSourceKind.failed,
        error: snapshot.error ?? 'Database imejibu bila rows.',
      );
    }

    ref.read(inventoryProvider.notifier).replaceAll(snapshot.products);
    ref.read(loansProvider.notifier).replaceAll(snapshot.loans);
    ref.read(branchesProvider.notifier).replaceAll(snapshot.branches);
    ref.read(activitiesProvider.notifier).replaceAll(snapshot.activities);
    ref.read(staffProvider.notifier).replaceAll(snapshot.staff);
    ref.read(pettyCashProvider.notifier).replaceAll(snapshot.pettyCash);
    ref.read(salesProvider.notifier).replaceAll(await SupabaseSource.fetchSales());

    return DataSourceState(
      kind: DataSourceKind.live,
      loadedAt: DateTime.now(),
      counts: {
        'products': snapshot.products.length,
        'loans': snapshot.loans.length,
        'branches': snapshot.branches.length,
        'activities': snapshot.activities.length,
        'staff': snapshot.staff.length,
        'expenses': snapshot.pettyCash.length,
      },
    );
  } catch (e) {
    return DataSourceState(kind: DataSourceKind.failed, error: e.toString());
  }
}

/// Reloads every live table and stores the result.
///
/// The launch load, a socket gap and a hand-pressed refresh all come through here,
/// so the header pill can never report a state the providers do not actually hold.
/// That is the whole point of the pill: if it says `Live`, rows are arriving.
Future<DataSourceState> reloadLiveData(WidgetRef ref) async {
  final state = await fetchAndApplyLiveRows(ref);
  final bridge = ref.read(realtimeBridgeProvider);
  // `off` and `down` are different apologies. A build that never had a feed is not
  // a build whose feed dropped, and only the second one is worth waiting on.
  final connection = state.kind != DataSourceKind.live || bridge == null
      ? LiveConnection.off
      : (bridge.isLive ? LiveConnection.live : LiveConnection.down);
  final next = state.copyWith(
    connection: connection,
    lastEventAt: bridge?.lastEventAt,
  );
  ref.read(dataSourceProvider.notifier).state = next;
  return next;
}

/// What a streamed row ended up doing.
enum LiveApplyOutcome {
  /// Written into a store the screens are watching.
  merged,

  /// Removed from a store by primary key.
  removed,

  /// The row was recognised but cannot be applied locally — a reload was issued.
  refetched,

  /// Nothing in the app owns this table, so a full reload was requested instead.
  unknownTable,
}

/// Writes one streamed row into the store that owns its table.
///
/// Split out of the loader so the merge rules can be tested with plain notifiers.
/// Those rules are the part most likely to be got wrong and least likely to be
/// noticed wrong on a screen: an update applied as an insert shows the same handset
/// twice, and a voided sale that is not removed keeps counting as money.
///
/// Two deliberate non-merges:
///
/// * **`sales` delete** — `REPLICA IDENTITY DEFAULT` sends only the primary key on a
///   delete, and [SaleRecord] is keyed on `receipt_no`, so the uuid in `oldRecord`
///   matches nothing on screen. It reloads the ledger instead. Guessing here is how
///   a voided sale keeps counting.
/// * **`activities`** — [ActivityItem] carries no id at all, so there is nothing to
///   merge into. The feed says "something happened" and the list is re-read.
///
/// Contract: [LiveApplyOutcome.unknownTable] is only ever returned after
/// [onUnknownTable] has been called, so a row this function cannot place always
/// turns into a reload rather than a silent no-op under a green `Live` label.
Future<LiveApplyOutcome> applyLiveRow(
  LiveChange change, {
  required InventoryNotifier inventory,
  required LoansNotifier loans,
  required StaffNotifier staff,
  required BranchesNotifier branches,
  required SalesNotifier sales,
  required Future<void> Function() refetchSales,
  required Future<void> Function() refetchActivities,
  required void Function() onUnknownTable,
}) async {
  const source = SupabaseSource();
  final key = change.rowKey;

  /// The row is real but unplaceable here — no key, an id in a format the store
  /// does not use, or a payload the parser rejected. Ask for a reload. Returning
  /// quietly is how a deleted row stays on a screen that says `Live`.
  LiveApplyOutcome unplaceable() {
    onUnknownTable();
    return LiveApplyOutcome.unknownTable;
  }

  if (change.kind == LiveEventKind.deleted) {
    if (key == null) return unplaceable();
    switch (change.table) {
      case 'products':
        final id = int.tryParse(key);
        if (id == null) return unplaceable();
        inventory.removeRow(id);
        return LiveApplyOutcome.removed;
      case 'loans':
        loans.removeRow(key);
        return LiveApplyOutcome.removed;
      case 'staff':
        staff.removeRow(key);
        return LiveApplyOutcome.removed;
      case 'branches':
        branches.removeRow(key);
        return LiveApplyOutcome.removed;
      case 'sales':
        await refetchSales();
        return LiveApplyOutcome.refetched;
      case 'activities':
        await refetchActivities();
        return LiveApplyOutcome.refetched;
    }
    return unplaceable();
  }

  final rows = <Map<String, dynamic>>[change.record];
  switch (change.table) {
    case 'products':
      final merged = source.parseProducts(rows);
      if (merged.isEmpty) return unplaceable();
      inventory.mergeRow(merged.first);
      return LiveApplyOutcome.merged;
    case 'loans':
      final merged = source.parseLoans(rows);
      if (merged.isEmpty) return unplaceable();
      loans.mergeRow(merged.first);
      return LiveApplyOutcome.merged;
    case 'staff':
      final merged = source.parseStaff(rows);
      if (merged.isEmpty) return unplaceable();
      staff.mergeRow(merged.first);
      return LiveApplyOutcome.merged;
    case 'branches':
      final merged = source.parseBranches(rows);
      if (merged.isEmpty) return unplaceable();
      branches.mergeRow(merged.first);
      return LiveApplyOutcome.merged;
    case 'sales':
      sales.mergeRow(SaleRecord.fromRow(change.record));
      return LiveApplyOutcome.merged;
    case 'activities':
      await refetchActivities();
      return LiveApplyOutcome.refetched;
  }
  return unplaceable();
}

/// Loads the live rows at launch and keeps them current afterwards.
///
/// Demo builds never call this: the flag is compiled out, so a public showcase
/// link cannot reach the database even if someone edits the URL.
class LiveDataLoader extends ConsumerStatefulWidget {
  const LiveDataLoader({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<LiveDataLoader> createState() => _LiveDataLoaderState();
}

class _LiveDataLoaderState extends ConsumerState<LiveDataLoader>
    with WidgetsBindingObserver {
  bool _started = false;
  Future<void>? _refetchWork;
  RealtimeBridge? _bridge;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final bridge = _bridge;
    _bridge = null;
    if (bridge != null) {
      // Fire-and-forget: dispose cannot await. The socket closes on its own
      // timeline, and a bridge that outlives its host would keep writing into
      // providers nobody is listening to.
      unawaited(bridge.stop());
      ref.read(realtimeBridgeProvider.notifier).state = null;
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Backgrounding a handset drops the websocket, and the rows that changed
    // while it was down were published to nobody. Coming back must refetch —
    // otherwise the screen that was "Live" when you locked the phone is a
    // snapshot pretending otherwise.
    if (state == AppLifecycleState.resumed) {
      final bridge = _bridge;
      if (bridge != null) unawaited(bridge.resume());
    }
  }

  Future<void> _load() async {
    if (_started) return;
    _started = true;

    if (AppConstants.demoMode && !SupabaseConfig.isConfigured) {
      ref.read(dataSourceProvider.notifier).state = const DataSourceState(
        kind: DataSourceKind.demo,
        counts: {},
      );
      return;
    }

    final first = await reloadLiveData(ref);
    if (!mounted) return;
    if (first.kind == DataSourceKind.live) await _startBridge();
  }

  /// Starts the feed, if this build can have one.
  Future<void> _startBridge() async {
    if (!SupabaseConfig.isConfigured || _bridge != null) return;
    final bridge = RealtimeBridge(
      socket: SupabaseLiveSocket(),
      onRow: _applyRow,
      onResync: _refetch,
    );
    _bridge = bridge;
    ref.read(realtimeBridgeProvider.notifier).state = bridge;

    await bridge.start();
    if (!mounted) return;
    ref.read(dataSourceProvider.notifier).state = ref
        .read(dataSourceProvider)
        .copyWith(
            connection:
                bridge.isLive ? LiveConnection.live : LiveConnection.down);
  }

  /// Refetches everything. Used after a socket gap, a row that could not be
  /// merged, and a manual sync.
  ///
  /// Concurrent callers join the read already in flight instead of starting a
  /// second one: a burst of dropped rows used to fire six full table loads.
  Future<void> _refetch() {
    final running = _refetchWork;
    if (running != null) return running;
    final work = _doRefetch();
    _refetchWork = work;
    return work.whenComplete(() => _refetchWork = null);
  }

  Future<void> _doRefetch() async {
    final state = await reloadLiveData(ref);
    if (state.kind != DataSourceKind.live) {
      // The rows already on screen came from an earlier good read. Keeping them
      // is right; keeping them silently is not, or a refill that failed looks
      // exactly like a refill that found nothing new.
      debugPrint('LIMS: live refetch failed -> ${state.error}');
    }
  }

  /// Writes one streamed row into the provider that owns its table.
  ///
  /// The outcome matters: a row this app cannot place is a gap in the snapshot, so
  /// it has to become a reload. Before this, an unplaceable row was applied-or-
  /// ignored and the pill still read `Live`, which is exactly the failure the shop
  /// reported — a number that looked current and was not.
  Future<void> _applyRow(LiveChange change) async {
    await applyLiveRow(
      change,
      inventory: ref.read(inventoryProvider.notifier),
      loans: ref.read(loansProvider.notifier),
      staff: ref.read(staffProvider.notifier),
      branches: ref.read(branchesProvider.notifier),
      sales: ref.read(salesProvider.notifier),
      refetchSales: _refetchSales,
      refetchActivities: _refetchActivities,
      // Debounced while the feed is up. If there is no bridge — the socket never
      // started, or it stopped between the event and this callback — there is no
      // debounce window to wait for, so reload now instead of never.
      onUnknownTable: () {
        final bridge = _bridge;
        if (bridge != null) {
          bridge.scheduleResync();
        } else {
          unawaited(_refetch());
        }
      },
    );

    if (!mounted) return;
    ref.read(dataSourceProvider.notifier).state =
        ref.read(dataSourceProvider).copyWith(
              connection: LiveConnection.live,
              lastEventAt: _bridge?.lastEventAt,
            );
  }

  /// One table, one request — cheaper than a full snapshot for a single sale.
  Future<void> _refetchSales() async {
    final rows = await SupabaseSource.fetchSales();
    if (!mounted) return;
    ref.read(salesProvider.notifier).replaceAll(rows);
  }

  Future<void> _refetchActivities() async {
    final rows = await ApiService().getActivities();
    if (!mounted) return;
    ref.read(activitiesProvider.notifier).replaceAll(const SupabaseSource().parseActivities(rows));
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// One short label for the header pill.
///
/// It is only allowed to say `Live` while events can actually arrive. The pill
/// used to read `Live Sync` unconditionally, which is what let a shop run a whole
/// day on yesterday's ledger without noticing.
String dataSourceLabel(DataSourceState state) {
  switch (state.kind) {
    case DataSourceKind.live:
      switch (state.connection) {
        case LiveConnection.live:
          return 'Live · Supabase';
        case LiveConnection.down:
          return 'Reconnecting…';
        case LiveConnection.off:
          return 'Snapshot · no feed';
      }
    case DataSourceKind.failed:
      return 'Offline · demo data';
    case DataSourceKind.demo:
      return 'Demo data';
  }
}

/// Colour for the pill: green only when the feed is delivering.
Color dataSourceColor(DataSourceState state) {
  if (state.kind != DataSourceKind.live) return const Color(0xFFB45309);
  switch (state.connection) {
    case LiveConnection.live:
      return const Color(0xFF059669);
    case LiveConnection.down:
    case LiveConnection.off:
      return const Color(0xFFB45309);
  }
}

/// A plain-language explanation for the sync action, computed at the moment it is
/// asked for — never a sentence printed after a fixed delay.
String describeDataFreshness(DataSourceState state, {required Duration since}) {
  final secs = since.inSeconds;
  final age = secs < 60
      ? '$secs s'
      : secs < 3600
          ? '${secs ~/ 60} min'
          : '${secs ~/ 3600} h';
  switch (state.kind) {
    case DataSourceKind.live:
      if (state.connection == LiveConnection.live) {
        return 'Live: rows update as soon as any branch writes them.'
            ' Last full load $age ago.';
      }
      return 'Connection to the row feed dropped. Showing the last snapshot,'
          ' loaded $age ago — write carelessly until it returns.';
    case DataSourceKind.failed:
      return 'No database reachable (${state.error ?? 'unknown reason'}).';
    case DataSourceKind.demo:
      return 'This build has no database behind it.';
  }
}
