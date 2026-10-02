import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class DiscrepancyCard extends StatelessWidget {
  final String title;
  final String expected;
  final String actual;
  final String difference;
  final VoidCallback? onViewDetails;

  const DiscrepancyCard({
    super.key,
    required this.title,
    required this.expected,
    required this.actual,
    required this.difference,
    this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppTheme.errorLight,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppTheme.errorColor, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.warning_rounded, color: AppTheme.errorColor, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.errorColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildRow('Expected', expected),
            const SizedBox(height: 4),
            _buildRow('Physical', actual),
            const SizedBox(height: 8),
            Text(
              difference,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.errorColor,
              ),
            ),
            if (onViewDetails != null) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: onViewDetails,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.errorColor,
                  side: const BorderSide(color: AppTheme.errorColor),
                  minimumSize: const Size(double.infinity, 44),
                ),
                child: const Text('VIEW DISCREPANCY'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
      ],
    );
  }
}
