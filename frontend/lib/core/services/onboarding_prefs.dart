import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Remembers that the introduction has been seen.
///
/// The onboarding screens existed but could only be reached by typing
/// `/#/onboarding`, because the router always opened on `/login`. A first-run
/// visitor therefore never saw them, and a returning visitor would have seen them
/// every time if the route had been the default.
///
/// One flag settles both cases: unset means show the introduction, set means go
/// straight to sign-in.
class OnboardingPrefs {
  static const String _key = 'lims.seen_onboarding.v1';

  /// Read once during startup, before the router is built.
  static Future<bool> hasSeen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_key) ?? false;
    } catch (_) {
      // Storage unavailable (private mode, blocked cookies). Showing the
      // introduction again is the harmless direction; a crash is not.
      return false;
    }
  }

  static Future<void> markSeen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, true);
    } catch (_) {
      // Same reasoning: failing to record the flag must not block navigation.
    }
  }
}

/// Resolved at startup and injected through a ProviderScope override.
final seenOnboardingProvider = Provider<bool>((ref) => true);
