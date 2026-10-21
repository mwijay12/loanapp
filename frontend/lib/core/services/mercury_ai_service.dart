import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'store_facts.dart';

/// Mercury 2.5 AI Assistant service using Inception Labs API.
/// Ultra-fast response with high quality retail loan and inventory reasoning.
class MercuryAiService {
  static const String _endpoint = 'https://api.inceptionlabs.ai/v1/chat/completions';

  // API keys injected at build time, comma-separated:
  // flutter run --dart-define=MERCURY_API_KEYS=sk_xxx,sk_yyy
  // Never hardcode live keys in source control.
  static const String _keysRaw = String.fromEnvironment('MERCURY_API_KEYS');

  List<String> get _apiKeys =>
      _keysRaw.isEmpty ? const [] : _keysRaw.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

  int _keyIndex = 0;

  String get _currentKey =>
      _apiKeys.isEmpty ? '' : _apiKeys[_keyIndex % _apiKeys.length];

  void _rotateKey() {
    if (_apiKeys.isEmpty) return;
    _keyIndex = (_keyIndex + 1) % _apiKeys.length;
  }

  /// Send prompt to Mercury 2.5 with live store context
  Future<String> queryAi({
    required String userPrompt,
    required List<Map<String, String>> chatHistory,
    Map<String, dynamic>? branchContext,
    StoreFacts? facts,
    bool swahili = false,
  }) async {
    if (_apiKeys.isEmpty) {
      return _localFallbackResponse(userPrompt, facts, swahili: swahili);
    }
    // Context comes from the facts object, never from a literal. The old prompt
    // filled missing values with "TZS 4,850,000" and "86 accounts", so even a
    // correctly configured model was told fiction and repeated it confidently.
    final storeFacts = branchContext == null
        ? null
        : StoreFacts(
            branch: (branchContext['branch'] ?? '—').toString(),
            salesCount: (branchContext['salesCount'] as num?)?.toInt() ?? 0,
            salesTotal: (branchContext['salesTotal'] as num?)?.toInt() ?? 0,
            cashTotal: (branchContext['cashTotal'] as num?)?.toInt() ?? 0,
            creditTotal: (branchContext['creditTotal'] as num?)?.toInt() ?? 0,
            stockUnits: (branchContext['stockUnits'] as num?)?.toInt() ?? 0,
            modelCount: (branchContext['modelCount'] as num?)?.toInt() ?? 0,
            lowStock: const [],
            loansActive: (branchContext['loansActive'] as num?)?.toInt() ?? 0,
            loansOverdue: (branchContext['loansOverdue'] as num?)?.toInt() ?? 0,
            overdueOutstanding:
                (branchContext['overdueOutstanding'] as num?)?.toInt() ?? 0,
            collectedToday: (branchContext['collectedToday'] as num?)?.toInt() ?? 0,
            scope: (branchContext['scope'] ?? 'demo').toString(),
          );

    final prompt = storeFacts == null
        ? 'No shop data is loaded.'
        : [
            'Branch: ${storeFacts.branch}',
            'Today: ${storeFacts.salesCount} transactions, '
                '${storeFacts.money(storeFacts.salesTotal)} total, '
                '${storeFacts.money(storeFacts.cashTotal)} cash, '
                '${storeFacts.money(storeFacts.creditTotal)} credit, '
                '${storeFacts.money(storeFacts.collectedToday)} collected',
            'Stock: ${storeFacts.stockUnits} units across '
                '${storeFacts.modelCount} models',
            'Loans: ${storeFacts.loansActive} active, '
                '${storeFacts.loansOverdue} overdue, '
                '${storeFacts.money(storeFacts.overdueOutstanding)} outstanding',
            'Data source: ${storeFacts.scope}',
          ].join('\n');

    final systemPrompt = """
You answer questions about one phone shop in Tanzania, from the figures below and
nothing else.

$prompt

Rules:
- Use only the figures above. If a number is not listed, say it is not available.
  Never estimate, forecast, or fill a gap with an example.
- No sales targets, growth rates, or staff attendance: this system does not record
  them.
- If the data source is demo, say once that these are demo figures.
- Answer in the language of the question (English or Kiswahili).
- Plain text with short bullets, no markdown symbols.
""";

    final messages = <Map<String, dynamic>>[
      {'role': 'system', 'content': systemPrompt},
    ];

    for (final msg in chatHistory) {
      messages.add(msg);
    }
    messages.add({'role': 'user', 'content': userPrompt});

    for (int attempt = 0; attempt < 3; attempt++) {
      try {
        final response = await http.post(
          Uri.parse(_endpoint),
          headers: {
            'Authorization': 'Bearer $_currentKey',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'model': 'mercury-2.5',
            'reasoning_effort': 'low',
            'messages': messages,
          }),
        ).timeout(const Duration(seconds: 12));

        if (response.statusCode == 200) {
          final data = jsonDecode(utf8.decode(response.bodyBytes));
          final choices = data['choices'] as List?;
          if (choices != null && choices.isNotEmpty) {
            final content = choices[0]['message']?['content'] as String?;
            if (content != null && content.trim().isNotEmpty) {
              return content.trim();
            }
          }
        } else if (response.statusCode == 429 || response.statusCode == 401) {
          // Rate limit au auth error -> zungusha key
          _rotateKey();
          continue;
        }
      } catch (_) {
        _rotateKey();
      }
    }

    // Fallback if offline or all keys timed out
    return _localFallbackResponse(userPrompt, storeFacts, swahili: swahili);
  }

  /// Offline answers, computed from the facts the caller passed in.
  ///
  /// This replaced a block of canned paragraphs that answered every build without
  /// an API key — which was every build — with 18 phones, TZS 7,420,000 and an 85%
  /// target that exist nowhere in the database.
  String _localFallbackResponse(
    String query,
    StoreFacts? facts, {
    bool swahili = false,
  }) {
    if (facts == null) {
      return swahili
          ? 'Data ya duka haijapakiwa bado. Fungua upya ukurasa wa mwanzo kisha uulize tena.'
          : 'Shop data has not loaded yet. Reopen the home screen, then ask again.';
    }
    return answerFromFacts(query, facts, swahili: swahili).text;
  }
}

final mercuryAiServiceProvider = Provider<MercuryAiService>((ref) => MercuryAiService());
