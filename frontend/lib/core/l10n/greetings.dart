/// Which part of the shop day it is, and the greeting that goes with it.
///
/// The counter used to open with one fixed line — "Welcome back," — at 8 a.m.
/// and at 8 p.m. alike, which is the kind of copy that stops being read after the
/// second morning. The greeting now follows the clock, on the same East Africa
/// offset the shop day is counted on ([eatDateOf] and friends in
/// `sales_provider`), so a cashier opening the app at dawn is not told good
/// evening because the device happens to be set to another timezone.
///
/// Kept as a pure function of a moment so it can be tested without waiting for
/// the wall clock.
library;

enum DayPart { morning, afternoon, evening }

/// 05:00–11:59 morning, 12:00–16:59 afternoon, 17:00–04:59 evening.
///
/// Three bands, not four: an English "good night" is a goodbye rather than a
/// greeting, so the late hours stay on "good evening", which is true at 23:00
/// and in Swahili is "habari za jioni".
DayPart dayPartAt(DateTime moment) {
  final eat = moment.toUtc().add(const Duration(hours: 3));
  final hour = eat.hour;
  if (hour >= 5 && hour < 12) return DayPart.morning;
  if (hour >= 12 && hour < 17) return DayPart.afternoon;
  return DayPart.evening;
}

/// The translation key for [part].
String salutationKeyFor(DayPart part) {
  switch (part) {
    case DayPart.morning:
      return 'greet.morning';
    case DayPart.afternoon:
      return 'greet.afternoon';
    case DayPart.evening:
      return 'greet.evening';
  }
}

/// The translation key for the greeting at [moment].
String salutationKeyAt(DateTime moment) => salutationKeyFor(dayPartAt(moment));
