/// Things the offline assistant can actually do.
///
/// The online model can only talk: it has no tools, so a request like "open the
/// stockroom" gets a polite sentence back and the user still has to find the
/// menu. The offline engine has an advantage there — it runs inside the app and
/// knows the routes — so it takes the action and says so.
///
/// Deliberately read-only. Every action below moves the user to a screen; none
/// of them writes a row. An assistant that can post a sale or an expense without
/// a confirmation step is a way to lose money to a misheard sentence, and a
/// speech-to-text mishearing is exactly the input this will get.
library;

/// One thing the assistant can offer after answering.
class AssistantAction {
  const AssistantAction({
    required this.label,
    required this.labelSw,
    required this.route,
  });

  /// Button text, e.g. "Open stockroom".
  final String label;
  final String labelSw;

  /// A route that already exists in `app_router.dart`.
  final String route;

  String labelFor({required bool swahili}) => swahili ? labelSw : label;
}

/// Words that ask a question rather than give an order.
const _questionWords = [
  'ngapi', 'kiasi', 'wangapi', 'vipi', 'nini', 'how many', 'how much',
  'what', 'which', 'why', 'when', 'who', 'show me the total', 'total',
];

/// Verbs that turn a noun into an instruction. Without one of these a bare noun
/// ("stock") is ambiguous - it could be "open stock" or "how much stock", and
/// the answer already covers the second.
const _openVerbs = [
  'open', 'go to', 'goto', 'take me', 'show me', 'bring up', 'navigate',
  'fungua', 'nionyeshe', 'nipe', 'nilete', 'peleka', 'enda',
];

/// Pairs of (trigger words, action). Order matters: the first match wins, so the
/// more specific phrases sit above the broader ones.
const _table = <(List<String>, AssistantAction)>[
  (
    ['petty cash', 'matumizi', 'expense', 'gharama'],
    AssistantAction(
      label: 'Open petty cash',
      labelSw: 'Fungua matumizi',
      route: '/petty-cash',
    ),
  ),
  (
    ['daily closing', 'close the shop', 'funga duka', 'funga siku', 'reconcile'],
    AssistantAction(
      label: 'Open daily closing',
      labelSw: 'Fungua kufunga siku',
      route: '/daily-closing',
    ),
  ),
  (
    ['transfer', 'transfers', 'hamisha', 'uhamisho'],
    AssistantAction(
      label: 'Open transfer',
      labelSw: 'Fungua uhamisho',
      route: '/transfer',
    ),
  ),
  (
    ['receive', 'shipment', 'pokea', 'shehena'],
    AssistantAction(
      label: 'Open receive stock',
      labelSw: 'Fungua kupokea stoo',
      route: '/receive',
    ),
  ),
  (
    ['attendance', 'clock in', 'mahudhurio', 'saa za kazi'],
    AssistantAction(
      label: 'Open attendance',
      labelSw: 'Fungua mahudhurio',
      route: '/attendance',
    ),
  ),
  (
    ['scan', 'imei', 'scanner'],
    AssistantAction(
      label: 'Open scanner',
      labelSw: 'Fungua skena',
      route: '/scanner',
    ),
  ),
  (
    ['sell', 'new sale', 'counter', 'uza', 'mauzo mapya', 'pos'],
    AssistantAction(
      label: 'Open the counter',
      labelSw: 'Fungua kaunta',
      route: '/sell-loan',
    ),
  ),
  (
    ['loan', 'loans', 'mkopo', 'mikopo', 'borrower', 'mkopaji'],
    AssistantAction(
      label: 'Open loans',
      labelSw: 'Fungua mikopo',
      route: '/loans',
    ),
  ),
  (
    ['stock', 'stocks', 'inventory', 'stoo', 'bidhaa', 'simu'],
    AssistantAction(
      label: 'Open stockroom',
      labelSw: 'Fungua stoo',
      route: '/stock',
    ),
  ),
  (
    ['report', 'reports', 'ripoti', 'takwimu'],
    AssistantAction(
      label: 'Open reports',
      labelSw: 'Fungua ripoti',
      route: '/reports',
    ),
  ),
  (
    ['branch', 'branches', 'tawi', 'matawi', 'console'],
    AssistantAction(
      label: 'Open branch console',
      labelSw: 'Fungua matawi',
      route: '/admin',
    ),
  ),
  (
    ['notification', 'notifications', 'taarifa', 'alerts'],
    AssistantAction(
      label: 'Open notifications',
      labelSw: 'Fungua taarifa',
      route: '/notifications',
    ),
  ),
  (
    ['setting', 'settings', 'mipangilio', 'profile', 'wasifu'],
    AssistantAction(
      label: 'Open settings',
      labelSw: 'Fungua mipangilio',
      route: '/settings',
    ),
  ),
];

bool _hasWord(String haystack, String needle) {
  final escaped = RegExp.escape(needle.trim());
  return RegExp('(^|[^a-z])$escaped([^a-z]|\$)').hasMatch(haystack);
}

/// Reads an instruction out of [query], or returns null when the question is
/// not asking for a screen.
///
/// Two conditions, both required: a known destination, and either an opening
/// verb or a bare destination with no question word in it. "How many phones in
/// stock?" mentions stock but asks a question, and navigating away mid-answer
/// would be worse than useless.
AssistantAction? parseAssistantAction(String query) {
  final q = query.toLowerCase().trim();
  if (q.isEmpty) return null;

  final asksQuestion = q.contains('?') || _questionWords.any((w) => _hasWord(q, w));
  final hasVerb = _openVerbs.any((w) => q.contains(w));

  for (final (triggers, action) in _table) {
    final mentions = triggers.any((t) => _hasWord(q, t));
    if (!mentions) continue;
    if (asksQuestion && !hasVerb) return null;
    return action;
  }
  return null;
}
