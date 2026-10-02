import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_localizations.dart';
import '../../../core/widgets/branch_card.dart';

class BranchPerformanceScreen extends ConsumerWidget {
  const BranchPerformanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.branch_performance),
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: const [
          BranchCard(
            name: 'Kariakoo',
            stock: 287,
            sales: 24,
            loans: 18,
            reports: 'Complete',
            attendance: '94%',
          ),
          BranchCard(
            name: 'Branch 12',
            stock: 198,
            sales: 18,
            loans: 12,
            reports: 'Complete',
            attendance: '89%',
          ),
          BranchCard(
            name: 'Branch 8',
            stock: 156,
            sales: 15,
            loans: 10,
            reports: 'Incomplete',
            attendance: '78%',
          ),
          BranchCard(
            name: 'Branch 27',
            stock: 234,
            sales: 22,
            loans: 16,
            reports: 'Complete',
            attendance: '92%',
          ),
          BranchCard(
            name: 'Branch 5',
            stock: 189,
            sales: 12,
            loans: 8,
            reports: 'Complete',
            attendance: '85%',
          ),
        ],
      ),
    );
  }
}
