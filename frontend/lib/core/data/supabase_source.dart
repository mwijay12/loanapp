import '../constants/app_constants.dart';
import 'package:flutter/material.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/api_service.dart';
import 'branch_provider.dart';
import 'sales_provider.dart';
import 'mock_lims_data.dart';
import 'sale_ledger.dart';
import 'petty_cash_provider.dart';

/// What the database did with a stock change.
///
/// `failed` and `unconfirmed` are different facts and must not share a word: the
/// first means the server refused and the row is untouched, the second means the
/// request left the device and no answer came back, so the number may already have
/// moved. A shop told "not saved" after an unconfirmed write enters the delivery
/// again and the stock ends up wrong in the other direction.
enum StockWriteStatus { saved, rejected, failed, unconfirmed, notConfigured }

class StockWrite {
  const StockWrite(this.status, {this.error, this.stock, this.previous});

  final StockWriteStatus status;
  final String? error;

  /// The stock Postgres agreed to hold, once the change landed.
  final int? stock;

  /// What the row said beforehand, so a screen can put its number back.
  final int? previous;

  bool get saved => status == StockWriteStatus.saved;
}

/// What the database did with a loan.
///
/// Same four answers as [StockWriteStatus], because the same distinction matters
/// most here: `unconfirmed` means the borrower may already be in the book, and
/// booking them twice doubles a debt.
enum LoanWriteStatus { saved, rejected, failed, unconfirmed, notConfigured }

class LoanWrite {
  const LoanWrite(this.status, {this.error, this.row});

  final LoanWriteStatus status;
  final String? error;

  /// The stored row, id included, once it exists.
  final Map<String, dynamic>? row;

  bool get saved => status == LoanWriteStatus.saved;
  int? get id => (row?['id'] as num?)?.toInt();
}

/// What the database did with a new catalogue row.
enum ProductWriteStatus {
  saved,

  /// The SKU was already on file, so the units went onto that product instead.
  duplicatedSku,
  rejected,
  failed,
  unconfirmed,
  notConfigured,
}

class ProductWrite {
  const ProductWrite(this.status, {this.product, this.message});

  final ProductWriteStatus status;

  /// The stored row, or the existing one when [ProductWriteStatus.duplicatedSku].
  final ProductItem? product;
  final String? message;

  bool get saved => status == ProductWriteStatus.saved;
  bool get restocked => status == ProductWriteStatus.duplicatedSku;
  bool get storedSomewhere => saved || restocked;
}

/// What the database said about a manager PIN.
///
/// The four states are not interchangeable at a counter:
///  * [granted] — a token that spends once within three minutes.
///  * [wrongPin] — the PIN did not match. The person may try again, and the
///    attempt is in `override_audit` as `pin_failed`.
///  * [locked] — five failures inside fifteen minutes. Trying more makes it
///    worse, so the message has to say stop, not "wrong PIN".
///  * [failed] — nothing to do with the PIN: no session, a role that may not set
///    one, a malformed PIN, or a server error.
enum ManagerOverrideStatus { granted, wrongPin, locked, failed, notConfigured }

@immutable
class ManagerOverride {
  const ManagerOverride(this.status, {this.token, this.error});

  final ManagerOverrideStatus status;

  /// The single-use uuid to put in `sales.override_token`.
  final String? token;
  final String? error;

  bool get isGranted => status == ManagerOverrideStatus.granted && token != null;

  /// A sentence for the person standing at the till.
  String get message => error ?? switch (status) {
        ManagerOverrideStatus.granted => 'Approved.',
        ManagerOverrideStatus.wrongPin =>
          'That PIN is not correct. The attempt was recorded.',
        ManagerOverrideStatus.locked =>
          'Too many wrong PINs. Overrides are locked for 15 minutes.',
        ManagerOverrideStatus.failed =>
          'The override could not be requested.',
        ManagerOverrideStatus.notConfigured =>
          'This build has no database, so no override was checked.',
      };
}

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
  /// It answers with [SaleLedgerWrite], not a bool. The old bool collapsed two
  /// different facts into `false`: "the server refused this row" and "the request
  /// went out and nothing came back". The first is safe to retry; the second may
  /// already be stored, and reporting it as a failure is how a handset gets sold
  /// twice. Nothing is thrown here; the caller decides what the counter is told.
  static Future<SaleLedgerWrite> recordSale({
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
    String? overrideToken,
  }) async {
    if (!SupabaseConfig.isConfigured) {
      return const SaleLedgerWrite(SalePersistence.notConfigured);
    }

    // Resolving the client is local work. If it fails, no request ever left the
    // device, so the row is definitely not stored and a retry cannot duplicate.
    final SupabaseQueryBuilder table;
    try {
      table = Supabase.instance.client.from('sales');
    } catch (e) {
      ApiService.lastBackendError = 'recordSale: $e';
      debugPrint('LIMS: no client for sale $receiptNo -> $e');
      return const SaleLedgerWrite(
        SalePersistence.failed,
        'The sale could not be sent because the database client is not ready.',
      );
    }

    try {
      await table.insert({
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
        // Null unless a Branch Manager typed their PIN for this very sale. The
        // INSERT policy calls manager_override_is_valid() on it, so a role that may
        // not sell is stopped by Postgres and not by this file. A forged uuid fails:
        // it is not in manager_overrides, and a spent one is gone.
        'override_token': overrideToken,
      });
      return const SaleLedgerWrite(SalePersistence.confirmed);
    } on PostgrestException catch (e) {
      // The database answered with an error status. The row is not there.
      ApiService.lastBackendError = 'recordSale: $e';
      debugPrint('LIMS: could not record sale $receiptNo -> $e');
      return SaleLedgerWrite(
        SalePersistence.failed,
        'The server refused the sale record (${e.code ?? 'no code'}): ${e.message}',
      );
    } catch (e) {
      // A timeout, a dropped socket, a proxy that answered nothing: the insert
      // may have committed before the answer went missing. Report the truth —
      // unknown — instead of inventing "not saved".
      ApiService.lastBackendError = 'recordSale: $e';
      debugPrint('LIMS: sale $receiptNo unconfirmed -> $e');
      return SaleLedgerWrite(
        SalePersistence.unconfirmed,
        'The sale was sent but the database did not confirm it. '
        'Check the sales ledger for receipt $receiptNo before ringing it up again.',
      );
    }
  }

  /// Writes `products.on_offer` for one handset.
  ///
  /// The column arrives with migration `2026_10_22_05_product_offers.sql`. Until
  /// that runs, PostgREST answers 42703 (undefined column) and nothing is saved —
  /// so this reports [OfferSaveOutcome.migrationMissing] instead of pretending
  /// the shop owner's choice stuck.
  static Future<OfferSaveOutcome> setProductOffer({
    required int productId,
    required bool onOffer,
  }) async {
    if (!SupabaseConfig.isConfigured) return OfferSaveOutcome.notConfigured;
    try {
      await Supabase.instance.client
          .from('products')
          .update({'on_offer': onOffer}).eq('id', productId);
      return OfferSaveOutcome.saved;
    } on PostgrestException catch (e) {
      ApiService.lastBackendError = 'setProductOffer: $e';
      debugPrint('LIMS: could not set offer on product $productId -> $e');
      if ((e.code ?? '') == '42703' || e.message.contains('on_offer')) {
        return OfferSaveOutcome.migrationMissing;
      }
      return OfferSaveOutcome.failed;
    } catch (e) {
      ApiService.lastBackendError = 'setProductOffer: $e';
      debugPrint('LIMS: could not set offer on product $productId -> $e');
      return OfferSaveOutcome.failed;
    }
  }

  /// Turns an RPC failure into one of the four honest answers.
  ///
  /// Pure on purpose: this is the only place the wording is decided, and it can be
  /// tested without a live project. The database raises with a fixed message and
  /// errcode (migration `2026_10_28_02_manager_override.sql`):
  /// `override_pin_locked` (42501), `override_no_session` / `override_role_forbidden`
  /// (42501), `override_pin_format` / `override_action_unknown` (22023).
  static ManagerOverride classifyOverrideFailure(Object error) {
    final text = error.toString();
    if (text.contains('override_pin_locked')) {
      return const ManagerOverride(
        ManagerOverrideStatus.locked,
        error:
            'Five wrong PINs in fifteen minutes. Overrides are locked for now — '
            'a Branch Manager can see the attempts in the override log.',
      );
    }
    if (text.contains('override_no_session')) {
      return const ManagerOverride(
        ManagerOverrideStatus.failed,
        error: 'The session is not recognised by the server, so no PIN was checked.',
      );
    }
    if (text.contains('override_role_forbidden')) {
      return const ManagerOverride(
        ManagerOverrideStatus.failed,
        error: 'This role cannot set an override PIN. Only a Branch Manager or Super Admin can.',
      );
    }
    if (text.contains('override_pin_format')) {
      return const ManagerOverride(
        ManagerOverrideStatus.failed,
        error: 'A PIN is 6 digits, numbers only.',
      );
    }
    if (text.contains('override_action_unknown')) {
      return const ManagerOverride(
        ManagerOverrideStatus.failed,
        error: 'Unknown override action: the server accepts a sale or a payment.',
      );
    }
    return ManagerOverride(
      ManagerOverrideStatus.failed,
      error: 'The server refused the request: ${text.replaceAll('PostgrestException:', '').trim()}',
    );
  }

  /// Asks a Branch Manager to authorise one action with their own PIN.
  ///
  /// This is the client half of the R9 gate. The PIN never touches a Dart
  /// comparison: it goes to `request_manager_override`, which checks it against
  /// `profiles.manager_pin_hash` with bcrypt and, on a match, returns a uuid that
  /// the INSERT policies accept once, for that action, for that staff member, for
  /// three minutes. A Storekeeper selling without it is refused **by the database**
  /// — the app cannot talk its way past that, which is the whole point.
  ///
  /// `p_pin` and `p_action` are the wire names. PostgREST resolves an RPC by
  /// parameter name, so `{'pin': ...}` answers `404 PGRST202` and every call looks
  /// like a missing function.
  static Future<ManagerOverride> requestManagerOverride({
    required String pin,
    String action = 'sale',
  }) async {
    if (!SupabaseConfig.isConfigured) {
      return const ManagerOverride(ManagerOverrideStatus.notConfigured);
    }
    // Fail before the request: five malformed guesses are all it takes to lock the
    // manager out for fifteen minutes, and a client-side format check costs nothing.
    if (pin.length != 6 || int.tryParse(pin) == null) {
      return const ManagerOverride(
        ManagerOverrideStatus.wrongPin,
        error: 'A PIN is 6 digits, numbers only.',
      );
    }

    try {
      final token = await Supabase.instance.client.rpc(
        'request_manager_override',
        params: {'p_pin': pin, 'p_action': action},
      );
      // A void-shaped uuid: the RPC returns null when the PIN did not match, and
      // it has already written the pin_failed row before doing so.
      if (token == null) {
        return const ManagerOverride(ManagerOverrideStatus.wrongPin);
      }
      return ManagerOverride(ManagerOverrideStatus.granted, token: token.toString());
    } on PostgrestException catch (e) {
      ApiService.lastBackendError = 'requestManagerOverride: $e';
      debugPrint('LIMS: override request refused -> ${e.code} ${e.message}');
      return classifyOverrideFailure(e.message);
    } catch (e) {
      ApiService.lastBackendError = 'requestManagerOverride: $e';
      debugPrint('LIMS: override request unconfirmed -> $e');
      return const ManagerOverride(
        ManagerOverrideStatus.failed,
        error:
            'The override request was sent but the server did not answer. '
            'Do not keep pressing: check the override log first.',
      );
    }
  }

  /// Stores a manager's own PIN. The server hashes it; this never sees a hash and
  /// never stores one on the device.
  static Future<ManagerOverride> setManagerPin({required String pin}) async {
    if (!SupabaseConfig.isConfigured) {
      return const ManagerOverride(ManagerOverrideStatus.notConfigured);
    }
    if (pin.length != 6 || int.tryParse(pin) == null) {
      return const ManagerOverride(
        ManagerOverrideStatus.failed,
        error: 'A PIN is 6 digits, numbers only.',
      );
    }
    try {
      await Supabase.instance.client
          .rpc('set_manager_pin', params: {'p_pin': pin});
      return const ManagerOverride(ManagerOverrideStatus.granted);
    } on PostgrestException catch (e) {
      ApiService.lastBackendError = 'setManagerPin: $e';
      debugPrint('LIMS: set PIN refused -> ${e.code} ${e.message}');
      return classifyOverrideFailure(e.message);
    } catch (e) {
      ApiService.lastBackendError = 'setManagerPin: $e';
      debugPrint('LIMS: set PIN unconfirmed -> $e');
      return const ManagerOverride(
        ManagerOverrideStatus.failed,
        error: 'The PIN was sent but the server did not confirm it. Try once more.',
      );
    }
  }

  /// The override log, newest first.
  ///
  /// `override_audit` cannot be written, changed or deleted by any client — that
  /// is what makes it worth showing. Profile uuids are resolved to names by the
  /// caller from the staff list it already has, because assuming an embedded
  /// resource here would mean assuming a foreign key that has not been verified.
  static Future<List<Map<String, dynamic>>> fetchOverrideAudit({int limit = 40}) async {
    if (!SupabaseConfig.isConfigured) return const [];
    try {
      final rows = await Supabase.instance.client
          .from('override_audit')
          .select('id, at, action, actor_profile, manager_profile, branch_name, target_table, target_id, detail')
          .order('at', ascending: false)
          .limit(limit);
      return (rows as List)
          .map((r) => Map<String, dynamic>.from(r as Map))
          .toList();
    } catch (e) {
      ApiService.lastBackendError = 'fetchOverrideAudit: $e';
      debugPrint('LIMS: could not read the override log -> $e');
      return const [];
    }
  }

  /// True when a loan of [amount] needs a manager standing at the counter.
  ///
  /// Pure, so the rule the till applies and the rule `loans_create` applies can be
  /// tested against the same number. The database's copy is
  /// `public.loan_override_threshold()`; if the two ever disagree the database wins,
  /// and this only decides whether to ask the manager before or after the refusal.
  static bool loanNeedsApproval(double amount, {double threshold = loanApprovalThreshold}) =>
      amount >= threshold;

  /// The amount in force in the database as of this writing. Kept as a named
  /// constant rather than scattered `1000000` literals so a change is one edit.
  static const double loanApprovalThreshold = 1000000;

  /// Books a loan. This is the credit book, so it is the one write that must not be
  /// simulated.
  ///
  /// Until now no code path inserted into `loans` at all: `ApiService.createLoan`
  /// existed with no callers and, on any error, returned
  /// `{'id': DateTime.now().millisecondsSinceEpoch, ...data}` — a fabricated row that
  /// looked like a saved borrower. A shop can survive losing a stock count for an
  /// afternoon; it cannot survive losing the record of who owes it money, and every
  /// "loan" taken on this build so far exists only in the memory of the device that
  /// rang it. The 16 rows in `loans` are all seed data from 15 October.
  ///
  /// A loan at or above [loanApprovalThreshold] is refused by the database unless
  /// [overrideToken] came from `request_manager_override` a moment ago — see
  /// migration `2026_10_29_02_loan_disbursement_gate.sql`.
  static Future<LoanWrite> createLoan({
    required String loanNo,
    required String borrowerName,
    String? borrowerPhone,
    String? nida,
    String? location,
    String? guarantorName,
    String? guarantorPhone,
    String? guarantorRelation,
    required String itemName,
    required double amount,
    required int paidPercent,
    required String dueInfo,
    double deposit = 0,
    double? weeklyInstallment,
    int? installmentWeeks,
    String? imei,
    String? branchId,
    String? overrideToken,
    String status = 'current',
  }) async {
    if (!SupabaseConfig.isConfigured) {
      return const LoanWrite(LoanWriteStatus.notConfigured);
    }
    if (borrowerName.trim().isEmpty || amount <= 0) {
      return const LoanWrite(LoanWriteStatus.rejected,
          error: 'A loan needs a borrower and a financed amount above zero.');
    }

    final values = <String, dynamic>{
      'loan_no': loanNo,
      'borrower_name': borrowerName.trim(),
      'item_name': itemName,
      'amount': amount,
      'paid_percent': paidPercent,
      'due_info': dueInfo,
      'status': status,
      'phone': borrowerPhone,
      'nida': nida,
      'location': location,
      'guarantor_name': guarantorName,
      'guarantor_phone': guarantorPhone,
      'guarantor_relation': guarantorRelation,
      'imei': (imei ?? '').trim().isEmpty ? null : imei!.trim(),
      'deposit': deposit,
      'weekly_installment': weeklyInstallment,
      'installment_weeks': installmentWeeks,
      'branch_id': branchId,
      'override_token': overrideToken,
    };

    final SupabaseQueryBuilder table;
    try {
      table = Supabase.instance.client.from('loans');
    } catch (e) {
      ApiService.lastBackendError = 'createLoan: $e';
      debugPrint('LIMS: no client for createLoan -> $e');
      return const LoanWrite(LoanWriteStatus.failed,
          error: 'The database client is not ready.');
    }

    try {
      final stored = await table.insert(values).select().single();
      debugPrint('LIMS: booked loan ${stored['id']} ${stored['borrower_name']} '
          '${stored['amount']}${overrideToken != null ? " (manager approved)" : ""}');
      return LoanWrite(LoanWriteStatus.saved, row: Map<String, dynamic>.from(stored));
    } on PostgrestException catch (e) {
      ApiService.lastBackendError = 'createLoan: $e';
      debugPrint('LIMS: could not book loan $loanNo -> $e');
      if ((e.code ?? '') == '42501') {
        // The policy refused. Two different reasons look identical from here —
        // amount over the threshold without a manager, and a role that may not
        // book loans at all — so say both rather than guessing.
        return const LoanWrite(
          LoanWriteStatus.rejected,
          error:
              'The server refused this loan. Either it is above the approval limit '
              'and needs a Branch Manager\'s PIN, or this role may not book loans.',
        );
      }
      if ((e.code ?? '') == '23505' && e.message.contains('loan_no')) {
        return LoanWrite(LoanWriteStatus.rejected,
            error: 'Loan $loanNo is already on file. Do not book it twice.');
      }
      return LoanWrite(LoanWriteStatus.failed,
          error:
              'The server refused the loan (${e.code ?? 'no code'}): ${e.message}');
    } catch (e) {
      ApiService.lastBackendError = 'createLoan: $e';
      debugPrint('LIMS: loan $loanNo unconfirmed -> $e');
      return const LoanWrite(
        LoanWriteStatus.unconfirmed,
        error:
            'The loan was sent but the database did not confirm it. Check the loan '
            'list before booking it again — a double booking is a double debt.',
      );
    }
  }

  /// Writes the two picture columns for one product.
  ///
  /// The photo editor used to call `InventoryNotifier.updateProductImage` and then
  /// toast "Picha ya ... imesasishwa kikamilifu!" — a success message for a change
  /// that lived in this isolate until the next reload. That is also half of why one
  /// product appeared to wear a different picture on a different screen: the picture
  /// the shop picked was never stored, so each surface fell back to whatever it
  /// chose for itself.
  ///
  /// Only a renderable value is sent. `ProductArt.samsung` and friends are Dart
  /// constant names, not files; storing one guarantees a runtime load failure and a
  /// per-screen substitute. Passing a symbolic name here clears the column instead,
  /// which is what lets the single [ProductArt] fallback apply everywhere.
  static Future<StockWrite> setProductImage({
    required int productId,
    String? imageAsset,
    String? imageUrl,
  }) async {
    if (!SupabaseConfig.isConfigured) {
      return const StockWrite(StockWriteStatus.notConfigured);
    }

    final asset = _realAssetPath(imageAsset);
    final url = (imageUrl ?? '').trim();
    // A picker can hand over both halves of a choice at once. One source per row is
    // the rule the catalogue is normalised to, so the asset wins and the URL goes.
    final values = <String, dynamic>{
      'image_asset': asset,
      'image_url': asset != null
          ? null
          : (url.startsWith('http') ? url : null),
    };

    final SupabaseQueryBuilder row;
    try {
      row = Supabase.instance.client.from('products');
    } catch (e) {
      ApiService.lastBackendError = 'setProductImage: $e';
      debugPrint('LIMS: no client for image on product $productId -> $e');
      return const StockWrite(StockWriteStatus.failed,
          error: 'The database client is not ready.');
    }

    try {
      await row.update(values).eq('id', productId);
      debugPrint('LIMS: product $productId image -> ${values['image_asset'] ?? values['image_url'] ?? '(cleared)'}');
      return const StockWrite(StockWriteStatus.saved);
    } on PostgrestException catch (e) {
      ApiService.lastBackendError = 'setProductImage: $e';
      debugPrint('LIMS: could not set image on product $productId -> $e');
      return StockWrite(StockWriteStatus.failed,
          error:
              'The server refused the picture (${e.code ?? 'no code'}): ${e.message}');
    } catch (e) {
      ApiService.lastBackendError = 'setProductImage: $e';
      debugPrint('LIMS: image write on $productId unconfirmed -> $e');
      return const StockWrite(
        StockWriteStatus.unconfirmed,
        error:
            'The picture was sent but the database did not confirm it. Reload before trying again.',
      );
    }
  }

  /// Adds units to, or takes them from, one product row.
  ///
  /// This is the write the stock screens never made. `InventoryNotifier.updateStock`
  /// moved the number in memory, the till said "Stock updated", and `products`
  /// still answered 166 the next time anything read it — which is exactly what the
  /// owner saw when he added 100 handsets and a refresh gave him 166 back.
  ///
  /// The caller describes the change the way the shop describes it ("+100",
  /// "-3"), never the number it hopes the row ends on, so the same mistake
  /// cannot come back: two screens that both pass a *total* into a parameter
  /// that is *added* produce 49 from 24 on the first click and 98 on the second.
  ///
  /// Read-then-write, not a raw `increment`: the row also carries `status`, which
  /// depends on the total. The cost is a race — a sale completing between the read
  /// and the write can be overwritten — so the honest follow-up is a
  /// `SECURITY DEFINER` RPC doing `stock = stock + p_qty` inside one statement.
  static Future<StockWrite> adjustStock({
    required int productId,
    required int delta,
    String? reason,
  }) async {
    if (!SupabaseConfig.isConfigured) {
      return const StockWrite(StockWriteStatus.notConfigured);
    }
    if (delta == 0) {
      return const StockWrite(StockWriteStatus.rejected,
          error: 'No quantity was given.');
    }

    try {
      // One statement in Postgres, so nothing is read, added and written back from
      // here. The previous version selected the row, computed `now + delta` in Dart
      // and PATCHed the sum: two movements in the same breath overwrote each other
      // and one of them vanished. `adjust_product_stock` also checks the roles the
      // `products_stock_write` policy checks, because SECURITY DEFINER walks past
      // RLS and the function would otherwise be a side door.
      final after = await Supabase.instance.client.rpc(
        'adjust_product_stock',
        params: {
          'p_product_id': productId,
          'p_delta': delta,
          'p_reason': reason,
        },
      );
      final stock = (after as num?)?.toInt();
      debugPrint('LIMS: product $productId adjusted by $delta -> $stock');
      return StockWrite(StockWriteStatus.saved, stock: stock);
    } on PostgrestException catch (e) {
      ApiService.lastBackendError = 'adjustStock: $e';
      debugPrint('LIMS: could not adjust stock on product $productId -> $e');
      return StockWrite(
        switch (e.code) {
          '42501' => StockWriteStatus.failed,
          'P0002' => StockWriteStatus.rejected,
          '22023' => StockWriteStatus.rejected,
          _ => StockWriteStatus.failed,
        },
        error: switch (e.message) {
          'stock_write_forbidden' =>
            'This role may not change stock. A Branch Manager or Storekeeper can.',
          'stock_product_unknown' =>
            'That product is not in the catalogue, so its stock cannot be changed.',
          'stock_delta_zero' => 'No quantity was given.',
          final other =>
            'The server refused the stock change (${e.code ?? 'no code'}): $other',
        },
      );
    } catch (e) {
      // The request may have committed with the answer lost. Saying "not saved" here
      // is how a delivery gets entered twice, so it gets its own status.
      ApiService.lastBackendError = 'adjustStock: $e';
      debugPrint('LIMS: stock adjust on $productId unconfirmed -> $e');
      return const StockWrite(
        StockWriteStatus.unconfirmed,
        error: 'The stock change was sent but the database did not confirm it. '
            'Check the stock list before saving it again.',
      );
    }
  }

  /// Writes the number a person is looking at on the shelf.
  ///
  /// This is the answer to "the database says 166 and the carton says 143". No
  /// replay of 47 old sales and no arithmetic can fix that; only a count can. The
  /// previous figure is kept in `product_history` as a `count` event, so the change
  /// has a name, a time and a reason next to it instead of looking like the
  /// database changed its mind.
  static Future<StockWrite> setStockCount({
    required int productId,
    required int stock,
    String? reason,
  }) async {
    if (!SupabaseConfig.isConfigured) {
      return const StockWrite(StockWriteStatus.notConfigured);
    }
    if (stock < 0) {
      return const StockWrite(StockWriteStatus.rejected,
          error: 'A counted quantity cannot be below zero.');
    }

    try {
      final after = await Supabase.instance.client.rpc(
        'set_product_stock',
        params: {
          'p_product_id': productId,
          'p_stock': stock,
          'p_reason': reason,
        },
      );
      final saved = (after as num?)?.toInt();
      debugPrint('LIMS: product $productId counted to $saved');
      return StockWrite(StockWriteStatus.saved, stock: saved);
    } on PostgrestException catch (e) {
      ApiService.lastBackendError = 'setStockCount: $e';
      debugPrint('LIMS: could not set the count on product $productId -> $e');
      return StockWrite(
        e.code == '42501' ? StockWriteStatus.failed : StockWriteStatus.rejected,
        error: switch (e.message) {
          'stock_write_forbidden' =>
            'This role may not record a count. A Branch Manager or Storekeeper can.',
          'stock_count_invalid' => 'A counted quantity cannot be below zero.',
          'stock_product_unknown' => 'That product is not in the catalogue.',
          final other =>
            'The server refused the count (${e.code ?? 'no code'}): $other',
        },
      );
    } catch (e) {
      ApiService.lastBackendError = 'setStockCount: $e';
      debugPrint('LIMS: count on $productId unconfirmed -> $e');
      return const StockWrite(
        StockWriteStatus.unconfirmed,
        error: 'The count was sent but the database did not confirm it. '
            'Look at the stock list before entering it again.',
      );
    }
  }

  /// Registers a new handset or accessory, and says what really happened.
  ///
  /// Every field the catalogue stores is sent. What the old code did was build a
  /// `ProductItem` with a made-up id (`millisecondsSinceEpoch % 10000`) and hand it
  /// to the provider, which put it at the front of a list in memory. Nothing was
  /// inserted, so `products` still held its twelve rows from 15 October and the
  /// refresh wiped the owner's new stock out.
  ///
  /// `sku` is UNIQUE in the database and the till builds it from brand, storage and
  /// colour, so the same model in the same finish collides on the second intake.
  /// A shop means "more of this one arrived" when it saves that again, so a
  /// collision restocks the existing row rather than reporting a failure — and
  /// [ProductWrite.duplicatedSku] exists so the screen can say that in words.
  static Future<ProductWrite> createProduct(ProductItem draft) async {
    if (!SupabaseConfig.isConfigured) {
      return const ProductWrite(ProductWriteStatus.notConfigured);
    }
    if (draft.name.trim().isEmpty || draft.price <= 0) {
      return const ProductWrite(ProductWriteStatus.rejected,
          message: 'A new product needs a name and a cash price above zero.');
    }

    // The row id belongs to Postgres (integer identity). The draft's id came from
    // the clock on this device, and `0` is what PostgREST reads as "assign one".
    final values = <String, dynamic>{
      'name': draft.name.trim(),
      'variant': draft.variant,
      'sku': draft.sku,
      'price': draft.price,
      'stock': draft.stock,
      'min_stock': draft.min,
      'category': draft.cat,
      'status': draft.status,
      'sold_today': draft.soldToday,
      'on_loan': draft.onLoan,
      'is_favorite': draft.fav,
      'gradient_start': _hex(draft.grad.first),
      'gradient_end': _hex(draft.grad.last),
      'brand': draft.brand,
      'imei1': draft.imei1,
      'imei2': draft.imei2,
      'cost_price': draft.costPrice,
      'loan_price': draft.loanPrice,
      // Symbolic art names (ProductArt.samsung) are not files, and a row storing
      // one renders differently on every screen that resolves it its own way. Only
      // a real asset path is worth storing.
      'image_asset': _realAssetPath(draft.imageAsset),
      'image_url': (draft.imageUrl ?? '').trim().isEmpty
          ? null
          : draft.imageUrl!.trim(),
    };

    final SupabaseQueryBuilder table;
    try {
      table = Supabase.instance.client.from('products');
    } catch (e) {
      ApiService.lastBackendError = 'createProduct: $e';
      debugPrint('LIMS: no client for createProduct -> $e');
      return const ProductWrite(ProductWriteStatus.failed,
          message: 'The database client is not ready.');
    }

    try {
      final stored = await table.insert(values).select().single();
      final saved = parseProductRow(stored);
      debugPrint('LIMS: created product ${saved.id} ${saved.name} stock ${saved.stock}');
      return ProductWrite(ProductWriteStatus.saved, product: saved);
    } on PostgrestException catch (e) {
      ApiService.lastBackendError = 'createProduct: $e';
      debugPrint('LIMS: could not create product ${draft.name} -> $e');

      final duplicate = (e.code ?? '') == '23505' ||
          e.message.contains('products_sku_key') ||
          e.message.contains('duplicate key');
      final bySku = duplicate ? await _rowBySku(draft.sku) : null;
      if (bySku != null) {
        if (draft.stock <= 0) {
          return ProductWrite(ProductWriteStatus.duplicatedSku, product: bySku);
        }
        final moved = await adjustStock(
          productId: bySku.id,
          delta: draft.stock,
        );
        if (moved.saved) {
          return ProductWrite(ProductWriteStatus.duplicatedSku,
              product: bySku.copyWith(stock: moved.stock),
              message: moved.error);
        }
        return ProductWrite(ProductWriteStatus.failed,
            message:
                'A product with SKU ${draft.sku} already exists and its stock could not be raised: '
                '${moved.error ?? 'the server refused the change'}');
      }
      if (duplicate) {
        return ProductWrite(ProductWriteStatus.failed,
            message:
                'SKU ${draft.sku} is already on file. Change the storage or colour, or add stock to the existing product instead.');
      }
      // A serial already registered under another model is a real answer, not a
      // form error to retry.
      if ((e.code ?? '') == '23505' && e.message.contains('imei1')) {
        return ProductWrite(ProductWriteStatus.failed,
            message:
                'IMEI ${draft.imei1} is already registered on another product.');
      }
      return ProductWrite(ProductWriteStatus.failed,
          message:
              'The server refused the new product (${e.code ?? 'no code'}): ${e.message}');
    } catch (e) {
      ApiService.lastBackendError = 'createProduct: $e';
      debugPrint('LIMS: createProduct unconfirmed -> $e');
      return const ProductWrite(
        ProductWriteStatus.unconfirmed,
        message:
            'The new product was sent but the database did not confirm it. '
            'Reload the stock list before saving it again.',
      );
    }
  }

  static Future<ProductItem?> _rowBySku(String sku) async {
    try {
      final row = await Supabase.instance.client
          .from('products')
          .select()
          .eq('sku', sku)
          .maybeSingle();
      return row == null ? null : parseProductRow(row);
    } catch (e) {
      debugPrint('LIMS: sku lookup for $sku failed -> $e');
      return null;
    }
  }

  /// Fetches petty cash expenses for the last [days] days.
  static Future<List<PettyCashRecord>> fetchPettyCash({int days = 60}) async {
    if (!SupabaseConfig.isConfigured) return const [];
    try {
      final client = Supabase.instance.client;
      final since = DateTime.now()
          .subtract(Duration(days: days))
          .toUtc()
          .toIso8601String();
      final rows = await client
          .from('petty_cash')
          .select()
          .gte('created_at', since)
          .order('created_at', ascending: false);
      return (rows as List)
          .map((r) => PettyCashRecord.fromRow(Map<String, dynamic>.from(r)))
          .toList();
    } catch (e) {
      ApiService.lastBackendError = 'fetchPettyCash: $e';
      debugPrint('LIMS: could not read petty cash -> $e');
      return const [];
    }
  }

  /// Records a new petty cash expense.
  static Future<bool> recordPettyCash({
    required int amount,
    required String category,
    String? description,
    String? branchId,
    String? staffId,
  }) async {
    if (!SupabaseConfig.isConfigured) return false;
    try {
      await Supabase.instance.client.from('petty_cash').insert({
        'amount': amount,
        'category': category,
        'description': description,
        'branch_id': branchId,
        'staff_id': staffId,
      });
      return true;
    } catch (e) {
      ApiService.lastBackendError = 'recordPettyCash: $e';
      debugPrint('LIMS: could not record petty cash -> $e');
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
      api.getPettyCash(),
    ]);

    return SupabaseSnapshot(
      products: parseProducts(results[0]),
      loans: parseLoans(results[1]),
      branches: parseBranches(results[2]),
      activities: parseActivities(results[3]),
      staff: parseStaff(results[4]),
      pettyCash: parsePettyCash(results[5]),
      error: ApiService.lastBackendError,
    );
  }

  List<PettyCashRecord> parsePettyCash(List<Map<String, dynamic>> rows) {
    return rows.map((r) => PettyCashRecord.fromRow(r)).toList();
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

  /// `Color(0xFF1B6EF3)` -> `'#1B6EF3'`, the format `products.gradient_*` holds.
  static String? _hex(Color? c) {
    if (c == null) return null;
    // `Color.value` is deprecated on Flutter 3.27+ in favour of the double
    // channels, but it is the one spelling that also compiles on the SDK this
    // project was built with, and nothing here depends on the alpha byte.
    // ignore: deprecated_member_use
    return '#${(c.value & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }

  /// A stored asset path, or null when the value is not one.
  ///
  /// Seven catalogue rows carry `ProductArt.samsung` and friends: a Dart class
  /// name, not a file. `Image.asset('ProductArt.samsung')` fails, and each screen
  /// then substitutes the artwork it picked itself — which is how one product ends
  /// up with several different pictures across the app. Storing the real path (or
  /// nothing, so the single ProductArt fallback applies) removes the disagreement.
  static String? _realAssetPath(String? raw) {
    final s = (raw ?? '').trim();
    if (s.isEmpty || s.startsWith('http')) return null;
    return s.startsWith('assets/') ? s : null;
  }

  List<ProductItem> parseProducts(List<Map<String, dynamic>> rows) {
    return rows.map(parseProductRow).toList();
  }

  /// One `products` row into the model the catalogue renders.
  ///
  /// Kept separate from [parseProducts] because a write returns exactly one row and
  /// the provider must be given the row Postgres actually stored — its id, its
  /// status, its sku — rather than the draft the form held.
  static ProductItem parseProductRow(Map<String, dynamic> r) {
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
      // Absent until migration 2026_10_22_05 runs; a missing key reads false
      // rather than failing the whole catalogue.
      onOffer: r['on_offer'] == true,
      brand: r['brand']?.toString(),
      imei1: r['imei1']?.toString(),
      imei2: r['imei2']?.toString(),
      branchId: r['branch_id']?.toString(),
      costPrice: r['cost_price'] == null ? null : parseMoney(r['cost_price']),
      loanPrice: r['loan_price'] == null ? null : parseMoney(r['loan_price']),
      imageAsset: r['image_asset']?.toString(),
      imageUrl: r['image_url']?.toString(),
    );
  }

  List<LoanItem> parseLoans(List<Map<String, dynamic>> rows) {
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
        dueDate: DateTime.tryParse((r['due_date'] ?? '').toString()),
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
  List<StaffMember> parseStaff(List<Map<String, dynamic>> rows) {
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

  List<BranchRecord> parseBranches(List<Map<String, dynamic>> rows) {
    return rows.map((r) {
      final sales = parseMoney(r['sales']);
      final flagged = parseMoney(r['sales_today']);
      return BranchRecord(
        id: (r['id'] ?? '').toString(),
        name: (r['name'] ?? 'Branch').toString(),
        city: (r['city'] ?? '').toString(),
        // Today means today. This used to fall back to the all-time `sales`
        // text when today was zero, which made every branch look like it had
        // taken money the moment the counter opened.
        salesToday: flagged,
        lowStock: (r['low_stock'] as num?)?.toInt() ?? 0,
        // The real column. Deriving it from `status` meant a branch could not be
        // dormant without also being painted a warning colour.
        active: (r['is_active'] as bool?) ?? true,
      );
    }).toList();
  }

  List<ActivityItem> parseActivities(List<Map<String, dynamic>> rows) {
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
        bgColor: color.withOpacity(0.12),
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
    this.pettyCash = const [],
    this.error,
  });

  final List<ProductItem> products;
  final List<LoanItem> loans;
  final List<BranchRecord> branches;
  final List<ActivityItem> activities;
  final List<StaffMember> staff;
  final List<PettyCashRecord> pettyCash;
  final String? error;

  bool get isEmpty =>
      products.isEmpty && loans.isEmpty && branches.isEmpty && activities.isEmpty && pettyCash.isEmpty;
}

/// The production [SaleLedger]: one row in `public.sales`, classified.
class SupabaseSaleLedger implements SaleLedger {
  const SupabaseSaleLedger();

  @override
  Future<SaleLedgerWrite> write({
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
    String? overrideToken,
  }) {
    return SupabaseSource.recordSale(
      receiptNo: receiptNo,
      kind: kind,
      total: total,
      paid: paid,
      balance: balance,
      paymentChannel: paymentChannel,
      customerName: customerName,
      customerPhone: customerPhone,
      phoneModel: phoneModel,
      imei: imei,
      branchId: branchId,
      productId: productId,
      overrideToken: overrideToken,
    );
  }
}

/// What happened to the "on offer" switch.
enum OfferSaveOutcome {
  /// `products.on_offer` was written.
  saved,

  /// No backend in this build: the choice lives in memory for this session only.
  notConfigured,

  /// The column does not exist yet — the SQL migration has not been run.
  migrationMissing,

  /// The write was attempted and failed.
  failed,
}
