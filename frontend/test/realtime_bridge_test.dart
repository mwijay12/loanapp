import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:loan_inventory_app/core/services/realtime_bridge.dart';

/// A [LiveSocket] the test drives by hand: it can drop, come back, refuse to
/// open, deliver a payload with no primary key, and hold a row open while the
/// next one arrives.
class FakeSocket implements LiveSocket {
  FakeSocket({this.goLiveOnOpen = true});

  List<String>? tables;
  void Function(LiveChange change)? onRow;
  void Function(bool live)? onAvailability;

  int openCalls = 0;
  int closeCalls = 0;
  bool failOpen = false;
  bool goLiveOnOpen;

  @override
  Future<void> open({
    required List<String> tables,
    required void Function(LiveChange change) onRow,
    required void Function(bool live) onAvailability,
  }) async {
    openCalls++;
    if (failOpen) throw StateError('socket refused the join');
    this.tables = tables;
    this.onRow = onRow;
    this.onAvailability = onAvailability;
    if (goLiveOnOpen) onAvailability(true);
  }

  @override
  Future<void> close() async {
    closeCalls++;
  }

  void emit(LiveChange change) => onRow!(change);
  void setLive(bool live) => onAvailability!(live);
}

/// Lets queued microtasks and the drain loop get as far as they can.
Future<void> tick() => Future<void>.delayed(Duration.zero);

LiveChange inserted(String table, Map<String, dynamic> record) => LiveChange(
      table: table,
      kind: LiveEventKind.inserted,
      record: record,
    );

void main() {
  group('LiveChange.rowKey', () {
    test('an insert or update reads the new record', () {
      expect(inserted('products', {'id': 7}).rowKey, '7');
      expect(
        const LiveChange(
          table: 'loans',
          kind: LiveEventKind.updated,
          record: {'id': '9f1c', 'status': 'overdue'},
        ).rowKey,
        '9f1c',
      );
    });

    test('a delete reads the old record, because the new one is empty', () {
      // REPLICA IDENTITY DEFAULT sends only the primary key on a delete. Reading
      // `record` first would find nothing and the row would never leave the screen.
      final change = const LiveChange(
        table: 'products',
        kind: LiveEventKind.deleted,
        record: {},
        oldRecord: {'id': 12},
      );
      expect(change.rowKey, '12');
    });

    test('a payload with no usable key is null, not an empty string', () {
      // Null is the signal that says "refetch, do not guess". An empty string
      // would slip through and match a row whose id really is empty.
      expect(inserted('products', {}).rowKey, isNull);
      expect(inserted('products', {'id': '   '}).rowKey, isNull);
      expect(inserted('products', {'id': null}).rowKey, isNull);
    });
  });

  group('which tables get subscribed', () {
    test('petty_cash and profiles are refused even if a caller asks', () async {
      // The reason this list exists: petty_cash's only SELECT policy is
      // `to public using (true)`, and Realtime applies RLS per subscriber, so a
      // subscription would stream the shop's cash expenses to any browser holding
      // the publishable key that ships inside every build.
      final socket = FakeSocket();
      final bridge = RealtimeBridge(
        socket: socket,
        tables: const [...kLiveTables, 'petty_cash', 'profiles'],
        onRow: (_) async {},
        onResync: () async {},
      );
      addTearDown(bridge.stop);

      await bridge.start();

      expect(socket.tables, containsAll(kLiveTables));
      expect(socket.tables, isNot(contains('petty_cash')));
      expect(socket.tables, isNot(contains('profiles')));
    });

    test('the three published-but-unowned tables are not in the client list', () {
      // They are published server-side, but no provider can hold their rows, so a
      // subscription would only receive data and throw it away.
      expect(kLiveTables, isNot(contains('product_units')));
      expect(kLiveTables, isNot(contains('stock_receipts')));
      expect(kLiveTables, isNot(contains('stock_receipt_lines')));
      expect(
        kLiveTables.where(kLiveRefusedTables.contains),
        isEmpty,
        reason: 'a refused table must never be in the default list',
      );
    });

    test('a socket that refuses to open leaves the bridge not live', () async {
      final socket = FakeSocket()..failOpen = true;
      final bridge = RealtimeBridge(
        socket: socket,
        onRow: (_) async {},
        onResync: () async {},
      );
      addTearDown(bridge.stop);

      final started = await bridge.start();

      expect(started, isFalse);
      expect(bridge.isLive, isFalse);
    });
  });

  group('applying rows', () {
    test('an insert reaches the handler exactly once', () async {
      final seen = <LiveChange>[];
      final bridge = RealtimeBridge(
        socket: FakeSocket(),
        onRow: (c) async => seen.add(c),
        onResync: () async {},
      );
      addTearDown(bridge.stop);
      await bridge.start();

      (bridge.socket as FakeSocket).emit(inserted('branches', {'id': 'BR-9'}));
      await tick();
      await tick();

      expect(seen, hasLength(1));
      expect(bridge.eventsApplied, 1);
      expect(bridge.eventsDropped, 0);
      expect(bridge.resyncCount, 0);
    });

    test('a row that fails after an await is counted and refetched', () async {
      // The point of the queue: with a `void` callback this try/catch could only
      // see synchronous throws, so a provider that failed partway through an async
      // merge counted as applied and nothing ever corrected the half-written row.
      var resyncs = 0;
      final socket = FakeSocket();
      final bridge = RealtimeBridge(
        socket: socket,
        resyncDebounce: const Duration(milliseconds: 5),
        onRow: (_) async {
          await tick();
          throw StateError('parser choked');
        },
        onResync: () async => resyncs++,
      );
      addTearDown(bridge.stop);
      await bridge.start();

      socket.emit(inserted('products', {'id': 1}));
      await Future<void>.delayed(const Duration(milliseconds: 40));

      expect(bridge.eventsApplied, 0);
      expect(bridge.eventsDropped, 1);
      expect(resyncs, 1);
    });

    test('a keyless row never reaches the handler and asks for a reload', () async {
      var handlerCalls = 0;
      var resyncs = 0;
      final socket = FakeSocket();
      final bridge = RealtimeBridge(
        socket: socket,
        resyncDebounce: const Duration(milliseconds: 5),
        onRow: (_) async => handlerCalls++,
        onResync: () async => resyncs++,
      );
      addTearDown(bridge.stop);
      await bridge.start();

      socket.emit(inserted('products', {'name': 'no id column'}));
      await Future<void>.delayed(const Duration(milliseconds: 40));

      expect(handlerCalls, 0, reason: 'guessing an id is worse than refetching');
      expect(bridge.eventsDropped, 1);
      expect(resyncs, 1);
    });

    test('rows apply in arrival order even when the slow one arrives first',
        () async {
      // Every event carries a whole row, so an out-of-order merge paints the older
      // value last and the screen settles on a number the database dropped.
      final order = <String>[];
      final socket = FakeSocket();
      final bridge = RealtimeBridge(
        socket: socket,
        onRow: (c) async {
          if (c.record['id'] == 1) {
            await Future<void>.delayed(const Duration(milliseconds: 20));
          }
          order.add(c.record['id'].toString());
        },
        onResync: () async {},
      );
      addTearDown(bridge.stop);
      await bridge.start();

      socket.emit(inserted('products', {'id': 1}));
      socket.emit(inserted('products', {'id': 2}));
      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(order, ['1', '2']);
      expect(bridge.eventsApplied, 2);
    });
  });

  group('connection gaps', () {
    test('the first subscribe does not refetch', () async {
      // The host has just loaded the snapshot this subscription continues from, so
      // a reload here would double every launch request for nothing.
      var resyncs = 0;
      final bridge = RealtimeBridge(
        socket: FakeSocket(),
        resyncDebounce: const Duration(milliseconds: 5),
        onRow: (_) async {},
        onResync: () async => resyncs++,
      );
      addTearDown(bridge.stop);

      await bridge.start();
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(resyncs, 0);
      expect(bridge.isLive, isTrue);
    });

    test('a drop and return refetches exactly once', () async {
      // A shop running on a dead socket looks identical to one running on live
      // data, which is the failure the admin reported: the till had already sold
      // the handset and the header still said yesterday.
      var resyncs = 0;
      final socket = FakeSocket();
      final bridge = RealtimeBridge(
        socket: socket,
        resyncDebounce: const Duration(milliseconds: 5),
        onRow: (_) async {},
        onResync: () async => resyncs++,
      );
      addTearDown(bridge.stop);
      await bridge.start();

      socket.setLive(false);
      expect(bridge.isLive, isFalse);
      socket.setLive(true);
      await Future<void>.delayed(const Duration(milliseconds: 40));

      expect(resyncs, 1);

      // Two separate gaps are two separate holes in the data, so each earns its own
      // reload — but not more than one each.
      socket.setLive(false);
      socket.setLive(true);
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(resyncs, 2);
    });

    test('a burst of bad rows collapses into one reload', () async {
      // A 40-line stock receipt arrives as 40 line events plus the receipt event.
      // Refetching 41 times would put more load on the database than the
      // subscription was meant to remove.
      var resyncs = 0;
      final socket = FakeSocket();
      final bridge = RealtimeBridge(
        socket: socket,
        resyncDebounce: const Duration(milliseconds: 20),
        onRow: (_) async {},
        onResync: () async => resyncs++,
      );
      addTearDown(bridge.stop);
      await bridge.start();

      for (var i = 0; i < 40; i++) {
        socket.emit(inserted('products', {})); // keyless, so each one asks to resync
      }
      await Future<void>.delayed(const Duration(milliseconds: 120));

      expect(resyncs, 1);
      expect(bridge.eventsDropped, 40);
    });

    test('the queue is abandoned rather than growing forever', () async {
      // If merging stops making progress, a backlog is no longer a record of
      // anything useful: dropping it costs one reload instead of unbounded memory.
      final gate = Completer<void>();
      var resyncs = 0;
      final socket = FakeSocket();
      final bridge = RealtimeBridge(
        socket: socket,
        resyncDebounce: const Duration(milliseconds: 5),
        onRow: (_) async => gate.future,
        onResync: () async => resyncs++,
      );
      addTearDown(bridge.stop);
      await bridge.start();

      for (var i = 0; i < 700; i++) {
        socket.emit(inserted('products', {'id': i}));
      }
      expect(bridge.eventsDropped, greaterThan(0));

      gate.complete();
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(resyncs, greaterThanOrEqualTo(1));
      expect(bridge.eventsApplied, lessThan(700));
    });
  });

  group('refresh now', () {
    test('a press on a bridge that never started does nothing', () async {
      var resyncs = 0;
      final bridge = RealtimeBridge(
        socket: FakeSocket(),
        onRow: (_) async {},
        onResync: () async => resyncs++,
      );

      await bridge.refreshNow().timeout(const Duration(seconds: 1));

      expect(resyncs, 0);
      expect(bridge.isStarted, isFalse);
    });

    test('a change landing mid-read earns a second pass', () async {
      // The whole honesty of the button: the read already in the air began before
      // the press, so awaiting it returns older rows. Answering "synced" from that
      // read is what this test guards against.
      final reads = <Completer<void>>[];
      final bridge = RealtimeBridge(
        socket: FakeSocket(),
        resyncDebounce: const Duration(milliseconds: 200),
        onRow: (_) async {},
        onResync: () {
          final c = Completer<void>();
          reads.add(c);
          return c.future;
        },
      );
      addTearDown(bridge.stop);
      await bridge.start();

      final done = bridge.refreshNow().timeout(const Duration(seconds: 2));
      await tick();
      expect(reads, hasLength(1));

      bridge.scheduleResync(); // a row arrives while the first read is in flight
      reads[0].complete();
      await tick();
      expect(reads, hasLength(2), reason: 'a second pass must be issued');

      reads[1].complete();
      await done;
      expect(bridge.resyncCount, 2);
    });

    test('resume refetches, because backgrounding publishes to nobody', () async {
      var resyncs = 0;
      final bridge = RealtimeBridge(
        socket: FakeSocket(),
        resyncDebounce: const Duration(milliseconds: 5),
        onRow: (_) async {},
        onResync: () async => resyncs++,
      );
      addTearDown(bridge.stop);
      await bridge.start();

      await bridge.resume().timeout(const Duration(seconds: 1));

      expect(resyncs, 1);
    });
  });

  group('stopping', () {
    test('a stop drops queued rows without counting them as data loss', () async {
      // The host is going away and the next one loads a fresh snapshot, so these
      // are not the "silently lost rows" the pill warns about.
      final gate = Completer<void>();
      final applied = <String>[];
      final socket = FakeSocket();
      final bridge = RealtimeBridge(
        socket: socket,
        onRow: (c) async {
          await gate.future;
          applied.add(c.rowKey!);
        },
        onResync: () async {},
      );
      await bridge.start();

      socket.emit(inserted('products', {'id': 1}));
      socket.emit(inserted('products', {'id': 2}));
      await tick();

      await bridge.stop();
      expect(bridge.eventsDropped, 0);
      expect(socket.closeCalls, 1);

      gate.complete();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(applied, ['1'], reason: 'only the row already in hand may land');
      expect(bridge.isStarted, isFalse);
    });
  });

  group('quiet feed watchdog', () {
    // Why this group exists: on 2026-10-31 this project's Realtime was subscribed,
    // reporting `ok`, and delivering nothing at all — nine tables published, a
    // replication connection streaming, zero frames. Every client-side signal said
    // healthy while the screen sat on numbers that never moved. The bridge has to
    // stop treating "subscribed" as proof of life.
    test('a socket that says live but delivers nothing still re-reads the tables',
        () async {
      var resyncs = 0;
      final bridge = RealtimeBridge(
        socket: FakeSocket(),
        onRow: (_) async {},
        onResync: () async => resyncs++,
        resyncDebounce: const Duration(milliseconds: 2),
        quietReconcileAfter: const Duration(milliseconds: 20),
      );
      addTearDown(bridge.stop);
      await bridge.start();

      await Future<void>.delayed(const Duration(milliseconds: 90));

      expect(bridge.isLive, isTrue,
          reason: 'the feed never reported a problem — that is the point');
      expect(bridge.eventsApplied, 0);
      expect(bridge.quietReconcileCount, greaterThan(0),
          reason: 'a live-but-silent feed must not be trusted indefinitely');
      expect(resyncs, greaterThan(0));
    });

    test('rows that keep arriving are their own proof of life', () async {
      var resyncs = 0;
      final socket = FakeSocket();
      final bridge = RealtimeBridge(
        socket: socket,
        onRow: (_) async {},
        onResync: () async => resyncs++,
        quietReconcileAfter: const Duration(milliseconds: 30),
      );
      addTearDown(bridge.stop);
      await bridge.start();

      for (var i = 0; i < 8; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        socket.emit(inserted('products', {'id': i}));
        await tick();
      }

      expect(bridge.eventsApplied, 8);
      expect(resyncs, 0,
          reason: 'a flowing feed needs no polling; the watchdog is not a poller');
    });

    test('a socket that is down is not polled', () async {
      // Recovery from a dead socket belongs to _handleAvailability, which refetches
      // on the way back up. Polling a network that is off is how three devices in a
      // shop end up hammering a database that cannot answer.
      var resyncs = 0;
      final bridge = RealtimeBridge(
        socket: FakeSocket(goLiveOnOpen: false),
        onRow: (_) async {},
        onResync: () async => resyncs++,
        quietReconcileAfter: const Duration(milliseconds: 20),
      );
      addTearDown(bridge.stop);
      await bridge.start();

      await Future<void>.delayed(const Duration(milliseconds: 90));

      expect(bridge.isLive, isFalse);
      expect(bridge.quietReconcileCount, 0);
      expect(resyncs, 0);
    });

    test('stopping cancels the watchdog', () async {
      final bridge = RealtimeBridge(
        socket: FakeSocket(),
        onRow: (_) async {},
        onResync: () async {},
        quietReconcileAfter: const Duration(milliseconds: 20),
      );
      await bridge.start();
      await bridge.stop();
      final before = bridge.quietReconcileCount;

      await Future<void>.delayed(const Duration(milliseconds: 80));

      expect(bridge.quietReconcileCount, before,
          reason: 'a stopped bridge must not keep timers alive');
    });
  });
}
