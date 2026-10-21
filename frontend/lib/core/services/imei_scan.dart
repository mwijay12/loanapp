/// Turning a scanned barcode into an IMEI, and checking it is a real one.
///
/// The screen used to have a button labelled "Simulate Camera Laser Scan" that
/// waited 1.2 seconds and then opened a handset nobody had scanned. This file is
/// the opposite of that: every code it returns either passes the GSMA check digit
/// or is rejected, and the caller decides what a valid IMEI means.
///
/// Three label formats reach a Tanzanian phone shop:
///
///   * the bare IMEI, printed under the battery or on the box barcode
///   * a GS1 DataMatrix, where the IMEI is the serial after the `21` application
///     identifier (AI `01` is the GTIN)
///   * a QR sticker the shop printed itself, in the form `LIMS:IMEI:<number>`
///
/// All three end up here. [parseImei] returns null when it cannot find a
/// well-formed IMEI, so a scanner pointed at a price tag does not become a false
/// "device found".
class ImeiScan {
  /// Pulls an IMEI out of whatever the scanner saw.
  ///
  /// Returns a normalised 15-digit string, or null. Validation is separate
  /// ([isValid]) so the UI can tell "this is not an IMEI at all" apart from "this
  /// is a 15-digit number that fails its check digit".
  static String? parseImei(String? raw) {
    if (raw == null) return null;
    final text = raw.trim();
    if (text.isEmpty) return null;

    // Our own QR payload, and the common human-readable prefixes.
    final prefixed = RegExp(r'^(?:LIMS:)?(?:IMEI|IMEI1|SN)[:\s#-]*([0-9 \-]{14,25})$',
        caseSensitive: false);
    final match = prefixed.firstMatch(text);
    if (match != null) {
      final digits = match.group(1)!.replaceAll(RegExp(r'[^0-9]'), '');
      if (digits.length == 15) return digits;
    }

    // GS1 DataMatrix: (01)GTIN(21)SERIAL, sometimes with a group separator.
    //
    // The search for the `21` starts after the GTIN, not at the beginning of the
    // string: a GTIN frequently contains the digits 21 itself, and matching those
    // returned eleven random digits plus whatever followed.
    if (text.startsWith('01') && text.length > 18) {
      final ai21 = text.indexOf('21', 2 + 14);
      if (ai21 != -1) {
        final serial = text.substring(ai21 + 2).replaceAll(RegExp(r'\D'), '');
        if (serial.length >= 15) return serial.substring(0, 15);
      }
    }

    // A URL some suppliers encode into the sticker: ...?imei=35...
    final query = RegExp(r'[?&](?:imei|sn)=(\d{15})', caseSensitive: false)
        .firstMatch(text);
    if (query != null) return query.group(1);

    // Anything else is accepted only when the whole payload is one number. A
    // label that says "3550 1234 5678 901 / Ksh 24,000" must not be read as an
    // IMEI by grabbing the first fifteen digits.
    final bare = text.replaceAll(RegExp(r'[\s\-]'), '');
    if (RegExp(r'^\d{15}$').hasMatch(bare)) return bare;

    return null;
  }

  /// GSMA check digit (Luhn over the first 14 digits).
  ///
  /// Position parity matters: IMEI doubles every *second* digit starting from the
  /// left, and a wrong parity accepts roughly one invalid number in ten — which
  /// is exactly the kind of bug that survives a manual test.
  static bool isValid(String? imei) {
    if (imei == null || !RegExp(r'^\d{15}$').hasMatch(imei)) return false;
    var sum = 0;
    for (var i = 0; i < 15; i++) {
      var digit = int.parse(imei[i]);
      if (i.isOdd) {
        digit *= 2;
        if (digit > 9) digit -= 9;
      }
      sum += digit;
    }
    return sum % 10 == 0;
  }

  /// A check digit for a 14-digit body, used by tests and by the intake screen
  /// when a supplier prints an IMEI without one.
  static String withCheckDigit(String body14) {
    if (!RegExp(r'^\d{14}$').hasMatch(body14)) {
      throw ArgumentError('IMEI body must be 14 digits');
    }
    var sum = 0;
    for (var i = 0; i < 14; i++) {
      var digit = int.parse(body14[i]);
      if (i.isOdd) {
        digit *= 2;
        if (digit > 9) digit -= 9;
      }
      sum += digit;
    }
    final check = (10 - (sum % 10)) % 10;
    return '$body14$check';
  }

  /// The TAC (first 8 digits) identifies the manufacturer and model family.
  /// Useful as a last-resort hint when an IMEI is not yet registered.
  static String? tac(String? imei) {
    if (imei == null || imei.length < 8) return null;
    return imei.substring(0, 8);
  }
}
