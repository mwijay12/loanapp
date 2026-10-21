import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// "Good morning" that is actually correct at the time it is read.
///
/// The header said good morning at 22:40 because the string was a literal. This
/// computes the greeting from the clock in East Africa Time and rebuilds on the
/// minute, so a terminal left open overnight rolls over by itself instead of
/// greeting the night shift with the morning.
///
/// EAT is UTC+3 with no daylight saving, which is why it is computed rather than
/// taken from the device: a handset set to the wrong zone would otherwise show
/// the wrong greeting, and the shop's day is the EAT day.
class LiveGreeting extends StatefulWidget {
  const LiveGreeting({super.key, this.style});

  final TextStyle? style;

  @override
  State<LiveGreeting> createState() => _LiveGreetingState();
}

class _LiveGreetingState extends State<LiveGreeting> {
  Timer? _ticker;
  late DateTime _now;

  @override
  void initState() {
    super.initState();
    _now = eatNow();
    // Rebuild every 30s: enough to cross a minute boundary promptly without
    // waking the browser more than necessary.
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      setState(() => _now = eatNow());
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      '${greetingFor(_now.hour)},',
      style: widget.style ??
          const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Color(0xFF475569),
          ),
    );
  }
}

/// Wall clock in East Africa Time, regardless of where the device thinks it is.
DateTime eatNow() => DateTime.now().toUtc().add(const Duration(hours: 3));

/// Morning < 12, afternoon < 17, evening after that. Night work after midnight is
/// still "evening" until 05:00, which reads better than "morning" at 02:00.
String greetingFor(int hour) {
  if (hour >= 5 && hour < 12) return 'Good morning';
  if (hour >= 12 && hour < 17) return 'Good afternoon';
  return 'Good evening';
}

/// "Tue, 22 Oct" in the shop's timezone.
String eatDateLabel(DateTime now) => DateFormat('EEE, d MMM').format(now);

class LiveDate extends StatefulWidget {
  const LiveDate({super.key, this.style});

  final TextStyle? style;

  @override
  State<LiveDate> createState() => _LiveDateState();
}

class _LiveDateState extends State<LiveDate> {
  Timer? _ticker;
  late DateTime _now;

  @override
  void initState() {
    super.initState();
    _now = eatNow();
    _ticker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted) return;
      setState(() => _now = eatNow());
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      eatDateLabel(_now),
      style: widget.style ??
          const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Color(0xFF94A3B8),
          ),
    );
  }
}
