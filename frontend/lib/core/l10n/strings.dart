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

  // The compact home that replaced eight stacked sections.
  'home.greetingMorning': {'en': 'Good morning', 'sw': 'Habari za asubuhi'},
  'home.greetingAfternoon': {'en': 'Good afternoon', 'sw': 'Habari za mchana'},
  'home.greetingEvening': {'en': 'Good evening', 'sw': 'Habari za jioni'},
  'home.summary': {'en': 'Today at a glance', 'sw': 'Muhtasari wa leo'},
  'home.quickActions': {'en': 'Quick actions', 'sw': 'Vitendo vya haraka'},
  'home.needsAttention': {'en': 'Needs attention', 'sw': 'Zinahitaji kushughulikiwa'},
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

  'home.refresh': {'en': 'Refresh from database', 'sw': 'Sasisha kutoka database'},
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
  'action.adminHubSub': {'en': 'Staff & roles', 'sw': 'Wafanyakazi na majukumu'},
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
  'action.collectionsSub': {'en': 'Overdue queue', 'sw': 'Orodha ya ucheleweshaji'},
  'action.scan': {'en': 'Scan IMEI', 'sw': 'Skani IMEI'},
  'action.scanSub': {'en': 'Verify a handset', 'sw': 'Hakiki kifaa'},
  'action.borrowers': {'en': 'Borrowers', 'sw': 'Wakopaji'},
  'action.borrowersSub': {'en': 'Contracts & balances', 'sw': 'Mikataba na salio'},
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
  'loans.search': {
    'en': 'Search customer, phone or IMEI…',
    'sw': 'Tafuta mteja, simu au IMEI…',
  },
  'loans.filterAll': {'en': 'All loans ({n})', 'sw': 'Mikopo yote ({n})'},
  'loans.filterOverdue': {'en': 'Overdue ({n})', 'sw': 'Iliyochelewa ({n})'},
  'loans.filterCurrent': {'en': 'On schedule ({n})', 'sw': 'Kwa wakati ({n})'},
  'loans.listTitle': {'en': 'Loan & device ledger', 'sw': 'Orodha ya mikopo na vifaa'},
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
    'en': 'Borrower and guarantor have signed the hire-purchase contract (PDPA compliant).',
    'sw': 'Mkopaji na mdhamini wamesaini mkataba wa mauzo ya mkopo (kwa mujibu wa PDPA).',
  },
  'loans.approve': {'en': 'Approve & issue handset', 'sw': 'Kubali na toa simu'},
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
  'stock.scanTitle': {'en': 'Scan / add serial IMEI', 'sw': 'Skani / ongeza IMEI'},
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
  'sell.eyebrow': {'en': 'POS counter sale & loan', 'sw': 'Mauzo na mikopo kaunta'},
  'sell.cashTitle': {'en': 'Cash sale', 'sw': 'Mauzo ya fedha'},
  'sell.loanTitle': {'en': 'Phone loan (financed)', 'sw': 'Mkopo wa simu'},
  'sell.backHome': {'en': 'Back to home', 'sw': 'Rudi nyumbani'},
  'sell.selectHandset': {
    'en': 'Select handset for checkout',
    'sw': 'Chagua simu ya kuuza',
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
  'sell.amountDue': {'en': 'Amount due (cash total)', 'sw': 'Kiasi cha kulipa (jumla)'},
  'sell.paymentChannel': {'en': 'Payment channel', 'sw': 'Njia ya malipo'},
  'sell.cashAtCounter': {'en': 'Cash at counter', 'sw': 'Fedha kaunta'},
  'sell.mpesa': {'en': 'M-Pesa Lipa Namba', 'sw': 'M-Pesa Lipa Namba'},
  'sell.airtel': {'en': 'Airtel Money', 'sw': 'Airtel Money'},
  'sell.tigopesa': {'en': 'Tigo Pesa', 'sw': 'Tigo Pesa'},
  'sell.card': {'en': 'CRDB / NMB card', 'sw': 'Kadi ya CRDB / NMB'},
  'sell.customerContact': {'en': 'Customer contact', 'sw': 'Mawasiliano ya mteja'},
  'sell.customerName': {'en': 'Borrower legal full name', 'sw': 'Jina kamili la mkopaji'},
  'sell.customerPhone': {
    'en': 'Customer phone (SMS receipt & warranty)',
    'sw': 'Simu ya mteja (risiti ya SMS na dhamana)',
  },
  'sell.nida': {'en': 'National NIDA ID (20 digits)', 'sw': 'Namba ya NIDA (tarakimu 20)'},
  'sell.address': {
    'en': 'Residential ward / street address',
    'sw': 'Mtaa / anuani ya makazi',
  },
  'sell.imei1': {'en': 'IMEI 1 (hardware S/N)', 'sw': 'IMEI 1 (namba ya kifaa)'},
  'sell.guarantor': {'en': 'Guarantor reference', 'sw': 'Mdhamini'},
  'sell.guarantorName': {'en': 'Guarantor full legal name', 'sw': 'Jina kamili la mdhamini'},
  'sell.guarantorPhone': {'en': 'Guarantor phone number', 'sw': 'Simu ya mdhamini'},
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
  'sell.cashDone': {'en': 'POS cash sale completed', 'sw': 'Mauzo ya fedha yamekamilika'},
  'sell.loanDone': {'en': 'Phone loan disbursed', 'sw': 'Mkopo wa simu umetolewa'},
  'sell.selectedHandset': {'en': 'Selected handset', 'sw': 'Simu iliyochaguliwa'},
  'sell.cashIntro': {
    'en': 'Take payment at the counter and hand over the device with an official receipt.',
    'sw': 'Pokea malipo kaunta na mkabidhi kifaa kwa risiti rasmi.',
  },
  'sell.step1': {'en': '1. Borrower KYC verification', 'sw': '1. Uthibitisho wa KYC wa mkopaji'},
  'sell.step2': {'en': '2. Guarantor reference', 'sw': '2. Mdhamini'},
  'sell.step3': {'en': '3. Transparent terms & schedule', 'sw': '3. Masharti na ratiba wazi'},
  'sell.step4': {'en': '4. Loan agreement', 'sw': '4. Mkataba wa mkopo'},
  'sell.kycSection': {
    'en': 'Customer identity, counter photo & NIDA record',
    'sw': 'Utambulisho wa mteja, picha ya kaunta na NIDA',
  },
  'sell.passportPhoto': {'en': 'Counter passport photo', 'sw': 'Picha ya mteja kaunta'},
  'sell.nidaHint': {
    'en': 'Tanzania NIDA format (e.g. 19920415-XXXXX-XXXXX-XX)',
    'sw': 'Muundo wa NIDA Tanzania (mf. 19920415-XXXXX-XXXXX-XX)',
  },
  'sell.minDeposit': {'en': 'Min deposit (25%)', 'sw': 'Kiwango cha chini (25%)'},
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
  'sell.schedule': {'en': 'Payment calendar preview', 'sw': 'Onyesho la ratiba ya malipo'},
  'sell.agreementTitle': {'en': 'Key customer agreement terms:', 'sw': 'Masharti muhimu ya mkataba:'},
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
  'sell.supervisorPin': {'en': 'Supervisor authorization PIN', 'sw': 'PIN ya msimamizi'},
  'sell.errResolve': {
    'en': 'Please resolve the highlighted validation errors.',
    'sw': 'Tafadhali rekebisha makosa yaliyoangaziwa.',
  },
  'sell.reviewDisbursement': {'en': 'Review loan disbursement', 'sw': 'Kagua utoaji wa mkopo'},
  'sell.reviewCashTitle': {'en': 'Review POS cash sale', 'sw': 'Kagua mauzo ya fedha'},
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
  'sell.errPhone': {'en': 'Please enter the customer phone', 'sw': 'Weka simu ya mteja'},
  'sell.errAddress': {
    'en': 'Please enter the residential address',
    'sw': 'Weka anuani ya makazi',
  },

  // ------------------------------------------------------------------- scanner
  'scan.eyebrow': {'en': 'Serialized stock operations', 'sw': 'Uendeshaji wa vifaa vilivyosajiliwa'},
  'scan.title': {'en': 'Scan & verify IMEI', 'sw': 'Skani na hakiki IMEI'},
  'scan.inspector': {'en': 'IMEI inspector', 'sw': 'Mkaguzi wa IMEI'},
  'scan.searchHint': {'en': 'Type or paste a 15-digit IMEI', 'sw': 'Andika au bandika IMEI ya tarakimu 15'},
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
    'sw': 'Ruhusa ya kamera imekataliwa. Iruhusu kwenye mipangilio au andika IMEI.',
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
  'borrower.chooseChannel': {'en': 'Choose payment channel', 'sw': 'Chagua Njia ya Malipo'},
  'borrower.refNo': {'en': 'Payment reference / Ref No.', 'sw': 'Kumbukumbu ya Malipo / Ref No.'},
  'borrower.confirmReceipt': {'en': 'Confirm and issue receipt', 'sw': 'Thibitisha na Weka Risiti'},
  'borrower.paymentVoucher': {'en': 'Payment voucher', 'sw': 'Stakabadhi ya Malipo'},
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
  'borrower.totalPaid': {'en': 'Total: {paid} of {total}', 'sw': 'Jumla: {paid} kati ya {total}'},
  'borrower.receipt': {'en': 'Receipt', 'sw': 'Risiti'},
  'borrower.recordedPayments': {'en': 'Recorded payments: {n}', 'sw': 'Marejesho yaliyorekodiwa: {n}'},
  'borrower.payNow': {'en': '+ Pay', 'sw': '+ Lipa'},
  'borrower.noPayments': {'en': 'No payments recorded yet', 'sw': 'Hakuna marejesho yaliyorekodiwa bado'},
  'borrower.firstPayment': {'en': 'Record the first payment', 'sw': 'Rekodi rejesho la kwanza'},
  'borrower.contract': {'en': 'Contract', 'sw': 'Mkataba'},
  'borrower.loanCleared': {'en': 'Loan settled', 'sw': 'Mkopo umekamilika'},
  'borrower.receivePayment': {'en': 'Receive payment', 'sw': 'Pokea rejesho'},
  'borrower.accountLine': {'en': 'Account: {id} · {item}', 'sw': 'Akaunti: {id} · {item}'},
  'borrower.accountSubtitle': {'en': 'Loan account: {id}', 'sw': 'Akaunti ya mkopo: {id}'},
  'borrower.overdueBadge': {'en': 'Overdue', 'sw': 'Imechelewa'},
  'borrower.currentBadge': {'en': 'Current', 'sw': 'Inalipika vizuri'},
  'borrower.accountState': {'en': 'Account state', 'sw': 'Hali ya akaunti'},
  'borrower.fullyPaid': {'en': 'Fully paid', 'sw': 'Imelipwa yote'},
  'borrower.statementPdf': {'en': 'Loan statement (PDF)', 'sw': 'Taarifa ya mkopo (PDF)'},
  'borrower.tabSummary': {'en': 'Summary & security', 'sw': 'Muhtasari & Ulinzi'},

  // --------------------------------------------------------------- receive stock
  'recv.title': {'en': 'Receive stock', 'sw': 'Pokea stoo'},
  'recv.noLines': {'en': 'No lines yet — add what arrived', 'sw': 'Hakuna bidhaa bado — ongeza zilizofika'},
  'recv.linesSummary': {
    'en': '{lines} lines · {units} units · TZS {value}',
    'sw': 'Bidhaa {lines} · vifaa {units} · TZS {value}',
  },
  'recv.sourceTitle': {'en': 'Where is this stock coming from?', 'sw': 'Stoo hii inatoka wapi?'},
  'recv.sourceSupplier': {'en': 'Supplier', 'sw': 'Msambazaji'},
  'recv.sourceTransfer': {'en': 'Branch transfer', 'sw': 'Uhamisho wa tawi'},
  'recv.sourceReturn': {'en': 'Customer return', 'sw': 'Marejesho ya mteja'},
  'recv.supplierName': {'en': 'Supplier name', 'sw': 'Jina la msambazaji'},
  'recv.supplierHint': {'en': 'e.g. Tech Distributors Ltd', 'sw': 'mf. Tech Distributors Ltd'},
  'recv.invoice': {'en': 'Invoice or delivery note no.', 'sw': 'Namba ya ankara / hati ya mzigo'},
  'recv.invoiceHint': {'en': 'e.g. INV-2026-0412', 'sw': 'mf. INV-2026-0412'},
  'recv.fromBranch': {'en': 'Branch it left', 'sw': 'Tawi lilikotoka'},
  'recv.transferNote': {
    'en': 'The sending branch should record the same transfer, so both counts agree.',
    'sw': 'Tawi linalotuma linapaswa kurekodi uhamisho huo huo ili hesabu zilingane.',
  },
  'recv.returnNote': {
    'en': 'Add the serials so the unit returns to stock as the same device.',
    'sw': 'Ongeza namba za IMEI ili kifaa kirudi stoo kikiwa kile kile.',
  },
  'recv.whatArrived': {'en': 'What arrived', 'sw': 'Kilichofika'},
  'recv.addLine': {'en': 'Add model', 'sw': 'Ongeza modeli'},
  'recv.emptyLines': {
    'en': 'Add the models in this delivery. Quantities start at 1 and can be changed.',
    'sw': 'Ongeza modeli zilizo kwenye mzigo huu. Idadi inaanza na 1 na inaweza kubadilishwa.',
  },
  'recv.totals': {'en': '{units} units · TZS {value}', 'sw': 'Vifaa {units} · TZS {value}'},
  'recv.catalogue': {'en': 'models in catalogue', 'sw': 'modeli kwenye orodha'},
  'recv.inBranch': {'en': 'in branch', 'sw': 'tawi hili'},
  'recv.pickModel': {'en': 'Add a model', 'sw': 'Ongeza modeli'},
  'recv.noProducts': {'en': 'No models in the catalogue yet.', 'sw': 'Hakuna modeli kwenye orodha bado.'},
  'recv.scanTitle': {'en': 'Scan or type the IMEI', 'sw': 'Skani au andika IMEI'},
  'recv.scanHint': {'en': '15-digit IMEI from the box', 'sw': 'IMEI ya tarakimu 15 kutoka kwenye boksi'},
  'recv.scanFirst': {'en': 'Set the quantities before scanning serials', 'sw': 'Weka idadi kabla ya kuskani IMEI'},
  'recv.scanProgress': {'en': '{scanned} of {expected} IMEIs scanned', 'sw': '{scanned} kati ya {expected} IMEI zimeskaniwa'},
  'recv.scanButton': {'en': 'Scan / add serial IMEI', 'sw': 'Skani / ongeza IMEI'},
  'recv.useImei': {'en': 'Use this IMEI', 'sw': 'Tumia IMEI hii'},
  'recv.badImei': {'en': 'Not a valid IMEI (15 digits, GSMA check).', 'sw': 'IMEI si sahihi (tarakimu 15, hakiki ya GSMA).'},
  'recv.alreadyScanned': {'en': 'IMEI {n} is already in this delivery', 'sw': 'IMEI {n} tayari iko kwenye mzigo huu'},
  'recv.added': {'en': 'IMEI {n} added', 'sw': 'IMEI {n} imeongezwa'},
  'recv.note': {'en': 'Note (optional)', 'sw': 'Maelezo (hiari)'},
  'recv.confirm': {'en': 'Confirm receive & update stock', 'sw': 'Thibitisha na sasisha stoo'},
  'recv.ok': {'en': '{n} units added at {b}', 'sw': 'Vifaa {n} vimeongezwa {b}'},
  'recv.okLocal': {'en': '{n} units recorded in this session only — database not connected', 'sw': 'Vifaa {n} vimerekodiwa kikao hiki tu — database haijaunganishwa'},
  'recv.failed': {'en': 'The database did not accept the delivery. Nothing changed.', 'sw': 'Database haikukubali mzigo. Hakuna kilichobadilika.'},
  'recv.offline': {'en': 'No database connection in this build.', 'sw': 'Hakuna muunganisho wa database kwenye build hii.'},
  'recv.serialsStored': {'en': '{n} IMEIs saved to the handset register', 'sw': 'IMEI {n} zimehifadhiwa kwenye rejista ya simu'},
  'recv.serialsSkipped': {'en': '{n} serials were already on file and were skipped', 'sw': 'Serial {n} zilikuwa zimekwisha hifadhiwa, zimerukwa'},
  'recv.noSerials': {'en': 'No IMEIs scanned — the units arrived but the individual handsets are not on file', 'sw': 'Hakuna IMEI iliyopimwa — vifaa vimefika lakini simu mahususi haziko kwenye kumbukumbu'},
  'recv.err_lines': {'en': 'Add at least one model.', 'sw': 'Ongeza modeli angalau moja.'},
  'recv.err_quantity': {'en': 'Every line needs a quantity of at least 1.', 'sw': 'Kila bidhaa inahitaji idadi ya angalau 1.'},
  'recv.err_supplier': {'en': 'Enter the supplier name.', 'sw': 'Weka jina la msambazaji.'},
  'recv.err_fromBranch': {'en': 'Choose the branch the stock came from.', 'sw': 'Chagua tawi lilikotoka stoo.'},

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
    'en': 'Payment is late. Call the borrower ({n}) or the guarantor who signed the contract.',
    'sw': 'Deni limechelewa. Wasiliana na mkopaji ({n}) au piga simu kwa mdhamini aliyesaini mkataba.',
  },
  'insp.currentBody': {
    'en': 'Handed over under a valid hire-purchase contract. Next instalment: {d}.',
    'sw': 'Kifaa kimekabidhiwa kwa mkataba halali wa hire-purchase. Rejesho lijalo: {d}.',
  },
  'insp.notFinanced': {'en': 'Not financed (in stock)', 'sw': 'Haijakopeshwa (Ipo Stoo)'},
  'insp.imeiHint': {'en': 'Enter the 15-digit IMEI', 'sw': 'Weka namba ya IMEI (tarakimu 15)'},
  'insp.branch': {'en': 'Registered branch', 'sw': 'Tawi la Usajili'},
  'insp.loanSection': {'en': 'Customer / loan details', 'sw': 'Mteja / Taarifa za Mkopo'},
  'insp.unknownModel': {'en': 'Not registered here', 'sw': 'Haijasajiliwa hapa'},
  'insp.unknownStatus': {'en': 'Not in this shop', 'sw': 'Haipo kwenye duka hili'},
  'insp.invalidStatus': {'en': 'Not a valid IMEI', 'sw': 'IMEI si sahihi'},
  'insp.reminderSms': {
    'en': 'Hello {name}, a reminder that your instalment of TZS {amount} is due. Please pay at the shop.',
    'sw': 'Habari {name}, tunakukumbusha rejesho lako la TZS {amount}. Tafadhali lipa dukani.',
  },
  'insp.reminderOpened': {'en': 'Opening your messaging app for {phone}.', 'sw': 'Tunafungua ujumbe kwa {phone}.'},
  'insp.reminderFailed': {'en': 'No messaging app available on this device.', 'sw': 'Hakuna app ya ujumbe kwenye kifaa hiki.'},
  'insp.dossierMissing': {'en': 'That contract is no longer in the list.', 'sw': 'Mkataba huo haupo kwenye orodha tena.'},

  // ------------------------------------------------------------------- stock sheet
  'stock.sellCash': {'en': 'Sell for cash', 'sw': 'Uza Cash'},
  'stock.issueLoan': {'en': 'Issue loan', 'sw': 'Toa Mkopo'},
  'stock.inventoryHistory': {'en': 'Inventory history', 'sw': 'Historia ya stoo'},
  'stock.editPhoto': {'en': 'Edit photo', 'sw': 'Hariri Picha'},
  'stock.editPhotoTitle': {'en': 'Edit product photo', 'sw': 'Hariri Picha ya Bidhaa'},
  'stock.presets': {'en': 'Choose from existing handset images (presets):', 'sw': 'Chagua Kutoka Picha za Simu Zilizopo (Presets):'},
  'stock.photoUrl': {'en': 'Or paste an image link / URL:', 'sw': 'Au Weka Link / URL ya Picha:'},
  'stock.savePhoto': {'en': 'Save new photo', 'sw': 'Hifadhi Picha Mpya'},
  'stock.photoHint': {'en': 'Pick a real photo so the shop and the loan contract match the device.', 'sw': 'Chagua picha halisi kuonyesha dukani na kwenye mkataba wa mkopo.'},
  'stock.compressNote': {'en': 'Photos are compressed from 4.8 MB to about 74 KB before upload. The free Supabase tier (1 GB) holds 13,900+ handsets.', 'sw': 'Picha inabanwa kutoka 4.8MB hadi 74KB kabla ya kutumwa. Hifadhi ya bure ya Supabase (1GB) inatosha simu 13,900+ bila kujaa!'},

  // -------------------------------------------------------------- notifications
  'notif.title': {'en': 'Notifications', 'sw': 'Taarifa'},
  'notif.unread': {'en': '{n} unread', 'sw': '{n} hazijasomwa'},
  'notif.allRead': {'en': 'All read', 'sw': 'Zote zimesomwa'},
  'notif.markAll': {'en': 'Mark all read', 'sw': 'Soma zote'},
  'notif.markedAll': {'en': 'All marked as read', 'sw': 'Zote zimewekwa kama zimesomwa'},
  'notif.empty': {
    'en': 'Nothing needs attention. Low stock and overdue loans will appear here.',
    'sw': 'Hakuna kinachohitaji kushughulikiwa. Stoo ndogo na mikopo iliyochelewa zitaonekana hapa.',
  },
  'notif.detailTitle': {'en': 'Notice', 'sw': 'Taarifa'},
  'notif.markUnread': {'en': 'Mark unread', 'sw': 'Weka kama haijasomwa'},
  'notif.open': {'en': 'Open the relevant screen', 'sw': 'Fungua screen husika'},
  'notif.resolved': {
    'en': 'This has been resolved since you opened the list.',
    'sw': 'Hili limeshatatuliwa tangu ufungue orodha.',
  },

  // -------------------------------------------------------- settings & admin
  'set.save': {'en': 'Save', 'sw': 'Hifadhi'},
  'set.smsGuarantor': {'en': 'SMS & call the guarantor', 'sw': 'SMS & Piga Simu kwa Mdhamini'},
  'set.negotiation': {'en': 'Settle directly with the customer', 'sw': 'Mazungumzo ya Makubaliano na Mteja'},
  'set.smsTest': {
    'en': 'Reminder SMS template sent (example: "Hello, your instalment of TZS ... is now due...")',
    'sw': 'Kiolezo cha SMS ya kukumbusha rejesho kimetumwa (Mfano: "Ndugu Mteja, rejesho lako la TZS ... linatakiwa kulipwa...")',
  },
  'set.legalNotice': {'en': 'Formal demand notice', 'sw': 'Notisi Rasmi ya Madai'},
  'set.smsTestButton': {
    'en': 'Test the payment reminder SMS',
    'sw': 'Jaribu Kiolezo cha SMS ya Marejesho',
  },
  'adm.branchActive': {'en': 'Branch is operating', 'sw': 'Tawi linafanya kazi'},
  'adm.branchClosed': {'en': 'Branch is closed', 'sw': 'Tawi limefungwa'},
  'adm.saveChanges': {'en': 'Save changes', 'sw': 'Hifadhi Mabadiliko'},
  'adm.userSheetSubtitle': {
    'en': 'Set the user details and their role',
    'sw': 'Weka taarifa za mtumiaji na jukumu lake',
  },
  'adm.assignedBranch': {'en': 'Assigned branch', 'sw': 'Tawi Lililopangiwa'},
  'adm.deviceHold': {'en': 'Place device hold', 'sw': 'Weka Device Hold'},

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
