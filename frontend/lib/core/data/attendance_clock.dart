/// The shop's shift clock, in one place.
///
/// Attendance rows are plain strings (`date`, `clockInTime`, `status`), so every
/// writer has to agree on how an instant becomes text. They did not: the ledger
/// stamped a hardcoded month, the late marker printed the wall-clock minute
/// instead of minutes past the threshold, and the clock-in punch ran on the
/// device's timezone while the dashboard it feeds runs on East Africa Time.
///
/// These helpers are pure and take the instant as an argument, so a test can
/// drive them across a midnight boundary without waiting for one. The EAT
/// conversion is reused from [eatClock] rather than restated, because a second
/// `+3` is a second place to get wrong.
library;

import 'sales_provider.dart' show eatClock;

/// Shift start, in East Africa Time. A punch at or before this is on time.
const int shiftStartHour = 8;
const int shiftStartMinute = 15;

const List<String> _weekdayShort = [
  'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun',
];

const List<String> _monthShort = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

const List<String> _weekdayLong = [
  'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
];

const List<String> _monthLong = [
  'January', 'February', 'March', 'April', 'May', 'June', //
  'July', 'August', 'September', 'October', 'November', 'December',
];

String _pad2(int n) => n.toString().padLeft(2, '0');

/// "Fri, 02 Oct 2026" — the format the ledger rows and the seeded history use.
String attendanceDateLabel(DateTime instant) {
  final e = eatClock(instant);
  return '${_weekdayShort[e.weekday - 1]}, ${_pad2(e.day)} '
      '${_monthShort[e.month - 1]} ${e.year}';
}

/// "Friday, 02 October 2026" for the shift header.
String attendanceLongDateLabel(DateTime instant) {
  final e = eatClock(instant);
  return '${_weekdayLong[e.weekday - 1]}, ${_pad2(e.day)} '
      '${_monthLong[e.month - 1]} ${e.year}';
}

/// "01:05 PM". The 24-hour digit that used to sit next to "PM" is the reason
/// this exists: `13:05 PM` is not a time anyone can read off a payslip.
String attendanceTimeLabel(DateTime instant) {
  final e = eatClock(instant);
  final h24 = e.hour;
  final h12 = h24 % 12 == 0 ? 12 : h24 % 12;
  return '${_pad2(h12)}:${_pad2(e.minute)} ${h24 >= 12 ? 'PM' : 'AM'}';
}

/// Minutes past the shift start. Zero or negative means on time.
///
/// This is minute-of-day arithmetic rather than a `Duration` between two
/// DateTimes on purpose: `eatClock` returns a UTC-flagged instant holding EAT
/// wall-clock fields, and building the 08:15 threshold as a local DateTime
/// would make the subtraction absorb the device's own offset. The shop has no
/// daylight saving, so a plain minute count is exact.
int minutesPastShiftStart(DateTime instant) {
  final e = eatClock(instant);
  final punchMinuteOfDay = e.hour * 60 + e.minute;
  return punchMinuteOfDay - (shiftStartHour * 60 + shiftStartMinute);
}

/// The status string the roster and the exported PDF print.
String attendanceStatusFor(DateTime instant) {
  final minutesLate = minutesPastShiftStart(instant);
  return minutesLate > 0 ? 'Late (${minutesLate}m)' : 'Present';
}
