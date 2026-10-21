import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/mercury_ai_service.dart';
import '../../../core/services/store_facts.dart';
import '../../../core/l10n/locale_provider.dart';

class AIScreen extends ConsumerStatefulWidget {
  const AIScreen({super.key});

  @override
  ConsumerState<AIScreen> createState() => _AIScreenState();
}

class _AIScreenState extends ConsumerState<AIScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<_Message> _messages = [];
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;

  /// Chips are answered by the same code as typed questions, so every one of them
  /// returns real rows.
  List<String> _chips(bool swahili) => swahili
      ? const ['Mauzo ya leo', 'Modeli zinazoisha', 'Mikopo iliyochelewa', 'Stoo yote']
      : const ["Today's sales summary", 'Which phones are low?', 'Overdue loans', 'Total stock'];

  @override
  void initState() {
    super.initState();
    // The greeting used to name a model and promise live answers even with no key
    // configured. It now states what it reads: this shop's own rows.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final swahili = ref.read(localeProvider).languageCode == 'sw';
      setState(() {
        _messages.add(_Message(
          text: swahili
              ? 'Habari. Naweza kukujibu kutoka data ya duka lako: mauzo ya leo, stoo, modeli zinazoisha, mikopo na mikopo iliyochelewa.'
              : "Hello. I answer from your shop's own data: today's sales, stock, models running low, loans and overdue loans.",
          isUser: false,
        ));
      });
    });
  }

  void _sendMessage(String text) async {
    final query = text.trim();
    if (query.isEmpty || _isLoading) return;

    setState(() {
      _messages.add(_Message(text: query, isUser: true));
      _isLoading = true;
    });

    _controller.clear();
    _scrollToBottom();

    // Prepare chat history
    final history = <Map<String, String>>[];
    for (final m in _messages.take(_messages.length - 1)) {
      history.add({
        'role': m.isUser ? 'user' : 'assistant',
        'content': m.text,
      });
    }

    try {
      final aiService = ref.read(mercuryAiServiceProvider);
      final facts = StoreFacts.fromProviders(ref);
      final swahili = ref.read(localeProvider).languageCode == 'sw';
      final response = await aiService.queryAi(
        userPrompt: query,
        chatHistory: history,
        facts: facts,
        swahili: swahili,
        branchContext: {
          'branch': facts.branch,
          'salesCount': facts.salesCount,
          'salesTotal': facts.salesTotal,
          'cashTotal': facts.cashTotal,
          'creditTotal': facts.creditTotal,
          'stockUnits': facts.stockUnits,
          'modelCount': facts.modelCount,
          'loansActive': facts.loansActive,
          'loansOverdue': facts.loansOverdue,
          'overdueOutstanding': facts.overdueOutstanding,
          'collectedToday': facts.collectedToday,
          'scope': facts.scope,
        },
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
          _messages.add(_Message(text: response, isUser: false));
        });
        _scrollToBottom();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          final facts = StoreFacts.fromProviders(ref);
          final swahili = ref.read(localeProvider).languageCode == 'sw';
          _messages.add(_Message(
            text: answerFromFacts(query, facts, swahili: swahili).text,
            isUser: false,
          ));
        });
        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final swahili = ref.watch(localeProvider).languageCode == 'sw';
    return Scaffold(
      backgroundColor: AppTheme.canvas,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.ink900),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF7C5CFC), Color(0xFF5B34EA)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 19),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'LIMS Assistant',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.ink900,
                  ),
                ),
                Text(
                  'Reads your shop data',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF12B76A),
                  ),
                ),
              ],
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFE2E8F0), height: 1),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  return _MessageBubble(message: _messages[index]);
                },
              ),
            ),

            if (_isLoading)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                alignment: Alignment.centerLeft,
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0EBFF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.auto_awesome_rounded, size: 15, color: Color(0xFF7C5CFC)),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Mercury 2.5 is thinking…',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF7C5CFC)),
                    ),
                  ],
                ),
              ),

            // Chips
            Container(
              height: 40,
              margin: const EdgeInsets.only(bottom: 8),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _chips(swahili).length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final text = _chips(swahili)[index];
                  return InkWell(
                    onTap: () => _sendMessage(text),
                    borderRadius: BorderRadius.circular(99),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x080F3478),
                            blurRadius: 10,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        text,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.ink700,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Input bar
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4F9FF),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: TextField(
                        controller: _controller,
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppTheme.ink900),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: 'Ask about stock, loans, sales…',
                          hintStyle: TextStyle(fontSize: 13, color: Color(0xFF9AA8BF), fontWeight: FontWeight.w500),
                        ),
                        onSubmitted: _sendMessage,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  InkWell(
                    onTap: () => _sendMessage(_controller.text),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppTheme.brand600,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x331B6EF3),
                            blurRadius: 12,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Message {
  final String text;
  final bool isUser;

  _Message({required this.text, required this.isUser});
}

class _MessageBubble extends StatelessWidget {
  final _Message message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.84,
        ),
        decoration: BoxDecoration(
          color: message.isUser ? AppTheme.brand600 : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(message.isUser ? 18 : 4),
            bottomRight: Radius.circular(message.isUser ? 4 : 18),
          ),
          boxShadow: [
            BoxShadow(
              color: message.isUser
                  ? const Color(0x221B6EF3)
                  : const Color(0x0C0F3478),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: _buildContent(context),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (message.isUser) {
      return Text(
        message.text,
        style: const TextStyle(
          fontSize: 13.5,
          color: Colors.white,
          height: 1.45,
          fontWeight: FontWeight.w600,
        ),
      );
    }

    // Clean and parse response without raw markdown symbols like **** or ####
    final rawLines = message.text.split('\n');
    final widgets = <Widget>[];

    for (final rawLine in rawLines) {
      var line = rawLine.trim();
      if (line.isEmpty) {
        widgets.add(const SizedBox(height: 6));
        continue;
      }

      // Check if it's a header like #### or ### or ## or #
      bool isHeader = false;
      if (line.startsWith('#')) {
        isHeader = true;
        line = line.replaceFirst(RegExp(r'^#+\s*'), '');
      }

      // Check if bullet point
      bool isBullet = false;
      if (line.startsWith('* ') || line.startsWith('- ')) {
        isBullet = true;
        line = line.substring(2);
      }

      // Clean redundant quadruple asterisks or stray asterisks
      line = line.replaceAll('****', '**');

      // Parse bold **word** segments
      final spans = <TextSpan>[];
      if (isBullet) {
        spans.add(const TextSpan(
          text: '• ',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: AppTheme.brand600,
          ),
        ));
      }

      final parts = line.split('**');
      for (int i = 0; i < parts.length; i++) {
        final part = parts[i];
        if (part.isEmpty) continue;

        final isBold = i % 2 == 1 || isHeader;
        spans.add(TextSpan(
          text: part,
          style: TextStyle(
            fontSize: isHeader ? 14 : 13.5,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w500,
            color: isHeader
                ? AppTheme.brand600
                : (isBold ? AppTheme.ink900 : const Color(0xFF26334D)),
            height: 1.45,
          ),
        ));
      }

      widgets.add(
        Padding(
          padding: EdgeInsets.only(bottom: isHeader ? 4 : 2, top: isHeader ? 4 : 0),
          child: RichText(
            text: TextSpan(children: spans),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: widgets,
    );
  }
}
