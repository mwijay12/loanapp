import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A branch as the business records it.
///
/// The console used to hold the branch list inline as four map literals, so a
/// manager could not open a new branch, rename one, or close one without a code
/// change. This provider is the single list the screens read, which makes those
/// operations data instead of edits.
class BranchRecord {
  const BranchRecord({
    required this.id,
    required this.name,
    required this.city,
    this.salesToday = 0,
    this.lowStock = 0,
    this.active = true,
  });

  final String id;
  final String name;
  final String city;
  final int salesToday;
  final int lowStock;
  final bool active;

  BranchRecord copyWith({
    String? name,
    String? city,
    int? salesToday,
    int? lowStock,
    bool? active,
  }) {
    return BranchRecord(
      id: id,
      name: name ?? this.name,
      city: city ?? this.city,
      salesToday: salesToday ?? this.salesToday,
      lowStock: lowStock ?? this.lowStock,
      active: active ?? this.active,
    );
  }
}

class BranchesNotifier extends StateNotifier<List<BranchRecord>> {
  BranchesNotifier()
      : super(const [
          BranchRecord(
            id: 'BR-01',
            name: 'Mbezi Branch',
            city: 'Dar es Salaam',
            salesToday: 4850000,
            lowStock: 12,
          ),
          BranchRecord(
            id: 'BR-02',
            name: 'Kariakoo Branch',
            city: 'Dar es Salaam',
            salesToday: 3920000,
            lowStock: 5,
          ),
          BranchRecord(
            id: 'BR-03',
            name: 'Mwanza Branch',
            city: 'Mwanza',
            salesToday: 2710000,
            lowStock: 8,
          ),
          BranchRecord(
            id: 'BR-04',
            name: 'Arusha Branch',
            city: 'Arusha',
            salesToday: 2340000,
            lowStock: 3,
          ),
        ]);

  void replaceAll(List<BranchRecord> items) {
    state = List.from(items);
  }

  void add({required String name, required String city}) {
    final nextId = 'BR-${(state.length + 1).toString().padLeft(2, '0')}';
    state = [
      ...state,
      BranchRecord(id: nextId, name: name, city: city),
    ];
  }

  /// Closing a branch is a record change, not a delete: the sales, loans and
  /// audit rows that point at it must keep resolving. Removing it from the list
  /// would orphan them.
  void closeBranch(String id) {
    state = [
      for (final b in state) b.id == id ? b.copyWith(active: false) : b,
    ];
  }

  void reopenBranch(String id) {
    state = [
      for (final b in state) b.id == id ? b.copyWith(active: true) : b,
    ];
  }

  void rename(String id, String name) {
    state = [
      for (final b in state) b.id == id ? b.copyWith(name: name) : b,
    ];
  }
}

final branchesProvider =
    StateNotifierProvider<BranchesNotifier, List<BranchRecord>>((ref) {
  return BranchesNotifier();
});

/// Active branches only — what an operator should be able to pick from.
final activeBranchesProvider = Provider<List<BranchRecord>>((ref) {
  return ref.watch(branchesProvider).where((b) => b.active).toList();
});
