import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/inventory_provider.dart';
import '../data/sales_provider.dart';
import 'live_data.dart';

/// The numbers the assistant is allowed to say.
///
/// The old assistant answered "Today's sales summary" with "18 phones, TZS
/// 7,420,000, 60% cash, 40% loan, 85% of target reached" while the database held
/// 3 sales totalling TZS 1,716,000 and no target at all. Those figures came from a
/// hardcoded fallback string, and the same string answered every build with no API
/// key — which is every build. A shop making decisions on invented takings is
/// worse off than one with no assistant.
///
/// So the assistant no longer composes numbers. It reads [StoreFacts], and every
/// figure it prints is a field below. If a question asks for something not in
/// here — a target, last month, a forecast — the answer says it is not available.
class StoreFacts {
  const StoreFacts({
    required this.branch,
    required this.salesCount,
    required this.salesTotal,
    required this.cashTotal,
    required this.creditTotal,
    required this.stockUnits,
    required this.modelCount,
    required this.lowStock,
    required this.loansActive,
    required this.loansOverdue,
    required this.overdueOutstanding,
    required this.collectedToday,
    required this.scope,
  });

  final String branch;
  final int salesCount;
  final int salesTotal;
  final int cashTotal;
  final int creditTotal;
  final int stockUnits;
  final int modelCount;

  /// Model name to units remaining, worst first.
  final List<MapEntry<String, int>> lowStock;

  final int loansActive;
  final int loansOverdue;
  final int overdueOutstanding;

  /// Money received against today's sales (deposits included, not the financed
  /// remainder).
  final int collectedToday;

  /// "live" or "demo" — because a demo branch has demo takings, and saying
  /// otherwise would be the same lie in a quieter voice.
  final String scope;

  bool get isEmpty => salesCount == 0 && stockUnits == 0 && loansActive == 0;

  static StoreFacts fromProviders(WidgetRef ref) {
    final sales = ref.watch(salesProvider);
    final products = ref.watch(inventoryProvider);
    final loans = ref.watch(loansProvider);
    final branch = ref.watch(activeBranchProvider);
    final scope = ref.watch(dataSourceProvider).kind == DataSourceKind.live
        ? 'live'
        : 'demo';

    final today = sales.where((s) => isEatToday(s.soldAt));

    var cash = 0;
    var credit = 0;
    var collected = 0;
    for (final s in today) {
      final isCredit = s.kind.toUpperCase() == 'LOAN';
      if (isCredit) {
        credit += s.total;
      } else {
        cash += s.total;
      }
      collected += s.paid;
    }

    final low = products
        .where((p) => p.stock <= p.min || p.status == 'low')
        .map((p) => MapEntry(p.name, p.stock))
        .toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    final active = loans.where((l) => l.status != 'settled').toList();
    final overdue = active.where((l) => l.status == 'overdue').toList();

    return StoreFacts(
      branch: branch,
      salesCount: today.length,
      salesTotal: cash + credit,
      cashTotal: cash,
      creditTotal: credit,
      stockUnits: products.fold<int>(0, (sum, p) => sum + p.stock),
      modelCount: products.length,
      lowStock: low,
      loansActive: active.length,
      loansOverdue: overdue.length,
      overdueOutstanding: overdue.fold<int>(
        0,
        (sum, l) => sum + l.remainingAmount,
      ),
      collectedToday: collected,
      scope: scope,
    );
  }

  /// Compact money for chat: 1,716,000 -> "TZS 1,716,000".
  String money(int value) {
    final s = value.toString();
    final out = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) out.write(',');
      out.write(s[i]);
    }
    return 'TZS $out';
  }
}

/// Answers built only from [StoreFacts].
///
/// Deliberately without a model: intent plus the row data is enough for the four
/// questions the counter actually asks, and a template cannot invent a total.
class StoreAnswer {
  const StoreAnswer(this.text, {this.sourced = true});

  final String text;

  /// False when the question asked for something the shop does not record.
  final bool sourced;
}

StoreAnswer answerFromFacts(
  String query,
  StoreFacts f, {
  required bool swahili,
}) {
  final q = query.toLowerCase();
  bool has(List<String> words) => words.any(q.contains);

  final money = f.money;

  if (has(['sales', 'mauzo', 'revenue', 'mapato', 'leo'])) {
    if (f.salesCount == 0) {
      return StoreAnswer(swahili
          ? 'Hakuna mauzo yaliyorekodiwa leo katika ${f.branch}.'
          : 'No sales recorded today at ${f.branch}.');
    }
    final lines = <String>[
      swahili
          ? 'Mauzo ya leo · ${f.branch}'
          : "Today's sales · ${f.branch}",
      swahili
          ? '• Miamala: ${f.salesCount}'
          : '• Transactions: ${f.salesCount}',
      swahili ? '• Jumla: ${money(f.salesTotal)}' : '• Total: ${money(f.salesTotal)}',
      swahili
          ? '• Fedha: ${money(f.cashTotal)} · Mkopo: ${money(f.creditTotal)}'
          : '• Cash: ${money(f.cashTotal)} · Credit: ${money(f.creditTotal)}',
      swahili
          ? '• Zilizokusanywa: ${money(f.collectedToday)}'
          : '• Collected: ${money(f.collectedToday)}',
    ];
    if (f.scope == 'demo') {
      lines.add(swahili
          ? 'Data hii ni ya majaribio (demo), sio mauzo halisi.'
          : 'This is demo data, not real takings.');
    }
    return StoreAnswer(lines.join('\n'));
  }

  if (has(['low stock', 'low', 'stoo ndogo', 'zinaisha', 'restock', 'imebaki'])) {
    if (f.lowStock.isEmpty) {
      return StoreAnswer(swahili
          ? 'Hakuna model iliyo chini ya kiwango cha akiba ${f.branch}.'
          : 'No model is below its buffer level at ${f.branch}.');
    }
    final top = f.lowStock.take(5).toList();
    final lines = <String>[
      swahili
          ? 'Modeli ${f.lowStock.length} chini ya kiwango:'
          : '${f.lowStock.length} models below buffer:',
      for (final e in top)
        swahili ? '• ${e.key}: ${e.value} zimebaki' : '• ${e.key}: ${e.value} left',
    ];
    return StoreAnswer(lines.join('\n'));
  }

  if (has(['stock', 'stoo', 'simu', 'inventory', 'bidhaa'])) {
    return StoreAnswer([
      swahili ? 'Stoo · ${f.branch}' : 'Stock · ${f.branch}',
      swahili
          ? '• Vifaa: ${f.stockUnits} katika modeli ${f.modelCount}'
          : '• Units: ${f.stockUnits} across ${f.modelCount} models',
      swahili
          ? '• Chini ya kiwango: ${f.lowStock.length}'
          : '• Below buffer: ${f.lowStock.length}',
    ].join('\n'));
  }

  if (has(['overdue', 'over due', 'imechelewa', 'chelewa', 'arrears'])) {
    if (f.loansOverdue == 0) {
      return StoreAnswer(swahili
          ? 'Hakuna mkopo uliochelewa kwa sasa.'
          : 'No loan is overdue right now.');
    }
    return StoreAnswer([
      swahili ? 'Mikopo iliyochelewa:' : 'Overdue loans:',
      swahili
          ? '• Idadi: ${f.loansOverdue} kati ya ${f.loansActive}'
          : '• Count: ${f.loansOverdue} of ${f.loansActive}',
      swahili
          ? '• Salio: ${money(f.overdueOutstanding)}'
          : '• Outstanding: ${money(f.overdueOutstanding)}',
    ].join('\n'));
  }

  if (has(['loan', 'mkopo', 'mikopo', 'credit'])) {
    return StoreAnswer([
      swahili ? 'Mikopo · ${f.branch}' : 'Loans · ${f.branch}',
      swahili
          ? '• Hai: ${f.loansActive} · Iliyochelewa: ${f.loansOverdue}'
          : '• Active: ${f.loansActive} · Overdue: ${f.loansOverdue}',
      swahili
          ? '• Salio la iliyochelewa: ${money(f.overdueOutstanding)}'
          : '• Overdue outstanding: ${money(f.overdueOutstanding)}',
    ].join('\n'));
  }

  if (has(['hello', 'hi ', 'habari', 'mambo', 'help', 'nisaidie', 'what can'])) {
    return StoreAnswer(swahili
        ? 'Naweza kukujibu kutoka data ya duka lako: mauzo ya leo, stoo, modeli zinazoisha, mikopo na mikopo iliyochelewa.'
        : 'I can answer from your shop data: today\'s sales, stock, models running low, loans and overdue loans.');
  }

  // No model runs behind this screen, so anything else is honestly out of reach.
  return StoreAnswer(
    swahili
        ? 'Sina jibu la hilo kutoka data ya duka. Naweza kukujibu kuhusu mauzo ya leo, stoo, modeli zinazoisha, mikopo na mikopo iliyochelewa.'
        : "I can't answer that from your shop data. I can cover today's sales, stock, models running low, loans and overdue loans.",
    sourced: false,
  );
}
