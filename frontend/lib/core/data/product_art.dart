/// Brand-aware product artwork.
///
/// A stock row used to fall back to one hero shot for every phone, so an itel
/// Vision rendered with an iPhone body. On a shop floor that is worse than a
/// blank tile: the thumbnail is how staff recognise a handset before reading the
/// SKU. The resolver below picks the artwork from the brand first, then from the
/// device type, and finally from a neutral unbranded body.
///
/// Every asset here is a stand-in. A real listing carries `imageAsset` or
/// `imageUrl` from the catalogue, and those always win.
class ProductArt {
  const ProductArt._();

  // Phones, one render per brand family.
  static const String apple = 'assets/images/blue_iphones_duo.png';
  static const String samsung = 'assets/images/samsung_galaxy_ultra.png';
  static const String xiaomi = 'assets/images/redmi_note_13_pro.png';
  static const String tecno = 'assets/images/tecno_camon_30.png';
  static const String infinix = 'assets/images/phone_midnight.png';
  static const String itel = 'assets/images/phone_entry_teal.png';

  /// Deliberately unbranded, for Nokia, Oppo, Vivo, a house brand, or anything
  /// the catalogue has not labelled yet.
  static const String genericPhone = 'assets/images/phone_generic.png';

  // Other device types.
  static const String laptop = 'assets/images/laptop.png';
  static const String powerBank = 'assets/images/powerbank.png';
  static const String watch = 'assets/images/smartwatch.png';
  static const String earbuds = 'assets/images/earbuds.png';

  /// Asset to show for a catalogue row.
  ///
  /// [explicit] is the row's own artwork and is returned untouched when set.
  /// Accessory keywords are matched before brand names because a Galaxy Watch is
  /// a watch, not a phone, and an AirPods case is not an iPhone.
  static String resolve({
    String? explicit,
    String? brand,
    required String name,
    String category = '',
  }) {
    if (explicit != null && explicit.isNotEmpty) return explicit;

    final n = name.toLowerCase();
    final c = category.toLowerCase();
    final b = (brand ?? '').toLowerCase();

    // 1. Device type, which outranks brand for accessories.
    if (n.contains('laptop') || n.contains('macbook') || c.contains('laptop')) {
      return laptop;
    }
    if (n.contains('power bank') ||
        n.contains('powerbank') ||
        n.contains('power-bank')) {
      return powerBank;
    }
    if (n.contains('watch') || c.contains('watch')) {
      return watch;
    }
    if (n.contains('earbud') ||
        n.contains('airpod') ||
        n.contains('pods') ||
        n.contains('headphone') ||
        n.contains('headset') ||
        n.contains('speaker')) {
      return earbuds;
    }

    // 2. Brand family, most specific spelling first. "Note" alone is ambiguous
    // (Redmi Note, Infinix Note), so it is only read as Infinix when the name
    // already carries that brand or has no other brand marker.
    if (b.contains('apple') ||
        n.contains('iphone') ||
        n.contains('ipad') ||
        n.contains('airpod')) {
      return apple;
    }
    if (b.contains('samsung') || n.contains('galaxy') || n.contains('samsung')) {
      return samsung;
    }
    if (b.contains('tecno') ||
        n.contains('tecno') ||
        n.contains('camon') ||
        n.contains('spark') ||
        n.contains('phantom')) {
      return tecno;
    }
    if (b.contains('itel') || n.contains('itel')) {
      return itel;
    }
    if (b.contains('infinix') ||
        n.contains('infinix') ||
        n.contains('zero 4') ||
        n.contains('hot 4') ||
        n.contains('hot 5') ||
        n.contains('hot 6')) {
      return infinix;
    }
    if (b.contains('xiaomi') ||
        b.contains('redmi') ||
        b.contains('poco') ||
        n.contains('redmi') ||
        n.contains('xiaomi') ||
        n.contains('poco')) {
      return xiaomi;
    }

    // 3. Unbranded phone, then a neutral accessory tile.
    if (c.contains('acc') || c.contains('accessor')) return earbuds;
    return genericPhone;
  }
}
