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
/// Values may contain `{placeholders}`. Screens fill them with [trf] rather than
/// concatenating fragments, because word order differs between the two languages
/// and a sentence glued together from pieces cannot be translated honestly.
const Map<String, Map<String, String>> _dictionary = {
  // ---------------------------------------------------------------- navigation
  'nav.home': {'en': 'Home', 'sw': 'Nyumbani'},

  // Storekeeper dashboard
  'skdash.welcome': {'en': 'Welcome Back,', 'sw': 'Karibu Tena,'},
  // Time-aware salutations. The band is chosen from the East Africa clock
  // (`salutationKeyAt`), not from a fixed string, so the first line of the home
  // screen is different at dawn and at dusk.
  'greet.morning': {'en': 'Good morning', 'sw': 'Habari za asubuhi'},
  'greet.afternoon': {'en': 'Good afternoon', 'sw': 'Habari za mchana'},
  'greet.evening': {'en': 'Good evening', 'sw': 'Habari za jioni'},

  // List / grid switch, and the long-press sheets it shares a vocabulary with.
  'view.list': {'en': 'List view', 'sw': 'Mwonekano wa orodha'},
  'view.grid': {'en': 'Grid view', 'sw': 'Mwonekano wa gridi'},
  'action.openDetails': {'en': 'Open details', 'sw': 'Fungua maelezo'},
  'action.quickActions': {'en': 'Quick actions', 'sw': 'Vitendo vya haraka'},
  'loans.peekTitle': {'en': 'Borrower at a glance', 'sw': 'Mkopaji kwa muhtasari'},
  'skdash.searchHint': {
    'en': 'Search IMEI, model, serial...',
    'sw': 'Tafuta IMEI, modeli, serial...',
  },
  'skdash.searchEmpty': {
    'en': 'Enter an IMEI or serial number first.',
    'sw': 'Ingiza IMEI au namba ya kifaa kwanza.',
  },
  'skdash.alertsOne': {
    'en': '1 low stock alert',
    'sw': 'tahadhari 1 ya stoo ndogo'
  },
  'skdash.alertsMany': {
    'en': '{n} low stock alerts',
    'sw': 'tahadhari {n} za stoo ndogo',
  },
  'skdash.alertsNone': {
    'en': 'No low stock alerts',
    'sw': 'Hakuna tahadhari ya stoo'
  },
  'skdash.todayActivity': {
    'en': "Today's Stock Activity",
    'sw': 'Shughuli za Stoo Leo'
  },
  'skdash.addedPos': {
    'en': '{imeis} IMEIs added · {pos} POs',
    'sw': 'IMEI {imeis} zimeongezwa · PO {pos}',
  },
  'skdash.handsetsInStock': {
    'en': 'handsets in stock',
    'sw': 'simu zilizopo stoo'
  },
  'skdash.viewInventory': {'en': 'View Inventory', 'sw': 'Angalia Stoo'},
  'skdash.services': {'en': 'Services', 'sw': 'Huduma'},
  'skdash.aiTitle': {'en': 'AI Assistant', 'sw': 'Msaidizi wa AI'},
  'skdash.aiSub': {'en': 'Ask anything', 'sw': 'Uliza chochote'},
  'skdash.recentActivity': {
    'en': 'Recent Activity',
    'sw': 'Shughuli za Karibuni'
  },
  'skdash.receiveStock': {'en': 'Receive Stock', 'sw': 'Pokea Stoo'},
  'skdash.dispatch': {'en': 'Dispatch', 'sw': 'Safirisha'},
  'skdash.scanImei': {'en': 'Scan IMEI', 'sw': 'Skani IMEI'},
  'skdash.reports': {'en': 'Reports', 'sw': 'Ripoti'},
  'skdash.mvSupplier': {
    'en': 'New stock received',
    'sw': 'Stoo mpya imepokelewa'
  },
  'skdash.mvTransfer': {'en': 'Dispatched', 'sw': 'Imesafirishwa'},
  'skdash.mvReturn': {'en': 'Customer return', 'sw': 'Marejeo ya mteja'},
  'skdash.mvUnits': {'en': '{n} units', 'sw': 'vifaa {n}'},
  'skdash.mvEmptyTitle': {
    'en': 'Nothing received yet',
    'sw': 'Hakuna kilichopokelewa bado',
  },
  'skdash.mvEmpty': {
    'en':
        'No stock movements recorded yet. Receive a delivery and it will appear here.',
    'sw': 'Bado hakuna shughuli za stoo. Pokea mzigo na itaonekana hapa.',
  },
  'skdash.mvError': {
    'en': 'Stock movements could not be loaded.',
    'sw': 'Shughuli za stoo hazikuweza kupakiwa.',
  },
  'skdash.retry': {'en': 'Retry', 'sw': 'Jaribu tena'},
  'skdash.notConnected': {
    'en': 'Not connected to the database',
    'sw': 'Haijaunganishwa na hifadhidata',
  },

  // Role home screens (cashier, loan officer, branch manager, auditor)
  'dash.counter': {'en': 'Counter POS Actions', 'sw': 'Vitendo vya Kaunta'},
  'dash.cashTill': {'en': "Today's Till", 'sw': 'Kasha la Leo'},
  'dash.cashSales': {'en': '{n} receipts today', 'sw': 'risiti {n} leo'},
  'dash.cashNoSales': {
    'en': 'No sale has been rung up yet today.',
    'sw': 'Bado hakuna mauzo yaliyofanyika leo.',
  },
  'dash.newSale': {'en': 'New POS Sale', 'sw': 'Uza Sasa'},
  'dash.newSaleSub': {'en': 'Cash or loan checkout', 'sw': 'Taslimu au mkopo'},
  'dash.customers': {'en': 'Customer Directory', 'sw': 'Orodha ya Wateja'},
  'dash.customersSub': {'en': 'Profiles & status', 'sw': 'Wasifu na hali'},
  'dash.scanCabinet': {'en': 'Scan Cabinet', 'sw': 'Skani Kabati'},
  'dash.scanCabinetSub': {'en': 'Check stock ready', 'sw': 'Hakiki stoo ipo'},
  'dash.clockShift': {'en': 'Clock Shift', 'sw': 'Saa za Zamu'},
  'dash.clockShiftSub': {'en': 'Till log & drawer', 'sw': 'Kumbukumbu ya kasha'},
  'dash.register': {'en': "Today's Register", 'sw': 'Daftari la Leo'},
  'dash.registerEmpty': {
    'en': 'The register is empty. A completed sale appears here immediately.',
    'sw': 'Daftari ni tupu. Mauzo yanayokamilika yanaonekana hapa papo hapo.',
  },
  'dash.cash': {'en': 'Cash', 'sw': 'Fedha taslimu'},
  'dash.loanKind': {'en': 'Loan', 'sw': 'Mkopo'},

  'dash.credit': {'en': 'Credit Portfolio', 'sw': 'Mikopo Iliyotolewa'},
  'dash.creditOutstanding': {'en': 'Still to collect', 'sw': 'Kinachosubiriwa'},
  'dash.creditCaption': {
    'en': '{active} active · {overdue} overdue',
    'sw': '{active} hai · {overdue} zimechelewa',
  },
  'dash.creditReview': {'en': 'Review Credit Book', 'sw': 'Kagua Mikopo'},
  'dash.creditOps': {'en': 'Credit Operations', 'sw': 'Shughuli za Mikopo'},
  'dash.issueLoan': {'en': 'Issue Loan', 'sw': 'Toa Mkopo'},
  'dash.issueLoanSub': {'en': 'KYC & collateral', 'sw': 'KYC na dhamana'},
  'dash.creditReviewTile': {'en': 'Credit Review', 'sw': 'Kagua Maombi'},
  'dash.creditReviewSub': {'en': 'Approve tier 1 & 2', 'sw': 'Idhinisha daraja 1 na 2'},
  'dash.inspector': {'en': 'Hardware Inspector', 'sw': 'Ukaguzi wa Kifaa'},
  'dash.inspectorSub': {'en': 'Verify phone IMEI', 'sw': 'Hakiki IMEI ya simu'},
  'dash.collections': {'en': 'Collections', 'sw': 'Makusanyo'},
  'dash.collectionsSub': {'en': 'Overdue queue', 'sw': 'Foleni ya mcheleweshaji'},
  'dash.dueBook': {'en': 'Overdue Accounts', 'sw': 'Mikopo Iliyochelewa'},
  'dash.dueEmpty': {
    'en': 'No loan is past due. Nothing to chase today.',
    'sw': 'Hakuna mkopo uliochelewa. Hakuna wa kufuatilia leo.',
  },
  'dash.dueItem': {'en': '{item} · {paid}% paid', 'sw': '{item} · {paid}% imelipwa'},
  // The home shows one line about arrears and sends the officer to the loan
  // book. Listing borrowers on the dashboard pushed the actions off-screen.
  'dash.dueAlertSub': {
    'en': '{amount} still to recover',
    'sw': '{amount} bado kurejeshwa',
  },
  'dash.dueClearSub': {
    'en': 'Every account is on schedule',
    'sw': 'Kila akaunti iko kwenye ratiba',
  },

  'dash.branchToday': {'en': 'Branch Today', 'sw': 'Tawi Leo'},
  'dash.branchCaption': {
    'en': '{n} receipts · {stock} handsets on hand',
    'sw': 'risiti {n} · simu {stock} zipo',
  },
  'dash.branchConsole': {'en': 'Branch Console', 'sw': 'Console ya Tawi'},
  'dash.branchOps': {'en': 'Branch Operations', 'sw': 'Uendeshaji wa Tawi'},
  'dash.salesAudit': {'en': 'Sales Audit', 'sw': 'Kagua Mauzo'},
  'dash.salesAuditSub': {'en': 'Reconcile tills', 'sw': 'Linganisha makasha'},
  'dash.supervisorPin': {'en': 'Supervisor PIN', 'sw': 'PIN ya Msimamizi'},
  'dash.supervisorPinSub': {'en': 'Discount overrides', 'sw': 'Idhini ya punguzo'},
  'dash.branchStock': {'en': 'Branch Stock', 'sw': 'Stoo ya Tawi'},
  'dash.branchStockSub': {'en': 'Cabinet & safe buffer', 'sw': 'Kabati na akiba'},
  'dash.staffShifts': {'en': 'Staff Shifts', 'sw': 'Zamu za Wafanyakazi'},
  'dash.staffShiftsSub': {'en': 'Attendance roster', 'sw': 'Orodha ya mahudhurio'},
  'dash.lowStockTile': {'en': 'Low stock', 'sw': 'Stoo ndogo'},
  'dash.overdueTile': {'en': 'Overdue loans', 'sw': 'Mikopo iliyochelewa'},
  'dash.onTimeTile': {'en': 'On-time rate', 'sw': 'Kiwango cha wakati'},

  'dash.auditAccess': {'en': 'Read-only access', 'sw': 'Ufikiaji wa kusoma tu'},
  'dash.readOnly': {'en': 'Read-only', 'sw': 'Kusoma tu'},
  'dash.auditBody': {
    'en':
        'Registers, loan history and reports are open to you. Creating, editing, approving or disbursing is not available to this role.',
    'sw':
        'Daftari, historia ya mikopo na ripoti ziko wazi kwako. Kuunda, kuhariri, kuidhinisha au kutoa fedha hakupo kwa jukumu hili.',
  },
  'dash.auditBooks': {'en': 'Registers & Reports', 'sw': 'Daftari na Ripoti'},
  'dash.salesRegister': {'en': 'Sales Register', 'sw': 'Daftari la Mauzo'},
  'dash.salesRegisterSub': {'en': 'Every receipt, by day', 'sw': 'Kila risiti, kwa siku'},
  'dash.loanLedger': {'en': 'Loan Ledger', 'sw': 'Daftari la Mikopo'},
  'dash.loanLedgerSub': {'en': 'History & balances', 'sw': 'Historia na salio'},
  'dash.stockRegister': {'en': 'Stock Register', 'sw': 'Daftari la Stoo'},
  'dash.stockRegisterSub': {'en': 'Units & movements', 'sw': 'Vifaa na mienendo'},
  'dash.imeiInspector': {'en': 'Device & IMEI Inspector', 'sw': 'Ukaguzi wa IMEI'},
  'dash.imeiInspectorSub': {'en': 'Check a serial', 'sw': 'Hakiki namba ya kifaa'},

  'nav.inventory': {'en': 'Inventory', 'sw': 'Stoo'},
  'nav.loans': {'en': 'Loans', 'sw': 'Mikopo'},
  // The door a Storekeeper gets instead of Loans. It is not a rename of
  // nav.inventory: both words appear in the same dock for a Branch Manager, so
  // sharing one key would put two icons under one name.
  'nav.stockroom': {'en': 'Stock Room', 'sw': 'Chumba cha Stoo'},
  'nav.operations': {'en': 'Operations', 'sw': 'Uendeshaji'},
  'nav.reports': {'en': 'Reports', 'sw': 'Ripoti'},
  'nav.console': {'en': 'Branch Console', 'sw': 'Dashibodi ya Tawi'},
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

  // ----------------------------------------------------------------- transfer
  'transfer.title': {'en': 'Transfer stock', 'sw': 'Hamisha stock'},
  'transfer.from': {'en': 'FROM', 'sw': 'KUTOKA'},
  'transfer.to': {'en': 'TO', 'sw': 'KWENDA'},
  'transfer.noBranches': {
    'en': 'There is no second open branch to send stock to.',
    'sw': 'Hakuna tawi lingine lililo wazi la kupeleka stock.',
  },
  'transfer.devices': {
    'en': 'Devices at this branch',
    'sw': 'Vifaa vilivyopo tawi hili'
  },
  'transfer.inStock': {'en': 'in stock', 'sw': 'zipo stock'},
  'transfer.selected': {'en': 'selected', 'sw': 'zimechaguliwa'},
  'transfer.atThisBranch': {'en': 'at this branch', 'sw': 'katika tawi hili'},
  'transfer.all': {'en': 'Select all', 'sw': 'Chagua zote'},
  'transfer.clear': {'en': 'Clear', 'sw': 'Ondoa zote'},
  'transfer.useSelection': {
    'en': 'Use selection',
    'sw': 'Tumia zilizochaguliwa'
  },
  'transfer.unspecified': {'en': 'Unspecified handset', 'sw': 'Simu bila jina'},
  'transfer.noUnitsTitle': {
    'en': 'No serials at this branch yet',
    'sw': 'Hakuna serial tawi hili bado',
  },
  'transfer.noUnitsBody': {
    'en':
        'A transfer moves individual handsets, so the serials have to be on file first. Receive the delivery with its IMEIs scanned, and those devices appear here.',
    'sw':
        'Uhamishaji unaondoa simu halisi, kwa hiyo serial lazima ziwe kwenye kumbukumbu kwanza. Pokea mzigo ukiwa umepima IMEI, na hizo simu zitaonekana hapa.',
  },
  'transfer.noDatabase': {
    'en':
        'This build has no database connection, so branch stock cannot be listed.',
    'sw':
        'Build hii haina muunganisho wa database, kwa hiyo stock ya tawi haiwezi kuorodheshwa.',
  },
  'transfer.chooseDestination': {
    'en': 'Choose the branch receiving the stock.',
    'sw': 'Chagua tawi linalopokea stock.',
  },
  'transfer.chooseUnits': {
    'en': 'Select at least one handset.',
    'sw': 'Chagua angalau simu moja.',
  },
  'transfer.sendEmpty': {
    'en': 'Select devices to send',
    'sw': 'Chagua vifaa vya kupeleka'
  },
  'transfer.send': {'en': 'Send', 'sw': 'Tuma'},
  'transfer.unit': {'en': 'unit', 'sw': 'kifaa'},
  'transfer.units': {'en': 'units', 'sw': 'vifaa'},
  'transfer.sent': {'en': 'transferred', 'sw': 'zimehamishwa'},
  'transfer.reference': {'en': 'reference', 'sw': 'kumbukumbu'},
  'transfer.failed': {
    'en': 'The transfer was not recorded. Nothing moved.',
    'sw': 'Uhamishaji haukuandikwa. Hakuna kilichohama.',
  },
  'transfer.noteTotals': {
    'en':
        'Company stock does not change: the phones changed branch, not owner.',
    'sw': 'Stock ya kampuni haibadiliki: simu zimebadili tawi, sio mmiliki.',
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
  'deals.onOffer': {'en': 'ON OFFER', 'sw': 'OFA MAALUM'},
  'deals.inStock': {'en': '{n} IN STOCK', 'sw': '{n} STOO'},
  // State only; the unit count lives on the spec line under the handset.
  'deals.inStockLabel': {'en': 'IN STOCK', 'sw': 'STOO'},

  'deals.units': {'en': '{n} units', 'sw': 'vipande {n}'},
  'deals.deposit': {'en': 'Deposit', 'sw': 'Malipo ya kwanza'},
  'deals.perWeek': {'en': '/wk', 'sw': '/wiki'},
  'stock.onOffer': {'en': 'On offer at the till', 'sw': 'Iko kwenye ofa kaunta'},
  'stock.onOfferSub': {
    'en':
        'Show this handset on the cashier home. Use it for models that have been sitting on the shelf.',
    'sw':
        'Onyesha simu hii kwenye ukurasa wa mhudumu. Tumia kwa modeli zilizokaa muda mrefu stoo.',
  },
  'stock.markOffer': {'en': 'Put on offer', 'sw': 'Weka kwenye ofa'},
  'stock.clearOffer': {'en': 'Take off offer', 'sw': 'Ondoa kwenye ofa'},
  'stock.offerSaved': {'en': 'Offer updated.', 'sw': 'Ofa imehifadhiwa.'},
  'stock.offerSession': {
    'en': 'Saved on this device for now — no database is connected.',
    'sw': 'Imehifadhiwa kwenye kifaa hiki kwa sasa — hakuna hifadhidata iliyounganishwa.',
  },
  'stock.offerMigration': {
    'en':
        'Not saved: the offers column is missing. Run 2026_10_22_05_product_offers.sql in Supabase.',
    'sw':
        'Haijahifadhiwa: safu ya ofa haipo. Endesha 2026_10_22_05_product_offers.sql kwenye Supabase.',
  },
  'stock.offerFailed': {
    'en': 'The offer was not saved. Try again.',
    'sw': 'Ofa haijahifadhiwa. Jaribu tena.',
  },
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

  // The compact home that replaced eight stacked sections.
  'home.greetingMorning': {'en': 'Good morning', 'sw': 'Habari za asubuhi'},
  'home.greetingAfternoon': {'en': 'Good afternoon', 'sw': 'Habari za mchana'},
  'home.greetingEvening': {'en': 'Good evening', 'sw': 'Habari za jioni'},
  'home.summary': {'en': 'Today at a glance', 'sw': 'Muhtasari wa leo'},
  'home.quickActions': {'en': 'Quick actions', 'sw': 'Vitendo vya haraka'},
  'home.needsAttention': {
    'en': 'Needs attention',
    'sw': 'Zinahitaji kushughulikiwa'
  },
  'home.allClear': {
    'en': 'Nothing needs attention right now.',
    'sw': 'Hakuna kinachohitaji kushughulikiwa sasa.',
  },
  'home.viewAll': {'en': 'View all', 'sw': 'Ona zote'},
  'home.restockModels': {
    'en': '{n} models need restocking',
    'sw': 'modeli {n} zinahitaji kuongezewa',
  },
  'home.overdueAccounts': {
    'en': '{n} accounts are overdue',
    'sw': 'akaunti {n} zimechelewa',
  },
  'home.pendingShipments': {
    'en': '{n} shipments waiting at the door',
    'sw': 'mizigo {n} inasubiri mlangoni',
  },

  'home.refresh': {
    'en': 'Refresh from database',
    'sw': 'Sasisha kutoka database'
  },
  'home.notifications': {'en': 'Notifications', 'sw': 'Taarifa'},
  'home.live': {'en': 'Live', 'sw': 'Hai'},
  'home.offline': {'en': 'Offline', 'sw': 'Nje ya mtandao'},
  'home.txCount': {'en': '{n} transactions today', 'sw': 'miamala {n} leo'},
  'home.refreshed': {
    'en': 'Synced: {products} products, {loans} loans',
    'sw': 'Imesasishwa: bidhaa {products}, mikopo {loans}',
  },
  'home.refreshEmpty': {
    'en': 'The database returned no rows.',
    'sw': 'Database haikurejesha rows.',
  },
  'home.pinNotEnforced': {
    'en': 'Supervisor approval is not enforced yet on this device.',
    'sw': 'Idhini ya msimamizi bado haijatekelezwa kwenye kifaa hiki.',
  },

  // Quick actions: one vocabulary for every role.
  'action.adminHub': {'en': 'Admin hub', 'sw': 'Kitovu cha msimamizi'},
  'action.adminHubSub': {
    'en': 'Staff & roles',
    'sw': 'Wafanyakazi na majukumu'
  },
  'action.audit': {'en': 'Stock audits', 'sw': 'Ukaguzi wa stoo'},
  'action.auditSub': {'en': 'Verify IMEI balance', 'sw': 'Hakiki IMEI'},
  'action.reports': {'en': 'Reports', 'sw': 'Ripoti'},
  'action.reportsSub': {'en': 'Sales & margins', 'sw': 'Mauzo na faida'},
  'action.transfers': {'en': 'Transfers', 'sw': 'Uhamishaji'},
  'action.transfersSub': {'en': 'Between branches', 'sw': 'Kati ya matawi'},
  'action.newSale': {'en': 'New sale', 'sw': 'Mauzo mapya'},
  'action.newSaleSub': {'en': 'Cash or loan', 'sw': 'Fedha au mkopo'},
  'action.stock': {'en': 'Branch stock', 'sw': 'Stoo ya tawi'},
  'action.stockSub': {'en': 'Shelves & buffer', 'sw': 'Rafu na akiba'},
  'action.shifts': {'en': 'Staff shifts', 'sw': 'Zamu za kazi'},
  'action.shiftsSub': {'en': 'Attendance', 'sw': 'Mahudhurio'},
  'action.issueLoan': {'en': 'Issue loan', 'sw': 'Toa mkopo'},
  'action.issueLoanSub': {'en': 'KYC & collateral', 'sw': 'KYC na dhamana'},
  'action.collections': {'en': 'Collections', 'sw': 'Makusanyo'},
  'action.collectionsSub': {
    'en': 'Overdue queue',
    'sw': 'Orodha ya ucheleweshaji'
  },
  'action.scan': {'en': 'Scan IMEI', 'sw': 'Skani IMEI'},
  'action.scanSub': {'en': 'Verify a handset', 'sw': 'Hakiki kifaa'},
  'action.borrowers': {'en': 'Borrowers', 'sw': 'Wakopaji'},
  'action.borrowersSub': {
    'en': 'Contracts & balances',
    'sw': 'Mikataba na salio'
  },
  'action.receive': {'en': 'Receive stock', 'sw': 'Pokea stoo'},
  'action.receiveSub': {'en': 'Supplier intake', 'sw': 'Mapokezi ya mzigo'},
  'action.count': {'en': 'Physical count', 'sw': 'Hesabu ya rafu'},
  'action.countSub': {'en': 'Cabinet audit', 'sw': 'Ukaguzi wa kabati'},
  'action.customers': {'en': 'Customers', 'sw': 'Wateja'},
  'action.customersSub': {'en': 'Profiles & status', 'sw': 'Wasifu na hali'},

  // ------------------------------------------------------------------ settings
  'settings.language': {'en': 'Language', 'sw': 'Lugha'},
  'settings.languageHint': {
    'en': 'Applies across the whole app.',
    'sw': 'Inatumika kote kwenye app.',
  },
  'settings.english': {'en': 'English', 'sw': 'Kiingereza'},
  'settings.swahili': {'en': 'Swahili', 'sw': 'Kiswahili'},

  // --------------------------------------------------------------------- loans
  'loans.eyebrow': {
    'en': 'Credit & Borrower Portfolio',
    'sw': 'Mikopo na Wateja',
  },
  'loans.title': {
    'en': 'Borrowers & Active Contracts',
    'sw': 'Wakopaji na Mikataba Hai',
  },
  'loans.issue': {'en': 'Issue loan', 'sw': 'Toa mkopo'},
  'loans.kpiActive': {'en': 'Active borrowers', 'sw': 'Wakopaji hai'},
  'loans.kpiOverdue': {'en': 'In arrears', 'sw': 'Wenye deni'},
  'loans.kpiOnSchedule': {'en': 'On schedule', 'sw': 'Kwa wakati'},
  // Shown when loans_read refuses the signed-in role. The role is interpolated
  // rather than hardcoded because the same screen is reached by a Storekeeper
  // and by a Counter Cashier; naming the wrong one would be a second lie on top
  // of the blank table this screen replaces.
  'loans.lockedTitle': {
    'en': 'Borrower files are not part of your role',
    'sw': 'Faili za wakopaji si sehemu ya jukumu lako'
  },
  'loans.lockedBody': {
    'en':
        'Loan records hold customer details, so the database lets a {role} see '
        'the handset a borrower is holding but not who they are. How you see '
        'that same stock is under Stock Room.',
    'sw':
        'Rekodi za mikopo zina taarifa za wateja, kwa hivyo database inamruhusu '
        '{role} kuona simu ambayo mkopaji anayo, lakini si kujua ni nani. Jinsi '
        'unavyoiona stoo hiyo iko chini ya Chumba cha Stoo.'
  },
  'loans.lockedAction': {'en': 'Open Stock Room', 'sw': 'Fungua Chumba cha Stoo'},
  'loans.search': {
    'en': 'Search customer, phone or IMEI…',
    'sw': 'Tafuta mteja, simu au IMEI…',
  },
  'loans.filterAll': {'en': 'All loans ({n})', 'sw': 'Mikopo yote ({n})'},
  'loans.filterOverdue': {'en': 'Overdue ({n})', 'sw': 'Iliyochelewa ({n})'},
  'loans.filterCurrent': {'en': 'On schedule ({n})', 'sw': 'Kwa wakati ({n})'},
  'loans.listTitle': {
    'en': 'Loan & device ledger',
    'sw': 'Orodha ya mikopo na vifaa'
  },
  'loans.total': {'en': 'Total: {n}', 'sw': 'Jumla: {n}'},
  'loans.empty': {
    'en': 'No borrower matches your search',
    'sw': 'Hakuna mkopaji anayelingana na utafutaji wako',
  },
  'loans.showAll': {'en': 'Show all', 'sw': 'Onyesha wote'},
  'loans.overdueBadge': {'en': 'Overdue', 'sw': 'Imechelewa'},
  'loans.paidPercent': {'en': '{n}% paid', 'sw': '{n}% imelipwa'},
  'loans.balance': {'en': 'Balance: {n}', 'sw': 'Salio: {n}'},
  'loans.viewDossier': {
    'en': 'View borrower dossier & schedule',
    'sw': 'Fungua wasifu na ratiba',
  },
  'loans.newTitle': {'en': 'Register new loan', 'sw': 'Sajili mkopo mpya'},
  'loans.newSubtitle': {
    'en': 'Register the borrower and the hire-purchase contract',
    'sw': 'Sajili mkopaji na mkataba wa mauzo ya mkopo',
  },
  'loans.fieldName': {
    'en': 'Full borrower name (e.g. Juma Ally)',
    'sw': 'Jina kamili la mkopaji (mf. Juma Ally)',
  },
  'loans.fieldPhone': {
    'en': 'Borrower phone (+255 7XX XXX XXX)',
    'sw': 'Simu ya mkopaji (+255 7XX XXX XXX)',
  },
  'loans.fieldNida': {
    'en': 'NIDA national ID (20 digits)',
    'sw': 'Namba ya NIDA (tarakimu 20)',
  },
  'loans.fieldTotal': {'en': 'Total loan price', 'sw': 'Bei yote ya mkopo'},
  'loans.fieldDeposit': {
    'en': 'Initial deposit (25%)',
    'sw': 'Malipo ya kwanza (25%)',
  },
  'loans.consent': {
    'en':
        'Borrower and guarantor have signed the hire-purchase contract (PDPA compliant).',
    'sw':
        'Mkopaji na mdhamini wamesaini mkataba wa mauzo ya mkopo (kwa mujibu wa PDPA).',
  },
  'loans.approve': {
    'en': 'Approve & issue handset',
    'sw': 'Kubali na toa simu'
  },
  'loans.disbursedTitle': {'en': 'Loan disbursed', 'sw': 'Mkopo umetolewa'},
  'loans.disbursedBody': {
    'en': '{name} approved and recorded in the active ledger.',
    'sw': '{name} ameidhinishwa na kurekodiwa kwenye daftari.',
  },
  'loans.depositLine': {
    'en': 'Deposit TZS {n}',
    'sw': 'Malipo ya kwanza TZS {n}',
  },
  'loans.noPhones': {
    'en': 'No handsets in stock',
    'sw': 'Hakuna simu stoo',
  },

  // --------------------------------------------------------------------- stock
  'stock.title': {'en': 'Receive stock', 'sw': 'Pokea stoo'},
  'stock.poLine': {
    'en': 'PO #{n} · arrived {t}',
    'sw': 'Oda #{n} · ilifika {t}',
  },
  'stock.units': {'en': '{n} units', 'sw': 'vifaa {n}'},
  'stock.unitsValue': {
    'en': '{n} units · TZS {value}',
    'sw': 'vifaa {n} · TZS {value}',
  },
  'stock.lines': {
    'en': '{n} lines in this delivery',
    'sw': 'mistari {n} kwenye mzigo huu',
  },
  'stock.scannedLine': {
    'en': '{n} units expected · {scanned} IMEIs scanned',
    'sw': 'vifaa {n} vinatarajiwa · IMEI {scanned} zimeskaniwa',
  },
  'stock.scanTitle': {
    'en': 'Scan / add serial IMEI',
    'sw': 'Skani / ongeza IMEI'
  },
  'stock.scanHint': {
    'en': 'Enter or scan the 15-digit GSMA IMEI',
    'sw': 'Weka au skani IMEI ya GSMA yenye tarakimu 15',
  },
  'stock.verify': {'en': 'Verify & add', 'sw': 'Hakiki na ongeza'},
  'stock.scanWithCamera': {'en': 'Scan IMEI label', 'sw': 'Skani lebo ya IMEI'},
  'stock.errLength': {
    'en': 'An IMEI must be exactly 15 digits (this one has {n})',
    'sw': 'IMEI lazima iwe tarakimu 15 kamili (hii ina {n})',
  },
  'stock.errDuplicate': {
    'en': 'IMEI {n} is already in this shipment',
    'sw': 'IMEI {n} tayari iko kwenye mzigo huu',
  },
  'stock.okAdded': {
    'en': 'IMEI {n} verified and added',
    'sw': 'IMEI {n} imehakikiwa na kuongezwa',
  },
  'stock.changePhoto': {
    'en': 'Change shipment photo',
    'sw': 'Badili picha ya mzigo',
  },
  'stock.takePhoto': {'en': 'Take photo', 'sw': 'Piga picha'},
  'stock.gallery': {'en': 'Upload from gallery', 'sw': 'Pakia kutoka galari'},
  'stock.confirmPhoto': {'en': 'Use this photo', 'sw': 'Tumia picha hii'},
  'stock.confirm': {
    'en': 'Confirm receive & update stock',
    'sw': 'Thibitisha na sasisha stoo',
  },
  'stock.received': {
    'en': 'Received & stored in inventory',
    'sw': 'Imepokelewa na kuhifadhiwa',
  },
  'stock.okReceived': {
    'en': 'Stock received: {n} units added to {branch}',
    'sw': 'Stoo imepokelewa: vifaa {n} vimeongezwa {branch}',
  },
  'stock.cameraNeeded': {
    'en': 'Camera permission is required to take a photo.',
    'sw': 'Ruhusa ya kamera inahitajika kupiga picha.',
  },
  'stock.photoSaved': {
    'en': 'Photo captured and compressed.',
    'sw': 'Picha imepigwa na kubanwa.',
  },
  'stock.photoPicked': {
    'en': 'Photo selected from the gallery.',
    'sw': 'Picha imechaguliwa kutoka galari.',
  },
  'stock.activityTitle': {
    'en': 'Stock received · {n} units',
    'sw': 'Stoo imepokelewa · vifaa {n}',
  },
  'stock.receivedAt': {
    'en': 'At {branch} · {scanned} serials scanned',
    'sw': 'Katika {branch} · seriali {scanned} zimeskaniwa',
  },
  'stock.unmatched': {
    'en': 'Not in the catalogue, so not added: {skus}',
    'sw': 'Hazipo kwenye katalogi, hazikuongezwa: {skus}',
  },
  'stock.photoUpdated': {
    'en': 'Photo for {n} updated',
    'sw': 'Picha ya {n} imesasishwa',
  },

  // ---------------------------------------------------------------------- sell
  'sell.eyebrow': {
    'en': 'POS counter sale & loan',
    'sw': 'Mauzo na mikopo kaunta'
  },
  'sell.cashTitle': {'en': 'Cash sale', 'sw': 'Mauzo ya fedha'},
  'sell.loanTitle': {'en': 'Phone loan (financed)', 'sw': 'Mkopo wa simu'},
  'sell.backHome': {'en': 'Back to home', 'sw': 'Rudi nyumbani'},
  'sell.selectHandset': {
    'en': 'Select handset for checkout',
    'sw': 'Chagua simu ya kuuza',
  },
  'sell.selectProduct': {
    'en': 'Select product for checkout',
    'sw': 'Chagua bidhaa ya kuuza',
  },
  'sell.noStockAny': {
    'en': 'No products available in stock',
    'sw': 'Hakuna bidhaa zilizopo stoo',
  },
  'sell.noStock': {
    'en': 'No phones available in stock',
    'sw': 'Hakuna simu zilizopo stoo',
  },
  'sell.stockInBranch': {'en': '{n} in branch', 'sw': '{n} stoo tawi'},
  'sell.changePhone': {'en': 'Change phone', 'sw': 'Badili simu'},
  'sell.cashSale': {'en': 'Cash sale', 'sw': 'Mauzo ya fedha'},
  'sell.creditSale': {'en': 'Credit sale', 'sw': 'Mauzo ya mkopo'},
  'sell.cashPrice': {'en': 'Cash retail price', 'sw': 'Bei ya fedha'},
  'sell.amountDue': {
    'en': 'Amount due (cash total)',
    'sw': 'Kiasi cha kulipa (jumla)'
  },
  'sell.paymentChannel': {'en': 'Payment channel', 'sw': 'Njia ya malipo'},
  'sell.cashAtCounter': {'en': 'Cash at counter', 'sw': 'Fedha kaunta'},
  'sell.mpesa': {'en': 'M-Pesa Lipa Namba', 'sw': 'M-Pesa Lipa Namba'},
  'sell.airtel': {'en': 'Airtel Money', 'sw': 'Airtel Money'},
  'sell.tigopesa': {'en': 'Tigo Pesa', 'sw': 'Tigo Pesa'},
  'sell.card': {'en': 'CRDB / NMB card', 'sw': 'Kadi ya CRDB / NMB'},
  'sell.customerContact': {
    'en': 'Customer contact',
    'sw': 'Mawasiliano ya mteja'
  },
  'sell.customerName': {
    'en': 'Borrower legal full name',
    'sw': 'Jina kamili la mkopaji'
  },
  'sell.customerPhone': {
    'en': 'Customer phone (SMS receipt & warranty)',
    'sw': 'Simu ya mteja (risiti ya SMS na dhamana)',
  },
  'sell.nida': {
    'en': 'National NIDA ID (20 digits)',
    'sw': 'Namba ya NIDA (tarakimu 20)'
  },
  'sell.address': {
    'en': 'Residential ward / street address',
    'sw': 'Mtaa / anuani ya makazi',
  },
  'sell.imei1': {
    'en': 'IMEI 1 (hardware S/N)',
    'sw': 'IMEI 1 (namba ya kifaa)'
  },
  'sell.guarantor': {'en': 'Guarantor reference', 'sw': 'Mdhamini'},
  'sell.guarantorName': {
    'en': 'Guarantor full legal name',
    'sw': 'Jina kamili la mdhamini'
  },
  'sell.guarantorPhone': {
    'en': 'Guarantor phone number',
    'sw': 'Simu ya mdhamini'
  },
  'sell.guarantorNida': {'en': 'Guarantor NIDA ID', 'sw': 'NIDA ya mdhamini'},
  'sell.term': {'en': 'Repayment term', 'sw': 'Muda wa malipo'},
  'sell.weeks': {'en': '{n} weeks', 'sw': 'wiki {n}'},
  'sell.weekly': {
    'en': 'Weekly installment commitment',
    'sw': 'Malipo ya kila wiki',
  },
  'sell.loanPrice': {'en': 'Cash selling price', 'sw': 'Bei ya fedha'},
  'sell.financeFee': {
    'en': 'Disclosed financing fee (+{n}%)',
    'sw': 'Ada ya ufadhili (+{n}%)',
  },
  'sell.deposit': {'en': 'Down payment (deposit)', 'sw': 'Malipo ya kwanza'},
  'sell.financed': {'en': 'Financed loan total', 'sw': 'Jumla ya mkopo'},
  'sell.repayable': {'en': 'Total loan repayable', 'sw': 'Jumla ya kulipa'},
  'sell.viewSchedule': {'en': 'View schedule ({n})', 'sw': 'Ona ratiba ({n})'},
  'sell.hideSchedule': {'en': 'Hide schedule', 'sw': 'Ficha ratiba'},
  'sell.reviewCash': {
    'en': 'Review cash sale · TZS {n}',
    'sw': 'Kagua mauzo · TZS {n}',
  },
  'sell.reviewLoan': {
    'en': 'Review loan · TZS {n} deposit',
    'sw': 'Kagua mkopo · TZS {n} malipo ya kwanza',
  },
  'sell.confirmHandover': {
    'en': 'Confirm & complete handset handover',
    'sw': 'Thibitisha na kamilisha makabidhiano',
  },
  'sell.printReceipt': {'en': 'Print receipt', 'sw': 'Chapisha risiti'},
  'sell.receiptReady': {
    'en': 'Receipt {n} is ready to print.',
    'sw': 'Risiti {n} iko tayari kuchapishwa.',
  },
  'sell.cashDone': {
    'en': 'POS cash sale completed',
    'sw': 'Mauzo ya fedha yamekamilika'
  },
  'sell.loanDone': {
    'en': 'Phone loan disbursed',
    'sw': 'Mkopo wa simu umetolewa'
  },
  'sell.saveFailed': {
    'en': 'Sale NOT recorded: {reason}',
    'sw': 'Mauzo HAYAKUHIFADHIWA: {reason}',
  },
  'sell.saveUnconfirmed': {
    'en':
        'Not saved and not refused — the database did not answer. Check the sales ledger for receipt {n} before trying again.',
    'sw':
        'Haijahifadhiwa wala kukataliwa — hifadhidata haikujibu. Kagua daftari la mauzo kwa risiti {n} kabla ya kujaribu tena.',
  },
  'sell.saveUnknownReason': {
    'en': 'the sale could not be saved.',
    'sw': 'mauzo hayakuweza kuhifadhiwa.',
  },
  'sell.demoNote': {
    'en':
        'Demo build — no database is connected, so nothing was written to the shop ledger and no receipt can be issued.',
    'sw':
        'Toleo la majaribio — hakuna hifadhidata iliyounganishwa, kwa hiyo hakuna kilichohifadhiwa kwenye daftari la duka na hakuna risiti inayoweza kutolewa.',
  },
  'sell.selectedHandset': {
    'en': 'Selected handset',
    'sw': 'Simu iliyochaguliwa'
  },
  'sell.cashIntro': {
    'en':
        'Take payment at the counter and hand over the device with an official receipt.',
    'sw': 'Pokea malipo kaunta na mkabidhi kifaa kwa risiti rasmi.',
  },
  'sell.step1': {
    'en': '1. Borrower KYC verification',
    'sw': '1. Uthibitisho wa KYC wa mkopaji'
  },
  'sell.step2': {'en': '2. Guarantor reference', 'sw': '2. Mdhamini'},
  'sell.step3': {
    'en': '3. Transparent terms & schedule',
    'sw': '3. Masharti na ratiba wazi'
  },
  'sell.step4': {'en': '4. Loan agreement', 'sw': '4. Mkataba wa mkopo'},
  'sell.kycSection': {
    'en': 'Customer identity, counter photo & NIDA record',
    'sw': 'Utambulisho wa mteja, picha ya kaunta na NIDA',
  },
  'sell.passportPhoto': {
    'en': 'Counter passport photo',
    'sw': 'Picha ya mteja kaunta'
  },
  'sell.nidaHint': {
    'en': 'Tanzania NIDA format (e.g. 19920415-XXXXX-XXXXX-XX)',
    'sw': 'Muundo wa NIDA Tanzania (mf. 19920415-XXXXX-XXXXX-XX)',
  },
  'sell.minDeposit': {
    'en': 'Min deposit (25%)',
    'sw': 'Kiwango cha chini (25%)'
  },
  'sell.minRequired': {
    'en': 'Minimum required deposit (25%)',
    'sw': 'Malipo ya chini yanayotakiwa (25%)',
  },
  'sell.mustBeAtLeast': {
    'en': 'Must be at least TZS {n}',
    'sw': 'Lazima iwe angalau TZS {n}',
  },
  'sell.errDeposit': {
    'en': 'The deposit cannot equal or exceed the loan price',
    'sw': 'Malipo ya kwanza haywezi kufikia au kuzidi bei ya mkopo',
  },
  'sell.perWeek': {'en': 'TZS {n} / week', 'sw': 'TZS {n} / wiki'},
  'sell.weeklyRepayment': {
    'en': 'Weekly repayment ({n} wks)',
    'sw': 'Malipo ya kila wiki (wiki {n})',
  },
  'sell.schedule': {
    'en': 'Payment calendar preview',
    'sw': 'Onyesho la ratiba ya malipo'
  },
  'sell.agreementTitle': {
    'en': 'Key customer agreement terms:',
    'sw': 'Masharti muhimu ya mkataba:'
  },
  'sell.contractTitle': {
    'en': 'Physical hire-purchase contract signed',
    'sw': 'Mkataba wa karatasi umesainiwa',
  },
  'sell.pdpa': {
    'en': 'PDPA data & guarantor notification consent',
    'sw': 'Idhini ya data ya PDPA na taarifa kwa mdhamini',
  },
  'sell.supervisorTitle': {
    'en': 'Branch supervisor override required',
    'sw': 'Idhini ya msimamizi wa tawi inahitajika',
  },
  'sell.supervisorPin': {
    'en': 'Supervisor authorization PIN',
    'sw': 'PIN ya msimamizi'
  },
  'sell.errResolve': {
    'en': 'Please resolve the highlighted validation errors.',
    'sw': 'Tafadhali rekebisha makosa yaliyoangaziwa.',
  },
  'sell.reviewDisbursement': {
    'en': 'Review loan disbursement',
    'sw': 'Kagua utoaji wa mkopo'
  },
  'sell.reviewCashTitle': {
    'en': 'Review POS cash sale',
    'sw': 'Kagua mauzo ya fedha'
  },
  'sell.totalFinanced': {'en': 'Total loan financed', 'sw': 'Jumla ya mkopo'},
  'sell.initialDeposit': {
    'en': 'Initial down payment (drawer)',
    'sw': 'Malipo ya kwanza (droo)',
  },
  'sell.remainingPrincipal': {
    'en': 'Remaining financed principal',
    'sw': 'Salio la mkopo',
  },
  'sell.totalCollected': {
    'en': 'Total collected in drawer',
    'sw': 'Jumla iliyokusanywa droo',
  },
  'sell.drawerChannel': {'en': 'Cashier drawer', 'sw': 'Droo ya kaunta'},
  'sell.capturePhoto': {'en': 'Capture photo', 'sw': 'Piga picha'},
  'sell.upload': {'en': 'Upload', 'sw': 'Pakia'},
  'sell.photoAttached': {
    'en': 'Photo attached to this application.',
    'sw': 'Picha imeambatishwa kwenye maombi haya.',
  },
  'sell.cameraNeeded': {
    'en': 'Camera permission is required to take the photo.',
    'sw': 'Ruhusa ya kamera inahitajika kupiga picha.',
  },
  'sell.kycMissing': {
    'en': 'No counter photo attached yet',
    'sw': 'Hakuna picha ya kaunta bado',
  },
  'sell.kycAttached': {
    'en': 'Counter photo attached',
    'sw': 'Picha ya kaunta imeambatishwa',
  },
  'sell.errNida': {
    'en': 'NIDA ID must be a valid 20-digit identifier',
    'sw': 'NIDA lazima iwe tarakimu 20 sahihi',
  },
  'sell.errName': {
    'en': 'Please enter the borrower legal name',
    'sw': 'Weka jina kamili la mkopaji',
  },
  'sell.errPhone': {
    'en': 'Please enter the customer phone',
    'sw': 'Weka simu ya mteja'
  },
  'sell.phoneHelp': {
    'en': '10 digits, starting with 0',
    'sw': 'Tarakimu 10, kuanzia na 0',
  },
  'sell.cardNumber': {
    'en': 'Card number (16 digits)',
    'sw': 'Namba ya kadi (tarakimu 16)',
  },
  'sell.cardHelp': {
    'en': 'Only the last four are kept, for the receipt',
    'sw': 'Tarakimu nne za mwisho pekee ndizo zinahifadhiwa, kwa risiti',
  },
  'sell.errAddress': {
    'en': 'Please enter the residential address',
    'sw': 'Weka anuani ya makazi',
  },

  // ------------------------------------------------------------------- scanner
  'scan.eyebrow': {
    'en': 'Serialized stock operations',
    'sw': 'Uendeshaji wa vifaa vilivyosajiliwa'
  },
  'scan.title': {'en': 'Scan & verify IMEI', 'sw': 'Skani na hakiki IMEI'},
  'scan.inspector': {'en': 'IMEI inspector', 'sw': 'Mkaguzi wa IMEI'},
  'scan.searchHint': {
    'en': 'Type or paste a 15-digit IMEI',
    'sw': 'Andika au bandika IMEI ya tarakimu 15'
  },
  'scan.start': {'en': 'Start camera scan', 'sw': 'Anzisha skani ya kamera'},
  'scan.stop': {'en': 'Stop camera', 'sw': 'Simamisha kamera'},
  'scan.looking': {
    'en': 'Point the camera at the IMEI barcode on the box',
    'sw': 'Elekeza kamera kwenye barcode ya IMEI kwenye boksi',
  },
  'scan.manual': {'en': 'Enter IMEI manually', 'sw': 'Weka IMEI kwa mkono'},
  'scan.noCamera': {
    'en': 'This device has no camera available. Enter the IMEI manually.',
    'sw': 'Kifaa hiki hakina kamera. Weka IMEI kwa mkono.',
  },
  'scan.cameraDenied': {
    'en': 'Camera permission denied. Allow it in settings or type the IMEI.',
    'sw':
        'Ruhusa ya kamera imekataliwa. Iruhusu kwenye mipangilio au andika IMEI.',
  },
  'scan.invalid': {
    'en': 'That code is not a valid IMEI (15 digits, checksum failed)',
    'sw': 'Msimbo huo si IMEI sahihi (tarakimu 15, checksum imeshindikana)',
  },
  'scan.notFound': {
    'en': 'IMEI {n} is not registered in this branch',
    'sw': 'IMEI {n} haijasajiliwa katika tawi hili',
  },
  'scan.inStock': {'en': 'In stock', 'sw': 'Ipo stoo'},
  'scan.onLoan': {'en': 'On loan', 'sw': 'Ipo kwenye mkopo'},
  'scan.cashPrice': {'en': 'Cash price', 'sw': 'Bei ya fedha'},
  'scan.loanPrice': {'en': 'Loan price', 'sw': 'Bei ya mkopo'},
  'scan.scanAgain': {'en': 'Scan another', 'sw': 'Skani nyingine'},
  'scan.copied': {'en': 'IMEI copied', 'sw': 'IMEI imenakiliwa'},

  // ------------------------------------------------------------- borrower screen
  'borrower.chooseChannel': {
    'en': 'Choose payment channel',
    'sw': 'Chagua Njia ya Malipo'
  },
  'borrower.refNo': {
    'en': 'Payment reference / Ref No.',
    'sw': 'Kumbukumbu ya Malipo / Ref No.'
  },
  'borrower.confirmReceipt': {
    'en': 'Confirm and issue receipt',
    'sw': 'Thibitisha na Weka Risiti'
  },
  'borrower.paymentVoucher': {
    'en': 'Payment voucher',
    'sw': 'Stakabadhi ya Malipo'
  },
  'borrower.customer': {'en': 'Customer', 'sw': 'Mteja'},
  'borrower.channel': {'en': 'Payment channel', 'sw': 'Njia ya Malipo'},
  'borrower.receiptPdf': {'en': 'Receipt (PDF)', 'sw': 'Risiti (PDF)'},
  'borrower.tabKyc': {'en': 'KYC & guarantor', 'sw': 'KYC & Mdhamini'},
  'borrower.tabHistory': {'en': 'Payment history', 'sw': 'Historia ya Malipo'},
  'borrower.collateral': {'en': 'Security held', 'sw': 'Ulinzi wa Dhamana'},
  'borrower.collateralValue': {
    'en': 'Hire-purchase contract and guarantor',
    'sw': 'Mkataba wa Hire-Purchase & Mdhamini',
  },
  'borrower.totalPaid': {
    'en': 'Total: {paid} of {total}',
    'sw': 'Jumla: {paid} kati ya {total}'
  },
  'borrower.receipt': {'en': 'Receipt', 'sw': 'Risiti'},
  'borrower.recordedPayments': {
    'en': 'Recorded payments: {n}',
    'sw': 'Marejesho yaliyorekodiwa: {n}'
  },
  'borrower.payNow': {'en': '+ Pay', 'sw': '+ Lipa'},
  'borrower.noPayments': {
    'en': 'No payments recorded yet',
    'sw': 'Hakuna marejesho yaliyorekodiwa bado'
  },
  'borrower.firstPayment': {
    'en': 'Record the first payment',
    'sw': 'Rekodi rejesho la kwanza'
  },
  'borrower.contract': {'en': 'Contract', 'sw': 'Mkataba'},
  'borrower.loanCleared': {'en': 'Loan settled', 'sw': 'Mkopo umekamilika'},
  'borrower.receivePayment': {'en': 'Receive payment', 'sw': 'Pokea rejesho'},
  'borrower.accountLine': {
    'en': 'Account: {id} · {item}',
    'sw': 'Akaunti: {id} · {item}'
  },
  'borrower.accountSubtitle': {
    'en': 'Loan account: {id}',
    'sw': 'Akaunti ya mkopo: {id}'
  },
  'borrower.overdueBadge': {'en': 'Overdue', 'sw': 'Imechelewa'},
  'borrower.currentBadge': {'en': 'Current', 'sw': 'Inalipika vizuri'},
  'borrower.accountState': {'en': 'Account state', 'sw': 'Hali ya akaunti'},
  'borrower.fullyPaid': {'en': 'Fully paid', 'sw': 'Imelipwa yote'},
  'borrower.statementPdf': {
    'en': 'Loan statement (PDF)',
    'sw': 'Taarifa ya mkopo (PDF)'
  },
  'borrower.tabSummary': {
    'en': 'Summary & security',
    'sw': 'Muhtasari & Ulinzi'
  },

  // --------------------------------------------------------------- receive stock
  'recv.title': {'en': 'Receive stock', 'sw': 'Pokea stoo'},
  'recv.noLines': {
    'en': 'No lines yet — add what arrived',
    'sw': 'Hakuna bidhaa bado — ongeza zilizofika'
  },
  'recv.linesSummary': {
    'en': '{lines} lines · {units} units · TZS {value}',
    'sw': 'Bidhaa {lines} · vifaa {units} · TZS {value}',
  },
  'recv.sourceTitle': {
    'en': 'Where is this stock coming from?',
    'sw': 'Stoo hii inatoka wapi?'
  },
  'recv.sourceSupplier': {'en': 'Supplier', 'sw': 'Msambazaji'},
  'recv.sourceTransfer': {'en': 'Branch transfer', 'sw': 'Uhamisho wa tawi'},
  'recv.sourceReturn': {'en': 'Customer return', 'sw': 'Marejesho ya mteja'},
  'recv.supplierName': {'en': 'Supplier name', 'sw': 'Jina la msambazaji'},
  'recv.supplierHint': {
    'en': 'e.g. Tech Distributors Ltd',
    'sw': 'mf. Tech Distributors Ltd'
  },
  'recv.invoice': {
    'en': 'Invoice or delivery note no.',
    'sw': 'Namba ya ankara / hati ya mzigo'
  },
  'recv.invoiceHint': {'en': 'e.g. INV-2026-0412', 'sw': 'mf. INV-2026-0412'},
  'recv.fromBranch': {'en': 'Branch it left', 'sw': 'Tawi lilikotoka'},
  'recv.transferNote': {
    'en':
        'The sending branch should record the same transfer, so both counts agree.',
    'sw':
        'Tawi linalotuma linapaswa kurekodi uhamisho huo huo ili hesabu zilingane.',
  },
  'recv.returnNote': {
    'en': 'Add the serials so the unit returns to stock as the same device.',
    'sw': 'Ongeza namba za IMEI ili kifaa kirudi stoo kikiwa kile kile.',
  },
  'recv.whatArrived': {'en': 'What arrived', 'sw': 'Kilichofika'},
  'recv.addLine': {'en': 'Add model', 'sw': 'Ongeza modeli'},
  'recv.emptyLines': {
    'en':
        'Add the models in this delivery. Quantities start at 1 and can be changed.',
    'sw':
        'Ongeza modeli zilizo kwenye mzigo huu. Idadi inaanza na 1 na inaweza kubadilishwa.',
  },
  'recv.totals': {
    'en': '{units} units · TZS {value}',
    'sw': 'Vifaa {units} · TZS {value}'
  },
  'recv.catalogue': {'en': 'models in catalogue', 'sw': 'modeli kwenye orodha'},
  'recv.inBranch': {'en': 'in branch', 'sw': 'tawi hili'},
  'recv.pickModel': {'en': 'Add a model', 'sw': 'Ongeza modeli'},
  'recv.noProducts': {
    'en': 'No models in the catalogue yet.',
    'sw': 'Hakuna modeli kwenye orodha bado.'
  },
  'recv.scanTitle': {
    'en': 'Scan or type the IMEI',
    'sw': 'Skani au andika IMEI'
  },
  'recv.scanHint': {
    'en': '15-digit IMEI from the box',
    'sw': 'IMEI ya tarakimu 15 kutoka kwenye boksi'
  },
  'recv.scanFirst': {
    'en': 'Set the quantities before scanning serials',
    'sw': 'Weka idadi kabla ya kuskani IMEI'
  },
  'recv.scanProgress': {
    'en': '{scanned} of {expected} IMEIs scanned',
    'sw': '{scanned} kati ya {expected} IMEI zimeskaniwa'
  },
  'recv.scanButton': {
    'en': 'Scan / add serial IMEI',
    'sw': 'Skani / ongeza IMEI'
  },
  'recv.useImei': {'en': 'Use this IMEI', 'sw': 'Tumia IMEI hii'},
  'recv.badImei': {
    'en': 'Not a valid IMEI (15 digits, GSMA check).',
    'sw': 'IMEI si sahihi (tarakimu 15, hakiki ya GSMA).'
  },
  'recv.alreadyScanned': {
    'en': 'IMEI {n} is already in this delivery',
    'sw': 'IMEI {n} tayari iko kwenye mzigo huu'
  },
  'recv.added': {'en': 'IMEI {n} added', 'sw': 'IMEI {n} imeongezwa'},
  'recv.note': {'en': 'Note (optional)', 'sw': 'Maelezo (hiari)'},
  'recv.confirm': {
    'en': 'Confirm receive & update stock',
    'sw': 'Thibitisha na sasisha stoo'
  },
  'recv.ok': {
    'en': '{n} units added at {b}',
    'sw': 'Vifaa {n} vimeongezwa {b}'
  },
  'recv.okLocal': {
    'en': '{n} units recorded in this session only — database not connected',
    'sw': 'Vifaa {n} vimerekodiwa kikao hiki tu — database haijaunganishwa'
  },
  'recv.failed': {
    'en': 'The database did not accept the delivery. Nothing changed.',
    'sw': 'Database haikukubali mzigo. Hakuna kilichobadilika.'
  },
  'recv.offline': {
    'en': 'No database connection in this build.',
    'sw': 'Hakuna muunganisho wa database kwenye build hii.'
  },
  'recv.serialsStored': {
    'en': '{n} IMEIs saved to the handset register',
    'sw': 'IMEI {n} zimehifadhiwa kwenye rejista ya simu'
  },
  'recv.serialsSkipped': {
    'en': '{n} serials were already on file and were skipped',
    'sw': 'Serial {n} zilikuwa zimekwisha hifadhiwa, zimerukwa'
  },
  'recv.serialsFailed': {
    'en':
        '{n} IMEIs could not be saved — the handset register did not accept them',
    'sw': 'IMEI {n} hazikuweza kuhifadhiwa — rejista ya simu haikuzipokea'
  },
  'recv.noSerials': {
    'en':
        'No IMEIs scanned — the units arrived but the individual handsets are not on file',
    'sw':
        'Hakuna IMEI iliyopimwa — vifaa vimefika lakini simu mahususi haziko kwenye kumbukumbu'
  },
  'recv.err_lines': {
    'en': 'Add at least one model.',
    'sw': 'Ongeza modeli angalau moja.'
  },
  'recv.err_quantity': {
    'en': 'Every line needs a quantity of at least 1.',
    'sw': 'Kila bidhaa inahitaji idadi ya angalau 1.'
  },
  'recv.err_supplier': {
    'en': 'Enter the supplier name.',
    'sw': 'Weka jina la msambazaji.'
  },
  'recv.err_fromBranch': {
    'en': 'Choose the branch the stock came from.',
    'sw': 'Chagua tawi lilikotoka stoo.'
  },

  // ------------------------------------------------------------------ inspector
  'insp.inStock': {'en': 'In stock (clean)', 'sw': 'Ipo Stoo (Clean)'},
  'insp.overdue': {'en': 'Installment overdue', 'sw': 'Rejesho Limechelewa'},
  'insp.onLoan': {'en': 'Loan running', 'sw': 'Mkopo Unaendelea'},
  'insp.overdueLine': {
    'en': 'Instalment overdue · Follow up borrower and guarantor',
    'sw': 'Rejesho Limechelewa · Fuatilia Mkopaji na Mdhamini',
  },
  'insp.currentLine': {
    'en': 'Loan running well · Legal record',
    'sw': 'Mkopo Unaendelea Vizuri · Rekodi ya Kisheria',
  },
  'insp.overdueBody': {
    'en':
        'Payment is late. Call the borrower ({n}) or the guarantor who signed the contract.',
    'sw':
        'Deni limechelewa. Wasiliana na mkopaji ({n}) au piga simu kwa mdhamini aliyesaini mkataba.',
  },
  'insp.currentBody': {
    'en':
        'Handed over under a valid hire-purchase contract. Next instalment: {d}.',
    'sw':
        'Kifaa kimekabidhiwa kwa mkataba halali wa hire-purchase. Rejesho lijalo: {d}.',
  },
  'insp.notFinanced': {
    'en': 'Not financed (in stock)',
    'sw': 'Haijakopeshwa (Ipo Stoo)'
  },
  'insp.imeiHint': {
    'en': 'Enter the 15-digit IMEI',
    'sw': 'Weka namba ya IMEI (tarakimu 15)'
  },
  'insp.branch': {'en': 'Registered branch', 'sw': 'Tawi la Usajili'},
  'insp.loanSection': {
    'en': 'Customer / loan details',
    'sw': 'Mteja / Taarifa za Mkopo'
  },
  'insp.unknownModel': {
    'en': 'Not registered here',
    'sw': 'Haijasajiliwa hapa'
  },
  'insp.unknownStatus': {
    'en': 'Not in this shop',
    'sw': 'Haipo kwenye duka hili'
  },
  'insp.invalidStatus': {'en': 'Not a valid IMEI', 'sw': 'IMEI si sahihi'},
  'insp.reminderSms': {
    'en':
        'Hello {name}, a reminder that your instalment of TZS {amount} is due. Please pay at the shop.',
    'sw':
        'Habari {name}, tunakukumbusha rejesho lako la TZS {amount}. Tafadhali lipa dukani.',
  },
  'insp.reminderOpened': {
    'en': 'Opening your messaging app for {phone}.',
    'sw': 'Tunafungua ujumbe kwa {phone}.'
  },
  'insp.reminderFailed': {
    'en': 'No messaging app available on this device.',
    'sw': 'Hakuna app ya ujumbe kwenye kifaa hiki.'
  },
  'insp.dossierMissing': {
    'en': 'That contract is no longer in the list.',
    'sw': 'Mkataba huo haupo kwenye orodha tena.'
  },
  'insp.serialsOnFile': {
    'en': 'Serials on file:',
    'sw': 'Namba zilizosajiliwa:'
  },
  'insp.auditTitle': {'en': 'Device audit trail', 'sw': 'Historia ya Kifaa'},
  'insp.auditEmpty': {
    'en':
        'No movement has been recorded for this handset yet: no contract, no instalments, no stock entry.',
    'sw':
        'Bado hakuna kumbukumbu ya kifaa hiki: hakuna mkataba, hakuna marejesho, hakuna kuingizwa stoo.',
  },
  'insp.auditInstallment': {
    'en': 'Instalment received',
    'sw': 'Rejesho limepokelewa'
  },
  'insp.auditContract': {'en': 'Contract {id}', 'sw': 'Mkataba {id}'},
  'insp.auditContractDeposit': {
    'en': '{name} · deposit TZS {deposit}',
    'sw': '{name} · dhamana TZS {deposit}',
  },
  'insp.auditContractNoDeposit': {
    'en': '{name} · no deposit recorded',
    'sw': '{name} · hakuna dhamana iliyosajiliwa',
  },
  'insp.auditInStock': {'en': 'On file in stock', 'sw': 'Ipo stoo'},
  'insp.auditInStockSub': {
    'en': 'SKU {sku} · {branch} · {stock} on hand',
    'sw': 'SKU {sku} · {branch} · {stock} zilizopo',
  },
  'insp.auditRemoteMatch': {
    'en': 'Serial found in the database',
    'sw': 'Namba imepatikana kwenye hifadhidata'
  },
  'insp.auditRemoteMatchSub': {
    'en': 'Unit record for {serial}',
    'sw': 'Kumbukumbu ya kifaa {serial}',
  },
  'insp.screenTitle': {
    'en': 'Hardware Verification & IMEI Inspector',
    'sw': 'Ukaguzi wa Kifaa & IMEI'
  },
  'insp.scanTooltip': {
    'en': 'Scan barcode / IMEI',
    'sw': 'Skani barcode / IMEI'
  },
  'insp.search': {'en': 'Check', 'sw': 'Kagua'},
  'insp.serialNo': {'en': 'Serial No.', 'sw': 'Namba ya Kifaa'},
  'insp.loanValue': {'en': 'Loan value', 'sw': 'Thamani ya Mkopo'},
  'insp.recoveryTitle': {
    'en': 'Hire-Purchase Recovery & Actions',
    'sw': 'Ufuatiliaji wa Mkopo & Hatua'
  },
  'insp.overdueTag': {'en': 'Overdue', 'sw': 'Imechelewa'},
  'insp.activeTag': {'en': 'Active', 'sw': 'Inaendelea'},
  'insp.sendSms': {'en': 'Send payment SMS', 'sw': 'Tuma SMS ya malipo'},
  'insp.borrowerDossier': {'en': 'Borrower file', 'sw': 'Jalada la Mkopaji'},
  'insp.fullFile': {'en': 'Full file', 'sw': 'Faili Kamili'},
  'insp.phoneNida': {
    'en': 'Phone: {phone} · NIDA: {nida}',
    'sw': 'Simu: {phone} · NIDA: {nida}'
  },
  'insp.remainingBalance': {
    'en': 'Remaining balance',
    'sw': 'Salio Lililobaki'
  },
  'insp.dueDate': {'en': 'Due date', 'sw': 'Tarehe ya malipo'},
  'insp.recordPayment': {'en': 'Record a payment', 'sw': 'Rekodi malipo'},
  'insp.warrantyTitle': {'en': 'Warranty status', 'sw': 'Hali ya Waranti'},
  'insp.warrantyIncludes': {
    'en':
        'Covers the original screen, motherboard and software work under the LIMS Care Guarantee.',
    'sw':
        'Inajumuisha: Kioo cha Asili, Motherboard & Ufundi wa Mfumo chini ya LIMS Care Guarantee.',
  },
  'insp.noActiveLoan': {
    'en': 'This device has no active loan.',
    'sw': 'Kifaa hiki hakina mkopo unaoendelea.'
  },
  'insp.noPhoneOnFile': {
    'en': 'No phone number is recorded on this contract.',
    'sw': 'Hakuna namba ya simu iliyosajiliwa kwenye mkataba huu.',
  },

  // ------------------------------------------------------------------- stock sheet
  'stock.sellCash': {'en': 'Sell for cash', 'sw': 'Uza Cash'},
  'stock.issueLoan': {'en': 'Issue loan', 'sw': 'Toa Mkopo'},
  'stock.inventoryHistory': {
    'en': 'Inventory history',
    'sw': 'Historia ya stoo'
  },
  'stock.editPhoto': {'en': 'Edit photo', 'sw': 'Hariri Picha'},
  'stock.editPhotoTitle': {
    'en': 'Edit product photo',
    'sw': 'Hariri Picha ya Bidhaa'
  },
  'stock.noSerialOnFile': {
    'en': 'No serial number is recorded for this unit yet.',
    'sw': 'Hakuna namba ya kifaa iliyosajiliwa kwa bidhaa hii bado.',
  },
  'stock.presets': {
    'en': 'Choose from existing handset images (presets):',
    'sw': 'Chagua Kutoka Picha za Simu Zilizopo (Presets):'
  },
  'stock.photoUrl': {
    'en': 'Or paste an image link / URL:',
    'sw': 'Au Weka Link / URL ya Picha:'
  },
  'stock.savePhoto': {'en': 'Save new photo', 'sw': 'Hifadhi Picha Mpya'},
  'stock.photoHint': {
    'en':
        'Pick a real photo so the shop and the loan contract match the device.',
    'sw': 'Chagua picha halisi kuonyesha dukani na kwenye mkataba wa mkopo.'
  },
  'stock.compressNote': {
    'en':
        'Photos are compressed from 4.8 MB to about 74 KB before upload. The free Supabase tier (1 GB) holds 13,900+ handsets.',
    'sw':
        'Picha inabanwa kutoka 4.8MB hadi 74KB kabla ya kutumwa. Hifadhi ya bure ya Supabase (1GB) inatosha simu 13,900+ bila kujaa!'
  },

  // -------------------------------------------------------------- notifications
  'notif.title': {'en': 'Notifications', 'sw': 'Taarifa'},
  'notif.unread': {'en': '{n} unread', 'sw': '{n} hazijasomwa'},
  'notif.allRead': {'en': 'All read', 'sw': 'Zote zimesomwa'},
  'notif.markAll': {'en': 'Mark all read', 'sw': 'Soma zote'},
  'notif.markedAll': {
    'en': 'All marked as read',
    'sw': 'Zote zimewekwa kama zimesomwa'
  },
  'notif.empty': {
    'en':
        'Nothing needs attention. Low stock and overdue loans will appear here.',
    'sw':
        'Hakuna kinachohitaji kushughulikiwa. Stoo ndogo na mikopo iliyochelewa zitaonekana hapa.',
  },
  'notif.detailTitle': {'en': 'Notice', 'sw': 'Taarifa'},
  'notif.markUnread': {'en': 'Mark unread', 'sw': 'Weka kama haijasomwa'},
  'notif.open': {
    'en': 'Open the relevant screen',
    'sw': 'Fungua screen husika'
  },
  'notif.resolved': {
    'en': 'This has been resolved since you opened the list.',
    'sw': 'Hili limeshatatuliwa tangu ufungue orodha.',
  },

  // -------------------------------------------------------- settings & admin
  'set.save': {'en': 'Save', 'sw': 'Hifadhi'},
  'set.smsGuarantor': {
    'en': 'SMS & call the guarantor',
    'sw': 'SMS & Piga Simu kwa Mdhamini'
  },
  'set.negotiation': {
    'en': 'Settle directly with the customer',
    'sw': 'Mazungumzo ya Makubaliano na Mteja'
  },
  'set.smsTest': {
    'en':
        'Reminder SMS template sent (example: "Hello, your instalment of TZS ... is now due...")',
    'sw':
        'Kiolezo cha SMS ya kukumbusha rejesho kimetumwa (Mfano: "Ndugu Mteja, rejesho lako la TZS ... linatakiwa kulipwa...")',
  },
  'set.legalNotice': {
    'en': 'Formal demand notice',
    'sw': 'Notisi Rasmi ya Madai'
  },
  'set.smsTestButton': {
    'en': 'Test the payment reminder SMS',
    'sw': 'Jaribu Kiolezo cha SMS ya Marejesho',
  },
  'adm.branchActive': {
    'en': 'Branch is operating',
    'sw': 'Tawi linafanya kazi'
  },
  'adm.branchClosed': {'en': 'Branch is closed', 'sw': 'Tawi limefungwa'},
  'adm.saveChanges': {'en': 'Save changes', 'sw': 'Hifadhi Mabadiliko'},
  'adm.userSheetSubtitle': {
    'en': 'Set the user details and their role',
    'sw': 'Weka taarifa za mtumiaji na jukumu lake',
  },
  'adm.assignedBranch': {'en': 'Assigned branch', 'sw': 'Tawi Lililopangiwa'},
  'adm.deviceHold': {'en': 'Place device hold', 'sw': 'Weka Device Hold'},

  // ------------------------------------------------------------ admin console
  // The console screens used to be half English, half Swahili on the same card
  // ("Branch Network & Hubs" above "Wafanyakazi & RBAC", "Week" next to "Mwezi").
  // Every visible word there now resolves through these keys, so one language
  // wins for the whole screen instead of per widget.
  'admin.titleAdmin': {'en': 'Admin Console', 'sw': 'Kituo cha Msimamizi'},
  'admin.titleBranch': {'en': 'Branch Console', 'sw': 'Kituo cha Tawi'},
  'admin.console': {'en': 'Console', 'sw': 'Kituo'},
  'admin.tabNetwork': {
    'en': 'Branch Network & Hubs',
    'sw': 'Mtandao wa Matawi',
  },
  'admin.staffTab': {'en': 'Staff & RBAC', 'sw': 'Wafanyakazi & RBAC'},
  'admin.revenueToday': {'en': 'Revenue today', 'sw': 'Mauzo ya leo'},
  'admin.activeBranches': {
    'en': 'Active branches',
    'sw': 'Matawi yanayofanya kazi'
  },
  'admin.branchesOpen': {
    'en': '{n} of {total} open',
    'sw': '{n} kati ya {total} wazi'
  },
  'admin.loansOutstanding': {
    'en': 'Loans outstanding',
    'sw': 'Mikopo inayodaiwa'
  },
  'admin.overdue': {'en': '{n} overdue', 'sw': '{n} imechelewa'},
  'admin.alerts': {'en': 'Alerts', 'sw': 'Tahadhari'},
  'admin.nothingPending': {'en': 'Nothing pending', 'sw': 'Hakuna inayosubiri'},
  'admin.needsReview': {'en': 'Needs review', 'sw': 'Inahitaji kuangaliwa'},
  'admin.vsYesterday': {'en': 'vs yesterday', 'sw': 'kulinganisha na jana'},
  'admin.noYesterday': {
    'en': 'No figure for yesterday',
    'sw': 'Hakuna kumbukumbu ya jana',
  },
  'admin.rangeWeek': {'en': 'Week', 'sw': 'Wiki'},
  'admin.rangeMonth': {'en': 'Month', 'sw': 'Mwezi'},
  'admin.periodWeek': {'en': 'this week', 'sw': 'wiki hii'},
  'admin.periodMonth': {'en': 'this month', 'sw': 'mwezi huu'},
  'admin.networkRevenue': {
    'en': 'Network revenue · {period}',
    'sw': 'Mauzo ya mtandao · {period}',
  },
  'admin.branchRevenue': {
    'en': 'Branch revenue · {period}',
    'sw': 'Mauzo ya tawi · {period}',
  },
  'admin.vsPrev': {'en': '{n}% vs prev', 'sw': '{n}% dhidi ya awali'},
  'admin.noSalesYet': {
    'en': 'No sales recorded yet',
    'sw': 'Hakuna mauzo yaliyorekodiwa bado',
  },
  'admin.tapBar': {
    'en': 'Tap a bar to see that day',
    'sw': 'Gusa upau kuona siku hiyo',
  },
  'admin.onlyDays': {
    'en': 'only {n} days recorded',
    'sw': 'siku {n} tu zimeandikwa',
  },
  'admin.transactions': {'en': 'transactions', 'sw': 'miamala'},
  'admin.was': {'en': 'was', 'sw': 'ilikuwa'},
  'admin.vsLastWeek': {
    'en': 'vs same day last week',
    'sw': 'vs siku kama hii wiki iliyopita'
  },
  'admin.noEarlierFigure': {
    'en': 'no figure for last week',
    'sw': 'hakuna kumbukumbu ya wiki iliyopita',
  },
  'admin.branches': {'en': 'Branches', 'sw': 'Matawi'},
  // The branch rows carry a currency figure. Without the period next to it, a
  // branch reading "TZS 0" looks like a branch that has never sold anything
  // rather than one with no takings on the books yet - and the reader has no
  // way to tell which of those they are looking at.
  'admin.revenueToDate': {
    'en': 'Revenue to date',
    'sw': 'Mapato hadi sasa'
  },
  'admin.lowStockModels': {
    'en': '{n} low-stock models',
    'sw': 'bidhaa {n} chini ya kiwango'
  },
  'admin.alertsTitle': {
    'en': 'Alerts & Escalations',
    'sw': 'Tahadhari na Mambo ya Dharura'
  },
  'admin.noAlerts': {
    'en': 'Nothing needs review right now.',
    'sw': 'Hakuna kinachohitaji kuangaliwa sasa.',
  },
  'admin.alertOverdue': {
    'en': '{n} loans are past their due date',
    'sw': 'mikopo {n} imepita tarehe ya malipo',
  },
  'admin.alertLowStock': {
    'en': '{n} models are low on stock',
    'sw': 'bidhaa {n} zina stock ndogo',
  },
  'admin.alertNoSalesToday': {
    'en': 'No sales recorded today',
    'sw': 'Hakuna mauzo yaliyorekodiwa leo',
  },
  'admin.alertNoSalesTodaySub': {
    'en': 'The shop day is open but the till has no entries',
    'sw': 'Siku ya kazi imefunguliwa lakini kasha halina kumbukumbu',
  },
  'admin.activeRoleTitle': {
    'en': 'Active role (server-assigned)',
    'sw': 'Jukumu linalotumika (limewekwa na server)',
  },
  'admin.signedInAs': {
    'en': 'Signed in as {role}. Role changes happen server-side.',
    'sw': 'Umeingia kama {role}. Mabadiliko ya jukumu hufanywa server.',
  },
  'admin.staffDirectory': {
    'en': 'Staff directory & credentials',
    'sw': 'Orodha ya wafanyakazi',
  },
  'admin.staffCount': {
    'en': '{n} staff registered across branches',
    'sw': 'wafanyakazi {n} wamesajiliwa katika matawi',
  },
  'admin.addStaff': {'en': 'Add staff', 'sw': 'Ongeza staff'},
  'admin.noAccessTitle': {
    'en': 'No console access',
    'sw': 'Huna ruhusa ya console'
  },
  'admin.noAccessBody': {
    'en':
        'Your role is {role}. The console needs Super Admin or Branch Manager. Ask your supervisor for access.',
    'sw':
        'Jukumu lako ni {role}. Kituo kinahitaji Super Admin au Branch Manager. Omba ruhusa kwa msimamizi wako.',
  },
  'admin.closeBranch': {'en': 'Close branch', 'sw': 'Funga tawi'},
  'admin.reopenBranch': {'en': 'Reopen branch', 'sw': 'Fungua tawi'},
  'admin.closeBranchHint': {
    'en': 'It disappears from the pickers, but its records stay.',
    'sw': 'Halitaonekana kwenye uchaguzi, lakini rekodi zake zinabaki.',
  },
  'admin.reopenBranchHint': {
    'en': 'It returns to the list of operating branches.',
    'sw': 'Litarudi kwenye orodha ya matawi yanayofanya kazi.',
  },
  'admin.roleSuperAdmin': {
    'en':
        'Full executive access: network revenue, profit margins, staff RBAC, and the device-hold policy switch.',
    'sw':
        'Uongozi kamili: mauzo ya mtandao, faida, ruhusa za wafanyakazi, na sera ya device hold.',
  },
  'admin.roleBranchManager': {
    'en':
        'Branch supervision: daily register and drawer audit, supervisor discount PIN overrides, staff shift audits.',
    'sw':
        'Usimamizi wa tawi: daftari la siku na ukaguzi wa kasha, PIN ya punguzo, ukaguzi wa zamu.',
  },
  'admin.roleCredit': {
    'en':
        'Credit and risk: customer KYC scoring, loan approval or rejection, device-hold flags for defaulters, and collections.',
    'sw':
        'Mikopo na hatari: alama za KYC, kukubali au kukataa mkopo, device hold kwa wadaiwa, na ukusanyaji.',
  },
  'admin.roleInventory': {
    'en':
        'Logistics and warehouse: inbound shipments, serialised IMEI intake, audits, and branch transfers.',
    'sw':
        'Usafirishaji na ghala: shehena zinazoingia, IMEI, ukaguzi, na uhamishaji wa matawi.',
  },
  'admin.roleStaff': {
    'en':
        'Retail POS: cash and mobile money sales, customer KYC intake, stock scan, and shift clock-in.',
    'sw':
        'Mauzo: fedha taslimu na mobile money, KYC ya mteja, skani ya stock, na kuingia zamu.',
  },
  'admin.roleAuditor': {
    'en':
        'Oversight only: read-only access to registers, loan history, stock movements and reports.',
    'sw':
        'Uangalizi tu: unaweza kusoma daftari, historia ya mikopo, mienendo ya stock na ripoti.',
  },
  'admin.roleInvited': {
    'en':
        'Invited but not yet activated: the account exists but has no access until the invitation is accepted.',
    'sw':
        'Amealikwa lakini hajaamilishwa: akaunti ipo lakini haina ruhusa hadi aukubali mwaliko.',
  },
  'admin.roleUnknown': {
    'en':
        'Unrecognised role — treated as read-only until a Super Admin assigns a valid role.',
    'sw':
        'Jukumu lisilotambulika — linahesabiwa kama kusoma tu hadi Super Admin ape jukumu halali.',
  },

  // ------------------------------------------------------- role labels & scope
  // Role names were rendered as "Super Admin (Mamlaka Kamili)" everywhere, so an
  // English screen always carried a Swahili gloss.
  'role.superAdmin': {'en': 'Super Admin', 'sw': 'Msimamizi Mkuu'},
  'role.branchManager': {'en': 'Branch Manager', 'sw': 'Meneja wa Tawi'},
  'role.loanOfficer': {'en': 'Loan Officer', 'sw': 'Afisa Mkopo'},
  'role.storekeeper': {'en': 'Storekeeper', 'sw': 'Afisa Stoo'},
  'role.counterCashier': {'en': 'Counter Cashier', 'sw': 'Mweka Hazina'},
  'role.auditor': {'en': 'Auditor', 'sw': 'Mkaguzi'},
  'role.pending': {'en': 'Pending invitation', 'sw': 'Mwaliko unasubiri'},
  'role.unknown': {'en': 'No role assigned', 'sw': 'Hana jukumu'},
  'role.notSignedIn': {'en': 'Not signed in', 'sw': 'Hujaingia'},

  // ------------------------------------------------------------------ settings
  'set.title': {'en': 'Settings & Profile', 'sw': 'Mipangilio na Wasifu'},
  'set.branch': {'en': 'Branch', 'sw': 'Tawi'},
  'set.assignedBranch': {
    'en': 'Your assigned branch',
    'sw': 'Tawi ulilopangiwa'
  },
  'set.terminal': {'en': 'Active terminal', 'sw': 'Kituo kinachotumika'},
  'set.noBranch': {
    'en': 'No branch on your profile',
    'sw': 'Hakuna tawi kwenye wasifu wako'
  },
  'set.activeAt': {'en': 'Active at', 'sw': 'Anafanya kazi'},
  'set.change': {'en': 'Change', 'sw': 'Badili'},
  'set.switchHintAdmin': {
    'en':
        'As Super Admin you can look at any branch. Sales, stock and loans follow the branch you pick.',
    'sw':
        'Kama Msimamizi Mkuu unaweza kuangalia tawi lolote. Mauzo, stock na mikopo hufuata tawi unalochagua.',
  },
  'set.switchHintLocked': {
    'en':
        'Your role works inside this branch only. Only a Super Admin can move the terminal.',
    'sw':
        'Jukumu lako linafanya kazi ndani ya tawi hili tu. Msimamizi Mkuu pekee anaweza kubadilisha kituo.',
  },
  'set.pickBranch': {'en': 'Choose a branch', 'sw': 'Chagua tawi'},
  'set.switched': {
    'en': 'Terminal switched to {branch}',
    'sw': 'Kituo kimehamia {branch}'
  },
  'set.switchRefused': {
    'en': 'Only a Super Admin can switch branches.',
    'sw': 'Msimamizi Mkuu pekee anaweza kubadilisha matawi.',
  },
  'set.language': {'en': 'Language', 'sw': 'Lugha'},
  'set.lang.en': {'en': 'English', 'sw': 'Kiingereza'},
  'set.lang.sw': {'en': 'Kiswahili', 'sw': 'Kiswahili'},
  'set.changePhoto': {'en': 'Change photo', 'sw': 'Badili picha'},
  'set.photoHint': {
    'en': 'Your own photo appears on the header, receipts and loan forms.',
    'sw': 'Picha yako inaonekana kwenye kichwa, risiti na fomu za mikopo.',
  },
  'set.uploadPhoto': {'en': 'Upload a photo', 'sw': 'Pakia picha'},
  'set.orPick': {'en': 'Or pick a portrait', 'sw': 'Au chagua picha ya mfano'},
  'set.photoSaved': {'en': 'Photo updated', 'sw': 'Picha imesasishwa'},
  'set.photoFailed': {
    'en': 'Could not save the photo',
    'sw': 'Imeshindikana kuhifadhi picha'
  },
  'set.dataTitle': {'en': 'Data', 'sw': 'Data'},
  'set.dataLive': {
    'en': 'Connected · {n} sales loaded from the database',
    'sw': 'Imeunganishwa · mauzo {n} yamepakiwa kutoka database',
  },
  'set.dataDemo': {
    'en': 'Demo data · this build has no database behind it',
    'sw': 'Data ya majaribio · build hii haina database',
  },
  'set.sessionTitle': {'en': 'Session', 'sw': 'Kipindi'},
  'set.staffCode': {'en': 'Staff number', 'sw': 'Namba ya mfanyakazi'},
  'set.loginEmail': {'en': 'Login email', 'sw': 'Barua pepe ya kuingia'},
  'set.rbacOwner': {'en': 'Roles & permissions', 'sw': 'Majukumu na ruhusa'},
  'set.rbacOwnerValue': {
    'en': 'Set by a Super Admin',
    'sw': 'Huwekwa na Msimamizi Mkuu',
  },
  'set.signOut': {'en': 'Sign out', 'sw': 'Toka'},
  'set.version': {
    'en': 'LIMS · branch terminal',
    'sw': 'LIMS · kituo cha tawi'
  },

  // ------------------------------------------------------------------ account
  'account.adminConsole': {'en': 'Admin console', 'sw': 'Kituo cha msimamizi'},
  'account.branchConsole': {'en': 'Branch console', 'sw': 'Kituo cha tawi'},
  'account.settingsProfile': {
    'en': 'Settings & profile',
    'sw': 'Mipangilio na wasifu'
  },

  // ------------------------------------------------------------ shell & session
  'shell.signOutTitle': {'en': 'Sign out of LIMS?', 'sw': 'Toka LIMS?'},
  'shell.signOutBody': {
    'en':
        'This session will end and you will need your email and password to get back in.',
    'sw':
        'Utatolewa kwenye session hii na utahitaji kuingia tena kwa email na password yako.',
  },
  'shell.stay': {'en': 'Stay', 'sw': 'Baki hapa'},
  'shell.signOut': {'en': 'Sign out', 'sw': 'Toka'},
  'session.expiringTitle': {'en': 'Session expiring', 'sw': 'Session inaisha'},
  'session.expiringBody': {
    'en':
        'No activity for a while. This session closes in {n} seconds. If you are still here, tap Continue.',
    'sw':
        'Hakuna shughuli kwa muda. Session itafungwa baada ya sekunde {n}. Kama bado uko hapa, gusa Endelea.',
  },
  'session.continue': {'en': 'Continue', 'sw': 'Endelea'},
  'session.signOutNow': {'en': 'Sign out now', 'sw': 'Toka sasa'},

  // ------------------------------------------------------- staff admin sheets
  'adm.editRbacTitle': {
    'en': 'Edit role & permissions',
    'sw': 'Hariri Majukumu & Ruhusa'
  },
  'adm.roleLabel': {'en': 'Role', 'sw': 'Jukumu'},
  'adm.addStaffTitle': {
    'en': 'Add a staff member',
    'sw': 'Ongeza Mfanyakazi Mpya'
  },
  'adm.fullName': {'en': 'Full name', 'sw': 'Jina Kamili'},
  'adm.phoneNumber': {'en': 'Phone number', 'sw': 'Namba ya Simu'},
  'adm.nameRequired': {
    'en': 'Enter the staff member name first',
    'sw': 'Tafadhali ingiza jina la mfanyakazi',
  },
  'adm.staffUpdated': {
    'en': '{name} has been updated',
    'sw': 'Taarifa za {name} zimesasishwa',
  },

  // ------------------------------------------------------ member logins (admin)
  // A roster name and a login are different things. These keys only ever talk
  // about the login: an email, a password and a role that the database honours.
  'member.sectionTitle': {'en': 'Logins & roles', 'sw': 'Akaunti & Majukumu'},
  'member.sectionSub': {
    'en': '{n} people can sign in',
    'sw': 'Watu {n} wanaweza kuingia',
  },
  'member.notLinked': {
    'en': 'No login linked',
    'sw': 'Hakuna akaunti iliyounganishwa',
  },
  'member.add': {'en': 'Add member', 'sw': 'Ongeza mwanachama'},
  'member.addTitle': {'en': 'Give someone a login', 'sw': 'Mpe mtu akaunti'},
  'member.addSub': {
    'en': 'They sign in with this email and password. The role decides what the database lets them see.',
    'sw': 'Ataingia kwa barua pepe na neno la siri hili. Jukumu linaamua anachoweza kuona kwenye database.',
  },
  'member.email': {'en': 'Login email', 'sw': 'Barua pepe ya kuingia'},
  'member.password': {'en': 'Password', 'sw': 'Neno la siri'},
  'member.regenerate': {'en': 'New password', 'sw': 'Neno lingine'},
  'member.create': {'en': 'Create login', 'sw': 'Tengeneza akaunti'},
  'member.creating': {'en': 'Creating…', 'sw': 'Inatengeneza…'},
  'member.created': {'en': 'Login created', 'sw': 'Akaunti imetengenezwa'},
  'member.shareHint': {
    'en': 'Send these to {name}. The password is shown once — copy it now.',
    'sw': 'Mtumie {name} taarifa hizi. Neno la siri linaonekana mara moja — linakili sasa.',
  },
  'member.copy': {'en': 'Copy', 'sw': 'Nakili'},
  'member.copied': {'en': 'Copied', 'sw': 'Imenakiliwa'},
  'member.done': {'en': 'Done', 'sw': 'Sawa'},
  'member.resetPassword': {'en': 'Reset password', 'sw': 'Badilisha neno la siri'},
  'member.suspend': {'en': 'Suspend', 'sw': 'Simamisha'},
  'member.reactivate': {'en': 'Reactivate', 'sw': 'Rejesha'},
  'member.changeRole': {'en': 'Change role', 'sw': 'Badilisha jukumu'},
  'member.suspended': {'en': 'Suspended', 'sw': 'Imesimamishwa'},
  'member.needEmail': {
    'en': 'Enter the email they will sign in with',
    'sw': 'Ingiza barua pepe atakayotumia kuingia',
  },
  'member.needPassword': {
    'en': 'At least 8 characters, with a letter and a number',
    'sw': 'Angalau herufi 8, zenye herufi na namba',
  },
  'member.noLogins': {
    'en': 'No logins yet',
    'sw': 'Hakuna akaunti bado',
  },
  'member.passwordReset': {
    'en': "{name}'s password has been changed",
    'sw': 'Neno la siri la {name} limebadilishwa',
  },
  'member.roleChanged': {
    'en': '{name} is now {role}',
    'sw': '{name} sasa ni {role}',
  },
  'member.onlyLogins': {
    'en': 'Only a login can sign in. A name on the roster without a login is just a name.',
    'sw': 'Ni akaunti pekee inayoweza kuingia. Jina kwenye orodha bila akaunti ni jina tu.',
  },

  // ------------------------------------------------------------------- generic
  'common.save': {'en': 'Save', 'sw': 'Hifadhi'},
  'common.cancel': {'en': 'Cancel', 'sw': 'Ghairi'},
  'common.close': {'en': 'Close', 'sw': 'Funga'},
  'common.retry': {'en': 'Try again', 'sw': 'Jaribu tena'},
  'common.justNow': {'en': 'Just now', 'sw': 'Sasa hivi'},
  'common.total': {'en': 'Total', 'sw': 'Jumla'},
};

/// Resolve a key for the given locale. English wins when a translation is absent
/// so a missing entry never reaches the screen as `home.totalStock`.
String tr(Locale locale, String key) {
  final entry = _dictionary[key];
  if (entry == null) return key;
  final lang = locale.languageCode;
  return entry[lang] ?? entry['en'] ?? key;
}

/// Same lookup, with `{placeholders}` filled.
///
/// A missing placeholder is left as written rather than replaced with an empty
/// string: a visible `{n}` in a receipt line is a bug report, an invisible one is
/// a wrong number.
String trf(Locale locale, String key, Map<String, Object?> args) {
  var text = tr(locale, key);
  args.forEach((name, value) {
    text = text.replaceAll('{$name}', '${value ?? ''}');
  });
  return text;
}

/// Every key, for a coverage check in tests.
Iterable<String> get allStringKeys => _dictionary.keys;

/// Keys that have no Swahili entry, so the gap is testable.
Iterable<String> get untranslatedKeys =>
    _dictionary.entries.where((e) => e.value['sw'] == null).map((e) => e.key);
