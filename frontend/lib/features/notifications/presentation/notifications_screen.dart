import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_localizations.dart';
import '../../../core/widgets/ui_kit.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          l10n.notifications,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppTheme.ink900,
          ),
        ),
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.ink900),
          onPressed: () => context.pop(),
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              LimsToast.show(
                context,
                'All notifications marked as read',
                isSuccess: true,
              );
            },
            icon: const Icon(Icons.done_all_rounded,
                size: 16, color: AppTheme.brand600),
            label: const Text(
              'Mark all read',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.brand600),
            ),
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFE2E8F0), height: 1),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          _NotificationItem(
            title: 'Stock discrepancy detected',
            subtitle: 'Branch 12 (Kariakoo) — Tap to review physical inventory',
            time: '2 hours ago',
            type: _NotificationType.error,
            onTap: () => context.push('/stock'),
          ),
          _NotificationItem(
            title: 'Daily report missing',
            subtitle: 'Posta Main Branch — Tap to perform Z-Report close',
            time: '3 hours ago',
            type: _NotificationType.warning,
            onTap: () => context.push('/daily-closing'),
          ),
          _NotificationItem(
            title: 'Low stock threshold reached',
            subtitle: 'Kariakoo Branch has 2 Galaxy A15 left — Tap to restock',
            time: '5 hours ago',
            type: _NotificationType.warning,
            onTap: () => context.push('/receive'),
          ),
          _NotificationItem(
            title: 'Loan payment overdue',
            subtitle: 'Juma Selemani · TZS 850,000 — Tap to view loan details',
            time: '1 day ago',
            type: _NotificationType.error,
            onTap: () => context.push('/loans'),
          ),
          _NotificationItem(
            title: 'Sync failed (3 offline receipts)',
            subtitle: 'Pending retry — Tap to force sync now',
            time: '1 day ago',
            type: _NotificationType.info,
            onTap: () {
              LimsToast.show(
                context,
                'Syncing 3 pending receipts to HQ central database...',
              );
            },
          ),
        ],
      ),
    );
  }
}

enum _NotificationType { error, warning, info }

class _NotificationItem extends StatelessWidget {
  final String title;
  final String subtitle;
  final String time;
  final _NotificationType type;
  final VoidCallback onTap;

  const _NotificationItem({
    required this.title,
    required this.subtitle,
    required this.time,
    required this.type,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _getBorderColor(),
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080F3478),
            blurRadius: 14,
            offset: Offset(0, 3),
          ),
        ],
      ),
      // The tile sits inside a DecoratedBox, so its ink splash had nothing to
      // paint on and Flutter raised "ListTile background color or ink splashes
      // may be invisible" on every notification. A transparent Material gives
      // the splash a surface without changing the card look.
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          onTap: onTap,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _getBackgroundColor(),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _getIcon(),
              color: _getIconColor(),
              size: 20,
            ),
          ),
          title: Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppTheme.ink900,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.ink500,
              ),
            ),
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                time,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF94A3B8),
                ),
              ),
              const SizedBox(height: 4),
              const Icon(Icons.chevron_right_rounded,
                  size: 16, color: Color(0xFFCBD5E1)),
            ],
          ),
        ),
      ),
    );
  }

  Color _getBorderColor() {
    switch (type) {
      case _NotificationType.error:
        return const Color(0xFFFECDD3);
      case _NotificationType.warning:
        return const Color(0xFFFED7AA);
      case _NotificationType.info:
        return const Color(0xFFBFDBFE);
    }
  }

  Color _getBackgroundColor() {
    switch (type) {
      case _NotificationType.error:
        return const Color(0xFFFFEDF1);
      case _NotificationType.warning:
        return const Color(0xFFFEF3E4);
      case _NotificationType.info:
        return const Color(0xFFEFF6FF);
    }
  }

  Color _getIconColor() {
    switch (type) {
      case _NotificationType.error:
        return const Color(0xFFF43F5E);
      case _NotificationType.warning:
        return const Color(0xFFF79009);
      case _NotificationType.info:
        return AppTheme.brand600;
    }
  }

  IconData _getIcon() {
    switch (type) {
      case _NotificationType.error:
        return Icons.error_rounded;
      case _NotificationType.warning:
        return Icons.warning_rounded;
      case _NotificationType.info:
        return Icons.info_rounded;
    }
  }
}
