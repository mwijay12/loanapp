import 'package:flutter_test/flutter_test.dart';
import 'package:loan_inventory_app/core/data/product_art.dart';

/// Locks the brand-to-artwork rule.
///
/// The bug this guards against is subtle and was live in the catalogue: an itel
/// Vision rendered with an iPhone body, because every phone without its own
/// photo fell back to one hero shot. A shop assistant scanning a shelf reads the
/// thumbnail first, so a wrong body is a wrong product.
void main() {
  group('ProductArt.resolve', () {
    test('each phone brand gets its own body', () {
      expect(
        ProductArt.resolve(brand: 'itel', name: 'itel Vision 3 Plus'),
        ProductArt.itel,
      );
      expect(
        ProductArt.resolve(name: 'Tecno Camon 30 Premier'),
        ProductArt.tecno,
      );
      expect(
        ProductArt.resolve(brand: 'Infinix', name: 'Zero 40'),
        ProductArt.infinix,
      );
      expect(
        ProductArt.resolve(name: 'Redmi Note 13 Pro'),
        ProductArt.xiaomi,
      );
      expect(
        ProductArt.resolve(brand: 'Samsung', name: 'Galaxy A55'),
        ProductArt.samsung,
      );
      expect(
        ProductArt.resolve(name: 'iPhone 15'),
        ProductArt.apple,
      );
    });

    test('an itel never renders as an iPhone', () {
      final art = ProductArt.resolve(name: 'itel Vision 3 Plus', category: 'phones');
      expect(art, isNot(ProductArt.apple));
      expect(art, ProductArt.itel);
    });

    test('an unknown brand falls back to the unbranded body, not a flagship', () {
      final art = ProductArt.resolve(name: 'Nokia C32', category: 'phones');
      expect(art, ProductArt.genericPhone);
      expect(art, isNot(ProductArt.apple));
      expect(art, isNot(ProductArt.samsung));
    });

    test('accessories resolve by type, not by brand', () {
      expect(
        ProductArt.resolve(name: 'Galaxy Watch 6', category: 'acc'),
        ProductArt.watch,
      );
      expect(
        ProductArt.resolve(name: 'AirPods Pro (2nd Gen)', category: 'acc'),
        ProductArt.earbuds,
      );
      expect(
        ProductArt.resolve(name: 'Power Bank 20,000mAh', category: 'acc'),
        ProductArt.powerBank,
      );
      expect(
        ProductArt.resolve(name: 'HP Laptop 15s', category: 'laptops'),
        ProductArt.laptop,
      );
    });

    test('a catalogue photo always wins over the fallback', () {
      expect(
        ProductArt.resolve(
          explicit: 'assets/images/custom_photo.png',
          brand: 'itel',
          name: 'itel Vision 3 Plus',
        ),
        'assets/images/custom_photo.png',
      );
    });
  });
}
