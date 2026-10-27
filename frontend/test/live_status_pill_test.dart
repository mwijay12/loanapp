import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:loan_inventory_app/core/services/live_data.dart';
import 'package:loan_inventory_app/core/services/realtime_bridge.dart';
import 'package:loan_inventory_app/core/widgets/live_status_pill.dart';

/// The pill used to read `Live Sync` in permanent green while the app held no
/// subscription at all, and tapping it waited 1.2s and then said "synced". Both
/// halves of that are pinned here: the words are only allowed while rows can
/// actually arrive, and a refresh that found no database says so.
const Color green = Color(0xFF059669);
const Color amber = Color(0xFFB45309);

DataSourceState live({
  DateTime? loadedAt,
  LiveConnection connection = LiveConnection.live,
}) =>
    DataSourceState(
      kind: DataSourceKind.live,
      loadedAt: loadedAt ?? DateTime.now(),
      connection: connection,
    );

/// A socket that goes green the moment it is opened, for a bridge that is really
/// started rather than one the test merely claims is.
class PillSocket implements LiveSocket {
  int openCalls = 0;
  int closeCalls = 0;
  void Function(bool live)? _availability;

  @override
  Future<void> open({
    required List<String> tables,
    required void Function(LiveChange change) onRow,
    required void Function(bool live) onAvailability,
  }) async {
    openCalls++;
    _availability = onAvailability;
    onAvailability(true);
  }

  @override
  Future<void> close() async {
    closeCalls++;
    _availability?.call(false);
  }

  void setLive(bool value) => _availability?.call(value);
}

void main() {
  group('the label may only claim what is true', () {
    test('Live appears only on a live connection', () {
      expect(dataSourceLabel(live()), 'Live · Supabase');
      expect(
        dataSourceLabel(live(connection: LiveConnection.down)),
        'Reconnecting…',
      );
      expect(
        dataSourceLabel(live(connection: LiveConnection.off)),
        'Snapshot · no feed',
      );
    });

    test('a read that failed says offline, not live', () {
      expect(
        dataSourceLabel(const DataSourceState(
          kind: DataSourceKind.failed,
          error: 'timeout',
        )),
        'Offline · demo data',
      );
      expect(
        dataSourceLabel(const DataSourceState(kind: DataSourceKind.demo)),
        'Demo data',
      );
    });

    test('green is reserved for rows that are arriving', () {
      expect(dataSourceColor(live()), green);
      expect(dataSourceColor(live(connection: LiveConnection.down)), amber);
      expect(dataSourceColor(live(connection: LiveConnection.off)), amber);
      expect(
        dataSourceColor(const DataSourceState(kind: DataSourceKind.failed)),
        amber,
      );
      expect(
        dataSourceColor(const DataSourceState(kind: DataSourceKind.demo)),
        amber,
      );
    });

    test('delivering is the single source of the claim', () {
      expect(live().delivering, isTrue);
      expect(live(connection: LiveConnection.down).delivering, isFalse);
      expect(live(connection: LiveConnection.off).delivering, isFalse);
    });
  });

  group('freshness wording', () {
    test('a live feed says rows arrive as branches write them', () {
      final text = describeDataFreshness(
        live(loadedAt: DateTime.now().subtract(const Duration(seconds: 8))),
        since: const Duration(seconds: 8),
      );
      expect(text, contains('Live'));
      expect(text, contains('8 s'));
    });

    test('a dropped feed apologises and names the age of the snapshot', () {
      final text = describeDataFreshness(
        live(
          loadedAt: DateTime.now().subtract(const Duration(minutes: 4)),
          connection: LiveConnection.down,
        ),
        since: const Duration(minutes: 4),
      );
      expect(text, contains('dropped'));
      expect(text, contains('4 min'));
      expect(text, isNot(contains('Live:')));
    });

    test('an hour reads in hours, not in seconds', () {
      final text = describeDataFreshness(
        live(connection: LiveConnection.off),
        since: const Duration(minutes: 95),
      );
      expect(text, contains('1 h'));
    });

    test('no database at all is stated plainly', () {
      expect(
        describeDataFreshness(
          const DataSourceState(kind: DataSourceKind.failed, error: 'dns'),
          since: Duration.zero,
        ),
        contains('No database reachable'),
      );
      expect(
        describeDataFreshness(
          const DataSourceState(kind: DataSourceKind.demo),
          since: Duration.zero,
        ),
        contains('no database behind it'),
      );
    });
  });

  group('the widget', () {
    Future<ProviderContainer> pumpPill(
      WidgetTester tester,
      DataSourceState state, {
      RealtimeBridge? bridge,
      double width = 400,
    }) async {
      tester.view.physicalSize = Size(width * 2, 400 * 2);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);

      // Set through the notifier rather than an override: a StateProvider in
      // riverpod 2.x cannot be overridden with a bare value, and the pill must see
      // exactly the state the loader would have written.
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(realtimeBridgeProvider.notifier).state = bridge;
      container.read(dataSourceProvider.notifier).state = state;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                // Narrow on purpose: the pill shares a header row with a greeting,
                // and a long label there used to be an overflow.
                child: SizedBox(
                  width: width,
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: LiveStatusPill(),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return container;
    }

    testWidgets('the words follow the state, one label each', (tester) async {
      final cases = <DataSourceState, String>{
        live(): 'Live · Supabase',
        live(connection: LiveConnection.down): 'Reconnecting…',
        live(connection: LiveConnection.off): 'Snapshot · no feed',
        const DataSourceState(kind: DataSourceKind.failed, error: 'x'):
            'Offline · demo data',
        const DataSourceState(kind: DataSourceKind.demo): 'Demo data',
      };

      for (final entry in cases.entries) {
        await pumpPill(tester, entry.key);
        expect(find.text(entry.value), findsOneWidget,
            reason: '${entry.key.kind}/${entry.key.connection}');
      }
    });

    testWidgets('a live feed shows the bolt, everything else shows cloud-off',
        (tester) async {
      await pumpPill(tester, live());
      expect(find.byIcon(Icons.bolt_rounded), findsOneWidget);

      await pumpPill(tester, live(connection: LiveConnection.down));
      expect(find.byIcon(Icons.cloud_off_rounded), findsOneWidget);
    });

    testWidgets('a long label in a narrow header does not overflow',
        (tester) async {
      await pumpPill(tester, live(), width: 150);
      // An unhandled RenderFlex overflow fails the whole file, and the pill sits
      // next to a greeting that can be any length.
      expect(tester.takeException(), isNull);
      expect(find.text('Live · Supabase'), findsOneWidget);
    });

    testWidgets('a tap with no feed admits there is no database',
        (tester) async {
      await pumpPill(tester, const DataSourceState(kind: DataSourceKind.demo));

      await tester.tap(find.byType(LiveStatusPill));
      await tester.pump();
      await tester.pumpAndSettle();

      // No dart-defines in a test build, so the honest answer is "unreachable" —
      // and never the old "synced" that was printed after a fixed delay.
      expect(find.textContaining('No database reachable'), findsOneWidget);
      expect(find.textContaining('Live: rows update'), findsNothing);

      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });

    testWidgets('a tap on a running feed goes through it, once', (tester) async {
      late ProviderContainer container;
      var resyncs = 0;
      final socket = PillSocket();
      final bridge = RealtimeBridge(
        socket: socket,
        onRow: (_) async {},
        onResync: () async {
          resyncs++;
          container.read(dataSourceProvider.notifier).state = live();
        },
      );
      await bridge.start();
      expect(bridge.isStarted, isTrue);

      container = await pumpPill(tester, live(connection: LiveConnection.off),
          bridge: bridge);
      expect(find.text('Snapshot · no feed'), findsOneWidget);

      await tester.tap(find.byType(LiveStatusPill));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(resyncs, greaterThanOrEqualTo(1),
          reason: 'the button must actually read, not just animate');
      expect(socket.openCalls, 1,
          reason: 'a manual sync must not open a second subscription');
      expect(find.textContaining('Live: rows update'), findsOneWidget);

      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await bridge.stop();
    });
  });
}
