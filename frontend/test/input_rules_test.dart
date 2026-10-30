import 'package:flutter_test/flutter_test.dart';
import 'package:loan_inventory_app/core/widgets/ui_kit.dart';

void main() {
  group('phone numbers', () {
    test('a Tanzanian mobile number is accepted', () {
      expect(LimsValidators.validatePhone10('0712345678'), isNull);
      expect(LimsValidators.validatePhone10('0687654321'), isNull);
    });

    test('the field stops at ten digits', () {
      expect(LimsValidators.phoneFormatters.length, 2);
      // The formatter list is exercised through the widget in sale_form_test;
      // here we assert the rule the message states.
      expect(LimsValidators.validatePhone10('079094747488899'),
          contains('10 digits'));
    });

    test('eleven digits is refused, and the message says how many arrived', () {
      final error = LimsValidators.validatePhone10('07123456789');
      expect(error, isNotNull);
      expect(error, contains('11'));
    });

    test('a number that does not start with 0/6/7 is refused', () {
      expect(LimsValidators.validatePhone10('0112345678'), isNotNull);
      expect(LimsValidators.validatePhone10('2512345678'), isNotNull);
    });

    test('empty is required, not silently valid', () {
      expect(LimsValidators.validatePhone10(''), isNotNull);
      expect(LimsValidators.validatePhone10(null), isNotNull);
    });
  });

  group('card numbers', () {
    test('sixteen digits is accepted', () {
      expect(LimsValidators.validateCardNumber('1234567812345678'), isNull);
    });

    test('fifteen is refused with the count in the message', () {
      expect(LimsValidators.validateCardNumber('123456781234567'),
          contains('15'));
    });

    test('spaces and dashes do not count as digits', () {
      expect(LimsValidators.validateCardNumber('1234 5678 1234 5678'), isNull);
    });

    test('only the last four survive for the receipt', () {
      expect(LimsValidators.last4('1234567812345678'), '5678');
      expect(LimsValidators.last4('123'), '123');
      expect(LimsValidators.last4(''), '');
    });
  });
}
