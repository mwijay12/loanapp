import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'store_facts.dart';

/// Which engine produced an answer.
///
/// The screen used to print a model's reply and a template's reply in the same
/// bubble, so a shopkeeper could not tell a sentence read from their own rows
/// from one a model had written. That difference matters when the question is
/// "how much did we take today".
enum AiSource {
  /// A language model wrote this, from the figures handed to it.
  model,

  /// No model was reachable; the answer was assembled from the local rows.
  local,
}

class AiReply {
  const AiReply(this.text, this.source);
  final String text;
  final AiSource source;
}

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

  /// Whether the online proxy has already been found missing.
  ///
  /// The function is deployed separately from the bundle, so an older project
  /// answers 404. Trying it on every message would put a failed request in the
  /// log for each question the cashier asks; one refusal per session is enough
  /// to know this build talks to the local engine only.
  bool _edgeUnavailable = false;

  /// Attaches a payment-channel breakdown for the proxy's system prompt.
  Map<String, dynamic> _payload(
    String prompt,
    List<Map<String, String>> history,
    StoreFacts? facts,
  ) =>
      {
        'prompt': prompt,
        'history': history,
        'facts': facts == null
            ? null
            : {
                'branch': facts.branch,
                'salesCount': facts.salesCount,
                'salesTotal': facts.salesTotal,
                'cashTotal': facts.cashTotal,
                'creditTotal': facts.creditTotal,
                'collectedToday': facts.collectedToday,
                'stockUnits': facts.stockUnits,
                'modelCount': facts.modelCount,
                'lowStock': {
                  for (final e in facts.lowStock.take(10)) e.key: e.value,
                },
                'loansActive': facts.loansActive,
                'loansOverdue': facts.loansOverdue,
                'overdueOutstanding': facts.overdueOutstanding,
                'scope': facts.scope,
              },
      };

  /// Ask the assistant, and say who answered.
  ///
  /// Order matters: the served proxy first (the key stays on the server), then
  /// a key compiled into this build for local development, then the shop's own
  /// rows. The last step is not a degraded mode - it is the one that works on a
  /// bad line in Kariakoo, and it cannot invent a number.
  Future<AiReply> ask({
    required String userPrompt,
    required List<Map<String, String>> chatHistory,
    Map<String, dynamic>? branchContext,
    StoreFacts? facts,
    bool swahili = false,
  }) async {
    if (!_edgeUnavailable) {
      try {
        final res = await Supabase.instance.client.functions.invoke(
          'ai-assistant',
          body: _payload(userPrompt, chatHistory, facts),
        );
        final answer = res.data is Map ? res.data['answer'] : null;
        if (answer is String && answer.trim().isNotEmpty) {
          return AiReply(answer.trim(), AiSource.model);
        }
      } catch (_) {
        _edgeUnavailable = true;
      }
    }

    if (_apiKeys.isNotEmpty) {
      final online = await _askDirect(
        userPrompt: userPrompt,
        chatHistory: chatHistory,
        branchContext: branchContext,
        facts: facts,
        swahili: swahili,
      );
      if (online != null) return AiReply(online, AiSource.model);
    }

    return AiReply(
      _localFallbackResponse(userPrompt, facts, swahili: swahili),
      AiSource.local,
    );
  }

  /// Send prompt to Mercury 2.5 with live store context
  Future<String> queryAi({
    required String userPrompt,
    required List<Map<String, String>> chatHistory,
    Map<String, dynamic>? branchContext,
    StoreFacts? facts,
    bool swahili = false,
  }) async {
    final online = await _askDirect(
      userPrompt: userPrompt,
      chatHistory: chatHistory,
      branchContext: branchContext,
      facts: facts,
      swahili: swahili,
    );
    return online ?? _localFallbackResponse(userPrompt, facts, swahili: swahili);
  }

  /// The direct-to-provider call, kept for a build that has its own key.
  ///
  /// Returns null when no key answered, so the caller decides what to show
  /// rather than being handed a template dressed as a model reply.
  Future<String?> _askDirect({
    required String userPrompt,
    required List<Map<String, String>> chatHistory,
    Map<String, dynamic>? branchContext,
    StoreFacts? facts,
    bool swahili = false,
  }) async {
    if (_apiKeys.isEmpty) return null;
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

    // Offline, or every key refused. Null says so.
    return null;
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
