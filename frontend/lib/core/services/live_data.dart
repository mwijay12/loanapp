import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_constants.dart';
import '../data/branch_provider.dart';
import '../data/inventory_provider.dart';
import '../data/supabase_source.dart';

/// Where the rows on screen came from.
///
/// The app shipped with mock data and a Supabase client that nobody called, so
/// "connected" was never true or false — it was unknown. This state makes it
/// explicit, and the home header reports it instead of a permanent "Live Sync"
/// that meant nothing.
enum DataSourceKind { demo, live, failed }

class DataSourceState {
  const DataSourceState({
    required this.kind,
    this.loadedAt,
    this.error,
    this.counts = const {},
  });

  final DataSourceKind kind;
  final DateTime? loadedAt;
  final String? error;
  final Map<String, int> counts;

  bool get isLoading => kind == DataSourceKind.demo && loadedAt == null;
}

final dataSourceProvider = StateProvider<DataSourceState>((ref) {
  return const DataSourceState(kind: DataSourceKind.demo);
});

/// Loads the live rows once per session and swaps the providers over.
///
/// Demo builds never call this: the flag is compiled out, so a public showcase
/// link cannot reach the database even if someone edits the URL.
class LiveDataLoader extends ConsumerStatefulWidget {
  const LiveDataLoader({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<LiveDataLoader> createState() => _LiveDataLoaderState();
}

class _LiveDataLoaderState extends ConsumerState<LiveDataLoader> {
  bool _started = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (_started) return;
    _started = true;

    if (AppConstants.demoMode) {
      ref.read(dataSourceProvider.notifier).state = const DataSourceState(
        kind: DataSourceKind.demo,
        counts: {},
      );
      return;
    }

    const source = SupabaseSource();
    if (!source.isConfigured) {
      ref.read(dataSourceProvider.notifier).state = const DataSourceState(
        kind: DataSourceKind.failed,
        error: 'Supabase URL na key hazijawepo kwenye build.',
      );
      return;
    }

    try {
      final snapshot = await source.load();
      if (!mounted) return;

      if (snapshot.isEmpty) {
        ref.read(dataSourceProvider.notifier).state = DataSourceState(
          kind: DataSourceKind.failed,
          error: snapshot.error ?? 'Database imejibu bila rows.',
        );
        return;
      }

      ref.read(inventoryProvider.notifier).replaceAll(snapshot.products);
      ref.read(loansProvider.notifier).replaceAll(snapshot.loans);
      ref.read(branchesProvider.notifier).replaceAll(snapshot.branches);
      ref.read(activitiesProvider.notifier).replaceAll(snapshot.activities);

      ref.read(dataSourceProvider.notifier).state = DataSourceState(
        kind: DataSourceKind.live,
        loadedAt: DateTime.now(),
        counts: {
          'products': snapshot.products.length,
          'loans': snapshot.loans.length,
          'branches': snapshot.branches.length,
          'activities': snapshot.activities.length,
        },
      );
    } catch (e) {
      if (!mounted) return;
      ref.read(dataSourceProvider.notifier).state = DataSourceState(
        kind: DataSourceKind.failed,
        error: e.toString(),
      );
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// One short label for the header pill.
String dataSourceLabel(DataSourceState state) {
  switch (state.kind) {
    case DataSourceKind.live:
      return 'Live · Supabase';
    case DataSourceKind.failed:
      return 'Offline · demo data';
    case DataSourceKind.demo:
      return 'Demo data';
  }
}
