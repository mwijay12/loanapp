import 'package:flutter_riverpod/flutter_riverpod.dart';

// API Service - Ready for Supabase integration
// Currently uses mock data, can be replaced with Supabase calls

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  Future<void> init() async {
    // TODO: Initialize Supabase
    // await SupabaseService.init();
    _isInitialized = true;
  }

  // Auth
  Future<Map<String, dynamic>> login(String email, String password) async {
    // TODO: Replace with Supabase auth
    // return await SupabaseService.signIn(email, password);
    await Future.delayed(const Duration(seconds: 1));
    return {
      'id': '1',
      'name': 'John',
      'email': email,
      'role': 'Branch Manager',
      'branch': 'Kariakoo Branch',
    };
  }

  // Phones
  Future<List<Map<String, dynamic>>> getPhones() async {
    // TODO: Replace with Supabase query
    // return await SupabaseService.getPhones();
    return [];
  }

  Future<Map<String, dynamic>?> getPhoneByImei(String imei) async {
    // TODO: Replace with Supabase query
    // return await SupabaseService.getPhoneByImei(imei);
    return null;
  }

  // Sales
  Future<Map<String, dynamic>> createSale(Map<String, dynamic> data) async {
    // TODO: Replace with Supabase insert
    // return await SupabaseService.createSale(data);
    return {'id': '1', ...data};
  }

  // Loans
  Future<Map<String, dynamic>> createLoan(Map<String, dynamic> data) async {
    // TODO: Replace with Supabase insert
    // return await SupabaseService.createLoan(data);
    return {'id': '1', ...data};
  }

  // Attendance
  Future<Map<String, dynamic>> checkIn(Map<String, dynamic> data) async {
    // TODO: Replace with Supabase insert
    // return await SupabaseService.checkIn(data);
    return {'id': '1', ...data};
  }

  // Notifications
  Future<List<Map<String, dynamic>>> getNotifications() async {
    // TODO: Replace with Supabase query
    // return await SupabaseService.getNotifications();
    return [];
  }
}

final apiServiceProvider = Provider<ApiService>((ref) => ApiService());
