import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import 'mock_lims_data.dart';
import 'branch_provider.dart';
import 'inventory_provider.dart';
import 'sales_provider.dart';
import 'sale_ledger.dart';
import 'supabase_source.dart';

/// Representation of an installment schedule item for loans
@immutable
class InstallmentScheduleItem {
  final int installmentNumber;
  final DateTime dueDate;
  final int amount;
  final String status; // 'pending', 'paid', 'overdue'

  const InstallmentScheduleItem({
    required this.installmentNumber,
    required this.dueDate,
    required this.amount,
    this.status = 'pending',
  });

  String get formattedDueDate {
    return '${dueDate.day.toString().padLeft(2, '0')}/${dueDate.month.toString().padLeft(2, '0')}/${dueDate.year}';
  }
}

/// Transparent Loan Quotation Breakdown
@immutable
class LoanQuote {
  final int cashPrice;
  final int loanPrice;
  final int minimumDeposit;
  final int downPayment;
  final int financedAmount;
  final int financeFee;
  final int totalRepayable;
  final int tenureWeeks;
  final int weeklyInstallment;
  final List<InstallmentScheduleItem> schedule;

  const LoanQuote({
    required this.cashPrice,
    required this.loanPrice,
    required this.minimumDeposit,
    required this.downPayment,
    required this.financedAmount,
    required this.financeFee,
    required this.totalRepayable,
    required this.tenureWeeks,
    required this.weeklyInstallment,
    required this.schedule,
  });

  /// Factory calculator based on agreed business rules:
  /// - Loan price is typically +18% to +25% markup over Cash price (or custom loanPrice).
  /// - Minimum deposit is 25% of loan price.
  /// - Financed amount = loanPrice - downPayment.
  /// - weekly installment = (financedAmount / tenureWeeks).round().
  factory LoanQuote.calculate({
    required int cashPrice,
    int? customLoanPrice,
    required int downPayment,
    required int tenureWeeks,
    DateTime? startDate,
  }) {
    final loanPrice = customLoanPrice ?? (cashPrice * 1.20).round();
    final minDeposit = (loanPrice * 0.25).round();
    final actualDeposit = downPayment.clamp(minDeposit, loanPrice);
    final financed = (loanPrice - actualDeposit).clamp(0, loanPrice);
    final fee = (loanPrice - cashPrice).clamp(0, loanPrice);
    final weekly = tenureWeeks > 0 ? (financed / tenureWeeks).round() : 0;

    final start = startDate ?? DateTime.now();
    final schedule = <InstallmentScheduleItem>[];
    for (int i = 1; i <= tenureWeeks; i++) {
      // The last instalment absorbs the rounding of the ones before it, so the
      // schedule adds up to exactly the amount financed. Rounding every week
      // and stopping there left a schedule that could over- or under-collect by
      // up to half a shilling per week — small, but a statement that does not
      // add up is the first thing a borrower checks.
      final amount = i == tenureWeeks ? financed - weekly * (tenureWeeks - 1) : weekly;
      schedule.add(
        InstallmentScheduleItem(
          installmentNumber: i,
          dueDate: start.add(Duration(days: i * 7)),
          amount: amount,
        ),
      );
    }

    return LoanQuote(
      cashPrice: cashPrice,
      loanPrice: loanPrice,
      minimumDeposit: minDeposit,
      downPayment: actualDeposit,
      financedAmount: financed,
      financeFee: fee,
      totalRepayable: loanPrice,
      tenureWeeks: tenureWeeks,
      weeklyInstallment: weekly,
      schedule: schedule,
    );
  }
}

/// Result of an executed POS transaction.
///
/// There is no `success` flag to set. The till used to build this object with
/// `success: true` and then attempt the write, so every printed receipt and
/// every green tick was asserted before anything was stored. Success is now
/// derived from [persistence], which only [LimsRepository] can fill in once the
/// ledger has answered.
@immutable
class POSSaleResult {
  /// What the ledger said. See [SalePersistence] for the possible answers.
  final SalePersistence persistence;
  final String receiptId;
  final String transactionType; // 'CASH' or 'LOAN'
  final String phoneModel;
  final String primaryImei;
  final String? secondaryImei;
  final String customerName;
  final String customerPhone;
  final int totalAmount;
  final int amountPaid;
  final int balanceRemaining;
  final String paymentChannel;
  final DateTime timestamp;

  /// The sentence to show the cashier when the sale did not complete. Null when
  /// there is nothing to report.
  final String? errorMessage;

  const POSSaleResult({
    required this.persistence,
    required this.receiptId,
    required this.transactionType,
    required this.phoneModel,
    required this.primaryImei,
    this.secondaryImei,
    required this.customerName,
    required this.customerPhone,
    required this.totalAmount,
    required this.amountPaid,
    required this.balanceRemaining,
    required this.paymentChannel,
    required this.timestamp,
    this.errorMessage,
  });

  /// True only when the till may tell the cashier the sale is done: the row is
  /// in `public.sales`, or this build has no database to write to at all (demo
  /// and offline builds), where nothing is claimed about a ledger either way.
  ///
  /// Four words that are easy to confuse, and what each one is allowed to mean:
  ///
  /// * [SalePersistence.confirmed] — the ledger answered and holds the row.
  /// * [SalePersistence.notConfigured] — **no database write occurred**; the
  ///   workflow still finishes locally so a demo can be demonstrated end to end.
  /// * [success] — "this workflow is complete": `confirmed` **or**
  ///   `notConfigured`. It says nothing about a stored row, so it may open the
  ///   success dialog and it may not print a receipt.
  /// * [isSaved] — `confirmed` only: the sale is persisted. Every claim of
  ///   record (receipt, PDF) depends on this, never on [success].
  bool get success =>
      persistence == SalePersistence.confirmed ||
      persistence == SalePersistence.notConfigured;

  /// True only when a row was written and confirmed. Receipt and PDF work must
  /// depend on this, not on [success]: a demo build completes the sale without
  /// a row, and a piece of paper saying otherwise is a false record.
  bool get isSaved => persistence == SalePersistence.confirmed;

  /// True when the request may have reached the database and no answer came
  /// back. Nothing here is safe to resend blindly.
  bool get isUnconfirmed => persistence == SalePersistence.unconfirmed;

  POSSaleResult copyWith({
    SalePersistence? persistence,
    String? errorMessage,
  }) {
    return POSSaleResult(
      persistence: persistence ?? this.persistence,
      receiptId: receiptId,
      transactionType: transactionType,
      phoneModel: phoneModel,
      primaryImei: primaryImei,
      secondaryImei: secondaryImei,
      customerName: customerName,
      customerPhone: customerPhone,
      totalAmount: totalAmount,
      amountPaid: amountPaid,
      balanceRemaining: balanceRemaining,
      paymentChannel: paymentChannel,
      timestamp: timestamp,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// Abstract contract for LIMS Data Repository
abstract class LimsRepository {
  /// Products the counter can ring up right now.
  ///
  /// [phonesOnly] is true for the loan flow, which only finances handsets.
  /// A cash sale is not a financing decision, so it may sell anything on the
  /// shelf — accessories, laptops, power banks — not just phones.
  List<ProductItem> getAvailableHandsets(
    WidgetRef ref, {
    String? branch,
    bool phonesOnly = true,
  });
  Future<POSSaleResult> executeCashSale({
    required WidgetRef ref,
    required ProductItem phone,
    required String customerName,
    required String customerPhone,
    required String paymentChannel,
  });
  Future<POSSaleResult> executeLoanDisbursement({
    required WidgetRef ref,
    required ProductItem phone,
    required String customerName,
    required String customerPhone,
    required String customerNida,
    required String residence,
    required String guarantorName,
    required String guarantorPhone,
    required LoanQuote quote,
    required String paymentChannel,
  });
}

/// Implementation using Riverpod in-memory state (ready to swap for SupabaseLimsRepository)
class MockLimsRepository implements LimsRepository {
  const MockLimsRepository({this.ledger = const SupabaseSaleLedger()});

  /// Where a completed sale is written. Production is the Supabase ledger; a
  /// test can pass a fake that answers "stored", "refused" or "no answer". The
  /// swap changes nothing else about the flow.
  final SaleLedger ledger;

  @override
  List<ProductItem> getAvailableHandsets(
    WidgetRef ref, {
    String? branch,
    bool phonesOnly = true,
  }) {
    final allProducts = ref.read(inventoryProvider);
    return allProducts
        .where((p) =>
            (!phonesOnly || p.cat == 'phones') &&
            p.stock > 0 &&
            p.status != 'out')
        .toList();
  }

  /// Writes a completed sale and reports what the ledger said.
  ///
  /// This used to return `void` and drop the result of the write on the floor,
  /// so a refused insert looked exactly like a stored one. The row reaches the
  /// in-memory ledger only when the database confirmed it — otherwise the till
  /// would show a sale the shop cannot reproduce.
  Future<SaleLedgerWrite> _persistSale(
    WidgetRef ref,
    POSSaleResult result,
    ProductItem phone, {
    required String kind,
  }) async {
    final branchName = ref.read(activeBranchProvider);
    final branches = ref.read(branchesProvider);
    String? branchId;
    for (final b in branches) {
      if (b.name == branchName) {
        branchId = b.id;
        break;
      }
    }
    final write = await ledger.write(
      receiptNo: result.receiptId,
      kind: kind,
      total: result.totalAmount,
      paid: result.amountPaid,
      balance: result.balanceRemaining,
      paymentChannel: result.paymentChannel,
      customerName: result.customerName,
      customerPhone: result.customerPhone,
      phoneModel: phone.name,
      imei: result.primaryImei,
      branchId: branchId,
      productId: phone.id,
    );
    if (write.isConfirmed) {
      ref.read(salesProvider.notifier).add(
            SaleRecord(
              receiptNo: result.receiptId,
              total: result.totalAmount,
              paid: result.amountPaid,
              kind: kind,
              soldAt: result.timestamp,
              imei: result.primaryImei,
              customerName: result.customerName,
              productId: phone.id,
            ),
          );
    }
    return write;
  }

  /// The parts of a sale the counter sees locally.
  ///
  /// They are applied only once the sale is allowed to count as done, which is
  /// why they no longer run before the write: a refused sale used to leave the
  /// shelf short, a phantom borrower in the book and an activity line for a sale
  /// that never happened — and ringing it up again duplicated the loan.
  void _applyLocalSale(
    WidgetRef ref, {
    required ProductItem phone,
    required bool isLoan,
    required ActivityItem activity,
    LoanItem? loan,
  }) {
    if (loan != null) ref.read(loansProvider.notifier).addLoan(loan);
    ref.read(inventoryProvider.notifier).sellProduct(
          phone.id,
          quantity: 1,
          isLoan: isLoan,
        );
    ref.read(activitiesProvider.notifier).addActivity(activity);
  }

  @override
  Future<POSSaleResult> executeCashSale({
    required WidgetRef ref,
    required ProductItem phone,
    required String customerName,
    required String customerPhone,
    required String paymentChannel,
  }) async {
    final now = DateTime.now();
    final receiptId = 'POS-CASH-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${now.millisecondsSinceEpoch.toString().substring(8)}';

    // A draft, not a success. `unconfirmed` is the literal truth before the
    // write: nothing is known about the record yet.
    final sale = POSSaleResult(
      persistence: SalePersistence.unconfirmed,
      receiptId: receiptId,
      transactionType: 'CASH',
      phoneModel: phone.name,
      primaryImei: phone.imei1 ?? phone.sku,
      secondaryImei: phone.imei2,
      customerName: customerName,
      customerPhone: customerPhone,
      totalAmount: phone.price,
      amountPaid: phone.price,
      balanceRemaining: 0,
      paymentChannel: paymentChannel,
      timestamp: now,
    );

    final write = await _persistSale(ref, sale, phone, kind: 'cash');

    if (write.isConfirmed || write.status == SalePersistence.notConfigured) {
      _applyLocalSale(
        ref,
        phone: phone,
        isLoan: false,
        activity: ActivityItem(
          icon: Icons.point_of_sale_rounded,
          iconColor: const Color(0xFF10B981),
          bgColor: const Color(0xFFECFDF5),
          title: 'Cash Sale · ${phone.name}',
          description: 'TZS ${phone.price} via $paymentChannel · $customerName',
          time: 'Just now',
        ),
      );
    }

    return sale.copyWith(
      persistence: write.status,
      errorMessage: write.message,
    );
  }

  @override
  Future<POSSaleResult> executeLoanDisbursement({
    required WidgetRef ref,
    required ProductItem phone,
    required String customerName,
    required String customerPhone,
    required String customerNida,
    required String residence,
    required String guarantorName,
    required String guarantorPhone,
    required LoanQuote quote,
    required String paymentChannel,
  }) async {
    final now = DateTime.now();
    final loanId = 'LN-${now.year}${now.month.toString().padLeft(2, '0')}-${now.millisecondsSinceEpoch.toString().substring(8)}';
    final receiptId = 'POS-LOAN-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${now.millisecondsSinceEpoch.toString().substring(8)}';

    // 1. Build the loan record. Nothing joins the book until the write is
    // confirmed, so a refused disbursement cannot leave a borrower behind.
    final newLoan = LoanItem(
      id: loanId,
      name: customerName,
      phone: customerPhone,
      nida: customerNida,
      location: residence,
      guarantorName: guarantorName,
      guarantorPhone: guarantorPhone,
      guarantorRelation: 'Guarantor / Kin',
      item: phone.name,
      amount: quote.loanPrice,
      paid: ((quote.downPayment / quote.loanPrice) * 100).round().clamp(10, 100),
      status: 'current',
      grad: const [AppTheme.brand600, Color(0xFF7C5CFC)],
      due: quote.schedule.isNotEmpty ? quote.schedule.first.formattedDueDate : 'Next Week',
      imei: phone.imei1 ?? phone.sku,
      totalDeposit: quote.downPayment,
      weeklyInstallment: quote.weeklyInstallment,
      installmentWeeks: quote.tenureWeeks,
      payments: [
        LoanPaymentRecord(
          id: 'PM-DEP-${now.millisecondsSinceEpoch.toString().substring(8)}',
          date: 'Today (Down Payment)',
          amount: quote.downPayment,
          channel: paymentChannel,
          refNumber: 'DEP-${now.millisecondsSinceEpoch.toString().substring(7)}',
          receiptNumber: receiptId,
        ),
      ],
    );

    final sale = POSSaleResult(
      persistence: SalePersistence.unconfirmed,
      receiptId: receiptId,
      transactionType: 'LOAN',
      phoneModel: phone.name,
      primaryImei: phone.imei1 ?? phone.sku,
      secondaryImei: phone.imei2,
      customerName: customerName,
      customerPhone: customerPhone,
      totalAmount: quote.loanPrice,
      amountPaid: quote.downPayment,
      balanceRemaining: quote.financedAmount,
      paymentChannel: paymentChannel,
      timestamp: now,
    );

    final write = await _persistSale(ref, sale, phone, kind: 'loan');

    if (write.isConfirmed || write.status == SalePersistence.notConfigured) {
      _applyLocalSale(
        ref,
        phone: phone,
        isLoan: true,
        loan: newLoan,
        activity: ActivityItem(
          icon: Icons.assignment_ind_rounded,
          iconColor: const Color(0xFF7C5CFC),
          bgColor: const Color(0xFFF0EBFF),
          title: 'Loan Disbursed · ${phone.name}',
          description: 'TZS ${quote.downPayment} deposit received · $customerName',
          time: 'Just now',
        ),
      );
    }

    return sale.copyWith(
      persistence: write.status,
      errorMessage: write.message,
    );
  }
}

/// Riverpod provider for the repository
final limsRepositoryProvider = Provider<LimsRepository>((ref) {
  return const MockLimsRepository();
});
