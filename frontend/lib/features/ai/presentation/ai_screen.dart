import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/mercury_ai_service.dart';
import '../../../core/services/ai_actions.dart';
import '../../../core/services/offline_sales.dart';
import '../../../core/services/store_facts.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../home/presentation/dashboard_kit.dart';

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
      ? const [
          'Mauzo ya leo',
          'Modeli zinazoisha',
          'Mikopo iliyochelewa',
          'Stoo yote'
        ]
      : const [
          "Today's sales summary",
          'Which phones are low?',
          'Overdue loans',
          'Total stock'
        ];

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
      var facts = StoreFacts.fromProviders(ref);
      // Sales the till took while the line was down are not in the database, so
      // the facts above do not see them. Fold them in before the answer is
      // composed, or the assistant contradicts the cashier's own drawer.
      try {
        final held = await const OfflineSaleQueue().pending();
        if (held.isNotEmpty) {
          facts = facts.copyWith(
            queuedCount: held.length,
            queuedTotal: held.fold<int>(0, (sum, q) => sum + q.total),
          );
        }
      } catch (_) {
        // A queue that cannot be read is not a reason to refuse the question.
      }
      final swahili = ref.read(localeProvider).languageCode == 'sw';
      final reply = await aiService.ask(
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
          _messages.add(_Message(
            text: reply.text,
            isUser: false,
            local: reply.source == AiSource.local,
            // Only the offline engine can act: the model has no tools, so a
            // button on its reply would be a promise nothing keeps.
            action: reply.source == AiSource.local
                ? parseAssistantAction(query)
                : null,
          ));
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
            local: true,
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
      backgroundColor: DashPalette.page,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: DashPalette.pageGradient,
            stops: DashPalette.pageStops,
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
                child: DashPageHeader(
                  title: swahili ? 'Msaidizi wa LIMS' : 'LIMS Assistant',
                  subtitle: swahili
                      ? 'Husoma data ya duka lako'
                      : 'Reads your shop data',
                  onBack: () => Navigator.of(context).pop(),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    return _MessageBubble(message: _messages[index]);
                  },
                ),
              ),

              if (_isLoading)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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
                        child: const Icon(Icons.auto_awesome_rounded,
                            size: 15, color: Color(0xFF7C5CFC)),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        swahili ? 'Inafikiria…' : 'Thinking…',
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF7C5CFC)),
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
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
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
                          style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.ink900),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            hintText: 'Ask about stock, loans, sales…',
                            hintStyle: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF9AA8BF),
                                fontWeight: FontWeight.w500),
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
                        child: const Icon(Icons.send_rounded,
                            color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Message {
  final String text;
  final bool isUser;

  /// True when the reply was assembled from the shop's rows instead of written
  /// by a model. Shown on the bubble: the two read the same, and only one of
  /// them can be wrong about a total.
  final bool local;

  /// A screen this reply can take the user to, when the offline engine
  /// recognised an instruction. Null for ordinary answers.
  final AssistantAction? action;

  _Message({
    required this.text,
    required this.isUser,
    this.local = false,
    this.action,
  });
}

class _MessageBubble extends ConsumerWidget {
  final _Message message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        child: _buildContent(context, ref),
      ),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref) {
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
          padding:
              EdgeInsets.only(bottom: isHeader ? 4 : 2, top: isHeader ? 4 : 0),
          child: RichText(
            text: TextSpan(children: spans),
          ),
        ),
      );
    }

    if (message.local) {
      // Says plainly where the sentence came from. Without this the two kinds
      // of reply are indistinguishable, and only one of them can be wrong.
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.offline_bolt_rounded,
                  size: 12, color: AppTheme.ink400),
              const SizedBox(width: 5),
              Text(
                ref.watch(localeProvider).languageCode == 'sw'
                    ? 'Imehesabiwa kutoka data yako · bila mtandao'
                    : 'Computed from your books · offline',
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.ink400,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final action = message.action;
    if (action != null) {
      final swahili = ref.watch(localeProvider).languageCode == 'sw';
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              // `go`, not `push`. The assistant lives outside the shell that
              // owns /stock and friends, so pushing a shell route stacked a
              // second shell with no child in it: the sidebar appeared, the
              // selected item moved, and the page itself came up blank.
              onTap: () => GoRouter.of(context).go(action.route),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.brand600,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      action.labelFor(swahili: swahili),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.arrow_forward_rounded,
                        size: 14, color: Colors.white),
                  ],
                ),
              ),
            ),
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
