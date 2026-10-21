import 'package:flutter_test/flutter_test.dart';
import 'package:loan_inventory_app/core/services/imei_scan.dart';

/// The scanner used to be decoration: it waited, then returned a phone from a
/// hardcoded list. These tests pin the part that has to be right when a real
/// camera is attached — what counts as an IMEI, and what counts as a valid one.
void main() {
  // Generated with the GSMA check digit, not typed by hand.
  const valid = '358920112849101';
  const validTwo = '864920042819387';

  group('parseImei', () {
    test('accepts a bare 15-digit IMEI', () {
      expect(ImeiScan.parseImei(valid), valid);
    });

    test('accepts spacing and dashes from a printed label', () {
      expect(ImeiScan.parseImei('358920 112849 101'), valid);
      expect(ImeiScan.parseImei('358920-112849-101'), valid);
    });

    test('reads the prefix on our own QR stickers', () {
      expect(ImeiScan.parseImei('LIMS:IMEI:$valid'), valid);
      expect(ImeiScan.parseImei('IMEI: $valid'), valid);
      expect(ImeiScan.parseImei('imei $valid'), valid);
    });

    test('reads the serial out of a GS1 DataMatrix', () {
      // 01 = GTIN, 21 = serial. The IMEI is the serial.
      expect(ImeiScan.parseImei('010123456789012321$valid'), valid);
    });

    test('reads an IMEI out of a supplier URL', () {
      expect(ImeiScan.parseImei('https://x.example/t?imei=$valid&b=1'), valid);
    });

    test('refuses a label that merely contains 15 digits', () {
      // A price tag must not be mistaken for a serial number. Grabbing the first
      // fifteen digits here would "find" a device that does not exist.
      expect(ImeiScan.parseImei('Nokia 105 · TZS 24,000 · 355012345678901'),
          isNull);
    });

    test('refuses empty and unrelated payloads', () {
      expect(ImeiScan.parseImei(''), isNull);
      expect(ImeiScan.parseImei(null), isNull);
      expect(ImeiScan.parseImei('hello world'), isNull);
    });
  });

  group('isValid', () {
    test('accepts numbers whose check digit is right', () {
      expect(ImeiScan.isValid(valid), isTrue);
      expect(ImeiScan.isValid(validTwo), isTrue);
    });

    test('rejects a single transposed digit', () {
      expect(ImeiScan.isValid('358920112849102'), isFalse);
      expect(ImeiScan.isValid('358920112849100'), isFalse);
    });

    test('rejects the wrong length', () {
      expect(ImeiScan.isValid('35892011284910'), isFalse);
      expect(ImeiScan.isValid('3589201128491011'), isFalse);
      expect(ImeiScan.isValid(''), isFalse);
      expect(ImeiScan.isValid(null), isFalse);
    });

    test('the parity is the GSMA one, not the first guess', () {
      // Doubling the wrong positions still accepts about one number in ten, so
      // this number is chosen because it passes only the correct parity.
      expect(ImeiScan.isValid('351982746201940'), isTrue);
      expect(ImeiScan.isValid('351982746201941'), isFalse);
    });
  });

  group('withCheckDigit', () {
    test('completes a 14-digit body', () {
      expect(ImeiScan.withCheckDigit('35892011284910'), valid);
    });

    test('refuses a body of the wrong length', () {
      expect(() => ImeiScan.withCheckDigit('123'), throwsArgumentError);
    });
  });

  test('tac exposes the first eight digits', () {
    expect(ImeiScan.tac(valid), '35892011');
    expect(ImeiScan.tac('123'), isNull);
  });
}
