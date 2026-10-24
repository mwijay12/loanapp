import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/data/inventory_provider.dart';
import '../../../core/data/sales_provider.dart';
import '../../../core/data/petty_cash_provider.dart';
import '../../../core/data/mock_lims_data.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../core/data/branch_provider.dart';

class DailyClosingScreen extends ConsumerStatefulWidget {
  const DailyClosingScreen({super.key});

  @override
  ConsumerState<DailyClosingScreen> createState() => _DailyClosingScreenState();
}

class _DailyClosingScreenState extends ConsumerState<DailyClosingScreen> {
  late final TextEditingController _countCtrl;
  bool _isClosed = false;

  @override
  void initState() {
    super.initState();
    _countCtrl = TextEditingController(text: '3,060,000');
  }

  void _closeDay() {
    final activeBranch = ref.read(activeBranchProvider);
    final todaySales = ref.read(salesTodayTotalProvider);
    final expenses = ref.read(expensesTodayProvider);
    final expectedDrawer = (todaySales - expenses).clamp(0, 99999999);

    setState(() => _isClosed = true);

    ref.read(activitiesProvider.notifier).addActivity(
      ActivityItem(
        icon: Icons.point_of_sale_rounded,
        iconColor: const Color(0xFF12B76A),
        bgColor: const Color(0xFFE7F8F0),
        title: 'Daily Close (Z-Report) Completed',
        description: 'Reconciled drawer at $activeBranch · ${LimsFormatters.currency(expectedDrawer)}',
        time: 'Just now',
      ),
    );

    LimsToast.show(
      context,
      'Day closed successfully & reconciled with HQ drawer ($activeBranch)',
      isSuccess: true,
    );

    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) context.pop();
    });
  }

  @override
  void dispose() {
    _countCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final todaySales = ref.watch(salesTodayTotalProvider);
    final expenses = ref.watch(expensesTodayProvider);
    final expectedDrawer = (todaySales - expenses).clamp(0, 99999999);

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.ink900),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Daily Close (Z-Report)',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppTheme.ink900,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFE2E8F0), height: 1),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            // Drawer Breakdown Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0C0F3478),
                    blurRadius: 20,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildCloseRow('Today\'s Takings', LimsFormatters.currency(todaySales)),
                  _buildCloseRow('Expenses (Petty Cash)', '− ${LimsFormatters.currency(expenses)}', valueColor: const Color(0xFFF43F5E)),
                  const Divider(height: 24, color: Color(0xFFE2E8F0)),
                  _buildCloseRow('Expected in drawer', LimsFormatters.currency(expectedDrawer), isTotal: true),
                ],
              ),
            ),
            const SizedBox(height: 20),

            const Text(
              'Cash count',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: AppTheme.ink900,
              ),
            ),
            const SizedBox(height: 10),

            // Count field
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0A0F3478),
                    blurRadius: 16,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.point_of_sale_rounded, size: 20, color: AppTheme.ink500),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _countCtrl,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.ink900),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Counted amount',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Balanced diff indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFE7F8F0),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle_outline_rounded, color: Color(0xFF12B76A), size: 16),
                  SizedBox(width: 6),
                  Text(
                    'Difference: TZS 0 — balanced',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF12B76A),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: _isClosed ? null : _closeDay,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.brand600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: Text(
                _isClosed ? 'Day Closed & Synced' : 'Close Day & Sync to HQ',
                style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCloseRow(String label, String value, {Color? valueColor, bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: isTotal ? 13.5 : 12.5,
                fontWeight: isTotal ? FontWeight.w800 : FontWeight.w500,
                color: isTotal ? AppTheme.ink900 : AppTheme.ink500,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: isTotal ? 15 : 13,
                fontWeight: FontWeight.w800,
                color: valueColor ?? AppTheme.ink900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
