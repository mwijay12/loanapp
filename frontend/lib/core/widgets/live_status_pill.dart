import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/live_data.dart';
import '../services/realtime_bridge.dart';
import 'ui_kit.dart';
import '../motion/motion.dart';

/// The header pill: what the rows on screen are, and a way to make them newer.
///
/// It lives here rather than inline in the home header because the two claims it
/// makes — *this is live* and *I just refreshed* — are testable promises, and a
/// widget that exists inside a 3,900-line screen cannot be pointed at by a test.
///
/// Before this, the pill said `Live Sync` in permanent green while the app had no
/// subscription of any kind, and tapping it ran a 1.2-second delay followed by
/// "synced". Both halves of that are now derived from [dataSourceProvider], and
/// the label is only allowed to read `Live` while [RealtimeBridge.isLive] is true.
class LiveStatusPill extends ConsumerStatefulWidget {
  const LiveStatusPill({super.key});

  @override
  ConsumerState<LiveStatusPill> createState() => _LiveStatusPillState();
}

class _LiveStatusPillState extends ConsumerState<LiveStatusPill> {
  bool _refreshing = false;

  /// Re-reads the shop and reports what it actually found.
  ///
  /// Goes through the bridge when one is running, so a manual press does not
  /// start a second full load next to the subscription. When there is no feed in
  /// this build it takes the plain REST reload instead — but it never claims a
  /// success it did not perform, which is the bug this whole file exists for.
  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);

    final bridge = ref.read(realtimeBridgeProvider);
    DataSourceState result;
    try {
      if (bridge != null && bridge.isStarted) {
        await bridge.refreshNow();
        result = ref.read(dataSourceProvider);
      } else {
        result = await reloadLiveData(ref);
      }
    } catch (e) {
      result = ref.read(dataSourceProvider);
      debugPrint('LIMS: manual sync threw -> $e');
    }
    if (!mounted) return;
    setState(() => _refreshing = false);

    final loadedAt = result.loadedAt;
    final age =
        loadedAt == null ? Duration.zero : DateTime.now().difference(loadedAt);
    LimsToast.show(
      context,
      describeDataFreshness(result, since: age),
      isSuccess: result.delivering,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dataSourceProvider);
    // Every colour here comes from the same state the loader writes, so a dropped
    // feed changes the header instead of staying a comforting green.
    final accent = dataSourceColor(state);

    return Tooltip(
      message: describeDataFreshness(
        state,
        since: state.age ?? Duration.zero,
      ),
      child: InkWell(
        onTap: _refresh,
        borderRadius: BorderRadius.circular(99),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          constraints: const BoxConstraints(maxWidth: 220),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: accent.withValues(alpha: 0.45)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _refreshing
                  ? SizedBox(
                      width: 10,
                      height: 10,
                      child: CircularProgressIndicator(
                          strokeWidth: 1.6, color: accent),
                    )
                  : Icon(
                      state.delivering
                          ? Icons.bolt_rounded
                          : Icons.cloud_off_rounded,
                      size: 12,
                      color: accent,
                    ),
              const SizedBox(width: 3),
              Flexible(
                child: AnimatedSwitcher(
                  duration: Motion.d(context, const Duration(milliseconds: 220)),
                  child: Text(
                    dataSourceLabel(state),
                    key: ValueKey(dataSourceLabel(state)),
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: accent,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
