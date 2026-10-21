import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/app_constants.dart';

/// Supabase Backend Configuration for LIMS
/// Organization: hvqssaxwrrmewmvqujus
/// Lead Architect: David Erick Mwijage (mwijay12)
class SupabaseConfig {
  // Injected at build time: flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
  // Never hardcode JWTs in source - use CI secrets / local --dart-define.
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// True when a build was given both halves of the client configuration.
  ///
  /// Supabase's newer dashboard calls the client key a "publishable" key; it
  /// travels in the same `apikey` header as the older anon key, so one define
  /// covers both.
  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}

/// Central API Service connecting Flutter UI with Supabase Cloud Database
class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  SupabaseClient? _client;
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  SupabaseClient get client {
    if (_client == null) {
      return Supabase.instance.client;
    }
    return _client!;
  }

  /// Initializes Supabase & sends a keep-alive heartbeat ping.
  /// P0: fails loud when --dart-define values are missing so a misbuilt
  /// APK can never silently run against no backend.
  Future<void> init() async {
    if (SupabaseConfig.supabaseUrl.isEmpty || SupabaseConfig.supabaseAnonKey.isEmpty) {
      throw StateError(
        'Missing SUPABASE_URL / SUPABASE_ANON_KEY. '
        'Build with --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...',
      );
    }
    try {
      await Supabase.initialize(
        url: SupabaseConfig.supabaseUrl,
        anonKey: SupabaseConfig.supabaseAnonKey,
      );
      _client = Supabase.instance.client;
      _isInitialized = true;

      // Automated heartbeat write to prevent 7-day inactivity pause
      await sendHeartbeatPing(source: 'flutter-app-launch');
    } catch (e) {
      _report('backend call', e);
      try {
        _client = Supabase.instance.client;
        _isInitialized = true;
      } catch (e) {
      _report('backend call', e);}
    }
  }

  /// Sends a keep-alive touch so the free-tier Supabase project never hits the
  /// 7-day inactivity pause.
  ///
  /// The column is `payload`, not `metadata`. The previous version inserted a
  /// `metadata` key, which PostgREST rejected, and the surrounding `catch (_) {}`
  /// hid the failure — so the in-app heartbeat never actually landed and the
  /// only thing keeping the project awake was the scheduled workflow.
  ///
  /// Order matters. `init()` calls this before anybody is signed in, and an
  /// anonymous INSERT into `heartbeat_pings` is the only write anon is allowed;
  /// once a session exists the ping is attributed to the real user.
  Future<void> sendHeartbeatPing({String source = 'in-app-ping'}) async {
    final payload = <String, dynamic>{
      'app': 'LIMS Mobile App',
      'source': source,
      'timestamp': DateTime.now().toIso8601String(),
    };

    // Preferred path: a real, attributable ping.
    try {
      if (client.auth.currentSession != null) {
        await client.from('heartbeat_pings').insert({
          'source': source,
          'payload': payload,
        });
        return;
      }
    } catch (e) {
      _report('backend call', e);
      // Fall through to the anonymous probe below.
    }

    // Anonymous path. `heartbeat_probe()` is SECURITY DEFINER, executable by
    // anon, and returns aggregate counts only — never cost or selling price.
    // Any successful request still counts as project activity.
    try {
      await client.rpc('heartbeat_probe');
    } catch (e) {
      _report('backend call', e);}
  }

  // ------------------------------------------------------------- Authentication & Staff Profiles
  //
  // SECURITY FIX — this method used to read the profile row and return a
  // session WITHOUT ever checking the password:
  //
  //   final res = await client.from('profiles').select()
  //       .or('phone.eq.$sanitized,email.eq.$sanitized').maybeSingle();
  //   if (res == null) throw StateError('Account not found...');
  //   return { ... 'role': res['role'] ?? 'Branch Manager' ... };
  //
  // Three separate problems, all fixed below:
  //   1. Any password was accepted for any known email or phone. That is an
  //      authentication bypass, not a bug.
  //   2. A null/unknown role silently became 'Branch Manager'.
  //   3. `.or('phone.eq.$sanitized,...')` interpolated user input straight into
  //      a PostgREST filter expression.
  //
  // Passwords can only be verified server-side, so the check now goes through
  // Supabase Auth (signInWithPassword) and the role is read back afterwards.
  // Every role read is normalised and unknown values fail closed.
  //
  // NOTE: this requires the Supabase Auth users to exist. Until they are
  // created (P1 Hatua 1), nobody can sign in — which is the correct behaviour:
  // the alternative is an open door.
  Future<Map<String, dynamic>> login(String identifier, String password) async {
    final email = identifier.trim().toLowerCase();
    final secret = password.trim();

    if (email.isEmpty || secret.isEmpty) {
      throw StateError('Enter your email and password.');
    }
    if (!email.contains('@')) {
      throw StateError('Sign in with your work email address.');
    }

    // DEMO BUILD ONLY. Compiled out when --dart-define=DEMO_MODE is not true,
    // so a production APK cannot reach this branch. It exists because the
    // showcase runs on mock data with no Supabase project behind it.
    // Only when the build has no database behind it. With Supabase configured
    // the demo accounts are real auth users, so the shortcut would return a
    // profile with no session and every RLS policy would then deny the reads.
    if (AppConstants.demoMode && !SupabaseConfig.isConfigured) {
      final account = AppConstants.demoAccounts[email];
      if (account == null || secret != AppConstants.demoPassword) {
        throw StateError(
          'Demo login failed. Use one of the demo accounts shown on this screen.',
        );
      }
      return {
        'id': 'demo-${account['role']}',
        'name': account['name'] ?? 'Demo User',
        'email': email,
        'phone': '',
        'role': account['role'],
        'branch': AppConstants.launchBranch,
      };
    }

    // 1. Verify the password. On failure Supabase throws an AuthException; the
    //    raw provider message is deliberately not surfaced, because it can
    //    reveal whether an address exists.
    final AuthResponse auth;
    try {
      auth = await client.auth.signInWithPassword(
        email: email,
        password: secret,
      );
    } on AuthException {
      throw StateError('Invalid email or password.');
    }

    final user = auth.user;
    if (user == null) {
      throw StateError('Invalid email or password.');
    }

    // 2. Read the server-owned role. This is display/routing data only; RLS on
    //    every table is what actually enforces access.
    //
    //    The live `public.profiles` table does NOT use the auth user id as its
    //    primary key. It carries a separate nullable `auth_user_id` column, and
    //    rows are keyed by their own `id`. Reading the profile by `.eq('id',
    //    user.id)` therefore matched nothing and every real account fell through
    //    to the fail-closed path — the accounts existed, the roles did not.
    //
    //    Resolution order, most authoritative first:
    //      1. auth_user_id  — the correct link on the live schema
    //      2. id            — correct on a schema where they are the same value
    //      3. email         — legacy rows written before the link existed
    //    `eq` escapes its argument, so no filter expression is interpolated.
    Map<String, dynamic>? res;

    try {
      res = await client
          .from('profiles')
          .select()
          .eq('auth_user_id', user.id)
          .maybeSingle();
    } catch (e) {
      _report('backend call', e);
      // Column absent on this schema — fall through.
    }

    if (res == null) {
      try {
        res = await client
            .from('profiles')
            .select()
            .eq('id', user.id)
            .maybeSingle();
      } catch (e) {
      _report('backend call', e);
        // id is not an auth id on every schema — fall through.
      }
    }

    if (res == null && (user.email ?? email).isNotEmpty) {
      try {
        res = await client
            .from('profiles')
            .select()
            .eq('email', user.email ?? email)
            .maybeSingle();
      } catch (e) {
      _report('backend call', e);
        // Leave res null; the fail-closed branch below reports it.
      }
    }

    final rawRole = res == null ? null : res['role'] as String?;
    final role = UserRoles.normalize(rawRole);

    // 3. Fail closed. An unrecognised or not-yet-activated account must not
    //    inherit any access, and must not be left holding a valid session.
    if (role == null || role == UserRoles.pending) {
      await client.auth.signOut();
      throw StateError(
        'Your account has no role assigned yet. '
        'Ask a Super Admin to activate it.',
      );
    }

    return {
      'id': user.id,
      'name': (res == null ? null : res['full_name'] as String?) ?? 'User',
      'email': user.email ?? email,
      'phone': (res == null ? null : res['phone'] as String?) ?? '',
      'role': role,
      'branch':
          (res == null ? null : res['branch_name'] as String?) ??
              AppConstants.launchBranch,
    };
  }

  /// A failed read used to be swallowed silently, so a missing table, an RLS
  /// denial and a dropped network all looked like "no data yet". Keeping the
  /// empty result is fine for the UI, but the failure now leaves a trace.
  void _report(String what, Object error) {
    debugPrint('LIMS: $what failed -> $error');
    lastBackendError = error.toString();
  }

  /// Last transport or schema error, for a diagnostics banner. Null when the
  /// most recent call succeeded.
  static String? lastBackendError;

  // ------------------------------------------------------------- Products & Inventory
  Future<List<Map<String, dynamic>>> getProducts() async {
    try {
      final response = await client.from('products').select().order('id');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      _report('backend call', e);
      return [];
    }
  }

  Future<Map<String, dynamic>?> getProductBySku(String sku) async {
    try {
      final response = await client.from('products').select().eq('sku', sku).maybeSingle();
      return response != null ? Map<String, dynamic>.from(response) : null;
    } catch (e) {
      _report('backend call', e);
      return null;
    }
  }

  // ------------------------------------------------------------- Loans & Credit Ledger
  Future<List<Map<String, dynamic>>> getLoans() async {
    try {
      final response = await client.from('loans').select().order('id');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      _report('backend call', e);
      return [];
    }
  }

  Future<Map<String, dynamic>> createLoan(Map<String, dynamic> data) async {
    try {
      final response = await client.from('loans').insert(data).select().single();
      return Map<String, dynamic>.from(response);
    } catch (e) {
      _report('backend call', e);
      return {'id': DateTime.now().millisecondsSinceEpoch, ...data};
    }
  }

  // ------------------------------------------------------------- Branches
  Future<List<Map<String, dynamic>>> getBranches() async {
    try {
      final response = await client.from('branches').select().order('name');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      _report('backend call', e);
      return [];
    }
  }

  // ------------------------------------------------------------- Activities Feed
  Future<List<Map<String, dynamic>>> getActivities() async {
    try {
      final response = await client.from('activities').select().order('created_at', ascending: false).limit(20);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      _report('backend call', e);
      return [];
    }
  }

  // ------------------------------------------------------------- Attendance
  Future<Map<String, dynamic>> checkIn(Map<String, dynamic> data) async {
    try {
      final response = await client.from('attendance').insert(data).select().single();
      return Map<String, dynamic>.from(response);
    } catch (e) {
      _report('backend call', e);
      return {'id': 'local-${DateTime.now().millisecondsSinceEpoch}', ...data};
    }
  }
}

final apiServiceProvider = Provider<ApiService>((ref) => ApiService());
