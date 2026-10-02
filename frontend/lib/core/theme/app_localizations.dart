import 'package:flutter/material.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        AppLocalizations(const Locale('en'));
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  static final Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'app_name': 'Loan & Inventory',
      'welcome': 'Welcome Back',
      'sign_in_to_continue': 'Sign in to continue',
      'email': 'Email',
      'password': 'Password',
      'enter_email': 'Enter your email',
      'enter_password': 'Enter your password',
      'forgot_password': 'Forgot Password?',
      'sign_in': 'SIGN IN',
      'good_morning': 'Good morning',
      'branch_name': 'Kariakoo Branch',
      'online': 'Online',
      'offline': 'Offline',
      'synced_just_now': 'Synced just now',
      'transactions_waiting': 'transactions waiting to sync',
      'syncing': 'Syncing...',
      'all_synced': 'All transactions synced',
      'scan_phone': 'SCAN PHONE',
      'scan_barcode_imei': 'Scan barcode / IMEI',
      'sell_loan': 'SELL / LOAN',
      'receive': 'RECEIVE',
      'transfer': 'TRANSFER',
      'stock': 'STOCK',
      'attendance': 'ATTENDANCE',
      'daily_close': 'DAILY CLOSE',
      'home': 'Home',
      'reports': 'Reports',
      'account': 'Account',
      'ai_assistant': 'AI Assistant',
      'ask_about_business': 'Ask about your business',
      'ask_anything': 'Ask anything...',
      'my_branch_stock': 'My Branch Stock',
      'phones': 'phones',
      'all': 'All',
      'available': 'Available',
      'transferred': 'Transferred',
      'sold': 'Sold',
      'returned': 'Returned',
      'damaged': 'Damaged',
      'search_by_imei': 'Search by IMEI, model, brand...',
      'no_phones_found': 'No phones found',
      'try_another_imei': 'Try another IMEI or filter.',
      'todays_report': "Today's Report",
      'sales': 'Sales',
      'loans': 'Loans',
      'revenue': 'Revenue',
      'phones_received': 'Phones Received',
      'phones_transferred': 'Phones Transferred',
      'present': 'Present',
      'stock_status': 'Stock Status',
      'matched': 'Matched',
      'generate_report': 'GENERATE REPORT',
      'send_report': 'SEND REPORT',
      'settings': 'Settings',
      'language': 'Language',
      'english': 'English',
      'swahili': 'Kiswahili',
      'sign_out': 'Sign Out',
      'notifications': 'Notifications',
      'admin_dashboard': 'Admin Dashboard',
      'branch_performance': 'Branch Performance',
      'demo_credentials': 'Demo Credentials',
      'no_pending_transfers': 'No pending transfers',
      'all_transfers_completed': 'All transfers have been completed.',
      'no_report_available': 'No report available',
      'report_after_closing': "The report will appear after today's closing.",
      'checking_in': 'CHECK IN',
      'checking_out': 'CHECK OUT',
      'checked_in': 'CHECKED IN',
      'not_checked_in': 'NOT CHECKED IN',
      'branch_verified': 'Branch verified',
      'start_stocktake': 'START STOCKTAKE',
      'close_day': 'CLOSE DAY',
      'physical_count': 'Physical Count',
      'pending': 'Pending',
      'stock_matched': 'STOCK MATCHED',
      'view_discrepancy': 'VIEW DISCREPANCY',
      'opening_stock': 'Opening Stock',
      'expected_closing': 'Expected Closing',
      'create_transfer': 'Create Transfer',
      'from': 'From',
      'to': 'To',
      'scan_phones': 'SCAN PHONES',
      'create_transfer_btn': 'CREATE TRANSFER',
      'no_phones_selected': 'No phones selected yet',
      'sell': 'SELL',
      'loan': 'LOAN',
      'choose_transaction': 'Choose transaction',
      'customer': 'Customer',
      'full_name': 'Full Name',
      'phone_number': 'Phone Number',
      'id_number': 'ID Number',
      'loan_details': 'Loan Details',
      'loan_amount': 'Loan Amount',
      'deposit': 'Deposit',
      'installment': 'Installment',
      'due_date': 'Due Date',
      'confirm_loan': 'CONFIRM LOAN',
      'confirm_sale': 'CONFIRM SALE',
      'loan_created': 'Loan successfully created',
      'sale_completed': 'Sale completed',
      'transaction_id': 'Transaction ID',
      'done': 'DONE',
      'cancel': 'CANCEL',
      'confirm': 'Confirm',
      'view_details': 'VIEW DETAILS',
      'receive_stock': 'Receive Stock',
      'scan_box': 'Scan box',
      'verify': 'VERIFY',
      'receive_stock_btn': 'RECEIVE STOCK',
      'box': 'BOX',
      'phones_detected': 'phones detected',
      'imeis_found': 'IMEIs found',
      'stock_discrepancy': 'Stock discrepancy',
      'expected': 'Expected',
      'physical': 'Physical',
      'phones_missing': 'phones missing',
      'unaccounted_for': 'UNACCOUNTED FOR',
      'loan_status': 'Loan status',
    },
    'sw': {
      'app_name': 'Mikopo & Hesabu',
      'welcome': 'Karibu Tena',
      'sign_in_to_continue': 'Ingia kuendelea',
      'email': 'Barua Pepe',
      'password': 'Nenosiri',
      'enter_email': 'Weka barua pepe yako',
      'enter_password': 'Weka nenosiri lako',
      'forgot_password': 'Umesahau Nenosiri?',
      'sign_in': 'INGIA',
      'good_morning': 'Habari za asubuhi',
      'branch_name': 'Tawi la Kariakoo',
      'online': 'Mtandaoni',
      'offline': 'Nje ya mtandao',
      'synced_just_now': 'Imesasishwa sasa hivi',
      'transactions_waiting': 'miamala inayosubiri kusasishwa',
      'syncing': 'Inasasisha...',
      'all_synced': 'Miamala yote imesasishwa',
      'scan_phone': 'SKANI SIMU',
      'scan_barcode_imei': 'Skani barcode / IMEI',
      'sell_loan': 'UZA / KOPA',
      'receive': 'POKEA',
      'transfer': 'HAMISHA',
      'stock': 'HESABU',
      'attendance': 'HUDHURIO',
      'daily_close': 'FUNGA SIKU',
      'home': 'Nyumbani',
      'reports': 'Ripoti',
      'account': 'Akaunti',
      'ai_assistant': 'Msaada wa AI',
      'ask_about_business': 'Uliza kuhusu biashara yako',
      'ask_anything': 'Uliza chochote...',
      'my_branch_stock': 'Hesabu za Tawi langu',
      'phones': 'simu',
      'all': 'Zote',
      'available': 'Inapatikana',
      'transferred': 'Imehamishwa',
      'sold': 'Imeuzwa',
      'returned': 'Imerejeshwa',
      'damaged': 'Imeharibika',
      'search_by_imei': 'Tafuta kwa IMEI, modeli, brandi...',
      'no_phones_found': 'Hakuna simu zilizopatikana',
      'try_another_imei': 'Jaribu IMEI nyingine au kichujio.',
      'todays_report': 'Ripoti ya Leo',
      'sales': 'Mauzo',
      'loans': 'Mikopo',
      'revenue': 'Mapato',
      'phones_received': 'Simu Zilizopokelewa',
      'phones_transferred': 'Simu Zilihamishwa',
      'present': 'Waliopatikana',
      'stock_status': 'Hali ya Hesabu',
      'matched': 'Imelingana',
      'generate_report': 'TENDA RIPOTI',
      'send_report': 'TUMA RIPOTI',
      'settings': 'Mipangilio',
      'language': 'Lugha',
      'english': 'Kiingereza',
      'swahili': 'Kiswahili',
      'sign_out': 'Toka',
      'notifications': 'Arifa',
      'admin_dashboard': 'Dashibodi ya Msimamizi',
      'branch_performance': 'Utendaji wa Tawi',
      'demo_credentials': 'Hesabu za Majaribio',
      'no_pending_transfers': 'Hakuna masuala yanayosubiri',
      'all_transfers_completed': 'Masuala yote yametokea.',
      'no_report_available': 'Hakuna ripoti inayopatikana',
      'report_after_closing': 'Ripoti itaonekana baada ya kufunga siku.',
      'checking_in': 'INGIA',
      'checking_out': 'TOKA',
      'checked_in': 'UMEWASILI',
      'not_checked_in': 'HUJAWASILI',
      'branch_verified': 'Tawi limethibitishwa',
      'start_stocktake': 'ANZA HESABU',
      'close_day': 'FUNGA SIKU',
      'physical_count': 'Hesabu ya Kimwili',
      'pending': 'Inasubiri',
      'stock_matched': 'HESABU IMELINGANA',
      'view_discrepancy': 'ONA TOFAUTI',
      'opening_stock': 'Hesabu ya Kufungua',
      'expected_closing': 'Kufungulia Kunakotarajiwa',
      'create_transfer': 'Tengeneza Uhamisho',
      'from': 'Kutoka',
      'to': 'Kwa',
      'scan_phones': 'SKANI SIMU',
      'create_transfer_btn': 'TENGENEZA UHAMISHO',
      'no_phones_selected': 'Hakuna simu zilizochaguliwa',
      'sell': 'UZA',
      'loan': 'KOPA',
      'choose_transaction': 'Chagua muamala',
      'customer': 'Mteja',
      'full_name': 'Jina Kamili',
      'phone_number': 'Nambari ya Simu',
      'id_number': 'Nambari ya Kitambulisho',
      'loan_details': 'Maelezo ya Mkopo',
      'loan_amount': 'Kiasi cha Mkopo',
      'deposit': 'Amana',
      'installment': 'Malipo ya Kila Mwezi',
      'due_date': 'Tarehe ya Malipo',
      'confirm_loan': 'THIBITISHA MKOPO',
      'confirm_sale': 'THIBITISHA MAUZO',
      'loan_created': 'Mkopo umefanikiwa kuundwa',
      'sale_completed': 'Mauzo yamekamilika',
      'transaction_id': 'Kitambulisho cha Muamala',
      'done': 'MALIZA',
      'cancel': 'GHARIKI',
      'confirm': 'Thibitisha',
      'view_details': 'ONA MAELEZO',
      'receive_stock': 'Pokea Hesabu',
      'scan_box': 'Skani sanduku',
      'verify': 'THIBITISHA',
      'receive_stock_btn': 'POKEA HESABU',
      'box': 'SANDUKU',
      'phones_detected': 'simu zimegunduliwa',
      'imeis_found': 'IMEI zilizopatikana',
      'stock_discrepancy': 'Tofauti ya hesabu',
      'expected': 'Inatarajiwa',
      'physical': 'Kimwili',
      'phones_missing': 'simu zinakosekana',
      'unaccounted_for': 'ZISIOHESABIKA',
      'loan_status': 'Hali ya Mkopo',
    },
  };

  String get app_name => _localizedValues[locale.languageCode]!['app_name']!;
  String get welcome => _localizedValues[locale.languageCode]!['welcome']!;
  String get sign_in_to_continue => _localizedValues[locale.languageCode]!['sign_in_to_continue']!;
  String get email => _localizedValues[locale.languageCode]!['email']!;
  String get password => _localizedValues[locale.languageCode]!['password']!;
  String get enter_email => _localizedValues[locale.languageCode]!['enter_email']!;
  String get enter_password => _localizedValues[locale.languageCode]!['enter_password']!;
  String get forgot_password => _localizedValues[locale.languageCode]!['forgot_password']!;
  String get sign_in => _localizedValues[locale.languageCode]!['sign_in']!;
  String get good_morning => _localizedValues[locale.languageCode]!['good_morning']!;
  String get branch_name => _localizedValues[locale.languageCode]!['branch_name']!;
  String get online => _localizedValues[locale.languageCode]!['online']!;
  String get offline => _localizedValues[locale.languageCode]!['offline']!;
  String get synced_just_now => _localizedValues[locale.languageCode]!['synced_just_now']!;
  String get transactions_waiting => _localizedValues[locale.languageCode]!['transactions_waiting']!;
  String get syncing => _localizedValues[locale.languageCode]!['syncing']!;
  String get all_synced => _localizedValues[locale.languageCode]!['all_synced']!;
  String get scan_phone => _localizedValues[locale.languageCode]!['scan_phone']!;
  String get scan_barcode_imei => _localizedValues[locale.languageCode]!['scan_barcode_imei']!;
  String get sell_loan => _localizedValues[locale.languageCode]!['sell_loan']!;
  String get receive => _localizedValues[locale.languageCode]!['receive']!;
  String get transfer => _localizedValues[locale.languageCode]!['transfer']!;
  String get stock => _localizedValues[locale.languageCode]!['stock']!;
  String get attendance => _localizedValues[locale.languageCode]!['attendance']!;
  String get daily_close => _localizedValues[locale.languageCode]!['daily_close']!;
  String get home => _localizedValues[locale.languageCode]!['home']!;
  String get reports => _localizedValues[locale.languageCode]!['reports']!;
  String get account => _localizedValues[locale.languageCode]!['account']!;
  String get ai_assistant => _localizedValues[locale.languageCode]!['ai_assistant']!;
  String get ask_about_business => _localizedValues[locale.languageCode]!['ask_about_business']!;
  String get ask_anything => _localizedValues[locale.languageCode]!['ask_anything']!;
  String get my_branch_stock => _localizedValues[locale.languageCode]!['my_branch_stock']!;
  String get phones => _localizedValues[locale.languageCode]!['phones']!;
  String get all => _localizedValues[locale.languageCode]!['all']!;
  String get available => _localizedValues[locale.languageCode]!['available']!;
  String get transferred => _localizedValues[locale.languageCode]!['transferred']!;
  String get sold => _localizedValues[locale.languageCode]!['sold']!;
  String get returned => _localizedValues[locale.languageCode]!['returned']!;
  String get damaged => _localizedValues[locale.languageCode]!['damaged']!;
  String get search_by_imei => _localizedValues[locale.languageCode]!['search_by_imei']!;
  String get no_phones_found => _localizedValues[locale.languageCode]!['no_phones_found']!;
  String get try_another_imei => _localizedValues[locale.languageCode]!['try_another_imei']!;
  String get todays_report => _localizedValues[locale.languageCode]!['todays_report']!;
  String get sales => _localizedValues[locale.languageCode]!['sales']!;
  String get loans => _localizedValues[locale.languageCode]!['loans']!;
  String get revenue => _localizedValues[locale.languageCode]!['revenue']!;
  String get phones_received => _localizedValues[locale.languageCode]!['phones_received']!;
  String get phones_transferred => _localizedValues[locale.languageCode]!['phones_transferred']!;
  String get present => _localizedValues[locale.languageCode]!['present']!;
  String get stock_status => _localizedValues[locale.languageCode]!['stock_status']!;
  String get matched => _localizedValues[locale.languageCode]!['matched']!;
  String get generate_report => _localizedValues[locale.languageCode]!['generate_report']!;
  String get send_report => _localizedValues[locale.languageCode]!['send_report']!;
  String get settings => _localizedValues[locale.languageCode]!['settings']!;
  String get language => _localizedValues[locale.languageCode]!['language']!;
  String get english => _localizedValues[locale.languageCode]!['english']!;
  String get swahili => _localizedValues[locale.languageCode]!['swahili']!;
  String get sign_out => _localizedValues[locale.languageCode]!['sign_out']!;
  String get notifications => _localizedValues[locale.languageCode]!['notifications']!;
  String get admin_dashboard => _localizedValues[locale.languageCode]!['admin_dashboard']!;
  String get branch_performance => _localizedValues[locale.languageCode]!['branch_performance']!;
  String get demo_credentials => _localizedValues[locale.languageCode]!['demo_credentials']!;
  String get no_pending_transfers => _localizedValues[locale.languageCode]!['no_pending_transfers']!;
  String get all_transfers_completed => _localizedValues[locale.languageCode]!['all_transfers_completed']!;
  String get no_report_available => _localizedValues[locale.languageCode]!['no_report_available']!;
  String get report_after_closing => _localizedValues[locale.languageCode]!['report_after_closing']!;
  String get checking_in => _localizedValues[locale.languageCode]!['checking_in']!;
  String get checking_out => _localizedValues[locale.languageCode]!['checking_out']!;
  String get checked_in => _localizedValues[locale.languageCode]!['checked_in']!;
  String get not_checked_in => _localizedValues[locale.languageCode]!['not_checked_in']!;
  String get branch_verified => _localizedValues[locale.languageCode]!['branch_verified']!;
  String get start_stocktake => _localizedValues[locale.languageCode]!['start_stocktake']!;
  String get close_day => _localizedValues[locale.languageCode]!['close_day']!;
  String get physical_count => _localizedValues[locale.languageCode]!['physical_count']!;
  String get pending => _localizedValues[locale.languageCode]!['pending']!;
  String get stock_matched => _localizedValues[locale.languageCode]!['stock_matched']!;
  String get view_discrepancy => _localizedValues[locale.languageCode]!['view_discrepancy']!;
  String get opening_stock => _localizedValues[locale.languageCode]!['opening_stock']!;
  String get expected_closing => _localizedValues[locale.languageCode]!['expected_closing']!;
  String get create_transfer => _localizedValues[locale.languageCode]!['create_transfer']!;
  String get from => _localizedValues[locale.languageCode]!['from']!;
  String get to => _localizedValues[locale.languageCode]!['to']!;
  String get scan_phones => _localizedValues[locale.languageCode]!['scan_phones']!;
  String get create_transfer_btn => _localizedValues[locale.languageCode]!['create_transfer_btn']!;
  String get no_phones_selected => _localizedValues[locale.languageCode]!['no_phones_selected']!;
  String get sell => _localizedValues[locale.languageCode]!['sell']!;
  String get loan => _localizedValues[locale.languageCode]!['loan']!;
  String get choose_transaction => _localizedValues[locale.languageCode]!['choose_transaction']!;
  String get customer => _localizedValues[locale.languageCode]!['customer']!;
  String get full_name => _localizedValues[locale.languageCode]!['full_name']!;
  String get phone_number => _localizedValues[locale.languageCode]!['phone_number']!;
  String get id_number => _localizedValues[locale.languageCode]!['id_number']!;
  String get loan_details => _localizedValues[locale.languageCode]!['loan_details']!;
  String get loan_amount => _localizedValues[locale.languageCode]!['loan_amount']!;
  String get deposit => _localizedValues[locale.languageCode]!['deposit']!;
  String get installment => _localizedValues[locale.languageCode]!['installment']!;
  String get due_date => _localizedValues[locale.languageCode]!['due_date']!;
  String get confirm_loan => _localizedValues[locale.languageCode]!['confirm_loan']!;
  String get confirm_sale => _localizedValues[locale.languageCode]!['confirm_sale']!;
  String get loan_created => _localizedValues[locale.languageCode]!['loan_created']!;
  String get sale_completed => _localizedValues[locale.languageCode]!['sale_completed']!;
  String get transaction_id => _localizedValues[locale.languageCode]!['transaction_id']!;
  String get done => _localizedValues[locale.languageCode]!['done']!;
  String get cancel => _localizedValues[locale.languageCode]!['cancel']!;
  String get confirm => _localizedValues[locale.languageCode]!['confirm']!;
  String get view_details => _localizedValues[locale.languageCode]!['view_details']!;
  String get receive_stock => _localizedValues[locale.languageCode]!['receive_stock']!;
  String get scan_box => _localizedValues[locale.languageCode]!['scan_box']!;
  String get verify => _localizedValues[locale.languageCode]!['verify']!;
  String get receive_stock_btn => _localizedValues[locale.languageCode]!['receive_stock_btn']!;
  String get box => _localizedValues[locale.languageCode]!['box']!;
  String get phones_detected => _localizedValues[locale.languageCode]!['phones_detected']!;
  String get imeis_found => _localizedValues[locale.languageCode]!['imeis_found']!;
  String get stock_discrepancy => _localizedValues[locale.languageCode]!['stock_discrepancy']!;
  String get expected => _localizedValues[locale.languageCode]!['expected']!;
  String get physical => _localizedValues[locale.languageCode]!['physical']!;
  String get phones_missing => _localizedValues[locale.languageCode]!['phones_missing']!;
  String get unaccounted_for => _localizedValues[locale.languageCode]!['unaccounted_for']!;
  String get loan_status => _localizedValues[locale.languageCode]!['loan_status']!;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['en', 'sw'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
