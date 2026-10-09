import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../theme/app_localizations.dart';

enum SyncState { synced, offline, syncing, success }

class SyncStatus extends ConsumerWidget {
  final SyncState state;
  final String? message;
  final int? pendingCount;
  final int? syncingTotal;
  final int? syncingCurrent;

  const SyncStatus({
    super.key,
    required this.state,
    this.message,
    this.pendingCount,
    this.syncingTotal,
    this.syncingCurrent,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _getBackgroundColor(),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _getBorderColor()),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildIcon(),
          const SizedBox(width: 8),
          Flexible(
            child: _buildText(l10n),
          ),
        ],
      ),
    );
  }

  Widget _buildIcon() {
    switch (state) {
      case SyncState.synced:
        return const Icon(Icons.cloud_done_rounded, size: 16, color: AppTheme.successColor);
      case SyncState.offline:
        return const Icon(Icons.cloud_off_rounded, size: 16, color: AppTheme.warningColor);
      case SyncState.syncing:
        return const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppTheme.primaryColor,
          ),
        );
      case SyncState.success:
        return const Icon(Icons.check_circle_rounded, size: 16, color: AppTheme.successColor);
    }
  }

  Widget _buildText(AppLocalizations l10n) {
    switch (state) {
      case SyncState.synced:
        return Text(
          message ?? l10n.synced_just_now,
          style: const TextStyle(fontSize: 12, color: AppTheme.successColor, fontWeight: FontWeight.w500),
        );
      case SyncState.offline:
        return Text(
          message ?? '${pendingCount ?? 0} ${l10n.transactions_waiting}',
          style: const TextStyle(fontSize: 12, color: AppTheme.warningColor, fontWeight: FontWeight.w500),
        );
      case SyncState.syncing:
        return Text(
          message ?? '${l10n.syncing} ${syncingCurrent ?? 0} of ${syncingTotal ?? 0}',
          style: const TextStyle(fontSize: 12, color: AppTheme.primaryColor, fontWeight: FontWeight.w500),
        );
      case SyncState.success:
        return Text(
          message ?? l10n.all_synced,
          style: const TextStyle(fontSize: 12, color: AppTheme.successColor, fontWeight: FontWeight.w500),
        );
    }
  }

  Color _getBackgroundColor() {
    switch (state) {
      case SyncState.synced:
        return AppTheme.successLight;
      case SyncState.offline:
        return AppTheme.warningLight;
      case SyncState.syncing:
        return AppTheme.primaryLight;
      case SyncState.success:
        return AppTheme.successLight;
    }
  }

  Color _getBorderColor() {
    switch (state) {
      case SyncState.synced:
        return AppTheme.successColor.withValues(alpha: 0.3);
      case SyncState.offline:
        return AppTheme.warningColor.withValues(alpha: 0.3);
      case SyncState.syncing:
        return AppTheme.primaryColor.withValues(alpha: 0.3);
      case SyncState.success:
        return AppTheme.successColor.withValues(alpha: 0.3);
    }
  }
}
