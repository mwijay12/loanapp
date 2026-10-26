import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Keeps a back gesture from closing the app when there is nothing underneath.
///
/// Every screen that is not one of the five shell tabs (the admin console,
/// petty cash, the POS, the scanner, the notebook of settings…) is declared as
/// a top-level route. When one of those is the first entry on the stack there is
/// no screen beneath it to pop to, so the platform back button popped the last
/// route and the app closed — on web the page was left altogether. A Super Admin
/// signing in lands on `/admin` exactly like that, which is why the console felt
/// like the place the app "switched off".
///
/// The guard keeps the ordinary pop whenever a previous screen exists, and
/// returns to [fallback] when it does not, so back always means "step back",
/// never "quit".
class BackGuard extends StatelessWidget {
  const BackGuard({
    super.key,
    required this.child,
    this.fallback = '/home',
  });

  final Widget child;

  /// Where back goes when this screen is the whole stack.
  final String fallback;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Handled below rather than by the platform, because the platform's
      // fallback for "nothing to pop" is to close the app.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        final router = GoRouter.of(context);
        if (router.canPop()) {
          router.pop();
          return;
        }
        // A screen opened as the first entry has no history of its own.
        router.go(fallback);
      },
      child: child,
    );
  }
}
