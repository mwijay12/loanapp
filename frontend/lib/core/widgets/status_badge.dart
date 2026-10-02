import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum StatusType { available, sold, transferred, damaged, returned, pending, inTransit, received, matched, notMatched, complete, incomplete, success, warning, error, info }

class StatusBadge extends StatelessWidget {
  final String label;
  final StatusType type;

  const StatusBadge({super.key, required this.label, required this.type});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
      decoration: BoxDecoration(
        color: _getBackgroundColor(),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _getTextColor().withAlpha(38)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: _getTextColor(),
          letterSpacing: 0.25,
        ),
      ),
    );
  }

  Color _getBackgroundColor() {
    switch (type) {
      case StatusType.available:
      case StatusType.matched:
      case StatusType.complete:
      case StatusType.success:
        return AppTheme.successLight;
      case StatusType.sold:
        return AppTheme.soldBg;
      case StatusType.transferred:
      case StatusType.inTransit:
      case StatusType.info:
        return AppTheme.transferredBg;
      case StatusType.damaged:
      case StatusType.notMatched:
      case StatusType.error:
        return AppTheme.damagedBg;
      case StatusType.returned:
      case StatusType.pending:
      case StatusType.warning:
        return AppTheme.warningLight;
      case StatusType.received:
        return AppTheme.successLight;
      case StatusType.incomplete:
        return AppTheme.warningLight;
    }
  }

  Color _getTextColor() {
    switch (type) {
      case StatusType.available:
      case StatusType.matched:
      case StatusType.complete:
      case StatusType.success:
        return AppTheme.successColor;
      case StatusType.sold:
        return AppTheme.sold;
      case StatusType.transferred:
      case StatusType.inTransit:
      case StatusType.info:
        return AppTheme.transferred;
      case StatusType.damaged:
      case StatusType.notMatched:
      case StatusType.error:
        return AppTheme.damaged;
      case StatusType.returned:
      case StatusType.pending:
      case StatusType.warning:
        return AppTheme.warningColor;
      case StatusType.received:
        return AppTheme.successColor;
      case StatusType.incomplete:
        return AppTheme.warningColor;
    }
  }
}
