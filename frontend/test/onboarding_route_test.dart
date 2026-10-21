import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:loan_inventory_app/core/routing/app_router.dart';
import 'package:loan_inventory_app/core/services/onboarding_prefs.dart';

/// The introduction has to appear once, then get out of the way.
///
/// The screens existed from the start but the router opened on /login, so nobody
/// saw them. Once the flag was added, the opposite mistake became possible: a
/// returning user shown the introduction on every launch. These two cases pin
/// both directions.
void main() {
  test('a first run opens the introduction', () {
    final container = ProviderContainer(
      overrides: [seenOnboardingProvider.overrideWithValue(false)],
    );
    addTearDown(container.dispose);

    expect(container.read(initialRouteProvider), '/onboarding');
  });

  test('a later run opens sign-in', () {
    final container = ProviderContainer(
      overrides: [seenOnboardingProvider.overrideWithValue(true)],
    );
    addTearDown(container.dispose);

    expect(container.read(initialRouteProvider), '/login');
  });

  test('both routes are reachable without a session', () {
    // A guard that forgot /onboarding would bounce a first-run visitor straight
    // back to sign-in, which looks like the introduction is broken.
    expect(kPublicRoutes, contains('/onboarding'));
    expect(kPublicRoutes, contains('/login'));
  });
}
