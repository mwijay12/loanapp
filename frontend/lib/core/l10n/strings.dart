import 'dart:ui';

/// Two languages, one dictionary.
///
/// The app mixed both tongues inside single screens — a Swahili heading above
/// English rows, "Nyumbani (Home)" on a tab, an English button in a Swahili
/// paragraph. A language switch existed in Settings, but it only moved the date
/// formatter; the words never changed.
///
/// Keys are grouped by screen so a missing translation is visible in the file
/// rather than at runtime. English is the default and the fallback: a key with no
/// Swahili entry renders English rather than the raw key, which is ugly but
/// readable.
///
/// Adding a screen means adding its block here and calling [tr] with the locale
/// the widgets already watch.
const Map<String, Map<String, String>> _dictionary = {
  // ---------------------------------------------------------------- navigation
  'nav.home': {'en': 'Home', 'sw': 'Nyumbani'},
  'nav.inventory': {'en': 'Inventory', 'sw': 'Stoo'},
  'nav.loans': {'en': 'Loans', 'sw': 'Mikopo'},
  'nav.operations': {'en': 'Operations', 'sw': 'Uendeshaji'},
  'nav.scan': {'en': 'Scan', 'sw': 'Skani'},

  // --------------------------------------------------------------------- login
  'login.welcome': {'en': 'Welcome back', 'sw': 'Karibu tena'},
  'login.subtitle': {
    'en': 'Sign in to continue to your branch workspace.',
    'sw': 'Ingia kuendelea na kazi ya tawi lako.',
  },
  'login.email': {'en': 'Work email', 'sw': 'Barua pepe ya kazi'},
  'login.password': {'en': 'Password', 'sw': 'Neno la siri'},
  'login.remember': {'en': 'Remember me', 'sw': 'Nikumbuke'},
  'login.forgot': {'en': 'Forgot password?', 'sw': 'Umesahau neno la siri?'},
  'login.signIn': {'en': 'Sign in', 'sw': 'Ingia'},
  'login.demoHint': {
    'en': 'Tap a demo account to fill the form',
    'sw': 'Gusa akaunti ya majaribio kujaza fomu',
  },

  // ---------------------------------------------------------------------- home
  'home.todaySales': {'en': "Today's Sales", 'sw': 'Mauzo ya Leo'},
  'home.transactionsToday': {
    'en': 'transactions today',
    'sw': 'miamala leo',
  },
  'home.totalStock': {'en': 'Total Stock', 'sw': 'Jumla ya Stoo'},
  'home.activeLoans': {'en': 'Active Loans', 'sw': 'Mikopo Hai'},
  'home.soldToday': {'en': 'sold today', 'sw': 'zimeuzwa leo'},
  'home.onTime': {'en': 'on-time', 'sw': 'kwa wakati'},
  'home.accounts': {'en': 'accounts', 'sw': 'akaunti'},
  'home.phones': {'en': 'phones', 'sw': 'simu'},
  'home.lowStock': {'en': 'low stock alerts', 'sw': 'tahadhari za stoo ndogo'},
  'home.overduePayments': {
    'en': 'overdue payments',
    'sw': 'malipo yaliyochelewa',
  },
  'home.featured': {
    'en': 'Featured Phone Deals & Loan Offers',
    'sw': 'Ofa za Simu na Mikopo',
  },
  'home.swipe': {'en': 'Swipe', 'sw': 'Telezesha'},
  'home.issueLoan': {'en': 'Issue Loan', 'sw': 'Toa Mkopo'},
  'home.adminHub': {'en': 'Admin Executive Hub', 'sw': 'Kitovu cha Msimamizi'},
  'home.hqSubtitle': {
    'en': 'HQ Multi-Branch Oversight & Audits',
    'sw': 'Usimamizi wa Matawi na Ukaguzi',
  },
  'home.fullConsole': {'en': 'Full Console', 'sw': 'Console Kamili'},
  'home.stockValue': {'en': 'Stock Value', 'sw': 'Thamani ya Stoo'},
  'home.salesToday': {'en': 'Sales Today', 'sw': 'Mauzo ya Leo'},
  'home.overdue': {'en': 'Overdue', 'sw': 'Yaliyochelewa'},
  'home.models': {'en': 'models', 'sw': 'modeli'},
  'home.branches': {'en': 'branches', 'sw': 'matawi'},
  'home.loansPastDue': {'en': 'loans past due', 'sw': 'mikopo iliyochelewa'},
  'home.branchOps': {'en': 'Branch operations', 'sw': 'Uendeshaji wa tawi'},
  'home.collections': {'en': 'Collections', 'sw': 'Makusanyo'},

  // ------------------------------------------------------------------ settings
  'settings.language': {'en': 'Language', 'sw': 'Lugha'},
  'settings.languageHint': {
    'en': 'Applies across the whole app.',
    'sw': 'Inatumika kote kwenye app.',
  },
  'settings.english': {'en': 'English', 'sw': 'Kiingereza'},
  'settings.swahili': {'en': 'Swahili', 'sw': 'Kiswahili'},

  // ------------------------------------------------------------------- generic
  'common.save': {'en': 'Save', 'sw': 'Hifadhi'},
  'common.cancel': {'en': 'Cancel', 'sw': 'Ghairi'},
  'common.close': {'en': 'Close', 'sw': 'Funga'},
  'common.retry': {'en': 'Try again', 'sw': 'Jaribu tena'},
};

/// Resolve a key for the given locale. English wins when a translation is absent
/// so a missing entry never reaches the screen as `home.totalStock`.
String tr(Locale locale, String key) {
  final entry = _dictionary[key];
  if (entry == null) return key;
  final lang = locale.languageCode;
  return entry[lang] ?? entry['en'] ?? key;
}

/// Every key, for a coverage check in tests.
Iterable<String> get allStringKeys => _dictionary.keys;

/// Keys that have no Swahili entry, so the gap is testable.
Iterable<String> get untranslatedKeys =>
    _dictionary.entries.where((e) => e.value['sw'] == null).map((e) => e.key);
