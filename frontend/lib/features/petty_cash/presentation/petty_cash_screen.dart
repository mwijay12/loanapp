import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/data/petty_cash_provider.dart';
import '../../../core/data/inventory_provider.dart';
import '../../../core/data/supabase_source.dart';
import '../../../core/data/branch_provider.dart';
import '../../../core/l10n/strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ui_kit.dart';

class PettyCashScreen extends ConsumerStatefulWidget {
  const PettyCashScreen({super.key});

  @override
  ConsumerState<PettyCashScreen> createState() => _PettyCashScreenState();
}

class _PettyCashScreenState extends ConsumerState<PettyCashScreen> {
  final _amountController = TextEditingController();
  final _descController = TextEditingController();
  String _selectedCategory = 'General';
  bool _isSaving = false;

  final List<String> _categories = [
    'General',
    'Usafi (Cleaning)',
    'Chakula (Food)',
    'Logistics',
    'Stationery',
    'Utilities',
    'Maintenance',
  ];

  @override
  void dispose() {
    _amountController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _saveExpense() async {
    final amountText = _amountController.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (amountText.isEmpty) {
      LimsToast.show(context, 'Tafadhali weka kiasi.', isSuccess: false);
      return;
    }

    final amount = int.parse(amountText);
    if (amount <= 0) {
      LimsToast.show(context, 'Kiasi lazima kiwe zaidi ya sufuri.', isSuccess: false);
      return;
    }

    setState(() => _isSaving = true);

    final staff = ref.read(activeStaffMemberProvider);
    final branch = ref.read(activeBranchProvider);

    final success = await SupabaseSource.recordPettyCash(
      amount: amount,
      category: _selectedCategory,
      description: _descController.text.trim(),
      branchId: branch,
      staffId: staff.id,
    );

    if (mounted) {
      setState(() => _isSaving = false);
      if (success) {
        LimsToast.show(context, 'Matumizi yamehifadhiwa (Petty Cash imerekodiwa).', isSuccess: true);
        _amountController.clear();
        _descController.clear();
        // Refresh list
        ref.read(pettyCashProvider.notifier).replaceAll(await SupabaseSource.fetchPettyCash());
        Navigator.pop(context);
      } else {
        LimsToast.show(context, 'Imefeli kuhifadhi. Jaribu tena.', isSuccess: false);
      }
    }
  }

  void _showAddDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Record New Expense (Petty Cash)',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppTheme.ink900),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Amount (TZS)',
                  prefixIcon: Icon(Icons.payments_rounded),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) => setState(() => _selectedCategory = v ?? 'General'),
                decoration: const InputDecoration(
                  labelText: 'Category',
                  prefixIcon: Icon(Icons.category_rounded),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _descController,
                decoration: const InputDecoration(
                  labelText: 'Description (Optional)',
                  prefixIcon: Icon(Icons.description_rounded),
                ),
              ),
              const SizedBox(height: 24),
              LimsButton(
                label: 'Save Record',
                isLoading: _isSaving,
                onPressed: _saveExpense,
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final expenses = ref.watch(pettyCashProvider);
    final totalToday = ref.watch(expensesTodayProvider);

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      appBar: AppBar(
        title: const Text('Petty Cash (Petty Cash)', style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        backgroundColor: AppTheme.brand600,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF334155)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Total Expenses Today', style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 8),
                Text(
                  LimsFormatters.currency(totalToday),
                  style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text('Recent Records', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.ink900)),
          const SizedBox(height: 12),
          if (expenses.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Text('Hakuna matumizi yaliyorekodiwa bado.', style: TextStyle(color: AppTheme.ink500)),
              ),
            )
          else
            for (final e in expenses)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFF1F5F9)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.outbox_rounded, color: Color(0xFFDC2626), size: 20),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(e.category, style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.ink900)),
                            if ((e.description ?? '').isNotEmpty)
                              Text(e.description!, style: const TextStyle(color: AppTheme.ink500, fontSize: 12)),
                            Text(
                              LimsFormatters.date(e.createdAt),
                              style: const TextStyle(color: AppTheme.ink400, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        LimsFormatters.currency(e.amount),
                        style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFFDC2626)),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
