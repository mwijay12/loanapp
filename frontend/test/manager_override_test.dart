import 'package:flutter_test/flutter_test.dart';
import 'package:loan_inventory_app/core/data/supabase_source.dart';

/// The counter has to say four different things about a PIN, and the difference is
/// not cosmetic: "try again" and "stop, this is locked for fifteen minutes" send a
/// person in opposite directions. These map the database's own messages (migration
/// 2026_10_28_02_manager_override.sql) onto those answers.
void main() {
  String textOf(String message) => 'PostgrestException: code: 42501, message: $message';

  group('override classification', () {
    test('a locked manager is told to stop, not to retry', () {
      final r = SupabaseSource.classifyOverrideFailure(textOf('override_pin_locked'));
      expect(r.status, ManagerOverrideStatus.locked);
      expect(r.message, contains('fifteen minutes'));
      expect(r.message, isNot(contains('try again')));
    });

    test('a role that may not set a PIN is told so in words', () {
      final r = SupabaseSource.classifyOverrideFailure(textOf('override_role_forbidden'));
      expect(r.status, ManagerOverrideStatus.failed);
      expect(r.message, contains('Branch Manager'));
    });

    test('a session the server does not recognise is not reported as a wrong PIN', () {
      final r = SupabaseSource.classifyOverrideFailure(textOf('override_no_session'));
      expect(r.status, ManagerOverrideStatus.failed);
      expect(r.message, isNot(contains('not correct')));
    });

    test('a malformed PIN is described by its format', () {
      final r = SupabaseSource.classifyOverrideFailure(textOf('override_pin_format'));
      expect(r.status, ManagerOverrideStatus.failed);
      expect(r.message, contains('6 digits'));
    });

    test('an unknown action is named rather than swallowed', () {
      final r = SupabaseSource.classifyOverrideFailure(textOf('override_action_unknown'));
      expect(r.status, ManagerOverrideStatus.failed);
      expect(r.message, contains('sale'));
    });

    test('anything else keeps the server sentence', () {
      final r = SupabaseSource.classifyOverrideFailure(
          'PostgrestException: code: 500, message: connection reset');
      expect(r.status, ManagerOverrideStatus.failed);
      expect(r.message, contains('connection reset'));
    });
  });

  group('the token itself', () {
    test('granted without a token is not granted', () {
      // An RPC that answered 200 with a null body means "wrong PIN", and a state
      // object that only looked at the enum would call that a success.
      const grantedButEmpty = ManagerOverride(ManagerOverrideStatus.granted);
      expect(grantedButEmpty.isGranted, isFalse);
      const withToken = ManagerOverride(
        ManagerOverrideStatus.granted,
        token: '8f14b2a2-6f1a-4a3b-9b04-2f1c0a5d7e11',
      );
      expect(withToken.isGranted, isTrue);
    });

    test('a build with no database never claims an override was checked', () {
      const none = ManagerOverride(ManagerOverrideStatus.notConfigured);
      expect(none.isGranted, isFalse);
      expect(none.message, contains('no database'));
    });
  });
}
