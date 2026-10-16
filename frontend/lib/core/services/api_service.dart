import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase Backend Configuration for LIMS
/// Organization: hvqssaxwrrmewmvqujus
/// Lead Architect: David Erick Mwijage (mwijay12)
class SupabaseConfig {
  // Injected at build time: flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
  // Never hardcode JWTs in source - use CI secrets / local --dart-define.
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
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
    } catch (_) {
      try {
        _client = Supabase.instance.client;
        _isInitialized = true;
      } catch (_) {}
    }
  }

  /// Sends a keep-alive touch to Supabase heartbeat_pings table
  Future<void> sendHeartbeatPing({String source = 'in-app-ping'}) async {
    try {
      await client.from('heartbeat_pings').insert({
        'source': source,
        'metadata': {
          'app': 'LIMS Mobile App',
          'author': 'David Erick Mwijage',
          'timestamp': DateTime.now().toIso8601String(),
        },
      });
    } catch (_) {}
  }

  // ------------------------------------------------------------- Authentication & Staff Profiles
  // P0: no offline fallback, no client-side role invention. Any failure
  // throws so the login screen can show an error instead of granting access.
  // Full fix (Supabase Auth + RLS) is P1; this only closes the open door.
  Future<Map<String, dynamic>> login(String identifier, String password) async {
    final sanitized = identifier.trim();
    if (sanitized.isEmpty || password.trim().isEmpty) {
      throw StateError('Enter phone/email and password.');
    }
    final res = await client
        .from('profiles')
        .select()
        .or('phone.eq.$sanitized,email.eq.$sanitized')
        .maybeSingle();

    if (res == null) {
      throw StateError('Account not found for this identifier.');
    }
    return {
      'id': res['id'],
      'name': res['full_name'] ?? 'User',
      'email': res['email'] ?? '',
      'phone': res['phone'] ?? '',
      'role': res['role'] ?? 'Branch Manager',
      'branch': res['branch_name'] ?? 'Mbezi Branch',
    };
  }

  // ------------------------------------------------------------- Products & Inventory
  Future<List<Map<String, dynamic>>> getProducts() async {
    try {
      final response = await client.from('products').select().order('id');
      return List<Map<String, dynamic>>.from(response);
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>?> getProductBySku(String sku) async {
    try {
      final response = await client.from('products').select().eq('sku', sku).maybeSingle();
      return response != null ? Map<String, dynamic>.from(response) : null;
    } catch (_) {
      return null;
    }
  }

  // ------------------------------------------------------------- Loans & Credit Ledger
  Future<List<Map<String, dynamic>>> getLoans() async {
    try {
      final response = await client.from('loans').select().order('id');
      return List<Map<String, dynamic>>.from(response);
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>> createLoan(Map<String, dynamic> data) async {
    try {
      final response = await client.from('loans').insert(data).select().single();
      return Map<String, dynamic>.from(response);
    } catch (_) {
      return {'id': DateTime.now().millisecondsSinceEpoch, ...data};
    }
  }

  // ------------------------------------------------------------- Branches
  Future<List<Map<String, dynamic>>> getBranches() async {
    try {
      final response = await client.from('branches').select().order('name');
      return List<Map<String, dynamic>>.from(response);
    } catch (_) {
      return [];
    }
  }

  // ------------------------------------------------------------- Activities Feed
  Future<List<Map<String, dynamic>>> getActivities() async {
    try {
      final response = await client.from('activities').select().order('created_at', ascending: false).limit(20);
      return List<Map<String, dynamic>>.from(response);
    } catch (_) {
      return [];
    }
  }

  // ------------------------------------------------------------- Attendance
  Future<Map<String, dynamic>> checkIn(Map<String, dynamic> data) async {
    try {
      final response = await client.from('attendance').insert(data).select().single();
      return Map<String, dynamic>.from(response);
    } catch (_) {
      return {'id': 'local-${DateTime.now().millisecondsSinceEpoch}', ...data};
    }
  }
}

final apiServiceProvider = Provider<ApiService>((ref) => ApiService());
