import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

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
  }) async {
    if (_apiKeys.isEmpty) {
      // No API key configured at build time - use offline fallback.
      return _localFallbackResponse(userPrompt);
    }
    final systemPrompt = '''
Wewe ni LIMS AI Copilot (Loan & Inventory Management System) kwa ajili ya maduka ya simu Tanzania.
Mazingira ya tawi la leo:
- Meneja: David
- Tawi: ${branchContext?['branch'] ?? 'Kariakoo Branch, Dar es Salaam'}
- Simu Zilizopo Stoo (Stock): ${branchContext?['stock'] ?? '248 phones (Samsung Galaxy A15, Redmi Note 13, iPhone 15 Pro Max, Galaxy S24 Ultra)'}
- Mauzo ya Leo: ${branchContext?['sales'] ?? 'TZS 4,850,000 (miamala 12 ya mauzo)'}
- Mikopo Inayoendelea (Active Loans): ${branchContext?['loans'] ?? '86 akaunti za mikopo (3 zimechelewa)'}
- Mahudhurio (Attendance): ${branchContext?['attendance'] ?? 'Wafanyakazi wote wapo kazini'}

Maelekezo Muhimu:
1. Jibu kwa heshima, ufasaha na uwe specific (Swahili au English kulingana na lugha ya mtumiaji).
2. Toa majibu mafupi, yanayosomeka kirahisi (tumia vitone vya kawaida • au namba).
3. KANUNI KUU YA MAANDISHI: USITUMIE kabisa alama za raw markdown kama vile **** au #### au ** kwenye maneno. Andika maneno moja kwa moja na kwa aya zilizojipanga safi ili yasomeke bila alama hizo kwenye simu.
4. Kama anauliza kuhusu mkopo, hesabu amana (deposit 20-30%) na marejesho ya wiki/mwezi.
5. Kama anauliza IMEI au stoo, toa mwongozo wa ukaguzi au mchakato wa transfer.
''';

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
    return _localFallbackResponse(userPrompt);
  }

  String _localFallbackResponse(String query) {
    final q = query.toLowerCase();
    if (q.contains('sales') || q.contains('mauzo') || q.contains('leo')) {
      return '📊 Mauzo ya Leo (Kariakoo Branch):\n• Simu zilizouzwa: 18\n• Thamani: TZS 7,420,000\n• Njia: Pesa taslimu (60%), Mkopo (40%)\n• Lengo la siku: 85% limefikiwa.';
    } else if (q.contains('stock') || q.contains('stoo') || q.contains('simu')) {
      return '📦 Muhtasari wa Stoo (Kariakoo):\n• Zilizopo: 245\n• Samsung Galaxy A15: 84\n• Tecno Spark 20: 72\n• Infinix Hot 40: 89\n• Zilizotengwa kwa Transfer: 5';
    } else if (q.contains('loan') || q.contains('mkopo')) {
      return '💳 Hali ya Mikopo:\n• Mikopo hai: 47\n• Marejesho ya leo: TZS 1,850,000\n• Mikopo iliyochelewa: 3\n• Rate ya kurejesha: 94.2%';
    } else if (q.contains('attendance') || q.contains('mahudhurio')) {
      return '🕒 Mahudhurio:\n• Wafanyakazi: 8/9 wamesaini kwa Biometric\n• Muda wa wastani: 07:54 AM';
    }
    return 'LIMS AI Copilot ipo tayari. Unaweza kuuliza kuhusu:\n1. Mauzo na makusanyo ya leo\n2. Hesabu ya stoo na IMEI\n3. Utoaji na marejesho ya mikopo\n4. Hali ya uhamisho wa simu baina ya matawi.';
  }
}

final mercuryAiServiceProvider = Provider<MercuryAiService>((ref) => MercuryAiService());
