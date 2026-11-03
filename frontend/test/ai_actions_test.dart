import 'package:flutter_test/flutter_test.dart';
import 'package:loan_inventory_app/core/services/ai_actions.dart';

void main() {
  test('an instruction opens the screen it names', () {
    expect(parseAssistantAction('fungua stoo')?.route, '/stock');
    expect(parseAssistantAction('open the loans screen')?.route, '/loans');
    expect(parseAssistantAction('take me to reports')?.route, '/reports');
    expect(parseAssistantAction('nionyeshe mikopo')?.route, '/loans');
  });

  test('a bare screen name is treated as an instruction', () {
    expect(parseAssistantAction('petty cash')?.route, '/petty-cash');
    expect(parseAssistantAction('daily closing')?.route, '/daily-closing');
  });

  // The dangerous case: the same noun, but the user asked a question and the
  // answer is the reply. Navigating away mid-answer is worse than useless.
  test('a question about a screen does not open it', () {
    expect(parseAssistantAction('how many phones in stock?'), isNull);
    expect(parseAssistantAction('ni simu ngapi stoo'), isNull);
    expect(parseAssistantAction('what is my total stock'), isNull);
  });

  test('an ordinary question yields no action', () {
    expect(parseAssistantAction('mauzo ya leo'), isNull);
    expect(parseAssistantAction('hello'), isNull);
    expect(parseAssistantAction(''), isNull);
  });

  test('the label follows the interface language', () {
    final a = parseAssistantAction('fungua stoo')!;
    expect(a.labelFor(swahili: true), 'Fungua stoo');
    expect(a.labelFor(swahili: false), 'Open stockroom');
  });
}
