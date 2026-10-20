import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:loan_inventory_app/core/data/branch_provider.dart';
import 'package:loan_inventory_app/core/data/inventory_provider.dart';

/// A sale has to move the numbers on the home screen.
///
/// The complaint was concrete: a cash sale completed, the receipt printed, and
/// the dashboard still showed the same figures. These tests pin the path from
/// the till back to the cards, so a future refactor cannot quietly break it.
void main() {
  test('a cash sale raises today revenue and the transaction count', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final beforeSales = container.read(todaySalesTotalProvider);
    final beforeTx = container.read(todayTransactionsCountProvider);
    final beforeStock = container.read(totalPhonesCountProvider);

    final phone = container
        .read(inventoryProvider)
        .firstWhere((p) => p.cat == 'phones' && p.stock > 0);

    container.read(inventoryProvider.notifier).sellProduct(phone.id);

    expect(container.read(todaySalesTotalProvider), beforeSales + phone.price);
    expect(container.read(todayTransactionsCountProvider), beforeTx + 1);
    expect(container.read(totalPhonesCountProvider), beforeStock - 1);
  });

  test('a financed sale moves a unit to loans, not to cash sales', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final beforeSales = container.read(todaySalesTotalProvider);
    final beforeStock = container.read(totalPhonesCountProvider);
    final phone = container
        .read(inventoryProvider)
        .firstWhere((p) => p.cat == 'phones' && p.stock > 0);

    container
        .read(inventoryProvider.notifier)
        .sellProduct(phone.id, isLoan: true);

    // A loan disbursement takes stock but does not book cash over the counter.
    expect(container.read(todaySalesTotalProvider), beforeSales);
    expect(container.read(totalPhonesCountProvider), beforeStock - 1);
    final updated =
        container.read(inventoryProvider).firstWhere((p) => p.id == phone.id);
    expect(updated.onLoan, phone.onLoan + 1);
  });

  test('closing a branch removes it from the active list but keeps the record',
      () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final all = container.read(branchesProvider);
    expect(all.length, 4);
    expect(container.read(activeBranchesProvider).length, 4);

    container.read(branchesProvider.notifier).closeBranch(all.first.id);

    expect(container.read(branchesProvider).length, 4);
    expect(container.read(activeBranchesProvider).length, 3);
    expect(container.read(activeBranchesProvider).any((b) => b.id == all.first.id),
        isFalse);
  });

  test('a reopened branch comes back', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final id = container.read(branchesProvider).first.id;
    final notifier = container.read(branchesProvider.notifier);
    notifier.closeBranch(id);
    notifier.reopenBranch(id);

    expect(container.read(activeBranchesProvider).length, 4);
  });

  test('a new branch can be added without touching code', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container
        .read(branchesProvider.notifier)
        .add(name: 'Dodoma Branch', city: 'Dodoma');

    final branches = container.read(activeBranchesProvider);
    expect(branches.length, 5);
    expect(branches.last.name, 'Dodoma Branch');
  });
}
