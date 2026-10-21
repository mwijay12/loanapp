import 'package:flutter_test/flutter_test.dart';
import 'package:loan_inventory_app/core/services/store_facts.dart';

/// The assistant used to answer "Today's sales summary" with 18 phones and TZS
/// 7,420,000, taken from a hardcoded string. These tests hold it to the rows it is
/// given: a figure that is not in [StoreFacts] must not appear in the answer.
void main() {
  StoreFacts facts({
    int salesCount = 3,
    int salesTotal = 1716000,
    int cash = 1000000,
    int credit = 716000,
    int collected = 500000,
    int stockUnits = 240,
    int modelCount = 12,
    List<MapEntry<String, int>> low = const [],
    int loansActive = 6,
    int loansOverdue = 2,
    int overdueOutstanding = 950000,
    String scope = 'live',
  }) {
    return StoreFacts(
      branch: 'Kariakoo',
      salesCount: salesCount,
      salesTotal: salesTotal,
      cashTotal: cash,
      creditTotal: credit,
      stockUnits: stockUnits,
      modelCount: modelCount,
      lowStock: low,
      loansActive: loansActive,
      loansOverdue: loansOverdue,
      overdueOutstanding: overdueOutstanding,
      collectedToday: collected,
      scope: scope,
    );
  }

  test('a sales answer prints the totals it was given, and nothing else', () {
    final a = answerFromFacts("Today's sales summary", facts(), swahili: false);
    expect(a.text, contains('1,716,000'));
    expect(a.text, contains('3'));
    // The old hardcoded numbers must not survive anywhere.
    expect(a.text, isNot(contains('7,420,000')));
    expect(a.text, isNot(contains('18')));
    expect(a.text, isNot(contains('85%')));
  });

  test('an empty day says zero rather than inventing takings', () {
    final a = answerFromFacts('sales', facts(salesCount: 0, salesTotal: 0),
        swahili: false);
    expect(a.text.toLowerCase(), contains('no sales recorded'));
    expect(a.text, isNot(contains('TZS')));
  });

  test('low stock lists only the models it was handed', () {
    final a = answerFromFacts('which phones are low on stock?',
        facts(low: const [MapEntry('itel Vision 3 Plus', 0)]),
        swahili: false);
    expect(a.text, contains('itel Vision 3 Plus'));
    expect(a.text, contains('0'));
    expect(a.text, isNot(contains('Samsung Galaxy A15')));
  });

  test('overdue answer uses the real count and outstanding balance', () {
    final a = answerFromFacts('overdue loans', facts(), swahili: false);
    expect(a.text, contains('2'));
    expect(a.text, contains('950,000'));
  });

  test('an unknown question is declined instead of answered with fiction', () {
    final a = answerFromFacts('what will my profit be next month?', facts(),
        swahili: false);
    expect(a.sourced, isFalse);
    expect(a.text.toLowerCase(), contains("can't answer"));
    expect(a.text, isNot(contains('TZS')));
  });

  test('Kiswahili is answered in Kiswahili', () {
    final a = answerFromFacts('mauzo ya leo', facts(), swahili: true);
    expect(a.text.contains('Mauzo ya leo'), isTrue);
    expect(a.text.contains('Miamala'), isTrue);
  });

  test('demo data is labelled as demo', () {
    final a = answerFromFacts('sales', facts(scope: 'demo'), swahili: false);
    expect(a.text.toLowerCase(), contains('demo'));
  });

  test('money is grouped in threes', () {
    expect(facts().money(1716000), 'TZS 1,716,000');
    expect(facts().money(950), 'TZS 950');
  });
}
