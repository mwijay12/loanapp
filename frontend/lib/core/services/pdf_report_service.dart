import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../data/mock_lims_data.dart';

class PdfReportService {
  PdfReportService._();

  static Future<void> generateAndDownloadFinancialReport({
    required String branchName,
    required List<ProductItem> products,
    required List<LoanItem> loans,
    required int totalSales,
    required int totalStock,
  }) async {
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
                    'Branch Operations, Sales & Credit Audit Report',
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
              _buildPdfKpiBox('Total Handset Units', '$totalStock units', PdfColors.blue700),
              _buildPdfKpiBox('Active Credit Ledger', 'TZS ${_formatNumber(totalLoanBal)}', PdfColors.purple700),
              _buildPdfKpiBox('Overdue Accounts', '${overdueLoans.length} active', overdueLoans.isNotEmpty ? PdfColors.red700 : PdfColors.green700),
              _buildPdfKpiBox('Audit Status', 'Reconciled', PdfColors.green700),
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
            headers: ['Model', 'Variant / SKU', 'Unit Price', 'In Stock', 'Status'],
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
            headers: ['Customer', 'Handset Item', 'Remaining Balance', 'Guarantor', 'Status'],
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
                  pw.Text('Prepared By: Branch Cashier / Storekeeper', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                  pw.SizedBox(height: 24),
                  pw.Container(width: 140, height: 1, color: PdfColors.grey400),
                  pw.SizedBox(height: 4),
                  pw.Text('Signature & Date', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('Verified By: Branch Manager / HQ Super Admin', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                  pw.SizedBox(height: 24),
                  pw.Container(width: 140, height: 1, color: PdfColors.grey400),
                  pw.SizedBox(height: 4),
                  pw.Text('Executive Stamp & Approval', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
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
    required String branchName,
    required List<AttendanceRecord> records,
  }) async {
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
                    'Official Staff Attendance & Timesheet Audit',
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
                    pw.Text('TIN: 142-998-314 | VRN: 40-028912-K', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
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
              _buildPdfKpiBox('Total Staff Logged', '${records.length} Staff', PdfColors.blue800),
              _buildPdfKpiBox('Active Shifts', '${records.where((r) => r.clockOutTime == null).length} On Duty', PdfColors.green800),
              _buildPdfKpiBox('Completed Shifts', '${records.where((r) => r.clockOutTime != null).length} Shifts', PdfColors.indigo800),
              _buildPdfKpiBox('Compliance Score', '97.4% On-Time', PdfColors.teal800),
            ],
          ),
          pw.SizedBox(height: 16),

          pw.Text('Shift Attendance Ledger', style: const pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),

          // Timesheet Table
          pw.TableHelper.fromTextArray(
            headers: ['Staff Name', 'Role', 'Date', 'Clock In', 'Clock Out', 'Hours', 'Verification & GPS', 'Status'],
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
              r.clockOutTime ?? 'Active',
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
                  pw.Text('Prepared By: HR & Shift Supervisor', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                  pw.SizedBox(height: 24),
                  pw.Container(width: 140, height: 1, color: PdfColors.grey400),
                  pw.SizedBox(height: 4),
                  pw.Text('Signature & Date', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('Executive Approval: Managing Director', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                  pw.SizedBox(height: 24),
                  pw.Container(width: 140, height: 1, color: PdfColors.grey400),
                  pw.SizedBox(height: 4),
                  pw.Text('Executive Stamp & Signature', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
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
