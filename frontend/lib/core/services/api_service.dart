import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/app_constants.dart';
import '../data/store_movement.dart';

/// Supabase Backend Configuration for LIMS
/// Organization: fzlykkwgkydswvnlryhk
/// Lead Architect: David Erick Mwijage (mwijay12)
class SupabaseConfig {
  // Injected at build time: flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
  // Never hardcode JWTs in source - use CI secrets / local --dart-define.
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY');

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
    if (SupabaseConfig.supabaseUrl.isEmpty ||
        SupabaseConfig.supabaseAnonKey.isEmpty) {
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
        _report('backend call', e);
      }
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
      _report('backend call', e);
    }
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
        'avatar': null,
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
      'branch': (res == null ? null : res['branch_name'] as String?) ??
          AppConstants.launchBranch,
      // The person's chosen portrait, so the header draws them and not a
      // role placeholder.
      'avatar': res == null ? null : res['avatar_asset'] as String?,
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

  /// Who owns this handset right now, from the two tables that record a serial.
  ///
  /// A scanned IMEI is either still in stock (`products.imei1`) or already out on
  /// a hire-purchase contract (`loans.imei1`). There is no third answer: if
  /// neither row exists the device was never received through this system, and
  /// the screen says so instead of inventing a model and a price.
  Future<ImeiLookup> findUnitByImei(String imei) async {
    try {
      // A serialised handset answers for itself: this row is the physical phone,
      // so its status beats whatever the model-level stock says.
      final unit = await client
          .from('product_units')
          .select()
          .eq('imei', imei)
          .maybeSingle();

      if (unit != null) {
        return ImeiLookup(
          imei: imei,
          status: (unit['status'] as String?) ?? 'in_stock',
          row: unit,
        );
      }

      final product = await client
          .from('products')
          .select()
          .eq('imei1', imei)
          .maybeSingle();

      if (product != null) {
        return ImeiLookup(imei: imei, status: 'in_stock', row: product);
      }

      final loan =
          await client.from('loans').select().eq('imei', imei).maybeSingle();

      if (loan != null) {
        final overdue = (loan['status'] as String?) == 'overdue';
        return ImeiLookup(
          imei: imei,
          status: overdue ? 'overdue' : 'on_loan',
          row: loan,
        );
      }

      return ImeiLookup(imei: imei, status: 'unknown');
    } catch (e) {
      _report('backend call', e);
      return ImeiLookup(imei: imei, status: 'unknown');
    }
  }

  Future<Map<String, dynamic>?> getProductBySku(String sku) async {
    try {
      final response =
          await client.from('products').select().eq('sku', sku).maybeSingle();
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
      final response =
          await client.from('loans').insert(data).select().single();
      return Map<String, dynamic>.from(response);
    } catch (e) {
      _report('backend call', e);
      return {'id': DateTime.now().millisecondsSinceEpoch, ...data};
    }
  }

  Future<List<Map<String, dynamic>>> getSales() async {
    try {
      final response = await client
          .from('sales')
          .select()
          .order('sold_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      _report('backend call', e);
      return [];
    }
  }

  /// Every handset physically present at one branch.
  ///
  /// Branch stock is not a number on the product row: `products.stock` is the
  /// company total. What is at Mbagala is the set of serials whose `product_units.branch`
  /// says so, which is the only claim the shop can defend when a customer asks.
  Future<List<Map<String, dynamic>>> listStockUnits(String branch) async {
    if (!isConfigured) return [];
    try {
      final rows = await client
          .from('product_units')
          .select()
          .eq('branch', branch)
          .eq('status', 'in_stock')
          .order('received_at');
      return List<Map<String, dynamic>>.from(rows);
    } catch (e) {
      _report('list stock units', e);
      return [];
    }
  }

  /// Handsets held at one branch in the given [statuses].
  ///
  /// `listStockUnits` above only asks for `in_stock`, so a Storekeeper wanting
  /// to know which of *his* handsets are physically outside the shop had no
  /// query to make. `product_units` is readable by every authenticated role
  /// (2026_10_22_08_product_units.sql:93-98), which is why custody can be shown
  /// to a Storekeeper while the borrower's identity in `loans` cannot.
  ///
  /// Returns the raw rows on purpose: the caller needs `imei`, `model`, `status`
  /// and `received_at`, and a screen that has to import a realtime or supabase
  /// type to read a shelf cannot be tested without a socket.
  ///
  /// There is no `product_name` column on this table — the description of a
  /// handset is `model`, verified against information_schema before this was
  /// written, because a select naming a column that does not exist does not
  /// crash: it is caught below and returns an empty shelf.
  Future<List<Map<String, dynamic>>> listBranchUnits({
    required String branch,
    required List<String> statuses,
    int limit = 200,
  }) async {
    if (!isConfigured || statuses.isEmpty) return [];
    try {
      final rows = await client
          .from('product_units')
          .select('id, imei, sku, model, status, branch, received_at')
          .eq('branch', branch)
          .inFilter('status', statuses)
          .order('received_at', ascending: false)
          .limit(limit);
      return List<Map<String, dynamic>>.from(rows);
    } catch (e) {
      _report('branch units', e);
      return [];
    }
  }

  /// What arrived at one branch since [since], counted from the delivery and
  /// serial ledgers.
  ///
  /// The dashboard used to print "14 IMEIs added · 2 POs" because the design
  /// said so. A shop that received nothing today must read zero, and a build
  /// with no database must say so instead of implying an empty day.
  Future<StoreDayCounts> getStoreDayCounts({
    required String branch,
    required DateTime since,
  }) async {
    if (!isConfigured) return const StoreDayCounts.unavailable();
    final iso = since.toUtc().toIso8601String();
    try {
      final receipts = await client
          .from('stock_receipts')
          .select('id, source')
          .eq('branch', branch)
          .gte('received_at', iso);
      final units = await client
          .from('product_units')
          .select('id')
          .eq('branch', branch)
          .gte('received_at', iso);

      final receiptRows = List<Map<String, dynamic>>.from(receipts);
      return StoreDayCounts(
        serialsAdded: List<Map<String, dynamic>>.from(units).length,
        deliveries: receiptRows.length,
        purchaseOrders:
            receiptRows.where((r) => r['source'] == 'supplier').length,
        available: true,
      );
    } catch (e) {
      _report('store day counts', e);
      return const StoreDayCounts.unavailable();
    }
  }

  /// The latest deliveries at one branch, newest first, with their lines.
  ///
  /// Lines are fetched separately rather than through an embedded select so a
  /// branch with no lines still reads as an empty day instead of an error.
  Future<List<StockMovement>> getRecentStoreMovements({
    required String branch,
    int limit = 6,
  }) async {
    if (!isConfigured) return const [];
    try {
      final rows = await client
          .from('stock_receipts')
          .select(
              'id, branch, source, units, supplier_name, invoice_no, from_branch, received_at')
          .eq('branch', branch)
          .order('received_at', ascending: false)
          .limit(limit);
      final receipts = List<Map<String, dynamic>>.from(rows);
      if (receipts.isEmpty) return const [];

      final ids = receipts.map((r) => r['id']).toList();
      final lineRows = await client
          .from('stock_receipt_lines')
          .select('receipt_id, sku, name, qty')
          .inFilter('receipt_id', ids);

      final byReceipt = <dynamic, List<StockMovementLine>>{};
      for (final l in List<Map<String, dynamic>>.from(lineRows)) {
        final key = l['receipt_id'];
        byReceipt.putIfAbsent(key, () => []).add(StockMovementLine(
              name: (l['name'] ?? '').toString(),
              qty: (l['qty'] as num?)?.toInt() ?? 0,
              sku: l['sku']?.toString(),
            ));
      }

      return [
        for (final r in receipts)
          StockMovement(
            id: (r['id'] as num?)?.toInt() ?? 0,
            branch: (r['branch'] ?? '').toString(),
            source: (r['source'] ?? '').toString(),
            units: (r['units'] as num?)?.toInt() ?? 0,
            receivedAt: DateTime.tryParse((r['received_at'] ?? '').toString())
                ?.toLocal(),
            supplierName: r['supplier_name']?.toString(),
            fromBranch: r['from_branch']?.toString(),
            invoiceNo: r['invoice_no']?.toString(),
            lines: byReceipt[r['id']] ?? const [],
          ),
      ];
    } catch (e) {
      _report('recent stock movements', e);
      rethrow;
    }
  }

  /// Moves handsets to another branch and records the movement.
  ///
  /// An internal transfer does not change how many phones the company owns, so
  /// `products.stock` is deliberately untouched - the old screen decremented it,
  /// which quietly wrote off stock every time a unit changed shops.
  ///
  /// Returns the receipt id, or null when nothing moved.
  Future<int?> transferUnits({
    required List<String> imeis,
    required String from,
    required String to,
    String? note,
  }) async {
    if (!isConfigured || imeis.isEmpty) return null;

    final now = DateTime.now().toUtc().toIso8601String();
    try {
      final units = await client
          .from('product_units')
          .select()
          .inFilter('imei', imeis)
          .eq('branch', from)
          .eq('status', 'in_stock');

      final rows = List<Map<String, dynamic>>.from(units);
      if (rows.isEmpty) {
        lastBackendError = 'No matching units at $from.';
        return null;
      }

      final receipt = await client
          .from('stock_receipts')
          .insert({
            'branch': to,
            'source': 'transfer',
            'from_branch': from,
            'units': rows.length,
            'note': note,
            'received_at': now,
          })
          .select('id')
          .single();

      final receiptId = receipt['id'];

      // Lines by model, so the receiving branch sees what arrived.
      final byModel = <String, int>{};
      for (final r in rows) {
        final model = (r['model'] as String?)?.trim();
        final key =
            (model == null || model.isEmpty) ? 'Unspecified handset' : model;
        byModel[key] = (byModel[key] ?? 0) + 1;
      }
      await client.from('stock_receipt_lines').insert([
        for (final e in byModel.entries)
          {
            'receipt_id': receiptId,
            'name': e.key,
            'qty': e.value,
            'unit_cost': 0,
          },
      ]);

      await client
          .from('product_units')
          .update({'branch': to, 'receipt_id': receiptId, 'updated_at': now})
          .inFilter('imei', rows.map((r) => r['imei']).toList())
          .eq('branch', from);

      return receiptId as int;
    } catch (e) {
      _report('transfer units', e);
      return null;
    }
  }

  /// Writes the scanned serials so the shop can answer "where is this handset?"
  ///
  /// One row per IMEI in `product_units`, one row for the delivery in
  /// `stock_receipts`. Returns how many serials were stored; a partial write is
  /// reported rather than rounded up to success.
  Future<int> recordUnits({
    required List<String> imeis,
    required String branch,
    required String source,
    required List<Map<String, dynamic>> lines,
    String? supplier,
    String? invoiceNo,
  }) async {
    if (!isConfigured || imeis.isEmpty) return 0;
    final now = DateTime.now().toUtc().toIso8601String();
    try {
      final receipt = await client
          .from('stock_receipts')
          .insert({
            'branch': branch,
            'source': source,
            'supplier_name': supplier,
            'invoice_no': invoiceNo,
            'units': imeis.length,
            'received_at': now,
          })
          .select('id')
          .single();

      final receiptId = receipt['id'];

      // The lines say what the delivery contained; without them the receipt is a
      // count with no memory of which models it covered.
      if (lines.isNotEmpty) {
        try {
          await client.from('stock_receipt_lines').insert([
            for (final l in lines) {...l, 'receipt_id': receiptId},
          ]);
        } catch (e) {
          _report('stock receipt lines', e);
        }
      }

      var stored = 0;
      for (final imei in imeis) {
        try {
          await client.from('product_units').insert({
            'imei': imei,
            'branch': branch,
            'receipt_id': receiptId,
            'status': 'in_stock',
            'received_at': now,
          });
          stored++;
        } catch (e) {
          // A unique-constraint hit means this serial is already on file; that is
          // a duplicate, not a failure of the whole delivery.
          _report('backend call', e);
        }
      }
      return stored;
    } catch (e) {
      _report('backend call', e);
      return 0;
    }
  }

  /// Adds received units to a product, and says whether the row really moved.
  ///
  /// Receiving used to call `updateStock(1..4)` on the local provider with product
  /// ids that do not exist in the database, then report success. The count on screen
  /// went up and the row in `products` did not change. This reads the current stock,
  /// writes the sum, and returns false when the database did not answer.
  Future<bool> addStock({required int productId, required int quantity}) async {
    if (quantity <= 0) return false;
    try {
      final row = await client
          .from('products')
          .select('stock, min_stock')
          .eq('id', productId)
          .maybeSingle();
      if (row == null) return false;

      final current = (row['stock'] as num?)?.toInt() ?? 0;
      final min = (row['min_stock'] as num?)?.toInt() ?? 0;
      final next = current + quantity;

      await client.from('products').update({
        'stock': next,
        'status': next <= min ? 'low' : 'in',
      }).eq('id', productId);
      return true;
    } catch (e) {
      _report('backend call', e);
      return false;
    }
  }

  bool get isConfigured => SupabaseConfig.isConfigured;

  Future<List<Map<String, dynamic>>> getStaff() async {
    try {
      final response = await client.from('staff').select().order('name');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      _report('backend call', e);
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getPettyCash() async {
    try {
      final response = await client.from('petty_cash').select().order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      _report('backend call', e);
      return [];
    }
  }

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
      final response = await client
          .from('activities')
          .select()
          .order('created_at', ascending: false)
          .limit(20);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      _report('backend call', e);
      return [];
    }
  }

  // ------------------------------------------------------------- Attendance
  Future<Map<String, dynamic>> checkIn(Map<String, dynamic> data) async {
    try {
      final response =
          await client.from('attendance').insert(data).select().single();
      return Map<String, dynamic>.from(response);
    } catch (e) {
      _report('backend call', e);
      return {'id': 'local-${DateTime.now().millisecondsSinceEpoch}', ...data};
    }
  }
}

final apiServiceProvider = Provider<ApiService>((ref) => ApiService());

/// The result of asking the database about one serial number.
class ImeiLookup {
  const ImeiLookup({required this.imei, required this.status, this.row});

  final String imei;

  /// `in_stock`, `on_loan`, or `unknown`.
  final String status;

  /// The raw row, so the screen can show the model and price it actually holds.
  final Map<String, dynamic>? row;

  bool get isKnown => status != 'unknown';

  String get model =>
      (row?['name'] ?? row?['model'] ?? row?['phone_model'] ?? '') as String;
}
