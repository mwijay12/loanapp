/// One set of motion values for the whole app.
///
/// Before this file existed, durations were typed in place: `260ms` on the revenue
/// bars, `320ms` on the toast, `250ms` on the notifications dialog, `220ms` on the
/// view toggle. Nothing wrong with any single one of them - the problem is that the
/// app then has no idea what its own speed *is*, so nothing lands together, and the
/// result reads as stock widgets rather than as one product. Numbers that agree with
/// each other are most of what "premium" means: the same 200-300ms family, the same
/// deceleration curve, and a short stagger on anything that arrives in a group.
///
/// Two rules that matter more than the constants:
///
///  1. **Everything here is finite.** Nothing loops forever. An infinite animation
///     keeps a `pumpAndSettle` in a widget test spinning until the test times out,
///     and more importantly it keeps the device redrawing - on the mid-range
///     Androids these shops actually run, a permanently animating screen is the
///     difference between feeling quick and feeling laggy. A number that counts up
///     once when the admin opens the tab is the effect; a number that breathes
///     forever is a battery drain that also stops being noticed after two seconds.
///  2. **`MediaQuery.disableAnimations` is obeyed everywhere**, because the OS
///     setting exists for people for whom this motion is nausea, not polish. One
///     check in [Motion.enabled] covers every widget in this folder.
library;

import 'package:flutter/widgets.dart';

abstract final class Motion {
  // ---- durations. Four values, used everywhere; nothing else.
  /// A press, a colour change, a tick. Short enough to feel like a direct response.
  static const Duration tap = Duration(milliseconds: 120);

  /// Tab selection, a bar highlight, an expand.
  static const Duration state = Duration(milliseconds: 200);

  /// A whole surface changing: tab body, filter range, empty state.
  static const Duration view = Duration(milliseconds: 300);

  /// The one-shot arrival of content on first build.
  static const Duration entrance = Duration(milliseconds: 420);

  /// A metric counting to its value.
  static const Duration count = Duration(milliseconds: 750);

  /// Gap between the arrivals of siblings in a group.
  static const Duration step = Duration(milliseconds: 55);

  // ---- curves. Deceleration is the default: things arrive and settle, they do
  // not swing. `emphasized` is only for small surfaces that pop - on a full-width
  // card an overshoot reads as a layout bug, not as bounce.
  static const Curve standard = Curves.easeOutCubic;
  static const Curve emphasized = Curves.easeOutBack;
  static const Curve inOut = Curves.easeInOutCubic;

  /// How far below its final position content starts when it rises in, in
  /// logical pixels. 14 is deliberately small: 40 looks like a page turn.
  static const double rise = 14;

  /// Scale a pressed control settles to while held.
  static const double pressScale = 0.972;

  /// Escape hatch for widget tests and for any host that wants the app still.
  ///
  /// [MediaQuery.disableAnimations] is the real, user-facing switch and is read
  /// from the platform; this one exists so a test can assert on the settled
  /// layout without pumping frames, without pretending the user asked for it.
  static bool ambientEnabled = true;

  /// Whether anything should animate right now.
  static bool enabled(BuildContext? context) {
    if (!ambientEnabled) return false;
    if (context == null) return true;
    return MediaQuery.maybeOf(context)?.disableAnimations != true;
  }

  /// [d], or zero when motion is off. Use this on implicit animated widgets
  /// (`AnimatedContainer`, `AnimatedSwitcher`) that take a duration rather than
  /// reading a value from a curve.
  static Duration d(BuildContext? context, Duration d) =>
      enabled(context) ? d : Duration.zero;

  /// The delay of the [index]-th item of a group, already zeroed when motion is
  /// off, so a caller never has to remember the reduce-motion branch twice.
  ///
  /// The total is capped: a list of forty rows staggered at 55ms would leave the
  /// last one arriving after two seconds, which is not polish, it is a queue. Items
  /// past the cap arrive together with the item that filled it.
  static Duration delayFor(BuildContext? context, int index,
      {Duration? each, int maxSteps = 8}) {
    if (!enabled(context)) return Duration.zero;
    final i = index > maxSteps ? maxSteps : index;
    return step * i;
  }
}
