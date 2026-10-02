import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import 'mock_lims_data.dart';
import 'inventory_provider.dart';

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
      schedule.add(
        InstallmentScheduleItem(
          installmentNumber: i,
          dueDate: start.add(Duration(days: i * 7)),
          amount: weekly,
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

/// Result of an executed POS transaction
@immutable
class POSSaleResult {
  final bool success;
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
  final String? errorMessage;

  const POSSaleResult({
    required this.success,
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
}

/// Abstract contract for LIMS Data Repository
abstract class LimsRepository {
  List<ProductItem> getAvailableHandsets(WidgetRef ref, {String? branch});
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
  const MockLimsRepository();

  @override
  List<ProductItem> getAvailableHandsets(WidgetRef ref, {String? branch}) {
    final allProducts = ref.read(inventoryProvider);
    return allProducts
        .where((p) => p.cat == 'phones' && p.stock > 0 && p.status != 'out')
        .toList();
  }

  @override
  Future<POSSaleResult> executeCashSale({
    required WidgetRef ref,
    required ProductItem phone,
    required String customerName,
    required String customerPhone,
    required String paymentChannel,
  }) async {
    // 1. Decrement inventory stock
    ref.read(inventoryProvider.notifier).sellProduct(phone.id, quantity: 1, isLoan: false);

    // 2. Generate unique POS receipt ID
    final now = DateTime.now();
    final receiptId = 'POS-CASH-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${now.millisecondsSinceEpoch.toString().substring(8)}';

    // 3. Log to activity feed
    ref.read(activitiesProvider.notifier).addActivity(
      ActivityItem(
        icon: Icons.point_of_sale_rounded,
        iconColor: const Color(0xFF10B981),
        bgColor: const Color(0xFFECFDF5),
        title: 'Cash Sale · ${phone.name}',
        description: 'TZS ${phone.price} via $paymentChannel · $customerName',
        time: 'Just now',
      ),
    );

    return POSSaleResult(
      success: true,
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

    // 1. Create and add LoanItem to loansProvider
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
    ref.read(loansProvider.notifier).addLoan(newLoan);

    // 2. Decrement inventory stock with isLoan flag
    ref.read(inventoryProvider.notifier).sellProduct(phone.id, quantity: 1, isLoan: true);

    // 3. Log to activity feed
    ref.read(activitiesProvider.notifier).addActivity(
      ActivityItem(
        icon: Icons.assignment_ind_rounded,
        iconColor: const Color(0xFF7C5CFC),
        bgColor: const Color(0xFFF0EBFF),
        title: 'Loan Disbursed · ${phone.name}',
        description: 'TZS ${quote.downPayment} deposit received · $customerName',
        time: 'Just now',
      ),
    );

    return POSSaleResult(
      success: true,
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
  }
}

/// Riverpod provider for the repository
final limsRepositoryProvider = Provider<LimsRepository>((ref) {
  return const MockLimsRepository();
});
