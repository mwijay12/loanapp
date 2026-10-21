import 'package:flutter_test/flutter_test.dart';
import 'package:loan_inventory_app/core/services/pdf_labels.dart';

/// Receipts were Swahili-only while the till was in English. Paper outlives the
/// screen, so the language has to be right at build time. These tests pin both
/// languages and guard against a key that silently falls back to its own name.
void main() {
  test('a receipt headed in English says SALES RECEIPT', () {
    final l = PdfLabels(PdfLang.en);
    expect(l.saleReceipt, 'SALES RECEIPT');
    expect(l.loanReceipt, 'LOAN RECEIPT');
    expect(l.customer, 'Customer');
    expect(l.deposit, 'Deposit');
  });

  test('the same receipt in Kiswahili says RISITI YA MAUZO', () {
    final l = PdfLabels(PdfLang.sw);
    expect(l.saleReceipt, 'RISITI YA MAUZO');
    expect(l.customer, 'Mteja');
    expect(l.deposit, 'Malipo ya kwanza');
  });

  test('dates use the month names of the chosen language', () {
    final d = DateTime(2026, 10, 22);
    expect(PdfLabels(PdfLang.en).longDate(d), '22 October 2026');
    expect(PdfLabels(PdfLang.sw).longDate(d), '22 Oktoba 2026');
  });

  test('no label falls back to its key', () {
    for (final lang in PdfLang.values) {
      final l = PdfLabels(lang);
      final labels = <String>[
        l.brand, l.reportTitle, l.stockSection, l.loansSection, l.model,
        l.sku, l.status, l.customer, l.guarantor, l.handset, l.amount,
        l.paid, l.remaining, l.nextDue, l.date, l.total, l.timesheetTitle,
        l.staffName, l.clockIn, l.clockOut, l.saleReceipt, l.loanReceipt,
        l.receiptNo, l.servedBy, l.phone, l.nida, l.location, l.item,
        l.retailPrice, l.deposit, l.balance, l.weekly, l.term, l.firstDue,
        l.channel, l.customerSign, l.sellerSign, l.branchStamp, l.thanks,
        l.saleNote, l.loanNote, l.statementTitle, l.statementNote, l.schedule,
      ];
      for (final label in labels) {
        expect(label.trim(), isNotEmpty);
        expect(label, isNot(startsWith('_')));
      }
    }
  });

  test('receipt filenames follow the language', () {
    expect(PdfLabels(PdfLang.en).receiptFilePrefix, 'Receipt');
    expect(PdfLabels(PdfLang.sw).receiptFilePrefix, 'Risiti');
  });
}
