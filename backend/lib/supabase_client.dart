import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  // Injected at build time via --dart-define. No hardcoded keys in repo.
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
}

class SupabaseService {
  static SupabaseClient? _client;

  static SupabaseClient get client {
    if (_client == null) {
      throw Exception('Supabase not initialized. Call init() first.');
    }
    return _client!;
  }

  static Future<void> init() async {
    await Supabase.initialize(
      url: SupabaseConfig.supabaseUrl,
      anonKey: SupabaseConfig.supabaseAnonKey,
    );
    _client = Supabase.instance.client;
  }

  // Auth
  static Future<AuthResponse> signIn(String email, String password) async {
    return await client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  static Future<void> signOut() async {
    await client.auth.signOut();
  }

  // Branches
  static Future<List<Map<String, dynamic>>> getBranches() async {
    final response = await client.from('branches').select();
    return List<Map<String, dynamic>>.from(response);
  }

  // Phones
  static Future<List<Map<String, dynamic>>> getPhones({String? branchId}) async {
    var query = client.from('phones').select();
    if (branchId != null) {
      query = query.eq('branch_id', branchId);
    }
    final response = await query;
    return List<Map<String, dynamic>>.from(response);
  }

  static Future<Map<String, dynamic>?> getPhoneByImei(String imei) async {
    final response = await client
        .from('phones')
        .select()
        .eq('imei', imei)
        .maybeSingle();
    return response != null ? Map<String, dynamic>.from(response) : null;
  }

  // Sales
  static Future<Map<String, dynamic>> createSale(Map<String, dynamic> data) async {
    final response = await client.from('sales').insert(data).select().single();
    return Map<String, dynamic>.from(response);
  }

  // Loans
  static Future<Map<String, dynamic>> createLoan(Map<String, dynamic> data) async {
    final response = await client.from('loans').insert(data).select().single();
    return Map<String, dynamic>.from(response);
  }

  // Attendance
  static Future<Map<String, dynamic>> checkIn(Map<String, dynamic> data) async {
    final response = await client.from('attendance').insert(data).select().single();
    return Map<String, dynamic>.from(response);
  }

  // Daily Closing
  static Future<Map<String, dynamic>> createDailyClosing(Map<String, dynamic> data) async {
    final response = await client.from('daily_closing').insert(data).select().single();
    return Map<String, dynamic>.from(response);
  }

  // Notifications
  static Future<List<Map<String, dynamic>>> getNotifications({String? branchId}) async {
    var query = client.from('notifications').select().order('created_at', ascending: false);
    if (branchId != null) {
      query = query.eq('branch_id', branchId);
    }
    final response = await query.limit(50);
    return List<Map<String, dynamic>>.from(response);
  }
}
