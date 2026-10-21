import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The language the app is showing.
///
/// Moved out of the account screen and given storage, because a choice that
/// disappears on reload is not a setting. A cashier who picks Swahili should find
/// Swahili the next morning on the same terminal.
final localeProvider = StateProvider<Locale>((ref) => const Locale('en'));

class LocaleStore {
  static const String _key = 'lims.locale.v1';

  static Future<Locale> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString(_key);
      if (code == 'sw') return const Locale('sw');
      return const Locale('en');
    } catch (_) {
      // Storage blocked: English is the safe default, never a crash.
      return const Locale('en');
    }
  }

  static Future<void> save(Locale locale) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, locale.languageCode);
    } catch (_) {
      // Same reasoning: failing to remember must not break the toggle.
    }
  }
}
