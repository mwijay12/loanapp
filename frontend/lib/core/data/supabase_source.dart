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
  }) async {
    if (!SupabaseConfig.isConfigured) {
      return const StockWrite(StockWriteStatus.notConfigured);
    }
    if (delta == 0) {
      return const StockWrite(StockWriteStatus.rejected,
          error: 'No quantity was given.');
    }

    final SupabaseQueryBuilder row;
    try {
      row = Supabase.instance.client.from('products');
    } catch (e) {
      ApiService.lastBackendError = 'adjustStock: $e';
      debugPrint('LIMS: no client for stock adjust $productId -> $e');
      return const StockWrite(StockWriteStatus.failed,
          error: 'The database client is not ready.');
    }

    try {
      final current = await row
          .select('stock, min_stock')
          .eq('id', productId)
          .maybeSingle();
      if (current == null) {
        return StockWrite(StockWriteStatus.rejected,
            error:
                'Product $productId is not in the catalogue, so its stock cannot be changed.');
      }

      final now = (current['stock'] as num?)?.toInt() ?? 0;
      final min = (current['min_stock'] as num?)?.toInt() ?? 0;
      final next = now + delta;
      if (next < 0) {
        return StockWrite(
          StockWriteStatus.rejected,
          error:
              'Only $now unit${now == 1 ? '' : 's'} of that product are on hand, so ${-delta} cannot be removed.',
        );
      }

      await row.update({
        'stock': next,
        'status': next <= 0 ? 'out' : (next <= min ? 'low' : 'in'),
      }).eq('id', productId);

      debugPrint('LIMS: product $productId stock $now -> $next (delta $delta)');
      return StockWrite(StockWriteStatus.saved, stock: next, previous: now);
    } on PostgrestException catch (e) {
      ApiService.lastBackendError = 'adjustStock: $e';
      debugPrint('LIMS: could not adjust stock on product $productId -> $e');
      return StockWrite(StockWriteStatus.failed,
          error:
              'The server refused the stock change (${e.code ?? 'no code'}): ${e.message}');
    } catch (e) {
      // Same distinction recordSale makes: the request may have committed and the
      // answer gone missing. Saying "not saved" here is how a delivery gets
      // entered twice.
      ApiService.lastBackendError = 'adjustStock: $e';
      debugPrint('LIMS: stock adjust on $productId unconfirmed -> $e');
      return const StockWrite(
        StockWriteStatus.unconfirmed,
        error:
            'The stock change was sent but the database did not confirm it. '
            'Check the stock list before saving it again.',
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
        salesToday: flagged > 0 ? flagged : sales,
        lowStock: (r['low_stock'] as num?)?.toInt() ?? 0,
        active: (r['status'] ?? 'green').toString() != 'closed',
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
