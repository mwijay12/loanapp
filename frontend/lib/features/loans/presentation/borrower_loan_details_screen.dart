import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/data/inventory_provider.dart';
import '../../../core/data/loan_balance.dart';
import '../../../core/data/mock_lims_data.dart';
import '../../../core/services/pdf_labels.dart';
import '../../../core/services/pdf_report_service.dart';
import '../../../core/services/telecom_service.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../../core/l10n/strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ui_kit.dart';

class BorrowerLoanDetailsScreen extends ConsumerStatefulWidget {
  final String loanId;
  final LoanItem? initialLoan;

  const BorrowerLoanDetailsScreen({
    super.key,
    required this.loanId,
    this.initialLoan,
  });

  @override
  ConsumerState<BorrowerLoanDetailsScreen> createState() => _BorrowerLoanDetailsScreenState();
}

class _BorrowerLoanDetailsScreenState extends ConsumerState<BorrowerLoanDetailsScreen>
    with SingleTickerProviderStateMixin {
  Locale get _locale => ref.read(localeProvider);
  late TabController _tabController;
  bool _unmaskNida = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  LoanItem? _findLoan(List<LoanItem> loans) {
    for (final l in loans) {
      if (l.id == widget.loanId || (widget.initialLoan != null && l.name == widget.initialLoan!.name)) {
        return l;
      }
    }
    return widget.initialLoan;
  }

  void _openRecordPaymentModal(LoanItem loan) {
    final amountCtrl = TextEditingController(text: LimsFormatters.formatNumber(loan.weeklyInstallment));
    final refCtrl = TextEditingController(text: 'MP${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}');
    String selectedChannel = 'M-Pesa Lipa Namba';

    LimsBottomSheet.show(
      context: context,
      title: 'Record a payment',
      subtitle: 'Mkopaji: ${loan.name} · Salio: ${loan.formattedRemainingAmount}',
      child: StatefulBuilder(
        builder: (ctx, setModalState) {
          final channels = [
            {'name': 'M-Pesa Lipa Namba', 'icon': Icons.phone_android_rounded, 'color': const Color(0xFFE11900)},
            {'name': 'Tigo Pesa', 'icon': Icons.sim_card_rounded, 'color': const Color(0xFF0033A0)},
            {'name': 'Airtel Money', 'icon': Icons.cell_tower_rounded, 'color': const Color(0xFFED1C24)},
            {'name': 'Cash Drawer (Droo)', 'icon': Icons.point_of_sale_rounded, 'color': AppTheme.brand600},
          ];

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr(_locale, 'borrower.chooseChannel'),
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppTheme.ink700),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: channels.map((c) {
                  final isSelected = selectedChannel == c['name'];
                  return InkWell(
                    onTap: () => setModalState(() => selectedChannel = c['name'] as String),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.brand50 : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isSelected ? AppTheme.brand600 : const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(c['icon'] as IconData, size: 16, color: c['color'] as Color),
                          const SizedBox(width: 6),
                          Text(
                            c['name'] as String,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                              color: isSelected ? AppTheme.brand600 : AppTheme.ink700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Payment amount (TZS)',
                  prefixText: 'TZS ',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: refCtrl,
                decoration: InputDecoration(
                  labelText: tr(_locale, 'borrower.refNo'),
                  border: const OutlineInputBorder(),
                  helperText: selectedChannel.contains('Cash') ? 'Namba ya risiti ya droo' : 'Kodi ya muamala wa simu',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () {
                    final rawAmount = int.tryParse(amountCtrl.text.replaceAll(',', '').trim()) ?? 0;
                    // One rule, shared with the tests: positive whole shillings,
                    // never more than what is still owed. An overpayment used to
                    // be clamped to "fully paid", which deleted the excess from
                    // the balance with nothing recorded anywhere.
                    switch (checkRepayment(rawAmount, loan)) {
                      case RepaymentProblem.notPositive:
                        LimsToast.show(context, 'Tafadhali weka kiasi halali cha malipo', isError: true);
                        return;
                      case RepaymentProblem.aboveBalance:
                        LimsToast.show(
                          context,
                          'Kiasi kinazidi salio la deni (TZS ${LimsFormatters.formatNumber(loan.remainingAmount)})',
                          isError: true,
                        );
                        return;
                      case RepaymentProblem.none:
                        break;
                    }

                    final newRecord = LoanPaymentRecord(
                      id: 'PM-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
                      date: 'Leo, ${TimeOfDay.now().format(context)}',
                      amount: rawAmount,
                      channel: selectedChannel,
                      refNumber: refCtrl.text.trim(),
                      receiptNumber: 'RCP-TZ-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}',
                    );

                    // Update Riverpod store
                    ref.read(loansProvider.notifier).recordPayment(loan.id, rawAmount, record: newRecord);

                    // Add to activity feed
                    ref.read(activitiesProvider.notifier).addActivity(
                      ActivityItem(
                        icon: Icons.payments_rounded,
                        iconColor: AppTheme.successColor,
                        bgColor: AppTheme.successLight,
                        title: 'Rejesho Limepokelewa · ${loan.name}',
                        description: 'TZS ${LimsFormatters.formatNumber(rawAmount)} · $selectedChannel (${refCtrl.text.trim()})',
                        time: 'Sasa hivi',
                      ),
                    );

                    Navigator.pop(ctx);
                    LimsToast.show(context, 'Rejesho la TZS ${LimsFormatters.formatNumber(rawAmount)} limefanikiwa kurekodiwa!', isSuccess: true);
                  },
                  icon: const Icon(Icons.check_circle_rounded, size: 20),
                  label: Text(tr(_locale, 'borrower.confirmReceipt'), style: TextStyle(fontWeight: FontWeight.w800)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.successColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showContractModal(LoanItem loan) {
    LimsBottomSheet.show(
      context: context,
      title: 'Loan sale agreement',
      subtitle: trf(_locale, 'borrower.accountSubtitle', {'id': loan.id}),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: SingleChildScrollView(
              child: Text(
                'HIRE-PURCHASE SMARTPHONE LOAN AGREEMENT\n\n'
                '1. Parties: Creditor (LIMS Dealership Ltd) and Borrower (${loan.name}, NIDA: ${loan.nida}, Phone: ${loan.phone}).\n\n'
                '2. Financed Device: Model ${loan.item}, Serialized IMEI: ${loan.imei}.\n\n'
                '3. Valuation & Deposit: Total loan value TZS ${loan.formattedAmount}. Initial deposit received: TZS ${loan.formattedDeposit}.\n\n'
                '4. Repayment Schedule: Weekly installment of TZS ${loan.formattedWeeklyInstallment} across ${loan.installmentWeeks} weeks.\n\n'
                '5. Default & Recovery Enforcement: In case of arrears exceeding 72 hours, creditor initiates formal debtor recovery proceedings, contact with the legally registered guarantor, and repossession notices in accordance with the Personal Data Protection Act (PDPA) and microfinance regulations.\n\n'
                '6. Guarantor: ${loan.guarantorName} (${loan.guarantorRelation}, Phone: ${loan.guarantorPhone}) confirms legal joint liability under Tanzania micro-lending regulations.',
                style: const TextStyle(fontSize: 12.5, height: 1.5, color: AppTheme.ink700),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                LimsToast.show(context, 'Downloading Loan Agreement PDF...', isSuccess: true);
              },
              icon: const Icon(Icons.picture_as_pdf_rounded, size: 18, color: AppTheme.brand600),
              label: const Text('Download Official Agreement (PDF)', style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.brand600)),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showReceiptModal(LoanPaymentRecord record, LoanItem loan) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: const BoxDecoration(
                color: AppTheme.successLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.receipt_long_rounded, color: AppTheme.successColor, size: 28),
            ),
            const SizedBox(height: 12),
            Text(
              tr(_locale, 'borrower.paymentVoucher'),
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppTheme.ink900),
            ),
            Text(
              record.receiptNumber,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.ink500),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  _receiptRow(tr(_locale, 'borrower.customer'), loan.name),
                  _receiptRow('Kifaa', loan.item),
                  _receiptRow('Amount paid', record.formattedAmount, isBold: true),
                  _receiptRow(tr(_locale, 'borrower.channel'), record.channel),
                  _receiptRow('Ref Code', record.refNumber),
                  _receiptRow('Tarehe', record.date),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.brand600,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Close receipt'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _receiptRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(fontSize: 11.5, color: AppTheme.ink500)),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
                color: isBold ? AppTheme.brand600 : AppTheme.ink900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allLoans = ref.watch(loansProvider);
    final loan = _findLoan(allLoans);

    if (loan == null) {
      return Scaffold(
        backgroundColor: AppTheme.canvas,
        appBar: AppBar(title: const Text('Loan details')),
        body: const Center(child: Text('Loan not found')),
      );
    }

    final isOverdue = loan.status == 'overdue';
    final isCleared = loan.status == 'cleared';

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.ink900, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              loan.name,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.ink900),
            ),
            Text(
              trf(_locale, 'borrower.accountLine', {'id': loan.id, 'item': loan.item}),
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppTheme.ink500),
            ),
          ],
        ),
        actions: [
          // Printed documents live behind one menu so the app bar stays readable
          // on a phone: the counter receipt, and the statement the customer keeps.
          PopupMenuButton<String>(
            icon: const Icon(Icons.picture_as_pdf_outlined,
                color: AppTheme.ink900, size: 22),
            tooltip: 'Chapisha',
            onSelected: (value) async {
              final branch = ref.read(activeBranchProvider);
              final staff = ref.read(activeStaffMemberProvider);
              if (value == 'receipt') {
                await PdfReportService.generateAndDownloadReceipt(
                  lang: _locale.languageCode == 'sw' ? PdfLang.sw : PdfLang.en,
                  loan: loan,
                  branchName: branch,
                  servedBy: staff.name,
                );
              } else {
                await PdfReportService.generateAndDownloadLoanStatement(
                  lang: _locale.languageCode == 'sw' ? PdfLang.sw : PdfLang.en,
                  loan: loan,
                  branchName: branch,
                );
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'receipt', child: Text(tr(_locale, 'borrower.receiptPdf'))),
              PopupMenuItem(
                  value: 'statement',
                  child: Text(tr(_locale, 'borrower.statementPdf'))),
            ],
          ),
          Container(
            margin: const EdgeInsets.only(right: 14),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isCleared
                  ? AppTheme.successLight
                  : isOverdue
                      ? const Color(0xFFFFEDF1)
                      : AppTheme.brand100,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isCleared
                      ? Icons.check_circle_rounded
                      : isOverdue
                          ? Icons.warning_amber_rounded
                          : Icons.schedule_rounded,
                  size: 14,
                  color: isCleared
                      ? AppTheme.successColor
                      : isOverdue
                          ? AppTheme.errorColor
                          : AppTheme.brand600,
                ),
                const SizedBox(width: 4),
                Text(
                  isCleared
                      ? tr(_locale, 'borrower.fullyPaid')
                      : isOverdue
                          ? tr(_locale, 'borrower.overdueBadge')
                          : tr(_locale, 'borrower.currentBadge'),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: isCleared
                        ? AppTheme.successColor
                        : isOverdue
                            ? AppTheme.errorColor
                            : AppTheme.brand600,
                  ),
                ),
              ],
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.brand600,
          unselectedLabelColor: AppTheme.ink500,
          indicatorColor: AppTheme.brand600,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
          tabs: [
            Tab(text: tr(_locale, 'borrower.tabSummary')),
            Tab(text: tr(_locale, 'borrower.tabKyc')),
            Tab(text: tr(_locale, 'borrower.tabHistory')),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 4,
              child: OutlinedButton.icon(
                onPressed: () => _showContractModal(loan),
                icon: const Icon(Icons.description_outlined, size: 18),
                label: Text(tr(_locale, 'borrower.contract'), style: const TextStyle(fontWeight: FontWeight.w700)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.brand600,
                  side: const BorderSide(color: AppTheme.brand600),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 6,
              child: ElevatedButton.icon(
                onPressed: isCleared ? null : () => _openRecordPaymentModal(loan),
                icon: const Icon(Icons.add_card_rounded, size: 18),
                label: Text(
                  isCleared
                      ? tr(_locale, 'borrower.loanCleared')
                      : tr(_locale, 'borrower.receivePayment'),
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.brand600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 2,
                ),
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // TAB 1: Summary & Debt Follow-up
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildBorrowerHeaderCard(loan),
                const SizedBox(height: 14),
                _buildDebtFollowUpControlCard(loan),
                const SizedBox(height: 14),
                _buildLoanFinancialsCard(loan),
                const SizedBox(height: 14),
                _buildQuickContactRow(loan),
              ],
            ),
          ),

          // TAB 2: KYC, Residence & Guarantor
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildKycDetailsCard(loan),
                const SizedBox(height: 14),
                _buildGuarantorCard(loan),
                const SizedBox(height: 14),
                _buildDeviceHardwareCard(loan),
              ],
            ),
          ),

          // TAB 3: Repayment Ledger History
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildRepaymentProgressHeader(loan),
                const SizedBox(height: 16),
                _buildPaymentsList(loan),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------------- WIDGETS
  Widget _buildBorrowerHeaderCard(LoanItem loan) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x080F3478), blurRadius: 16, offset: Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: loan.grad, begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                loan.initials,
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        loan.name,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.ink900),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.successLight,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.verified_rounded, size: 11, color: AppTheme.successColor),
                          SizedBox(width: 3),
                          Text('KYC NIDA', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: AppTheme.successColor)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Simu: ${loan.phone} · ${loan.location}',
                  style: const TextStyle(fontSize: 12, color: AppTheme.ink500),
                ),
                const SizedBox(height: 4),
                Text(
                  'Kifaa: ${loan.item}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.brand600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDebtFollowUpControlCard(LoanItem loan) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: loan.status == 'overdue' ? AppTheme.errorColor : AppTheme.brand600,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  loan.status == 'overdue' ? Icons.warning_amber_rounded : Icons.contact_phone_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loan.status == 'overdue' ? 'ARREARS ESCALATION STATUS' : 'DEBT FOLLOW-UP & ACCOUNT STANDING',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: loan.status == 'overdue' ? AppTheme.errorColor : AppTheme.ink900,
                      ),
                    ),
                    Text(
                      loan.status == 'overdue'
                          ? 'Installment payment is past due. Follow up with borrower and guarantor.'
                          : 'Account is in good standing. Next payment scheduled for ${loan.due}.',
                      style: const TextStyle(fontSize: 11, color: AppTheme.ink500),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    TelecomService.sendSmsMessage(
                      context,
                      loan.phone,
                      body: 'Habari ${loan.name}, ukumbusho wa rejesho la mkopo wa ${loan.item}. Salio ni ${loan.formattedRemainingAmount}. Lipa kupitia Lipa Namba 552219.',
                    );
                  },
                  icon: const Icon(Icons.sms_rounded, size: 15),
                  label: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Send SMS',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.brand600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        title: const Row(
                          children: [
                            Icon(Icons.supervisor_account_rounded, color: Color(0xFFF79009)),
                            SizedBox(width: 8),
                            Text('Guarantor Contact', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                          ],
                        ),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Guarantor: ${loan.guarantorName}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            Text('Phone: ${loan.guarantorPhone}', style: const TextStyle(fontSize: 13, color: AppTheme.brand600)),
                            const SizedBox(height: 4),
                            Text('Relationship: ${loan.guarantorRelation}', style: const TextStyle(fontSize: 12, color: AppTheme.ink500)),
                            const SizedBox(height: 12),
                            const Text(
                              'Please call or message guarantor only if borrower cannot be reached within 3 business days.',
                              style: TextStyle(fontSize: 11, color: AppTheme.ink600),
                            ),
                          ],
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
                          OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(ctx);
                              TelecomService.openWhatsAppChat(
                                context,
                                loan.guarantorPhone,
                                recipientName: loan.guarantorName,
                                message: 'Habari Ndg. ${loan.guarantorName}, huu ni ukumbusho kutoka LIMS kuhusu mteja uliyemdhamini (${loan.name}) kwa mkopo wa simu (${loan.item}).',
                              );
                            },
                            icon: const Icon(Icons.chat_bubble_rounded, size: 15, color: Color(0xFF25D366)),
                            label: const Text('WhatsApp'),
                          ),
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(ctx);
                              TelecomService.makePhoneCall(context, loan.guarantorPhone, recipientName: loan.guarantorName);
                            },
                            icon: const Icon(Icons.phone_rounded, size: 15),
                            label: const Text('Call Guarantor'),
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF79009), foregroundColor: Colors.white),
                          ),
                        ],
                      ),
                    );
                  },
                  icon: const Icon(Icons.supervisor_account_outlined, size: 15),
                  label: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('Guarantor', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.ink700,
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _openRecordPaymentModal(loan),
              icon: const Icon(Icons.point_of_sale_rounded, size: 18),
              label: const Text(
                'Record Installment Repayment',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoanFinancialsCard(LoanItem loan) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x080F3478), blurRadius: 16, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Repayment Status & Balance',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.ink900),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  '${loan.paidPercent}% Repaid',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: loan.status == 'overdue' ? AppTheme.errorColor : AppTheme.brand600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: loan.paidPercent / 100.0,
              minHeight: 8,
              backgroundColor: const Color(0xFFE9F2FF),
              valueColor: AlwaysStoppedAnimation<Color>(
                loan.status == 'overdue' ? AppTheme.errorColor : AppTheme.brand600,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _metricBox('Total Loan Price', loan.formattedAmount, AppTheme.ink900),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _metricBox('Initial Deposit', loan.formattedDeposit, AppTheme.successColor),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _metricBox('Total Repaid', loan.formattedTotalPaidAmount, AppTheme.brand600),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _metricBox('Remaining Balance', loan.formattedRemainingAmount, loan.remainingAmount > 0 ? AppTheme.errorColor : AppTheme.successColor),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.calendar_month_rounded, size: 16, color: AppTheme.brand600),
                      SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Weekly Due:',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.ink700),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    '${loan.formattedWeeklyInstallment} / week (${loan.due})',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppTheme.brand600),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricBox(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppTheme.ink500)),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickContactRow(LoanItem loan) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              TelecomService.makePhoneCall(context, loan.phone, recipientName: loan.name);
            },
            icon: const Icon(Icons.call_rounded, size: 15, color: AppTheme.successColor),
            label: const FittedBox(
              fit: BoxFit.scaleDown,
              child: Text('Piga Simu', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.ink900,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              TelecomService.openWhatsAppChat(
                context,
                loan.phone,
                recipientName: loan.name,
                message: 'Habari ${loan.name}, huu ni ukumbusho kutoka LIMS kuhusiana na mkopo wako wa ${loan.item}. Salio lako lililosalia ni ${loan.formattedRemainingAmount}. Asante.',
              );
            },
            icon: const Icon(Icons.chat_bubble_rounded, size: 15, color: Color(0xFF25D366)),
            label: const FittedBox(
              fit: BoxFit.scaleDown,
              child: Text('WhatsApp', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.ink900,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              TelecomService.sendSmsMessage(
                context,
                loan.phone,
                body: 'Habari ${loan.name}, ukumbusho wa rejesho la mkopo wa simu (${loan.item}). Lipa kupitia Lipa Namba 552219. Asante.',
              );
            },
            icon: const Icon(Icons.sms_rounded, size: 15, color: AppTheme.brand600),
            label: const FittedBox(
              fit: BoxFit.scaleDown,
              child: Text('Tuma SMS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.ink900,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  // TAB 2: KYC & Guarantor
  Widget _buildKycDetailsCard(LoanItem loan) {
    // P0: PII unmask is allow-listed. Unknown sessions ('noSession'),
    // cashiers and storekeepers always see masked PII.
    final viewerRole = ref.watch(userRoleProvider);
    final canViewPii = UserRoles.canViewPii(viewerRole);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x080F3478), blurRadius: 16, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Row(
                  children: [
                    Icon(Icons.badge_rounded, color: AppTheme.brand600, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Borrower Identity & KYC Details',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.ink900),
                      ),
                    ),
                  ],
                ),
              ),
              if (canViewPii)
                InkWell(
                  onTap: () => setState(() => _unmaskNida = !_unmaskNida),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Row(
                      children: [
                        Icon(_unmaskNida ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 13, color: const Color(0xFF1E60F2)),
                        const SizedBox(width: 4),
                        Text(_unmaskNida ? 'Mask PII' : 'Unmask NIDA', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF1E60F2))),
                      ],
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('PII Masked · Restricted Scope', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Borrower Live Passport Photo Portrait Section
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Container(
                  width: 58,
                  height: 70,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
                    image: const DecorationImage(
                      image: NetworkImage('https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=300&auto=format&fit=crop&q=80'),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.verified_rounded, color: Color(0xFF10B981), size: 16),
                          SizedBox(width: 4),
                          Text(
                            'Live Passport Photo Verified',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                          ),
                        ],
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Captured at Kariakoo Office Terminal #01\nBiometric Match: 98.4% Confidence',
                        style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B), height: 1.3),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          _infoRow('Legal Full Name', loan.name),
          _infoRowWithCopy(
            'National NIDA ID',
            (canViewPii && _unmaskNida)
                ? loan.nida
                : (loan.nida.length >= 10
                    ? '${loan.nida.substring(0, 8)}-••••-••••-${loan.nida.substring(loan.nida.length - 2)}'
                    : loan.nida),
          ),
          _infoRowWithCopy('M-Pesa Primary Phone', loan.phone),
          _infoRow('Residential Address & Ward', loan.location),
          _infoRow('Employer / Business Stand', loan.businessAddress),
          _infoRow('NIDA Verification Status', 'Verified & Linked to Phone IMEI', valueColor: AppTheme.successColor),
        ],
      ),
    );
  }

  Widget _buildGuarantorCard(LoanItem loan) {
    // P0: same allow-list as NIDA above — mask by default.
    final viewerRole = ref.watch(userRoleProvider);
    final canViewPii = UserRoles.canViewPii(viewerRole);
    final displayedGuarantorPhone = canViewPii
        ? loan.guarantorPhone
        : (loan.guarantorPhone.length >= 8
            ? '${loan.guarantorPhone.substring(0, 4)} *** **${loan.guarantorPhone.substring(loan.guarantorPhone.length - 2)}'
            : loan.guarantorPhone);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x080F3478), blurRadius: 16, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.people_alt_rounded, color: Color(0xFF7C5CFC), size: 20),
              SizedBox(width: 8),
              Text(
                'Guarantor & Reference Verification',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.ink900),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _infoRow('Guarantor Full Name', loan.guarantorName),
          _infoRow('Relationship to Borrower', loan.guarantorRelation),
          _infoRowWithCopy('Guarantor Contact Phone', displayedGuarantorPhone),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    TelecomService.makePhoneCall(context, loan.guarantorPhone, recipientName: loan.guarantorName);
                  },
                  icon: const Icon(Icons.phone_rounded, size: 15),
                  label: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('Call Guarantor', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7C5CFC),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    TelecomService.openWhatsAppChat(
                      context,
                      loan.guarantorPhone,
                      recipientName: loan.guarantorName,
                      message: 'Habari Ndg. ${loan.guarantorName}, huu ni ukumbusho kutoka LIMS kwa mteja ${loan.name} uliyemdhamini kwa simu ya ${loan.item}.',
                    );
                  },
                  icon: const Icon(Icons.chat_bubble_rounded, size: 15, color: Color(0xFF25D366)),
                  label: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('WhatsApp', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.ink900,
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceHardwareCard(LoanItem loan) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x080F3478), blurRadius: 16, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.phone_android_rounded, color: AppTheme.brand600, size: 20),
              SizedBox(width: 8),
              Text(
                'Kifaa Kilichokabidhiwa (Handset)',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.ink900),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _infoRow('Model ya Simu', loan.item),
          _infoRowWithCopy('IMEI 1 (Hardware ID)', loan.imei),
          _infoRow(tr(_locale, 'borrower.collateral'), tr(_locale, 'borrower.collateralValue')),
          _infoRow(tr(_locale, 'borrower.accountState'), loan.status == 'overdue'
                ? tr(_locale, 'borrower.overdueBadge')
                : tr(_locale, 'borrower.currentBadge'), valueColor: loan.status == 'overdue' ? AppTheme.errorColor : AppTheme.successColor),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppTheme.ink500)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: valueColor ?? AppTheme.ink900),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRowWithCopy(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppTheme.ink500)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppTheme.ink900),
            ),
          ),
          InkWell(
            onTap: () {
              Clipboard.setData(ClipboardData(text: value));
              LimsToast.show(context, '$label imenakiliwa!', isSuccess: true);
            },
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.copy_rounded, size: 16, color: AppTheme.brand600),
            ),
          ),
        ],
      ),
    );
  }

  // TAB 3: Repayment Ledger History
  Widget _buildRepaymentProgressHeader(LoanItem loan) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.brand50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.account_balance_wallet_rounded, color: AppTheme.brand600, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  trf(_locale, 'borrower.recordedPayments', {'n': '${loan.payments.length}'}),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.ink900),
                ),
                Text(
                  trf(_locale, 'borrower.totalPaid', {'paid': loan.formattedTotalPaidAmount, 'total': loan.formattedAmount}),
                  style: const TextStyle(fontSize: 12, color: AppTheme.ink500),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => _openRecordPaymentModal(loan),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.brand600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(tr(_locale, 'borrower.payNow'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentsList(LoanItem loan) {
    if (loan.payments.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Icon(Icons.receipt_long_outlined, size: 48, color: AppTheme.ink500.withValues(alpha: 0.5)),
              const SizedBox(height: 12),
              Text(
                tr(_locale, 'borrower.noPayments'),
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.ink700),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => _openRecordPaymentModal(loan),
                child: Text(tr(_locale, 'borrower.firstPayment')),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: loan.payments.map((p) {
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const [
              BoxShadow(color: Color(0x060F3478), blurRadius: 10, offset: Offset(0, 2)),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.successLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.check_rounded, color: AppTheme.successColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.formattedAmount,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.ink900),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${p.channel} · Ref: ${p.refNumber}',
                      style: const TextStyle(fontSize: 11.5, color: AppTheme.ink500),
                    ),
                    Text(
                      p.date,
                      style: const TextStyle(fontSize: 10.5, color: Color(0xFF9AA8BF)),
                    ),
                  ],
                ),
              ),
              OutlinedButton(
                onPressed: () => _showReceiptModal(p, loan),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.brand600,
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(tr(_locale, 'borrower.receipt'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
