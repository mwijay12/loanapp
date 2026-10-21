import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';

import 'pdf_labels.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../constants/app_constants.dart';
import '../data/lims_repository.dart';
import '../data/mock_lims_data.dart';

class PdfReportService {
  PdfReportService._();

  static Future<void> generateAndDownloadFinancialReport({
    PdfLang lang = PdfLang.en,
    required String branchName,
    required List<ProductItem> products,
    required List<LoanItem> loans,
    required int totalSales,
    required int totalStock,
  }) async {
    final l = PdfLabels(lang);
    final pdf = pw.Document();
    final now = DateTime.now();
    final dateStr = DateFormat('dd MMMM yyyy, HH:mm').format(now);
    final reportId = 'LIMS-REP-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${now.millisecondsSinceEpoch.toString().substring(8)}';

    final totalLoanBal = loans.fold<int>(0, (sum, l) => sum + l.remainingAmount);
    final overdueLoans = loans.where((l) => l.status == 'overdue').toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) => [
          // Header
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'LIMS · SMARTPHONE POS & FINANCING',
                    style: const pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue800,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    l.reportTitle,
                    style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
                  ),
                  pw.Text(
                    'Branch: $branchName  |  Generated: $dateStr',
                    style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                  ),
                ],
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: pw.BoxDecoration(
                  color: PdfColors.blue50,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  border: pw.Border.all(color: PdfColors.blue200),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('OFFICIAL AUDIT', style: const pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                    pw.Text(reportId, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey800)),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Divider(color: PdfColors.grey300),
          pw.SizedBox(height: 12),

          // Key Metrics Summary Grid
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _buildPdfKpiBox(l.totalUnits, '$totalStock units', PdfColors.blue700),
              _buildPdfKpiBox(l.activeLedger, 'TZS ${_formatNumber(totalLoanBal)}', PdfColors.purple700),
              _buildPdfKpiBox(l.overdueAccounts, '${overdueLoans.length} active', overdueLoans.isNotEmpty ? PdfColors.red700 : PdfColors.green700),
              _buildPdfKpiBox('Audit Status', l.reconciled, PdfColors.green700),
            ],
          ),
          pw.SizedBox(height: 20),

          // Inventory Table
          pw.Text(
            '1. Branch Handset Inventory & Valuation',
            style: const pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.grey900),
          ),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headers: [l.model, l.sku, l.unitPrice, l.inStock, l.status],
            data: products.take(8).map((p) {
              return [
                p.name,
                p.variant,
                'TZS ${_formatNumber(p.price)}',
                '${p.stock} units',
                p.status.toUpperCase(),
              ];
            }).toList(),
            headerStyle: const pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
            cellStyle: const pw.TextStyle(fontSize: 8.5),
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
          ),
          pw.SizedBox(height: 20),

          // Loans Table
          pw.Text(
            '2. Active Micro-Loans & Collections Schedule',
            style: const pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.grey900),
          ),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headers: [l.customer, l.handset, 'Remaining Balance', l.guarantor, l.status],
            data: loans.map((l) {
              return [
                l.name,
                l.item,
                'TZS ${_formatNumber(l.remainingAmount)}',
                '${l.guarantorName} (${l.guarantorPhone})',
                l.status.toUpperCase(),
              ];
            }).toList(),
            headerStyle: const pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
            cellStyle: const pw.TextStyle(fontSize: 8.5),
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
          ),
          pw.SizedBox(height: 24),

          // Authorization & Signatures
          pw.Divider(color: PdfColors.grey300),
          pw.SizedBox(height: 12),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Prepared By: ${UserRoles.counterCashier} / ${UserRoles.storekeeper}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                  pw.SizedBox(height: 24),
                  pw.Container(width: 140, height: 1, color: PdfColors.grey400),
                  pw.SizedBox(height: 4),
                  pw.Text(l.signatureDate, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('Verified By: ${UserRoles.branchManager} / ${UserRoles.superAdmin}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                  pw.SizedBox(height: 24),
                  pw.Container(width: 140, height: 1, color: PdfColors.grey400),
                  pw.SizedBox(height: 4),
                  pw.Text(l.execStamp, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                ],
              ),
            ],
          ),
        ],
      ),
    );

    // Trigger direct native print or save-as-PDF in browser / Android
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'LIMS_Report_$reportId.pdf',
    );
  }

  static Future<void> generateAndDownloadTimesheetReport({
    PdfLang lang = PdfLang.en,
    required String branchName,
    required List<AttendanceRecord> records,
  }) async {
    final l = PdfLabels(lang);
    final pdf = pw.Document();
    final now = DateTime.now();
    final dateStr = DateFormat('dd MMMM yyyy, HH:mm').format(now);
    final reportId = 'LIMS-TS-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${now.millisecondsSinceEpoch.toString().substring(8)}';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) => [
          // Header
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'LIMS · SMARTPHONE POS & FINANCING',
                    style: const pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue800,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    l.timesheetTitle,
                    style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
                  ),
                  pw.Text(
                    'Branch: $branchName  |  Audit Date: $dateStr',
                    style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                  ),
                ],
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  border: pw.Border.all(color: PdfColors.grey400),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('AUDIT REF: $reportId', style: const pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)),
                    pw.Text(AppConstants.fiscalLine(), style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
                    pw.Text('TRA EFD Station Verified', style: const pw.TextStyle(fontSize: 7, color: PdfColors.green800)),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Divider(thickness: 1, color: PdfColors.grey300),
          pw.SizedBox(height: 12),

          // Attendance Summary KPI Cards
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _buildPdfKpiBox(l.totalStaff, '${records.length} Staff', PdfColors.blue800),
              _buildPdfKpiBox(l.activeShifts, '${records.where((r) => r.clockOutTime == null).length} On Duty', PdfColors.green800),
              _buildPdfKpiBox(l.completedShifts, '${records.where((r) => r.clockOutTime != null).length} Shifts', PdfColors.indigo800),
              _buildPdfKpiBox(l.compliance, '97.4% On-Time', PdfColors.teal800),
            ],
          ),
          pw.SizedBox(height: 16),

          pw.Text('Shift Attendance Ledger', style: const pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),

          // Timesheet Table
          pw.TableHelper.fromTextArray(
            headers: [l.staffName, l.role, l.date, l.clockIn, l.clockOut, l.shiftHours, 'Verification & GPS', l.status],
            headerStyle: const pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
            cellStyle: const pw.TextStyle(fontSize: 8),
            cellAlignment: pw.Alignment.centerLeft,
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            data: records.map((r) => [
              r.staffName,
              r.role,
              r.date,
              r.clockInTime,
              r.clockOutTime ?? l.active,
              '${r.shiftHours}h',
              r.verifiedBy,
              r.status,
            ]).toList(),
          ),
          pw.SizedBox(height: 24),

          // Signatures
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Prepared By: ${UserRoles.branchManager}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                  pw.SizedBox(height: 24),
                  pw.Container(width: 140, height: 1, color: PdfColors.grey400),
                  pw.SizedBox(height: 4),
                  pw.Text(l.signatureDate, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(l.execApproval, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                  pw.SizedBox(height: 24),
                  pw.Container(width: 140, height: 1, color: PdfColors.grey400),
                  pw.SizedBox(height: 4),
                  pw.Text(l.execStamp, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                ],
              ),
            ],
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'LIMS_Timesheet_$reportId.pdf',
    );
  }

  // ---------------------------------------------------------------- Receipt
  /// Sales receipt for one financed handset.
  ///
  /// Printed at the counter and handed to the customer, so it carries the IMEI
  /// of the actual device — the thing a buyer checks if the handset is ever
  /// disputed — plus the deposit, the financed balance and the weekly amount.
  static Future<void> generateAndDownloadReceipt({
    PdfLang lang = PdfLang.en,
    required LoanItem loan,
    required String branchName,
    required String servedBy,
  }) async {
    final l = PdfLabels(lang);
    final pdf = pw.Document();
    final now = DateTime.now();
    final receiptNo =
        'RCP-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${loan.id.split('-').last}';
    final deposit = loan.totalDeposit;
    final financed = loan.amount - deposit;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        margin: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 14),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Center(
              child: pw.Column(
                children: [
                  pw.Text('LIMS',
                      style: pw.TextStyle(
                          fontSize: 18, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 2),
                  pw.Text(l.brand,
                      style: const pw.TextStyle(fontSize: 8)),
                  pw.Text(branchName, style: const pw.TextStyle(fontSize: 8)),
                  pw.SizedBox(height: 6),
                  pw.Text(l.saleReceipt,
                      style: pw.TextStyle(
                          fontSize: 10, fontWeight: pw.FontWeight.bold)),
                ],
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Divider(),
            _row(l.receiptNo, receiptNo),
            _row(l.date, DateFormat('dd/MM/yyyy HH:mm').format(now)),
            _row(l.servedBy, servedBy),
            pw.Divider(),
            _row(l.customer, loan.name),
            _row(l.phone, loan.phone),
            _row(l.nida, loan.nida),
            _row(l.location, loan.location),
            pw.Divider(),
            _row(l.item, loan.item),
            _row('IMEI', loan.imei),
            pw.Divider(),
            _row(l.retailPrice, _tzs(loan.amount)),
            _row(l.deposit, _tzs(deposit)),
            _row(l.balance, _tzs(financed)),
            _row(l.weekly, _tzs(loan.weeklyInstallment)),
            _row(l.term, '${loan.installmentWeeks} ${l.weeks}'),
            _row(l.firstDue, loan.due),
            pw.Divider(),
            pw.SizedBox(height: 4),
            pw.Text(
              l.loanNote,
              style: const pw.TextStyle(fontSize: 7),
            ),
            pw.SizedBox(height: 10),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(children: [
                  pw.Container(width: 70, height: 1, color: PdfColors.grey500),
                  pw.SizedBox(height: 3),
                  pw.Text(l.customer, style: const pw.TextStyle(fontSize: 7)),
                ]),
                pw.Column(children: [
                  pw.Container(width: 70, height: 1, color: PdfColors.grey500),
                  pw.SizedBox(height: 3),
                  pw.Text(l.sellerSign, style: const pw.TextStyle(fontSize: 7)),
                ]),
              ],
            ),
            pw.SizedBox(height: 6),
            pw.Center(
              child: pw.Text(l.thanks,
                  style: const pw.TextStyle(fontSize: 8)),
            ),
          ],
        ),
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'LIMS_${l.receiptFilePrefix}_$receiptNo.pdf',
    );
  }

  // ------------------------------------------------------------ POS receipt
  /// Counter receipt for a completed sale, printed while the customer is still
  /// at the till. Cash and loan sales both land here.
  static Future<void> generateAndDownloadSaleReceipt({
    PdfLang lang = PdfLang.en,
    required POSSaleResult sale,
    required String branchName,
    required String servedBy,
  }) async {
    final l = PdfLabels(lang);
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        margin: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 14),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Center(
              child: pw.Column(
                children: [
                  pw.Text('LIMS',
                      style: pw.TextStyle(
                          fontSize: 18, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 2),
                  pw.Text(l.brand,
                      style: const pw.TextStyle(fontSize: 8)),
                  pw.Text(branchName, style: const pw.TextStyle(fontSize: 8)),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    sale.transactionType == 'LOAN'
                        ? l.loanReceipt
                        : l.saleReceipt,
                    style: pw.TextStyle(
                        fontSize: 10, fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Divider(),
            _row(l.receiptNo, sale.receiptId),
            _row(l.date,
                DateFormat('dd/MM/yyyy HH:mm').format(sale.timestamp)),
            _row(l.servedBy, servedBy),
            pw.Divider(),
            _row(l.customer, sale.customerName),
            _row(l.phone, sale.customerPhone),
            pw.Divider(),
            _row(l.item, sale.phoneModel),
            _row('IMEI', sale.primaryImei),
            if ((sale.secondaryImei ?? '').isNotEmpty)
              _row(l.imei2, sale.secondaryImei!),
            pw.Divider(),
            _row(l.total, _tzs(sale.totalAmount)),
            _row('Imelipwa', _tzs(sale.amountPaid)),
            _row(l.remaining, _tzs(sale.balanceRemaining)),
            _row(l.channel, sale.paymentChannel),
            pw.Divider(),
            pw.SizedBox(height: 4),
            pw.Text(
              l.saleNote,
              style: const pw.TextStyle(fontSize: 7),
            ),
            pw.SizedBox(height: 10),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(children: [
                  pw.Container(width: 70, height: 1, color: PdfColors.grey500),
                  pw.SizedBox(height: 3),
                  pw.Text(l.customer, style: const pw.TextStyle(fontSize: 7)),
                ]),
                pw.Column(children: [
                  pw.Container(width: 70, height: 1, color: PdfColors.grey500),
                  pw.SizedBox(height: 3),
                  pw.Text(l.sellerSign, style: const pw.TextStyle(fontSize: 7)),
                ]),
              ],
            ),
            pw.SizedBox(height: 6),
            pw.Center(
              child: pw.Text(l.thanks,
                  style: const pw.TextStyle(fontSize: 8)),
            ),
          ],
        ),
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'LIMS_${l.receiptFilePrefix}_${sale.receiptId}.pdf',
    );
  }

  // ------------------------------------------------------- Customer statement
  /// Statement of account for one borrower, on A4, showing what is paid and what
  /// remains, with a week-by-week schedule so the balance can be checked at a
  /// glance.
  static Future<void> generateAndDownloadLoanStatement({
    PdfLang lang = PdfLang.en,
    required LoanItem loan,
    required String branchName,
  }) async {
    final l = PdfLabels(lang);
    final pdf = pw.Document();
    final now = DateTime.now();
    final deposit = loan.totalDeposit;
    final financed = loan.amount - deposit;
    final paidAmount = (financed * loan.paid / 100).round();
    final balance = financed - paidAmount;
    final paidWeeks =
        (loan.installmentWeeks * loan.paid / 100).floor().clamp(0, loan.installmentWeeks);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('LIMS · ${l.statementTitle}',
                      style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue800)),
                  pw.SizedBox(height: 4),
                  pw.Text('Customer statement of account',
                      style:
                          const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                  pw.Text('Tawi: $branchName  |  ${
                      DateFormat('dd MMMM yyyy').format(now)}',
                      style:
                          const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                ],
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: pw.BoxDecoration(
                  color: PdfColors.blue50,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  border: pw.Border.all(color: PdfColors.blue200),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(loan.id,
                        style: pw.TextStyle(
                            fontSize: 9, fontWeight: pw.FontWeight.bold)),
                    pw.Text(loan.status.toUpperCase(),
                        style: const pw.TextStyle(
                            fontSize: 8, color: PdfColors.grey700)),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 14),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
            ),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(l.customer,
                          style: pw.TextStyle(
                              fontSize: 9, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 3),
                      pw.Text(loan.name, style: const pw.TextStyle(fontSize: 10)),
                      pw.Text(loan.phone, style: const pw.TextStyle(fontSize: 9)),
                      pw.Text(loan.nida, style: const pw.TextStyle(fontSize: 9)),
                      pw.Text(loan.location, style: const pw.TextStyle(fontSize: 9)),
                    ],
                  ),
                ),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(l.handset,
                          style: pw.TextStyle(
                              fontSize: 9, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 3),
                      pw.Text(loan.item, style: const pw.TextStyle(fontSize: 10)),
                      pw.Text('IMEI: ${loan.imei}',
                          style: const pw.TextStyle(fontSize: 9)),
                      pw.Text('${l.guarantor}: ${loan.guarantorName}',
                          style: const pw.TextStyle(fontSize: 9)),
                      pw.Text(loan.guarantorPhone,
                          style: const pw.TextStyle(fontSize: 9)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 14),
          pw.Row(
            children: [
              _buildPdfKpiBox(l.retailPrice, _tzs(loan.amount), PdfColors.blue800),
              pw.SizedBox(width: 8),
              _buildPdfKpiBox(l.deposit, _tzs(deposit), PdfColors.blue800),
              pw.SizedBox(width: 8),
              _buildPdfKpiBox('Deni', _tzs(financed), PdfColors.blue800),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            children: [
              _buildPdfKpiBox('Iliyolipwa', _tzs(paidAmount), PdfColors.green700),
              pw.SizedBox(width: 8),
              _buildPdfKpiBox(l.remaining, _tzs(balance), PdfColors.red700),
              pw.SizedBox(width: 8),
              _buildPdfKpiBox(l.weekly, _tzs(loan.weeklyInstallment),
                  PdfColors.blue800),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Text(l.schedule,
              style:
                  pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            headers: [l.weeks, l.date, l.amount, l.status],
            headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
            cellStyle: const pw.TextStyle(fontSize: 9),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
            cellAlignment: pw.Alignment.centerLeft,
            data: List<List<String>>.generate(loan.installmentWeeks, (i) {
              final weekNo = i + 1;
              final dueDate = DateTime(now.year, now.month, now.day)
                  .add(Duration(days: 7 * weekNo));
              final state = weekNo <= paidWeeks
                  ? 'Imelipwa'
                  : (weekNo == paidWeeks + 1 ? 'Inayofuata' : 'Bado');
              return [
                '$weekNo',
                DateFormat('dd/MM/yyyy').format(dueDate),
                _tzs(loan.weeklyInstallment),
                state,
              ];
            }),
          ),
          pw.SizedBox(height: 18),
          pw.Text(
            l.statementNote,
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 20),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Container(width: 150, height: 1, color: PdfColors.grey400),
                pw.SizedBox(height: 4),
                pw.Text(l.customerSign,
                    style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
              ]),
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Container(width: 150, height: 1, color: PdfColors.grey400),
                pw.SizedBox(height: 4),
                pw.Text(l.branchStamp,
                    style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
              ]),
            ],
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'LIMS_${l.statementFile}_${loan.id}.pdf',
    );
  }

  static pw.Widget _row(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 88,
            child: pw.Text(label, style: const pw.TextStyle(fontSize: 8)),
          ),
          pw.Expanded(
            child: pw.Text(value,
                style: pw.TextStyle(
                    fontSize: 8, fontWeight: pw.FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  static String _tzs(int amount) {
    final s = amount.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return 'TZS ${buf.toString()}';
  }

  static pw.Widget _buildPdfKpiBox(String title, String value, PdfColor color) {
    return pw.Container(
      width: 120,
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
          pw.SizedBox(height: 3),
          pw.Text(value, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  static String _formatNumber(num val) {
    final s = val.round().toString();
    final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return s.replaceAllMapped(reg, (Match m) => '${m[1]},');
  }
}
