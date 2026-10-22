import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loan_inventory_app/core/data/inventory_provider.dart';
import 'package:loan_inventory_app/core/data/lims_repository.dart';
import 'package:loan_inventory_app/core/data/mock_lims_data.dart';

/// The counter could only sell phones for cash.
///
/// Both flows asked the repository for `getAvailableHandsets`, which filtered
/// `cat == 'phones'`, so a power bank on the shelf never appeared in the cash
/// picker while it showed up fine on the stock screen. A cash sale is not a
/// financing decision — anything in stock may be sold — so the filter is now
/// the caller's choice: phones for a loan, everything for cash.

ProductItem _product({
  required int id,
  required String name,
  required String cat,
  int stock = 5,
}) {
  return ProductItem(
    id: id,
    name: name,
    variant: 'Standard',
    sku: 'SKU-$id',
    price: 89000,
    stock: stock,
    min: 2,
    cat: cat,
    grad: const [Color(0xFF347FF5), Color(0xFFBBD9FF)],
    status: stock <= 2 ? 'low' : 'in',
    soldToday: 0,
    onLoan: 0,
    fav: false,
  );
}

class _Probe extends ConsumerWidget {
  const _Probe({required this.phonesOnly});

  final bool phonesOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final names = const MockLimsRepository()
        .getAvailableHandsets(ref, phonesOnly: phonesOnly)
        .map((p) => p.name)
        .join('|');
    return Text(names.isEmpty ? '(none)' : names);
  }
}

Future<void> _pump(WidgetTester tester, {required bool phonesOnly}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        inventoryProvider.overrideWith((ref) => InventoryNotifier([
              _product(id: 1, name: 'Infinix Zero 40', cat: 'phones'),
              _product(id: 2, name: 'Power Bank 20,000mAh', cat: 'acc'),
              _product(id: 3, name: 'HP Laptop 15s', cat: 'laptops'),
              _product(id: 4, name: 'Sold Out Phone', cat: 'phones', stock: 0),
            ])),
      ],
      child: MaterialApp(home: Scaffold(body: _Probe(phonesOnly: phonesOnly))),
    ),
  );
}

void main() {
  testWidgets('a cash sale may ring up accessories and laptops', (tester) async {
    await _pump(tester, phonesOnly: false);

    expect(find.textContaining('Power Bank 20,000mAh'), findsOneWidget);
    expect(find.textContaining('HP Laptop 15s'), findsOneWidget);
    expect(find.textContaining('Infinix Zero 40'), findsOneWidget);
    // Nothing out of stock, whatever the category.
    expect(find.textContaining('Sold Out Phone'), findsNothing);
  });

  testWidgets('a loan still only finances handsets', (tester) async {
    await _pump(tester, phonesOnly: true);

    expect(find.textContaining('Infinix Zero 40'), findsOneWidget);
    expect(find.textContaining('Power Bank'), findsNothing);
    expect(find.textContaining('HP Laptop'), findsNothing);
  });
}
