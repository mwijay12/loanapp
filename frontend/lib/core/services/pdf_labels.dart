/// Words printed on paper, in the language the shop chose.
///
/// The receipts were Swahili-only while the app around them was English: a cashier
/// running the till in English handed a customer a slip headed "RISITI YA MAUZO"
/// with "Mteja" and "Malipo ya kwanza" underneath. Paper leaves the building, so it
/// cannot be fixed by the next screen refresh — the language has to be decided when
/// the document is built.
enum PdfLang { en, sw }

class PdfLabels {
  PdfLabels(this.lang);

  final PdfLang lang;

  bool get isSw => lang == PdfLang.sw;

  String _(String key) {
    final entry = _table[key];
    if (entry == null) return key;
    return isSw ? entry[1] : entry[0];
  }

  // -- masthead
  String get brand => _('brand');
  String get auditBadge => _('auditBadge');
  String get auditRef => _('auditRef');
  String get reportTitle => _('reportTitle');
  String get generated => _('generated');
  String get auditDate => _('auditDate');
  String get preparedBy => _('preparedBy');
  String get verifiedBy => _('verifiedBy');
  String get execApproval => _('execApproval');
  String get execStamp => _('execStamp');

  // -- sections
  String get stockSection => _('stockSection');
  String get loansSection => _('loansSection');
  String get totalUnits => _('totalUnits');
  String get activeLedger => _('activeLedger');
  String get overdueAccounts => _('overdueAccounts');
  String get onTime => _('onTime');

  // -- columns
  String get model => _('model');
  String get sku => _('sku');
  String get imei => _('imei');
  String get imei2 => _('imei2');
  String get status => _('status');
  String get unitPrice => _('unitPrice');
  String get units => _('units');
  String get inStock => _('inStock');
  String get customer => _('customer');
  String get guarantor => _('guarantor');
  String get handset => _('handset');
  String get amount => _('amount');
  String get paid => _('paid');
  String get remaining => _('remaining');
  String get nextDue => _('nextDue');
  String get date => _('date');
  String get total => _('total');
  String get active => _('active');
  String get overdue => _('overdue');

  // -- attendance
  String get timesheetTitle => _('timesheetTitle');
  String get staffName => _('staffName');
  String get role => _('role');
  String get shiftHours => _('shiftHours');
  String get clockIn => _('clockIn');
  String get clockOut => _('clockOut');
  String get totalStaff => _('totalStaff');
  String get activeShifts => _('activeShifts');
  String get completedShifts => _('completedShifts');
  String get onDuty => _('onDuty');
  String get compliance => _('compliance');
  String get reconciled => _('reconciled');
  String get signatureDate => _('signatureDate');

  // -- receipts
  String get saleReceipt => _('saleReceipt');
  String get loanReceipt => _('loanReceipt');
  String get receiptNo => _('receiptNo');
  String get servedBy => _('servedBy');
  String get phone => _('phone');
  String get nida => _('nida');
  String get location => _('location');
  String get item => _('item');
  String get retailPrice => _('retailPrice');
  String get deposit => _('deposit');
  String get balance => _('balance');
  String get weekly => _('weekly');
  String get term => _('term');
  String get weeks => _('weeks');
  String get firstDue => _('firstDue');
  String get channel => _('channel');
  String get customerSign => _('customerSign');
  String get sellerSign => _('sellerSign');
  String get branchStamp => _('branchStamp');
  String get thanks => _('thanks');
  String get saleNote => _('saleNote');
  String get loanNote => _('loanNote');

  // -- statement
  String get statementTitle => _('statementTitle');
  String get statementNote => _('statementNote');
  String get schedule => _('schedule');
  String get statementFile => _('statementFile');

  String get receiptFilePrefix => isSw ? 'Risiti' : 'Receipt';

  static const List<List<String>> _monthNames = [
    ['January', 'Januari'],
    ['February', 'Februari'],
    ['March', 'Machi'],
    ['April', 'Aprili'],
    ['May', 'Mei'],
    ['June', 'Juni'],
    ['July', 'Julai'],
    ['August', 'Agosti'],
    ['September', 'Septemba'],
    ['October', 'Oktoba'],
    ['November', 'Novemba'],
    ['December', 'Desemba'],
  ];

  /// `22 October 2026` / `22 Oktoba 2026`.
  String longDate(DateTime d) {
    final month = _monthNames[d.month - 1][isSw ? 1 : 0];
    return '${d.day} $month ${d.year}';
  }

  static const Map<String, List<String>> _table = {
    'brand': ['Smartphone Retail & Hire Purchase', 'Uuzaji wa Simu na Mikopo'],
    'auditBadge': ['OFFICIAL AUDIT', 'UKAGUZI RASMI'],
    'auditRef': ['AUDIT REF', 'KUMBUKUMBU YA UKAGUZI'],
    'reportTitle': [
      'Branch Operations, Sales & Credit Audit Report',
      'Ripoti ya Uendeshaji, Mauzo na Mikopo',
    ],
    'generated': ['Generated', 'Imetengenezwa'],
    'auditDate': ['Audit date', 'Tarehe ya ukaguzi'],
    'preparedBy': ['Prepared by', 'Imeandaliwa na'],
    'verifiedBy': ['Verified by', 'Imethibitishwa na'],
    'execApproval': [
      'Executive approval: Managing Director',
      'Idhini ya mtendaji: Mkurugenzi',
    ],
    'execStamp': ['Executive stamp & signature', 'Muhuri na sahihi ya mtendaji'],
    'stockSection': [
      '1. Branch handset inventory & valuation',
      '1. Orodha ya simu na thamani yake',
    ],
    'loansSection': [
      '2. Active micro-loans & collections schedule',
      '2. Mikopo hai na ratiba ya makusanyo',
    ],
    'totalUnits': ['Total handset units', 'Jumla ya vifaa'],
    'activeLedger': ['Active credit ledger', 'Daftari la mikopo hai'],
    'overdueAccounts': ['Overdue accounts', 'Mikopo iliyochelewa'],
    'onTime': ['On time', 'Kwa wakati'],
    'model': ['Model', 'Modeli'],
    'sku': ['Variant / SKU', 'Aina / SKU'],
    'imei': ['IMEI', 'IMEI'],
    'imei2': ['IMEI 2', 'IMEI 2'],
    'status': ['Status', 'Hali'],
    'unitPrice': ['Unit price', 'Bei ya kimoja'],
    'units': ['Units', 'Vifaa'],
    'inStock': ['In stock', 'Ipo stoo'],
    'customer': ['Customer', 'Mteja'],
    'guarantor': ['Guarantor', 'Mdhamini'],
    'handset': ['Handset', 'Kifaa'],
    'amount': ['Amount', 'Kiasi'],
    'paid': ['Paid', 'Iliyolipwa'],
    'remaining': ['Remaining', 'Salio'],
    'nextDue': ['Next due', 'Inayofuata'],
    'date': ['Date', 'Tarehe'],
    'total': ['Total', 'Jumla'],
    'active': ['Active', 'Hai'],
    'overdue': ['Overdue', 'Imechelewa'],
    'timesheetTitle': [
      'Official staff attendance & timesheet audit',
      'Ripoti ya mahudhurio na saa za kazi',
    ],
    'staffName': ['Staff name', 'Jina la mfanyakazi'],
    'role': ['Role', 'Jukumu'],
    'shiftHours': ['Hours', 'Saa'],
    'clockIn': ['Clock in', 'Kuingia'],
    'clockOut': ['Clock out', 'Kutoka'],
    'totalStaff': ['Total staff logged', 'Jumla ya wafanyakazi'],
    'activeShifts': ['Active shifts', 'Zamu zinazoendelea'],
    'completedShifts': ['Completed shifts', 'Zamu zilizokamilika'],
    'onDuty': ['On duty', 'Kazini'],
    'compliance': ['Compliance score', 'Alama ya uzingatiaji'],
    'reconciled': ['Reconciled', 'Imelinganishwa'],
    'signatureDate': ['Signature & date', 'Sahihi na tarehe'],
    'saleReceipt': ['SALES RECEIPT', 'RISITI YA MAUZO'],
    'loanReceipt': ['LOAN RECEIPT', 'RISITI YA MKOPO'],
    'receiptNo': ['Receipt no.', 'Risiti na.'],
    'servedBy': ['Served by', 'Aliyehudumia'],
    'phone': ['Phone', 'Simu'],
    'nida': ['NIDA', 'NIDA'],
    'location': ['Location', 'Mahali'],
    'item': ['Item', 'Bidhaa'],
    'retailPrice': ['Retail price', 'Bei ya rejareja'],
    'deposit': ['Deposit', 'Malipo ya kwanza'],
    'balance': ['Balance financed', 'Deni lililobaki'],
    'weekly': ['Weekly instalment', 'Mkopo wa wiki'],
    'term': ['Term', 'Muda'],
    'weeks': ['weeks', 'wiki'],
    'firstDue': ['First instalment due', 'Malipo ya kwanza tarehe'],
    'channel': ['Payment channel', 'Njia ya malipo'],
    'customerSign': ['Customer', 'Mteja'],
    'sellerSign': ['Seller', 'Muuzaji'],
    'branchStamp': ['Branch stamp', 'Muhuri wa tawi'],
    'thanks': ['Thank you for choosing LIMS', 'Asante kwa kuchagua LIMS'],
    'saleNote': [
      'This handset is registered under the IMEI above. Keep this receipt as proof '
          'of purchase and warranty.',
      'Kifaa hiki kimeandikishwa kwa IMEI hapo juu. Hifadhi risiti hii kama '
          'uthibitisho wa ununuzi na dhamana.',
    ],
    'loanNote': [
      'This handset is registered under the IMEI above. This receipt is proof of '
          'ownership and of the instalment agreement.',
      'Kifaa hiki kimeandikishwa kwa IMEI hapo juu. Risiti hii ni uthibitisho wa '
          'umiliki na wa mkataba wa malipo kwa awamu.',
    ],
    'statementTitle': ['CUSTOMER STATEMENT', 'TAARIFA YA MKOPO'],
    'statementNote': [
      'This statement reflects the records held in LIMS. If a payment is missing, '
          'contact your branch with the receipt.',
      'Taarifa hii inaonyesha rekodi zilizopo kwenye mfumo wa LIMS. Kama kuna '
          'malipo ambayo hayajaonekana, wasiliana na tawi lako na leta risiti.',
    ],
    'schedule': ['Payment schedule', 'Ratiba ya malipo'],
    'statementFile': ['Statement', 'Taarifa'],
  };
}
