import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'status_badge.dart';

class PhoneListTile extends StatelessWidget {
  final String model;
  final String imei;
  final String status;
  final StatusType statusType;
  final VoidCallback? onTap;

  const PhoneListTile({
    super.key,
    required this.model,
    required this.imei,
    required this.status,
    required this.statusType,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.pastelBlue,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.smartphone_rounded,
                  color: AppTheme.iconBlue,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      model,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'IMEI: $imei',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              StatusBadge(label: status, type: statusType),
            ],
          ),
        ),
      ),
    );
  }
}
