import 'package:flutter_test/flutter_test.dart';

import 'package:loan_inventory_app/core/data/supabase_source.dart';

/// Money arrives from Postgres as formatted text, so the reader has to survive
/// it. These cases are copied from the live rows.
void main() {
  group('parseMoney', () {
    test('reads grouped thousands', () {
      expect(SupabaseSource.parseMoney('3,850,000'), 3850000);
      expect(SupabaseSource.parseMoney('2,400,000'), 2400000);
    });

    test('reads the compact branch form', () {
      expect(SupabaseSource.parseMoney('TZS 4.85M'), 4850000);
      expect(SupabaseSource.parseMoney('TZS 1.42M'), 1420000);
      expect(SupabaseSource.parseMoney('620K'), 620000);
      expect(SupabaseSource.parseMoney('1.2B'), 1200000000);
    });

    test('passes numbers through', () {
      expect(SupabaseSource.parseMoney(3850000), 3850000);
      expect(SupabaseSource.parseMoney(2400000.0), 2400000);
    });

    test('returns zero rather than throwing on junk', () {
      expect(SupabaseSource.parseMoney(null), 0);
      expect(SupabaseSource.parseMoney(''), 0);
      expect(SupabaseSource.parseMoney('—'), 0);
      expect(SupabaseSource.parseMoney('TZS'), 0);
    });

    test('a compact suffix is not read as a bare number', () {
      // The bug this prevents: stripping letters from 'TZS 4.85M' leaves '4.85',
      // which would show a 4.8 million shilling branch as 4 shillings.
      expect(SupabaseSource.parseMoney('TZS 4.85M'), isNot(4));
    });
  });
}
