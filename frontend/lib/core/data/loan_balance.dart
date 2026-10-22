import 'mock_lims_data.dart';

/// One set of financial definitions for a loan, shared by the screens and by
/// the PDF statement.
///
/// Before this file there were three answers to "what does this borrower still
/// owe": [LoanItem.remainingAmount] (used by the loan screens), a private
/// calculation inside the PDF statement that subtracted the deposit a second
/// time, and a fourth inline `amount * (100 - paid) / 100` in two dashboards.
/// They agreed only when the deposit was zero.
///
/// The definition the application actually stores, and therefore the one used
/// here, is:
///
/// * **loan price** ([loanPrice]) — the price on the hire-purchase contract,
///   which already contains the finance markup. This is `loans.amount`.
/// * **deposit** ([deposit]) — what the borrower paid on the day, already
///   counted inside [paid].
/// * **financed** ([financed]) — the part that is carried: loan price − deposit.
/// * **paid** ([paid]) — money received so far. `paid_percent` is a percentage
///   **of the loan price**, not of the financed amount: a 25% deposit is stored
///   as 25.
/// * **remaining** ([remaining]) — loan price − paid. Nothing is added back.
///
/// Rounding happens once, at the edge, in whole shillings: the shilling is the
/// smallest unit the shop handles, and every figure here is an integer.
class LoanBalance {
  const LoanBalance({
    required this.loanPrice,
    required this.deposit,
    required this.financed,
    required this.paid,
    required this.remaining,
    required this.paidPercent,
    required this.weeks,
    required this.weekly,
  });

  /// Snapshot of the figures for one loan, from the same getters the UI reads.
  factory LoanBalance.of(LoanItem loan) {
    return LoanBalance(
      loanPrice: loan.amount,
      deposit: loan.totalDeposit,
      financed: (loan.amount - loan.totalDeposit).clamp(0, loan.amount),
      paid: loan.totalPaidAmount,
      remaining: loan.remainingAmount,
      paidPercent: loan.paidPercent,
      weeks: loan.installmentWeeks,
      weekly: loan.weeklyInstallment,
    );
  }

  final int loanPrice;
  final int deposit;
  final int financed;
  final int paid;
  final int remaining;
  final int paidPercent;
  final int weeks;
  final int weekly;

  /// Whole weeks settled, floored: a half-paid week is not a paid week.
  int get paidWeeks {
    if (weeks <= 0) return 0;
    return (weeks * paidPercent / 100).floor().clamp(0, weeks);
  }

  /// Balance after the schedule has been walked, for reconciling a statement
  /// against its own instalments.
  int get scheduleTotal => weekly * weeks;
}

/// Why a repayment may not be accepted, or null when it is fine.
///
/// Kept next to the definitions so the dialog and the tests ask the same
/// question. The shilling is the unit: anything that is not a positive whole
/// number of shillings, or that is larger than what is still owed, is refused
/// rather than clamped — a clamped overpayment deletes the excess from the
/// balance and leaves the borrower with no record of it.
enum RepaymentProblem { none, notPositive, aboveBalance }

RepaymentProblem checkRepayment(int amount, LoanItem loan) {
  if (amount <= 0) return RepaymentProblem.notPositive;
  if (amount > loan.remainingAmount) return RepaymentProblem.aboveBalance;
  return RepaymentProblem.none;
}
