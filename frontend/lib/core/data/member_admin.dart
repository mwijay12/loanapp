import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/api_service.dart';

/// A person who can sign in: one `auth.users` row plus the `profiles` row that
/// carries the role the whole app reads.
///
/// This is deliberately separate from `StaffMember`, which is the roster in the
/// `staff` table. A roster entry is a name on a list; a member is a set of
/// credentials. The old "add staff" sheet only ever made the former and the
/// credentials were imagined, which is why nothing could log in afterwards.
class MemberRecord {
  const MemberRecord({
    required this.id,
    required this.authUserId,
    required this.email,
    required this.fullName,
    required this.role,
    this.branchName,
    this.phone,
  });

  final String id;
  final String? authUserId;
  final String email;
  final String fullName;
  final String role;
  final String? branchName;
  final String? phone;

  bool get hasLogin => (authUserId ?? '').isNotEmpty;

  /// Two capital letters the avatar can show without a photo.
  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) {
      return email.isEmpty ? '?' : email.substring(0, 1).toUpperCase();
    }
    final first = parts.first.substring(0, 1);
    final last = parts.length > 1 ? parts.last.substring(0, 1) : '';
    return (first + last).toUpperCase();
  }

  factory MemberRecord.fromRow(Map<String, dynamic> row) {
    return MemberRecord(
      id: (row['id'] ?? '').toString(),
      authUserId: row['auth_user_id']?.toString(),
      email: (row['email'] ?? '').toString(),
      fullName: (row['full_name'] ?? '').toString(),
      role: (row['role'] ?? '').toString(),
      branchName: row['branch_name']?.toString(),
      phone: row['phone']?.toString(),
    );
  }
}

/// The result of a member action, so the UI can print the server's own words
/// instead of inventing a success.
class MemberActionResult {
  const MemberActionResult({this.ok = false, this.error, this.member});

  final bool ok;
  final String? error;
  final MemberRecord? member;

  static MemberActionResult failure(String message) =>
      MemberActionResult(ok: false, error: message);
}

/// Talks to the `admin-members` Edge Function.
///
/// The browser never holds a service_role key: this call carries only the
/// signed-in user's JWT, and the function decides whether that user is a Super
/// Admin before it creates anything.
/// The live client, or null when the app was built without keys or is running
/// under a widget test that never initialised Supabase. `Supabase.instance`
/// throws in that second case, and a settings row is not worth a crash.
SupabaseClient? liveClient() {
  if (!SupabaseConfig.isConfigured) return null;
  try {
    return Supabase.instance.client;
  } catch (_) {
    return null;
  }
}

class MemberAdminService {
  const MemberAdminService();

  bool get _ready {
    final client = liveClient();
    return client != null && client.auth.currentUser != null;
  }

  Future<MemberActionResult> _invoke(Map<String, dynamic> body) async {
    if (!_ready) {
      return MemberActionResult.failure('Not signed in.');
    }
    final client = liveClient();
    if (client == null) return MemberActionResult.failure('Not signed in.');
    try {
      final response = await client.functions.invoke(
        'admin-members',
        body: body,
      );
      final data = response.data;
      final map = data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
      if (map['error'] != null) {
        return MemberActionResult.failure(map['error'].toString());
      }
      final member = map['member'];
      return MemberActionResult(
        ok: map['ok'] == true,
        member: member is Map
            ? MemberRecord.fromRow(Map<String, dynamic>.from(member))
            : null,
      );
    } on FunctionException catch (e) {
      final details = e.details;
      if (details is Map && details['error'] != null) {
        return MemberActionResult.failure(details['error'].toString());
      }
      return MemberActionResult.failure(
          details?.toString() ?? 'Server said ${e.status}.');
    } catch (e) {
      debugPrint('LIMS: member action failed -> $e');
      return MemberActionResult.failure(e.toString());
    }
  }

  Future<MemberActionResult> createMember({
    required String email,
    required String password,
    required String fullName,
    required String role,
    String? branchName,
    String? phone,
  }) {
    return _invoke({
      'action': 'create',
      'email': email,
      'password': password,
      'full_name': fullName,
      'role': role,
      'branch_name': branchName ?? '',
      'phone': phone ?? '',
    });
  }

  Future<MemberActionResult> resetPassword({
    required String profileId,
    required String password,
  }) {
    return _invoke({
      'action': 'reset_password',
      'profile_id': profileId,
      'password': password,
    });
  }

  Future<MemberActionResult> setRole({
    required String profileId,
    required String role,
  }) {
    return _invoke({
      'action': 'set_role',
      'profile_id': profileId,
      'role': role,
    });
  }

  Future<MemberActionResult> setActive({
    required String profileId,
    required bool active,
  }) {
    return _invoke({
      'action': 'set_active',
      'profile_id': profileId,
      'active': active,
    });
  }
}

final memberAdminServiceProvider =
    Provider<MemberAdminService>((ref) => const MemberAdminService());

/// Every login in the shop. Readable by a Super Admin through the
/// `profiles_read_staff` policy; a member with no such role just sees themselves,
/// which is what the policy already says.
final membersProvider = FutureProvider<List<MemberRecord>>((ref) async {
  final client = liveClient();
  if (client == null) return const [];
  final rows = await client
      .from('profiles')
      .select('id, auth_user_id, email, full_name, role, branch_name, phone')
      .order('role')
      .order('full_name');
  final list = (rows as List)
      .map((r) => MemberRecord.fromRow(Map<String, dynamic>.from(r as Map)))
      .toList();
  // A profile with no email is not a login anybody can use; hiding it is more
  // honest than listing a blank row.
  return list.where((m) => m.email.isNotEmpty).toList();
});

/// The signed-in person's own profile row.
///
/// Settings used to read the identity block from the `staff` roster, which has
/// no email and no staff code, so it printed two dashes as if the account were
/// unbound. The email the person actually signed in with lives on the session,
/// and the role lives on their profile - that is what this reads.
final currentMemberProvider = FutureProvider<MemberRecord?>((ref) async {
  final client = liveClient();
  if (client == null) return null;
  final user = client.auth.currentUser;
  if (user == null) return null;
  try {
    final row = await client
        .from('profiles')
        .select('id, auth_user_id, email, full_name, role, branch_name, phone')
        .eq('auth_user_id', user.id)
        .maybeSingle();
    if (row == null) return null;
    final member = MemberRecord.fromRow(Map<String, dynamic>.from(row));
    // GoTrue knows the address even if the profile row was created before it.
    if (member.email.isEmpty && (user.email ?? '').isNotEmpty) {
      return MemberRecord(
        id: member.id,
        authUserId: member.authUserId,
        email: user.email!,
        fullName: member.fullName,
        role: member.role,
        branchName: member.branchName,
        phone: member.phone,
      );
    }
    return member;
  } catch (e) {
    debugPrint('LIMS: could not read the signed-in profile -> $e');
    return null;
  }
});

/// A password a person can read off a phone and type on a keypad: no ambiguous
/// characters (0/O, 1/l/I), letters and digits, long enough for GoTrue.
String generateMemberPassword([Random? random]) {
  const letters = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
  const digits = '23456789';
  final rng = random ?? Random.secure();
  final word = List.generate(3, (_) => letters[rng.nextInt(letters.length)])
      .join();
  final tail = List.generate(4, (_) => digits[rng.nextInt(digits.length)])
      .join();
  return 'Lims-$word-$tail';
}
