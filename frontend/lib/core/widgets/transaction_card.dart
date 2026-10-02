import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'status_badge.dart';

class TransactionCard extends StatelessWidget {
  final String id;
  final String type;
  final String amount;
  final String date;
  final String status;
  final StatusType statusType;
  final String? description;

  const TransactionCard({
    super.key,
    required this.id,
    required this.type,
    required this.amount,
    required this.date,
    required this.status,
    required this.statusType,
    this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppTheme.primaryLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _getIconForType(),
                color: AppTheme.primaryColor,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    type,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$id · $date',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                  if (description != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      description!,
                      style: const TextStyle(fontSize: 12, color: AppTheme.textTertiary),
                    ),
                  ],
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  amount,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                StatusBadge(label: status, type: statusType),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIconForType() {
    switch (type.toLowerCase()) {
      case 'sale':
        return Icons.shopping_cart_rounded;
      case 'loan':
        return Icons.handshake_rounded;
      case 'transfer':
        return Icons.swap_horiz_rounded;
      case 'receive':
        return Icons.inventory_2_rounded;
      default:
        return Icons.receipt_rounded;
    }
  }
}
