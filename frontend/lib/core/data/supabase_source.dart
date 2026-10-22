import '../constants/app_constants.dart';
import 'package:flutter/material.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/api_service.dart';
import 'branch_provider.dart';
import 'sales_provider.dart';
import 'mock_lims_data.dart';

/// Reads the app's rows out of Supabase.
///
/// The live database stores money as formatted text — `'3,850,000'`,
/// `'TZS 4.85M'` — so every financial value passes through [parseMoney] before it
/// reaches a provider. That is deliberately defensive: the column type is wrong
/// at the source, and a parser that only handles the happy path would silently
/// turn `'4.85M'` into 4.85 the first time a branch row is loaded.
///
/// Until the money columns are cast to numeric (see migration 2026_10_20_02),
/// this is the only safe way to read them.
class SupabaseSource {
  const SupabaseSource();

  bool get isConfigured => SupabaseConfig.isConfigured;

  /// Sales for the last [days] days. The home screen totals come from here, so a
  /// completed sale changes the numbers without a reload or a rebuild.
  static Future<List<SaleRecord>> fetchSales({int days = 60}) async {
    if (!SupabaseConfig.isConfigured) return const [];
    try {
      final client = Supabase.instance.client;
      final since = DateTime.now()
          .subtract(Duration(days: days))
          .toUtc()
          .toIso8601String();
      final rows = await client
          .from('sales')
          .select()
          .gte('sold_at', since)
          .order('sold_at', ascending: false);
      return (rows as List)
          .map((r) => SaleRecord.fromRow(Map<String, dynamic>.from(r)))
          .toList();
    } catch (e) {
      ApiService.lastBackendError = 'fetchSales: $e';
      debugPrint('LIMS: could not read sales -> $e');
      return const [];
    }
  }

  /// Writes one completed sale to `public.sales`.
  ///
  /// The till used to keep its sales in memory, so a printed receipt had no
  /// record behind it and the ledger started again on reload. This is the row
  /// that makes the receipt reproducible.
  ///
  /// Best effort on purpose: a sale that has already taken money must not be lost
  /// because the network blinked, so failures are recorded rather than thrown.
  static Future<bool> recordSale({
    required String receiptNo,
    required String kind,
    required int total,
    required int paid,
    required int balance,
    required String paymentChannel,
    required String customerName,
    required String customerPhone,
    required String phoneModel,
    String? imei,
    String? branchId,
    int? productId,
  }) async {
    if (!SupabaseConfig.isConfigured) return false;
    try {
      final client = Supabase.instance.client;
      await client.from('sales').insert({
        'receipt_no': receiptNo,
        'branch_id': branchId,
        'staff_id': null,
        'loan_id': null,
        'product_id': productId,
        'imei': imei,
        'customer_name': customerName,
        'customer_phone': customerPhone,
        'kind': kind,
        'total': total,
        'paid': paid,
        'balance': balance,
        'payment_channel': paymentChannel,
      });
      return true;
    } catch (e) {
      ApiService.lastBackendError = 'recordSale: $e';
      debugPrint('LIMS: could not record sale $receiptNo -> $e');
      return false;
    }
  }

  Future<SupabaseSnapshot> load() async {
    final api = ApiService();
    final results = await Future.wait([
      api.getProducts(),
      api.getLoans(),
      api.getBranches(),
      api.getActivities(),
      api.getStaff(),
    ]);

    return SupabaseSnapshot(
      products: _products(results[0]),
      loans: _loans(results[1]),
      branches: _branches(results[2]),
      activities: _activities(results[3]),
      staff: _staff(results[4]),
      error: ApiService.lastBackendError,
    );
  }

  /// `'3,850,000'` -> 3850000, `'TZS 4.85M'` -> 4850000, `3850000` -> 3850000.
  ///
  /// Returns 0 for anything unreadable rather than throwing: one malformed row
  /// should not blank the whole screen, and 0 is visibly wrong on a dashboard.
  static int parseMoney(dynamic raw) {
    if (raw == null) return 0;
    if (raw is int) return raw;
    if (raw is num) return raw.round();

    var s = raw.toString().trim().toUpperCase();
    if (s.isEmpty) return 0;

    var multiplier = 1;
    if (s.endsWith('B')) {
      multiplier = 1000000000;
      s = s.substring(0, s.length - 1);
    } else if (s.endsWith('M')) {
      multiplier = 1000000;
      s = s.substring(0, s.length - 1);
    } else if (s.endsWith('K')) {
      multiplier = 1000;
      s = s.substring(0, s.length - 1);
    }

    s = s.replaceAll(RegExp(r'[^0-9.\-]'), '');
    if (s.isEmpty) return 0;
    final value = double.tryParse(s);
    if (value == null) return 0;
    return (value * multiplier).round();
  }

  static List<Color> _gradient(dynamic start, dynamic end) {
    Color? parse(Object? v) {
      if (v is! String) return null;
      final hex = v.replaceAll('#', '').trim();
      if (hex.length != 6) return null;
      final value = int.tryParse(hex, radix: 16);
      return value == null ? null : Color(0xFF000000 | value);
    }

    final a = parse(start) ?? const Color(0xFF1B6EF3);
    final b = parse(end) ?? const Color(0xFF0A49B8);
    return [a, b];
  }

  List<ProductItem> _products(List<Map<String, dynamic>> rows) {
    return rows.map((r) {
      final stock = (r['stock'] as num?)?.toInt() ?? 0;
      final min = (r['min_stock'] as num?)?.toInt() ?? 0;
      return ProductItem(
        id: (r['id'] as num).toInt(),
        name: (r['name'] ?? '').toString(),
        variant: (r['variant'] ?? '').toString(),
        sku: (r['sku'] ?? '').toString(),
        price: parseMoney(r['price']),
        stock: stock,
        min: min,
        cat: (r['category'] ?? 'phones').toString(),
        grad: _gradient(r['gradient_start'], r['gradient_end']),
        status: (r['status'] ?? 'in').toString(),
        soldToday: (r['sold_today'] as num?)?.toInt() ?? 0,
        onLoan: (r['on_loan'] as num?)?.toInt() ?? 0,
        fav: r['is_favorite'] == true,
        brand: r['brand']?.toString(),
        imei1: r['imei1']?.toString(),
        imei2: r['imei2']?.toString(),
        costPrice: r['cost_price'] == null ? null : parseMoney(r['cost_price']),
        loanPrice: r['loan_price'] == null ? null : parseMoney(r['loan_price']),
        imageAsset: r['image_asset']?.toString(),
        imageUrl: r['image_url']?.toString(),
      );
    }).toList();
  }

  List<LoanItem> _loans(List<Map<String, dynamic>> rows) {
    const palette = <List<Color>>[
      [Color(0xFF6366F1), Color(0xFF8B5CF6)],
      [Color(0xFF0EA5E9), Color(0xFF2563EB)],
      [Color(0xFFF59E0B), Color(0xFFEF4444)],
    ];

    return rows.map((r) {
      final status = (r['status'] ?? 'current').toString();
      final amount = parseMoney(r['amount']);
      final deposit = r['deposit'] == null ? null : parseMoney(r['deposit']);
      final weeks = (r['installment_weeks'] as num?)?.toInt();

      return LoanItem(
        id: (r['id'] ?? '').toString(),
        name: (r['borrower_name'] ?? '').toString(),
        item: (r['item_name'] ?? '').toString(),
        amount: amount,
        paid: (r['paid_percent'] as num?)?.toInt() ?? 0,
        due: (r['due_info'] ?? '—').toString(),
        status: status,
        grad: palette[amount % palette.length],
        phone: r['phone']?.toString(),
        nida: r['nida']?.toString(),
        location: r['location']?.toString(),
        businessAddress: r['business_address']?.toString(),
        imei: r['imei']?.toString(),
        guarantorName: r['guarantor_name']?.toString(),
        guarantorPhone: r['guarantor_phone']?.toString(),
        guarantorRelation: r['guarantor_relation']?.toString(),
        isKnoxLocked: status == 'overdue',
        totalDeposit: deposit,
        weeklyInstallment:
            r['weekly_installment'] == null ? null : parseMoney(r['weekly_installment']),
        installmentWeeks: weeks,
      );
    }).toList();
  }

  /// Rows from `staff`, with the person's own portrait when the column is set.
  List<StaffMember> _staff(List<Map<String, dynamic>> rows) {
    return rows.map((r) {
      final role = UserRoles.normalize(r['role']?.toString());
      return StaffMember(
        id: (r['id'] ?? '').toString(),
        name: (r['name'] ?? '').toString(),
        role: role ?? UserRoles.pending,
        email: (r['email'] ?? '').toString(),
        phone: (r['phone'] ?? '').toString(),
        branch: (r['branch'] ?? r['branch_name'] ?? '').toString(),
        staffCode: (r['staff_code'] ?? r['code'] ?? '—').toString(),
        supervisorPin: (r['supervisor_pin'] ?? '').toString(),
        status: (r['status'] ?? 'Active').toString(),
        canDisburseLoans: r['can_disburse_loans'] == true,
        canKnoxLock: r['can_knox_lock'] == true,
        canViewMargins: r['can_view_margins'] == true,
        canEditStock: r['can_edit_stock'] == true,
        canApproveOverrides: r['can_approve_overrides'] == true,
        avatarAsset: r['avatar_asset']?.toString(),
        lastActive: (r['last_active'] ?? '—').toString(),
        grad: _gradient(r['gradient_start'], r['gradient_end']),
      );
    }).toList();
  }

  List<BranchRecord> _branches(List<Map<String, dynamic>> rows) {
    return rows.map((r) {
      final sales = parseMoney(r['sales']);
      final flagged = parseMoney(r['sales_today']);
      return BranchRecord(
        id: (r['id'] ?? '').toString(),
        name: (r['name'] ?? 'Branch').toString(),
        city: (r['city'] ?? '').toString(),
        salesToday: flagged > 0 ? flagged : sales,
        lowStock: (r['low_stock'] as num?)?.toInt() ?? 0,
        active: (r['status'] ?? 'green').toString() != 'closed',
      );
    }).toList();
  }

  List<ActivityItem> _activities(List<Map<String, dynamic>> rows) {
    IconData iconFor(String? name) {
      switch (name) {
        case 'payments':
          return Icons.payments_rounded;
        case 'inventory_2':
          return Icons.inventory_2_rounded;
        case 'person_add':
          return Icons.person_add_alt_1_rounded;
        case 'warning':
          return Icons.warning_amber_rounded;
        default:
          return Icons.bolt_rounded;
      }
    }

    Color colorFor(String? key) {
      switch (key) {
        case 'green':
          return const Color(0xFF10B981);
        case 'blue':
          return const Color(0xFF2563EB);
        case 'amber':
          return const Color(0xFFF59E0B);
        case 'red':
          return const Color(0xFFEF4444);
        default:
          return const Color(0xFF64748B);
      }
    }

    return rows.map((r) {
      final color = colorFor(r['color_key']?.toString());
      return ActivityItem(
        icon: iconFor(r['icon_name']?.toString()),
        iconColor: color,
        bgColor: color.withValues(alpha: 0.12),
        title: (r['title'] ?? '').toString(),
        description: (r['detail'] ?? '').toString(),
        time: (r['time_label'] ?? '').toString(),
      );
    }).toList();
  }
}

class SupabaseSnapshot {
  const SupabaseSnapshot({
    required this.products,
    required this.loans,
    required this.branches,
    required this.activities,
    this.staff = const [],
    this.error,
  });

  final List<ProductItem> products;
  final List<LoanItem> loans;
  final List<BranchRecord> branches;
  final List<ActivityItem> activities;
  final List<StaffMember> staff;
  final String? error;

  bool get isEmpty =>
      products.isEmpty && loans.isEmpty && branches.isEmpty && activities.isEmpty;
}
