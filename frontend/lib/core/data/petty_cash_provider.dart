import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'sales_provider.dart';

class PettyCashRecord {
  const PettyCashRecord({
    required this.id,
    required this.amount,
    required this.category,
    this.description,
    required this.createdAt,
    this.staffId,
    this.branchId,
  });

  final String id;
  final int amount;
  final String category;
  final String? description;
  final DateTime createdAt;
  final String? staffId;
  final String? branchId;

  factory PettyCashRecord.fromRow(Map<String, dynamic> row) {
    return PettyCashRecord(
      id: (row['id'] ?? '').toString(),
      amount: _money(row['amount']),
      category: (row['category'] ?? 'General').toString(),
      description: row['description']?.toString(),
      createdAt: DateTime.tryParse((row['created_at'] ?? '').toString())?.toLocal() ??
          DateTime.now(),
      staffId: row['staff_id']?.toString(),
      branchId: row['branch_id']?.toString(),
    );
  }

  static int _money(dynamic v) {
    if (v is num) return v.round();
    if (v is String) {
      final cleaned = v.replaceAll(RegExp(r'[^0-9.\-]'), '');
      return double.tryParse(cleaned)?.round() ?? 0;
    }
    return 0;
  }
}

class PettyCashNotifier extends StateNotifier<List<PettyCashRecord>> {
  PettyCashNotifier() : super([]);

  void replaceAll(List<PettyCashRecord> rows) {
    state = List<PettyCashRecord>.from(rows);
  }

  void add(PettyCashRecord record) {
    state = [record, ...state];
  }
}

final pettyCashProvider =
    StateNotifierProvider<PettyCashNotifier, List<PettyCashRecord>>((ref) {
  return PettyCashNotifier();
});

final expensesTodayProvider = Provider<int>((ref) {
  return ref
      .watch(pettyCashProvider)
      .where((e) => isEatToday(e.createdAt))
      .fold<int>(0, (sum, e) => sum + e.amount);
});
