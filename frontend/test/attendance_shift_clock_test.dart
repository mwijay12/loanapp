import 'package:flutter_test/flutter_test.dart';

import 'package:loan_inventory_app/core/data/attendance_clock.dart';
import 'package:loan_inventory_app/core/data/inventory_provider.dart';

/// Punches are absolute instants. Every expectation below is written in East
/// Africa Time because that is the shop's day, and the tests never call
/// `DateTime.now()` — the whole point is that a machine in another timezone
/// produces the same row.
void main() {
  group('date label', () {
    test('names the real month instead of a hardcoded one', () {
      // The ledger used to print 'Today, ${now.day} Oct ${now.year}', so every
      // shift in November 2026 was filed under October.
      expect(
        attendanceDateLabel(DateTime.utc(2026, 11, 30, 22, 16)),
        'Tue, 01 Dec 2026',
      );
      expect(
        attendanceDateLabel(DateTime.utc(2026, 1, 1, 9, 0)),
        'Thu, 01 Jan 2026',
      );
    });

    test('crosses into tomorrow with the day, not just the date text', () {
      // 23:00 UTC on 31 Dec 2026 is 02:00 EAT on 1 Jan 2027: the year moves too.
      expect(attendanceDateLabel(DateTime.utc(2026, 12, 31, 23, 0)),
          'Fri, 01 Jan 2027');
    });

    test('matches the format the seeded history already uses', () {
      // mock_lims_data rows read 'Fri, 02 Oct 2026'. If this drifts, the
      // "today" roster filter silently stops matching freshly written rows.
      expect(attendanceDateLabel(DateTime.utc(2026, 10, 2, 10, 5)),
          'Fri, 02 Oct 2026');
      expect(attendanceLongDateLabel(DateTime.utc(2026, 10, 2, 10, 5)),
          'Friday, 02 October 2026');
    });
  });

  group('time label', () {
    test('never prints a 24-hour digit next to AM/PM', () {
      // 13:05 used to be stored as '13:05 PM'.
      expect(attendanceTimeLabel(DateTime.utc(2026, 10, 2, 10, 5)), '01:05 PM');
      expect(attendanceTimeLabel(DateTime.utc(2026, 10, 2, 5, 4)), '08:04 AM');
    });

    test('renders midnight as 12 AM and noon as 12 PM', () {
      expect(attendanceTimeLabel(DateTime.utc(2026, 10, 2, 21, 30)), '12:30 AM');
      expect(attendanceTimeLabel(DateTime.utc(2026, 10, 2, 9, 0)), '12:00 PM');
    });
  });

  group('lateness', () {
    test('counts minutes past the 08:15 threshold, not the clock minute', () {
      // 09:40 used to be recorded as 'Late (40m)' because the code printed
      // now.minute. It is 85 minutes past shift start.
      expect(minutesPastShiftStart(DateTime.utc(2026, 10, 2, 6, 40)), 85);
      expect(attendanceStatusFor(DateTime.utc(2026, 10, 2, 6, 40)),
          'Late (85m)');
    });

    test('the threshold itself is not late', () {
      expect(minutesPastShiftStart(DateTime.utc(2026, 10, 2, 5, 15)), 0);
      expect(attendanceStatusFor(DateTime.utc(2026, 10, 2, 5, 15)), 'Present');
      expect(attendanceStatusFor(DateTime.utc(2026, 10, 2, 5, 16)), 'Late (1m)');
    });

    test('an early-hours punch is not treated as late', () {
      // 01:16 EAT is before the shift, so the old `now.hour > 8` test already
      // got this right — but only by accident, and only for the hour.
      expect(minutesPastShiftStart(DateTime.utc(2026, 11, 30, 22, 16)), -419);
      expect(attendanceStatusFor(DateTime.utc(2026, 11, 30, 22, 16)), 'Present');
    });
  });

  group('AttendanceNotifier', () {
    test('clockIn stamps the row from the shop clock', () {
      final notifier = AttendanceNotifier();
      notifier.clockIn(
        staffId: 'STF-9',
        staffName: 'Amina Hassan',
        role: 'Sales Associate',
        branch: 'Kinondoni',
        instant: DateTime.utc(2026, 11, 30, 22, 16),
      );

      final row = notifier.state.first;
      expect(row.date, 'Tue, 01 Dec 2026');
      expect(row.clockInTime, '01:16 AM');
      expect(row.status, 'Present');
      expect(row.clockOutTime, isNull);
    });

    test('a late punch lands in the ledger with the real overrun', () {
      final notifier = AttendanceNotifier();
      notifier.clockIn(
        staffId: 'STF-9',
        staffName: 'Amina Hassan',
        role: 'Sales Associate',
        branch: 'Kinondoni',
        instant: DateTime.utc(2026, 10, 2, 6, 40),
      );

      final row = notifier.state.first;
      expect(row.status, 'Late (85m)');
      expect(row.clockInTime, '09:40 AM');
      expect(row.date, 'Fri, 02 Oct 2026');
    });

    test('clockOut closes the row on the same clock', () {
      final notifier = AttendanceNotifier();
      notifier.clockIn(
        staffId: 'STF-9',
        staffName: 'Amina Hassan',
        role: 'Sales Associate',
        branch: 'Kinondoni',
        instant: DateTime.utc(2026, 10, 2, 5, 4),
      );
      final id = notifier.state.first.id;
      notifier.clockOut(id, instant: DateTime.utc(2026, 10, 2, 14, 30));

      final row = notifier.state.first;
      expect(row.clockInTime, '08:04 AM');
      expect(row.clockOutTime, '05:30 PM');
      expect(row.status, 'Completed');
    });

    test('the new row is the one a same-day filter finds', () {
      // The roster looks rows up by their date label. A punch has to be
      // retrievable with the label generated from the same instant, or the
      // staff card drops back to "clock in" a second after clocking in.
      final notifier = AttendanceNotifier();
      final at = DateTime.utc(2026, 10, 2, 6, 40);
      notifier.clockIn(
        staffId: 'STF-9',
        staffName: 'Amina Hassan',
        role: 'Sales Associate',
        branch: 'Kinondoni',
        instant: at,
      );

      expect(
        notifier.state.where((r) => r.date == attendanceDateLabel(at)).length,
        greaterThanOrEqualTo(1),
      );
    });
  });
}
