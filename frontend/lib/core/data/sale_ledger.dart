import 'package:flutter/foundation.dart';

/// What the ledger actually said about a sale.
///
/// Three answers, not two, because "it did not work" and "I do not know" are
/// different facts and the counter must act on them differently. A write that
/// timed out may well have landed, and reporting that as a plain failure would
/// invite the cashier to ring the same handset up twice.
///
/// What the database does about a duplicate: the repository migrations declare
/// `sales.receipt_no` as `text unique not null`
/// (`backend/supabase/migrations/2026_10_21_02c_sales.sql`,
/// `2026_10_20_02_money_and_loan_fields.sql`). That is a statement about the
/// migration files only — the deployed project's actual index has not been
/// verified from here — and it would not catch a resend in any case, because
/// every attempt mints a fresh receipt number, so a retry lands as a second row
/// rather than as a duplicate key. The only protection against that is the
/// cashier checking the ledger before ringing the sale up again.
enum SalePersistence {
  /// `public.sales` confirmed the row. This is the only state a receipt or a PDF
  /// may be produced from: [POSSaleResult.isSaved] means exactly this, and
  /// `PdfReportService.generateAndDownloadSaleReceipt` refuses everything else.
  confirmed,

  /// The build has no Supabase configuration, so there is no ledger to write to
  /// (demo and offline builds). **No database write occurred**: nothing was
  /// saved, and nothing claims it was. The workflow still treats the sale as
  /// locally complete — [POSSaleResult.success] is true for it — but
  /// [POSSaleResult.isSaved] is false, so it cannot produce a receipt.
  notConfigured,

  /// The server answered and refused. Nothing was stored; retrying is safe.
  failed,

  /// The request was sent and no usable answer came back. The row may exist.
  /// Never report this as "not recorded", and never resend it automatically.
  unconfirmed,

  /// The sale was kept on this device because no answer came back, and will be
  /// sent again under the same `client_ref`. The money is in the drawer and the
  /// handset left the shelf, so the counter treats it as sold; it is not in the
  /// ledger yet, so no receipt may be printed from it.
  queued,
}

/// The outcome of one attempt to write a sale, plus the sentence a cashier can
/// act on.
@immutable
class SaleLedgerWrite {
  const SaleLedgerWrite(this.status, [this.message]);

  final SalePersistence status;
  final String? message;

  bool get isConfirmed => status == SalePersistence.confirmed;

  /// The server answered "no". Retrying cannot duplicate anything.
  bool get isRefused => status == SalePersistence.failed;

  /// The write may or may not exist. A retry here is the one that duplicates.
  bool get isUnknown => status == SalePersistence.unconfirmed;
}

/// The single thing a completed sale needs from the network: store the row.
///
/// This is a seam, not a new architecture. Production uses
/// [SupabaseSaleLedger], which is the same `SupabaseSource.recordSale` call the
/// till made before; a test can answer "stored", "refused" or "no answer"
/// without a live project and without touching demo data.
abstract class SaleLedger {
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
    String? clientRef,
  });
}

/// One-shot latch around a sale submission.
///
/// The till pops its review sheet before awaiting the write, so for a moment the
/// confirm button is gone and the underlying primary button is the only target
/// left. A second tap there used to start a second sale. The guard refuses the
/// second entry, and it is released on both the success and the failure path.
///
/// This is tap protection in one client. It is not idempotency: two devices, or
/// a re-send after an [SalePersistence.unconfirmed] write, can still produce two
/// rows, because the guard is not shared between devices and because a retry
/// mints a new receipt number — the `text unique not null` constraint declared
/// in the migrations cannot recognise the second row as a repeat.
class SaleSubmitGuard {
  bool _inFlight = false;

  bool get isInFlight => _inFlight;

  /// Returns true when this caller owns the submission and must [release] it.
  bool tryBegin() {
    if (_inFlight) return false;
    _inFlight = true;
    return true;
  }

  void release() => _inFlight = false;
}
