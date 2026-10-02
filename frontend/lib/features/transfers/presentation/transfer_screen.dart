import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/data/mock_lims_data.dart';
import '../../../core/data/inventory_provider.dart';
import '../../../core/widgets/ui_kit.dart';

class TransferScreen extends ConsumerStatefulWidget {
  const TransferScreen({super.key});

  @override
  ConsumerState<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends ConsumerState<TransferScreen> {
  String _selectedDestination = 'Mwanza Branch';

  final List<String> _branches = [
    'Mwanza Branch',
    'Arusha Branch',
    'Dodoma Branch',
    'Kariakoo Branch',
  ];

  final List<Map<String, dynamic>> _transferItems = [
    {
      'id': 7,
      'name': 'iPhone 15',
      'qty': 2,
      'available': 12,
      'grad': [AppTheme.brand600, AppTheme.brand700],
    },
    {
      'id': 5,
      'name': 'AirPods Pro (2nd Gen)',
      'qty': 3,
      'available': 8,
      'grad': [const Color(0xFFF472B6), const Color(0xFFDB2777)],
    },
    {
      'id': 11,
      'name': 'Smart Watch X2',
      'qty': 4,
      'available': 15,
      'grad': [const Color(0xFFEC4899), const Color(0xFFBE185D)],
    },
  ];

  void _sendTransfer() {
    int totalTransferred = 0;
    for (final item in _transferItems) {
      final id = item['id'] as int;
      final qty = item['qty'] as int;
      totalTransferred += qty;
      ref.read(inventoryProvider.notifier).updateStock(id, -qty);
    }

    ref.read(activitiesProvider.notifier).addActivity(
      ActivityItem(
        icon: Icons.swap_horiz_rounded,
        iconColor: const Color(0xFF7C5CFC),
        bgColor: const Color(0xFFF0EBFF),
        title: 'Transfer Sent · $totalTransferred units',
        description: 'To $_selectedDestination (Transit #TR-902)',
        time: 'Just now',
      ),
    );

    LimsToast.show(
      context,
      'Stock transfer ($totalTransferred units) dispatched to $_selectedDestination!',
      isSuccess: true,
    );

    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) context.pop();
    });
  }

  @override
  Widget build(BuildContext context) {
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
          'Transfer Stock',
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
            // Route Card
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildRouteBox('From', 'Mbezi Branch'),
                      const Icon(Icons.arrow_forward_rounded, color: AppTheme.brand600, size: 20),
                      _buildRouteBox('To', _selectedDestination),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Destination Chips
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _branches.map((b) {
                      final isSelected = _selectedDestination == b;
                      final shortName = b.replaceAll(' Branch', '');
                      return InkWell(
                        onTap: () => setState(() => _selectedDestination = b),
                        borderRadius: BorderRadius.circular(99),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: isSelected ? AppTheme.brand600 : const Color(0xFFF4F9FF),
                            borderRadius: BorderRadius.circular(99),
                            border: Border.all(
                              color: isSelected ? AppTheme.brand600 : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Text(
                            shortName,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isSelected ? Colors.white : AppTheme.ink700,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            const Text(
              'Items to transfer',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: AppTheme.ink900,
              ),
            ),
            const SizedBox(height: 10),

            // Transfer items list with stepper
            Container(
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
                children: _transferItems.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final item = entry.value;
                  final isLast = idx == _transferItems.length - 1;

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      border: isLast ? null : const Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: item['grad'] as List<Color>,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: const Icon(Icons.smartphone_rounded, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['name'] as String,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.ink900,
                                ),
                              ),
                              Text(
                                'Available: ${item['available']}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.ink500,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Stepper
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF4F9FF),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove_rounded, size: 16),
                                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                padding: EdgeInsets.zero,
                                onPressed: () {
                                  if ((item['qty'] as int) > 1) {
                                    setState(() => item['qty'] = (item['qty'] as int) - 1);
                                  }
                                },
                              ),
                              Text(
                                '${item['qty']}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.ink900,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add_rounded, size: 16),
                                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                padding: EdgeInsets.zero,
                                onPressed: () {
                                  if ((item['qty'] as int) < (item['available'] as int)) {
                                    setState(() => item['qty'] = (item['qty'] as int) + 1);
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: _sendTransfer,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.brand600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: const Text(
                'Send Transfer',
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteBox(String label, String branch) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppTheme.ink500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          branch,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
            color: AppTheme.ink900,
          ),
        ),
      ],
    );
  }
}
