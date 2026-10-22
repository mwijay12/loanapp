import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loan_inventory_app/core/data/loan_balance.dart';
import 'package:loan_inventory_app/core/data/inventory_provider.dart';
import 'package:loan_inventory_app/core/data/lims_repository.dart';
import 'package:loan_inventory_app/core/data/mock_lims_data.dart';

/// Task 2 — one balance, used by the screen and by the statement.
///
/// The numbers below are written out as literals on purpose. If a definition
/// changes, a test that recomputes it from the same helper would keep passing
/// while the shop's arithmetic changed underneath it.

LoanItem _loan({
  int amount = 655000,
  int paid = 25,
  int deposit = 163750,
  int weeks = 8,
  int weekly = 61406,
  String status = 'current',
  List<LoanPaymentRecord> payments = const [],
}) {
  return LoanItem(
    id: 'LIMS-LN-TEST',
    name: 'Test Borrower',
    item: 'Infinix Zero 40',
    amount: amount,
    paid: paid,
    due: 'Due in 3 days',
    status: status,
    grad: const [Color(0xFF1B6EF3), Color(0xFF0A49B8)],
    totalDeposit: deposit,
    installmentWeeks: weeks,
    weeklyInstallment: weekly,
    payments: payments,
  );
}

void main() {
  group('one balance for the screen and the statement', () {
    test('a 25% deposit counts as 25% paid, not 18.75%', () {
      final loan = _loan();
      final figures = LoanBalance.of(loan);

      // 25% of 655,000.
      expect(figures.paid, 163750);
      expect(figures.remaining, 491250);

      // What the statement used to print: it took the deposit off the price,
      // then applied 25% to the remainder, so the deposit was subtracted twice.
      const oldStatementBalance = 368437;
      expect(figures.remaining, isNot(oldStatementBalance));

      // The screen reads the same object, so the two cannot drift apart.
      expect(figures.remaining, loan.remainingAmount);
      expect(figures.paid, loan.totalPaidAmount);
    });

    test('the deposit is not added back to the debt', () {
      final loan = _loan();
      final figures = LoanBalance.of(loan);

      expect(figures.financed, 491250); // 655,000 − 163,750
      expect(figures.financed, figures.remaining); // nothing paid past the deposit
    });

    test('paid weeks are floored, never rounded up', () {
      final loan = _loan(paid: 37, weeks: 8); // 37% of eight weeks
      expect(LoanBalance.of(loan).paidWeeks, 2);
    });
  });

  group('small repayments are not rounded into nothing', () {
    test('TZS 1,000 moves the balance by exactly TZS 1,000', () {
      // 60% of 2.4M = 1,440,000; the old code added round(1000/2400000*100)=0.
      final loan = _loan(amount: 2400000, paid: 60, deposit: 600000);
      expect(loan.remainingAmount, 960000);

      final notifier = LoansNotifier([loan]);
      notifier.recordPayment(loan.id, 1000);

      expect(notifier.state.single.totalPaidAmount, 1441000);
      expect(notifier.state.single.remainingAmount, 959000);
    });

    test('a repayment below one percent still leaves a receipt and a balance',
        () {
      final loan = _loan(amount: 2400000, paid: 60, deposit: 600000);
      final notifier = LoansNotifier([loan]);
      notifier.recordPayment(loan.id, 500);

      final after = notifier.state.single;
      expect(after.payments.length, 1); // the history kept it
      expect(after.remainingAmount, 959500); // and so did the balance
    });
  });

  group('installment schedules reconcile', () {
    test('the schedule adds up to the amount financed', () {
      final quote = LoanQuote.calculate(
        cashPrice: 655000,
        downPayment: 0,
        tenureWeeks: 8,
      );

      expect(quote.loanPrice, 786000); // 655,000 × 1.20
      expect(quote.minimumDeposit, 196500); // 25%
      expect(quote.financedAmount, 589500);

      final total = quote.schedule.fold<int>(0, (s, i) => s + i.amount);
      expect(total, quote.financedAmount);
    });

    test('the last installment absorbs the rounding of the others', () {
      final quote = LoanQuote.calculate(
        cashPrice: 655000,
        downPayment: 0,
        tenureWeeks: 8,
      );

      // 589,500 / 8 = 73,687.5 → 73,688 a week, and the last week carries the
      // four shillings the rounding left behind.
      expect(quote.weeklyInstallment, 73688);
      expect(quote.schedule.first.amount, 73688);
      expect(quote.schedule.last.amount, 73684);
      expect(quote.schedule.last.amount, isNot(quote.weeklyInstallment));
    });

    test('a one-week term puts the whole balance in that week', () {
      final quote = LoanQuote.calculate(
        cashPrice: 100000,
        downPayment: 0,
        tenureWeeks: 1,
      );
      expect(quote.schedule.single.amount, quote.financedAmount);
    });
  });

  group('fully repaid reads zero', () {
    test('100% paid leaves nothing outstanding', () {
      final loan = _loan(paid: 100);
      expect(loan.remainingAmount, 0);
      expect(loan.paidPercent, 100);
    });

    test('paying the exact remainder clears the loan', () {
      final loan = _loan(amount: 1000000, paid: 50, deposit: 250000);
      final notifier = LoansNotifier([loan]);
      notifier.recordPayment(loan.id, loan.remainingAmount);

      expect(notifier.state.single.remainingAmount, 0);
      expect(notifier.state.single.status, 'cleared');
      expect(notifier.state.single.paidPercent, 100);
    });
  });

  group('the agreed rules still hold', () {
    test('price, deposit and weekly amount are unchanged', () {
      final quote = LoanQuote.calculate(
        cashPrice: 500000,
        downPayment: 150000, // exactly the 25% minimum
        tenureWeeks: 8,
      );

      expect(quote.loanPrice, 600000);
      expect(quote.minimumDeposit, 150000);
      expect(quote.downPayment, 150000);
      expect(quote.financedAmount, 450000);
      expect(quote.weeklyInstallment, 56250);
      expect(quote.totalRepayable, quote.loanPrice);
    });

    test('a deposit below the minimum is raised to it, not invented', () {
      final quote = LoanQuote.calculate(
        cashPrice: 500000,
        downPayment: 10000,
        tenureWeeks: 8,
      );
      expect(quote.downPayment, 150000);
      expect(quote.financedAmount, 450000);
    });
  });

  group('unusable repayments are refused, not clamped', () {
    test('zero and negative amounts', () {
      final loan = _loan();
      expect(checkRepayment(0, loan), RepaymentProblem.notPositive);
      expect(checkRepayment(-5000, loan), RepaymentProblem.notPositive);
    });

    test('more than the remaining balance', () {
      final loan = _loan();
      expect(checkRepayment(491251, loan), RepaymentProblem.aboveBalance);
    });

    test('exactly the remaining balance is accepted', () {
      final loan = _loan();
      expect(checkRepayment(491250, loan), RepaymentProblem.none);
    });
  });
}
