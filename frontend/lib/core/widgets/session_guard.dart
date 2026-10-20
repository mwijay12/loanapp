import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/inventory_provider.dart';
import '../theme/app_theme.dart';

/// Idle handling for the signed-in shell.
///
/// A retail counter is a shared terminal: a cashier signs in, serves a customer,
/// walks off, and the next person finds an authenticated Super Admin session on
/// screen. Locking on inactivity is the cheapest way to bound that exposure, so
/// this widget tracks pointer and keyboard activity, warns before cutting the
/// session, and signs the user out when the warning expires.
///
/// The clock only runs while the shell is mounted, which means it does not run
/// on the login screen or during onboarding.
class SessionGuard extends ConsumerStatefulWidget {
  const SessionGuard({
    super.key,
    required this.child,
    this.idleLimit = const Duration(minutes: 15),
    this.warningWindow = const Duration(seconds: 60),
  });

  final Widget child;
  final Duration idleLimit;
  final Duration warningWindow;

  @override
  ConsumerState<SessionGuard> createState() => _SessionGuardState();
}

class _SessionGuardState extends ConsumerState<SessionGuard> {
  Timer? _idleTimer;
  Timer? _warningTicker;
  bool _warningOpen = false;
  int _secondsLeft = 0;

  @override
  void initState() {
    super.initState();
    _restart();
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    _warningTicker?.cancel();
    super.dispose();
  }

  /// Restart the idle clock. Called on every real interaction.
  void _restart() {
    if (_warningOpen) return;
    _idleTimer?.cancel();
    _idleTimer = Timer(widget.idleLimit, _showWarning);
  }

  void _showWarning() {
    if (!mounted || _warningOpen) return;
    setState(() {
      _warningOpen = true;
      _secondsLeft = widget.warningWindow.inSeconds;
    });

    _warningTicker?.cancel();
    _warningTicker = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_secondsLeft <= 1) {
        t.cancel();
        _signOut();
        return;
      }
      setState(() => _secondsLeft--);
    });

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.rLg),
        ),
        title: const Row(
          children: [
            Icon(Icons.lock_clock_rounded, color: AppTheme.brand600),
            SizedBox(width: 10),
            Text('Session inaisha'),
          ],
        ),
        content: Text(
          'Hakuna shughuli kwa muda. Session itafungwa baada ya sekunde '
          '$_secondsLeft. Kama bado uko hapa, gusa "Endelea".',
          style: const TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _resume();
            },
            child: const Text('Endelea'),
          ),
          FilledButton(
            onPressed: _signOut,
            child: const Text('Toka sasa'),
          ),
        ],
      ),
    ).then((_) {
      // Dismissed by the sign-out path or by us; either way clear the flag so
      // the next idle cycle can fire again.
      if (mounted) setState(() => _warningOpen = false);
    });
  }

  void _resume() {
    _warningTicker?.cancel();
    if (!mounted) return;
    setState(() {
      _warningOpen = false;
      _secondsLeft = 0;
    });
    _restart();
  }

  void _signOut() {
    _warningTicker?.cancel();
    _idleTimer?.cancel();
    if (!mounted) return;
    final nav = Navigator.of(context);
    if (nav.canPop()) nav.pop();
    ref.read(userRoleProvider.notifier).clearSession();
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _restart(),
      onPointerSignal: (_) => _restart(),
      child: Focus(
        canRequestFocus: false,
        onKeyEvent: (_, __) {
          _restart();
          return KeyEventResult.ignored;
        },
        child: widget.child,
      ),
    );
  }
}
