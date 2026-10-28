import 'package:flutter_test/flutter_test.dart';
import 'package:loan_inventory_app/core/data/inventory_provider.dart';
import 'package:loan_inventory_app/core/data/mock_lims_data.dart';

/// The owner added 100 handsets on the admin screen, saw the count move, refreshed,
/// and got 166 back — the number in `products` that no request had ever changed.
/// Two defects were behind that, and both are pinned here.
///
///  1. `addProduct`/`updateStock` only mutated this list. The writes now live in
///     `SupabaseSource.createProduct`/`adjustStock`, and the provider exposes
///     methods named for what they mirror, so a screen cannot quietly "save" by
///     calling a local mutator.
///  2. `updateStock(id, delta)` was called with the *new total*:
///     `updateStock(p.id, p.stock + qty)`. With 24 units and a delivery of 1 that
///     computed 24 + 25 = 49, and 98 on the next click.
void main() {
  ProductItem handset({int stock = 24, int min = 5}) => ProductItem(
        id: 1,
        name: 'iPhone 15 Pro Max',
        variant: '256GB · Natural Titanium',
        sku: 'IP15PM-256-NT',
        price: 3850000,
        stock: stock,
        min: min,
        cat: 'phones',
        grad: const [],
        status: 'in',
        soldToday: 0,
        onLoan: 0,
      );

  InventoryNotifier shelf({int stock = 24}) =>
      InventoryNotifier([handset(stock: stock)]);

  group('stock mutations', () {
    test('a delivery of one unit is one unit, not the new total added again', () {
      final notifier = shelf();
      // The old call shape was updateStock(1, 24 + 1), which produced 49.
      notifier.addStockUnits(1, 1);
      expect(notifier.state.single.stock, 25);
    });

    test('a hundred handsets arrives as a hundred units', () {
      final notifier = shelf();
      notifier.addStockUnits(1, 100);
      expect(notifier.state.single.stock, 124);
    });

    test('reducing stock never goes below zero', () {
      final notifier = shelf(stock: 3);
      notifier.reduceStockUnits(1, 10);
      expect(notifier.state.single.stock, 0);
    });

    test('a zero or negative quantity moves nothing', () {
      final notifier = shelf();
      notifier.addStockUnits(1, 0);
      notifier.addStockUnits(1, -5);
      notifier.reduceStockUnits(1, 0);
      notifier.reduceStockUnits(1, -5);
      expect(notifier.state.single.stock, 24);
    });

    test('the status follows the count in both directions', () {
      final notifier = shelf(stock: 6);
      notifier.reduceStockUnits(1, 2); // 4, at or below min -> low
      expect(notifier.state.single.status, 'low');
      notifier.reduceStockUnits(1, 4); // 0 -> out
      expect(notifier.state.single.status, 'out');
      notifier.addStockUnits(1, 20); // 20 -> back in stock
      expect(notifier.state.single.status, 'in');
    });

    test('setStockTotal paints the number the database returned', () {
      final notifier = shelf();
      // adjustStock answers with the stored value, so the screen shows Postgres
      // rather than arithmetic done on the device.
      notifier.setStockTotal(1, 166);
      expect(notifier.state.single.stock, 166);
      expect(notifier.state.single.status, 'in');
    });

    test('an unknown product id is left alone', () {
      final notifier = shelf();
      notifier.addStockUnits(9999, 50);
      notifier.setStockTotal(9999, 50);
      expect(notifier.state.single.stock, 24);
    });
  });

  group('the catalogue list', () {
    test('mergeRow replaces by id instead of showing the handset twice', () {
      // The Realtime INSERT for a product the till just saved can land around the
      // same time as the local apply, and a duplicate row would count its stock
      // twice.
      final notifier = shelf();
      notifier.mergeRow(handset(stock: 124));
      expect(notifier.state.length, 1);
      expect(notifier.state.single.stock, 124);
    });

    test('mergeRow puts a genuinely new row at the front', () {
      final notifier = shelf();
      notifier.mergeRow(ProductItem(
        id: 19,
        name: 'Galaxy S25',
        variant: '256GB · Navy',
        sku: 'SGS25-256-NV',
        price: 2400000,
        stock: 8,
        min: 2,
        cat: 'phones',
        grad: const [],
        status: 'in',
        soldToday: 0,
        onLoan: 0,
      ));
      expect(notifier.state.first.id, 19);
      expect(notifier.state.length, 2);
    });
  });
}
