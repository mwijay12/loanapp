import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:loan_inventory_app/core/l10n/strings.dart';

/// A language switch is only real if every key has both sides.
///
/// The failure this prevents: a screen rendered in Swahili with three English
/// labels left over, which is exactly the mixing the switch is meant to end.
void main() {
  test('every key has an English and a Swahili entry', () {
    expect(untranslatedKeys, isEmpty);
  });

  test('looking up a key returns the right language', () {
    expect(tr(const Locale('en'), 'nav.home'), 'Home');
    expect(tr(const Locale('sw'), 'nav.home'), 'Nyumbani');
  });

  test('an unknown locale falls back to English, not to the key', () {
    expect(tr(const Locale('fr'), 'home.totalStock'), 'Total Stock');
  });

  test('a missing key is returned visibly rather than silently empty', () {
    expect(tr(const Locale('en'), 'no.such.key'), 'no.such.key');
  });

  test('the dictionary is not empty', () {
    expect(allStringKeys.length, greaterThan(30));
  });
}
