import 'package:flutter/services.dart';

/// Small, shared haptic vocabulary for the touch screens.
///
/// Every call is fire-and-forget and swallows its own failure: the same build
/// runs on Android (where a vibration motor answers), on the web preview (where
/// nothing does) and on desktop. A missing motor is not an error the cashier
/// should ever see, and an unawaited `HapticFeedback` call must not be able to
/// take a tap handler down with it.
class Haptics {
  Haptics._();

  /// A switch changed — the shortest tick the platform offers.
  static Future<void> select() => _run(HapticFeedback.selectionClick);

  /// Something was pressed and will navigate or open a sheet.
  static Future<void> tap() => _run(HapticFeedback.lightImpact);

  /// A long press was recognised, so the finger gets a firmer answer before the
  /// sheet appears.
  static Future<void> longPress() => _run(HapticFeedback.mediumImpact);

  static Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      // No motor, no plugin, or a platform that ignores the channel.
    }
  }
}
