// End-to-end check that the app can read the live project.
//
// Run from frontend/:
//   dart run tool/live_check.dart <supabase-url> <publishable-key>
//
// It speaks the same REST calls the Flutter client makes and runs the rows
// through the same parser, so a green result here means the data layer works —
// not just that the network is up.

import 'dart:convert';
import 'dart:io';

Future<List<Map<String, dynamic>>> fetch(
  String base,
  String key,
  String table, {
  int limit = 3,
}) async {
  final client = HttpClient();
  final uri = Uri.parse('$base/rest/v1/$table?select=*&limit=$limit');
  final req = await client.getUrl(uri);
  req.headers.set('apikey', key);
  req.headers.set('Authorization', 'Bearer $key');
  final res = await req.close();
  final body = await res.transform(utf8.decoder).join();
  client.close();

  if (res.statusCode != 200) {
    stderr.writeln('  $table -> HTTP ${res.statusCode}: ${body.substring(0, body.length < 160 ? body.length : 160)}');
    return [];
  }
  final decoded = jsonDecode(body);
  if (decoded is! List) return [];
  return decoded.cast<Map<String, dynamic>>();
}

/// Mirrors SupabaseSource.parseMoney, so this check exercises the same rules.
int parseMoney(dynamic raw) {
  if (raw == null) return 0;
  if (raw is int) return raw;
  if (raw is num) return raw.round();
  var s = raw.toString().trim().toUpperCase();
  if (s.isEmpty) return 0;
  var mult = 1;
  if (s.endsWith('B')) {
    mult = 1000000000;
    s = s.substring(0, s.length - 1);
  } else if (s.endsWith('M')) {
    mult = 1000000;
    s = s.substring(0, s.length - 1);
  } else if (s.endsWith('K')) {
    mult = 1000;
    s = s.substring(0, s.length - 1);
  }
  s = s.replaceAll(RegExp(r'[^0-9.\-]'), '');
  final v = double.tryParse(s);
  return v == null ? 0 : (v * mult).round();
}

Future<void> main(List<String> args) async {
  if (args.length < 2) {
    stderr.writeln('usage: dart run tool/live_check.dart <url> <publishable-key>');
    exit(64);
  }
  final base = args[0].replaceAll(RegExp(r'/$'), '');
  final key = args[1];

  stdout.writeln('Project: $base');

  var failures = 0;

  final products = await fetch(base, key, 'products', limit: 50);
  stdout.writeln('\nproducts: ${products.length} rows');
  for (final p in products.take(3)) {
    final price = parseMoney(p['price']);
    stdout.writeln(
        '  ${p['name']} | price "${p['price']}" -> $price | stock ${p['stock']} | cat ${p['category']}');
    if (price <= 0) {
      failures++;
      stdout.writeln('  ! price did not parse');
    }
    for (final col in ['imei1', 'imei2', 'brand', 'cost_price']) {
      if (!p.containsKey(col)) {
        stdout.writeln('  ! missing column: $col');
      }
    }
  }

  final loans = await fetch(base, key, 'loans', limit: 50);
  stdout.writeln('\nloans: ${loans.length} rows');
  if (loans.isNotEmpty) {
    final l = loans.first;
    stdout.writeln(
        '  ${l['borrower_name']} | amount "${l['amount']}" -> ${parseMoney(l['amount'])} | ${l['status']}');
    for (final col in [
      'imei',
      'phone',
      'nida',
      'deposit',
      'weekly_installment',
      'installment_weeks',
      'guarantor_name',
    ]) {
      if (!l.containsKey(col)) {
        stdout.writeln('  ! missing column: $col (cannot store a receipt)');
        failures++;
      }
    }
  }

  final branches = await fetch(base, key, 'branches');
  stdout.writeln('\nbranches: ${branches.length} rows');
  for (final b in branches.take(2)) {
    stdout.writeln('  ${b['name']} | sales "${b['sales']}" -> ${parseMoney(b['sales'])}');
  }

  final activities = await fetch(base, key, 'activities');
  stdout.writeln('\nactivities: ${activities.length} rows');

  final profiles = await fetch(base, key, 'profiles');
  stdout.writeln('\nprofiles: ${profiles.length} rows');
  if (profiles.isNotEmpty && profiles.first.containsKey('password_hash')) {
    failures++;
    stdout.writeln('  ! password_hash is readable with this key — remove it');
  }

  stdout.writeln('\n${failures == 0 ? 'OK' : 'ISSUES: $failures'}');
  exit(failures == 0 ? 0 : 1);
}
