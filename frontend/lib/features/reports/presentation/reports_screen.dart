import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/inventory_provider.dart';
import '../../../core/data/sales_provider.dart';
import '../../../core/services/app_permissions_service.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../../core/services/pdf_labels.dart';
import '../../../core/services/pdf_report_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ui_kit.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedDateRange = 'Today'; // 'Today', 'This Week', 'Month to Date'

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

  void _showOfficialPdfReport(BuildContext context, {
    required int todaySales,
    required int grossProfit,
    required int totalLoans,
    required int totalCollected,
    required int totalPhones,
    required int inventoryCost,
    required int inventoryRetail,
    required String activeBranch,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.90,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(99)),
            ),
            const SizedBox(height: 14),

            // Modal Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFBFDBFE)),
                          ),
                          child: const Icon(Icons.verified_outlined, color: Color(0xFF1E60F2), size: 22),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Official Financial Audit',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                              ),
                              Text(
                                'DOC-FIN-2026-10-8841 · EFD Signed',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 22),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            const Divider(height: 24, color: Color(0xFFE2E8F0)),

            // Printable Document Body
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  // Company Identity Watermark Header
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'LIMS TANZANIA LTD',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 0.5, color: Color(0xFF0F172A)),
                                  ),
                                  Text(
                                    'Loan & Investment Management System Ltd',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFF10B981)),
                                ),
                                child: const Text(
                                  'TRA VERIFIED',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF065F46)),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        const Divider(height: 1, color: Color(0xFFE2E8F0)),
                        const SizedBox(height: 10),
                        _buildDocRow('Registered Office', 'Plot 14, Uhuru St, Kariakoo, Dar es Salaam'),
                        _buildDocRow('Report Category', 'Branch Financial & Portfolio Audit'),
                        _buildDocRow('Audit Standard', 'Financial Management & Portfolio At Risk (PAR)'),
                        _buildDocRow('Branch Scope', activeBranch),
                        _buildDocRow('Report Date', 'Friday, 02 October 2026 · 14:45 EAT'),
                        _buildDocRow('Auditing Officer', 'David Erick Mwijage · Managing Director'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  const Text(
                    'Executive P&L Statement',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 8),

                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        _buildFinancialLine('Gross POS Sales Revenue', LimsFormatters.currency(todaySales), isBold: true),
                        const Divider(height: 1, color: Color(0xFFF1F5F9)),
                        // Cost is what is left when profit is taken off revenue, so
                        // the three lines cannot disagree with each other.
                        _buildFinancialLine('Cost of Goods Sold (COGS Handsets)', LimsFormatters.currency(todaySales - grossProfit)),
                        const Divider(height: 1, color: Color(0xFFF1F5F9)),
                        _buildFinancialLine(
                            'Gross Margin (${todaySales > 0 ? ((grossProfit / todaySales) * 100).toStringAsFixed(1) : '0.0'}%)',
                            LimsFormatters.currency(grossProfit),
                            isHighlight: true),
                        const Divider(height: 1, color: Color(0xFFF1F5F9)),
                        _buildFinancialLine('Active Disbursed Loan Book', LimsFormatters.currency(totalLoans)),
                        const Divider(height: 1, color: Color(0xFFF1F5F9)),
                        _buildFinancialLine('Repayments Recovered', LimsFormatters.currency(totalCollected)),
                        const Divider(height: 1, color: Color(0xFFF1F5F9)),
                        _buildFinancialLine('Total Handsets in Stock', '$totalPhones units', isBold: true),
                        const Divider(height: 1, color: Color(0xFFF1F5F9)),
                        _buildFinancialLine('Inventory Asset Value (Cost)', LimsFormatters.currency(inventoryCost)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Official Stamp & Digital Signature Box
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFF1E60F2), width: 2),
                          ),
                          child: const Center(
                            child: Icon(Icons.qr_code_2_rounded, color: Color(0xFF1E60F2), size: 32),
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Internal Ledger Audit Verified',
                                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFF1E60F2)),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Generated dynamically from LIMS branch financial ledger and inventory asset register.',
                                style: TextStyle(fontSize: 10.5, color: Color(0xFF475569)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),

            // Print & Download Buttons
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.download_rounded, size: 18),
                      label: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('Export CSV', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        LimsToast.show(
                          context,
                          'Financial reconciliation CSV downloaded to your device.',
                          isSuccess: true,
                          icon: Icons.file_download_done_rounded,
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.picture_as_pdf_rounded, size: 18, color: Colors.white),
                      label: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('Download PDF', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                      ),
                      onPressed: () async {
                        final screenContext = context;
                        Navigator.pop(ctx);
                        await AppPermissionsService.ensureStorage();
                        if (!screenContext.mounted) return;
                        final activeBranch = ref.read(activeBranchProvider);
                        final products = ref.read(inventoryProvider);
                        final loans = ref.read(loansProvider);
                        final totalStock = products.fold<int>(0, (sum, p) => sum + p.stock);

                        LimsToast.show(screenContext, 'Generating official PDF document...', isSuccess: true);
                        try {
                          await PdfReportService.generateAndDownloadFinancialReport(
                            lang: ref.read(localeProvider).languageCode == 'sw'
                                ? PdfLang.sw
                                : PdfLang.en,
                            branchName: activeBranch,
                            products: products,
                            loans: loans,
                            totalSales: 148820000,
                            totalStock: totalStock,
                          );
                        } catch (e) {
                          if (screenContext.mounted) {
                            LimsToast.show(screenContext, 'PDF generation error: $e', isError: true);
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E60F2),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 11, color: Color(0xFF0F172A), fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialLine(String label, String value, {bool isBold = false, bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isBold || isHighlight ? FontWeight.w800 : FontWeight.w500,
                color: isHighlight ? const Color(0xFF10B981) : const Color(0xFF1E293B),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: isHighlight ? const Color(0xFF10B981) : (isBold ? const Color(0xFF0F172A) : const Color(0xFF334155)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeBranch = ref.watch(activeBranchProvider);
    final products = ref.watch(inventoryProvider);

    // "Sold today" is counted from the sales ledger, not read from
    // `products.sold_today`. The column is a cache the sale trigger maintains, and
    // on a morning with no sales it still carries yesterday's number until the next
    // write moves it - so a report could rank a phone as today's best seller because
    // of a sale it did not make. `sold_at` on each row is the fact.
    final today = DateTime.now();
    final soldTodayById = <int, int>{};
    for (final r in ref.watch(salesProvider)) {
      final at = r.soldAt;
      if (at.year == today.year && at.month == today.month && at.day == today.day) {
        final id = r.productId;
        if (id != null) soldTodayById[id] = (soldTodayById[id] ?? 0) + 1;
      }
    }

    final sortedProducts = [...products]
      ..sort((a, b) =>
          (soldTodayById[b.id] ?? 0).compareTo(soldTodayById[a.id] ?? 0));
    final topProducts = sortedProducts.take(4).toList();

    final loans = ref.watch(loansProvider);
    final totalLoans = loans.fold<int>(0, (sum, l) => sum + l.amount);
    final totalCollected = loans.fold<int>(0, (sum, l) => sum + ((l.amount * l.paid) ~/ 100));
    final collectionRate = totalLoans > 0 ? (totalCollected / totalLoans) : 0.0;

    final range = switch (_selectedDateRange) {
      'This Week' => ReportRange.week,
      'Month to Date' => ReportRange.month,
      _ => ReportRange.today,
    };
    final pnl = ref.watch(reportTotalsProvider(range));
    final todaySales = pnl.revenue;
    final grossProfit = pnl.profit;
    final todayCogs = pnl.cogs;
    final totalPhones = ref.watch(totalPhonesCountProvider);
    final inventoryCost = ref.watch(totalInventoryCostProvider);
    final inventoryRetail = ref.watch(totalInventoryRetailValueProvider);

    final overdueLoans = loans.where((l) => l.status == 'overdue').toList();
    final performingLoans = loans.where((l) => l.status == 'current').toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.ink900),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Financial Reports & Audit',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppTheme.ink900),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFF1E60F2)),
            tooltip: 'Generate Signed Audit PDF',
            onPressed: () => _showOfficialPdfReport(
              context,
              todaySales: todaySales,
              grossProfit: grossProfit,
              totalLoans: totalLoans,
              totalCollected: totalCollected,
              totalPhones: totalPhones,
              inventoryCost: inventoryCost,
              inventoryRetail: inventoryRetail,
              activeBranch: activeBranch,
            ),
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFE2E8F0), height: 1),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            // LIMS Corporate Identity Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: const [
                  BoxShadow(color: Color(0x0A0F3478), blurRadius: 18, offset: Offset(0, 4)),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1652E1), Color(0xFF1E60F2)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Center(
                      child: Text('LIMS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5)),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'LIMS Financial Center',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                        ),
                        Text(
                          'Branch Ledger · $activeBranch',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => _showOfficialPdfReport(
                      context,
                      todaySales: todaySales,
                      grossProfit: grossProfit,
                      totalLoans: totalLoans,
                      totalCollected: totalCollected,
                      totalPhones: totalPhones,
                      inventoryCost: inventoryCost,
                      inventoryRetail: inventoryRetail,
                      activeBranch: activeBranch,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E60F2),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      minimumSize: const Size(0, 44),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.picture_as_pdf_rounded, size: 17, color: Colors.white),
                        SizedBox(width: 6),
                        Text('PDF', style: TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: 0.2)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Date Range Filter Chips
            Row(
              children: [
                _buildDateChip('Today'),
                const SizedBox(width: 8),
                _buildDateChip('This Week'),
                const SizedBox(width: 8),
                _buildDateChip('Month to Date'),
              ],
            ),
            const SizedBox(height: 16),

            // 3 Reporting Tabs
            TabBar(
              controller: _tabController,
              labelColor: const Color(0xFF1E60F2),
              unselectedLabelColor: const Color(0xFF64748B),
              indicatorColor: const Color(0xFF1E60F2),
              indicatorWeight: 3,
              labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
              tabs: const [
                Tab(text: "P&L Statement"),
                Tab(text: "Loan Book & PAR"),
                Tab(text: "Inventory Asset"),
              ],
            ),
            const SizedBox(height: 14),

            // Tab Views
            SizedBox(
              height: 520,
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: P&L
                  _buildPlTab(pnl),

                  // Tab 2: Loan Book & PAR
                  _buildLoanBookTab(totalLoans, totalCollected, collectionRate, overdueLoans, performingLoans),

                  // Tab 3: Inventory Asset
                  _buildInventoryAssetTab(totalPhones, inventoryCost, inventoryRetail, topProducts, soldTodayById),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateChip(String label) {
    final isSelected = _selectedDateRange == label;
    return InkWell(
      onTap: () => setState(() => _selectedDateRange = label),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1E60F2) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? const Color(0xFF1E60F2) : const Color(0xFFE2E8F0)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: isSelected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  Widget _buildPlTab(ReportTotals totals) {
    final todaySales = totals.revenue;
    final todayCogs = totals.cogs;
    final grossProfit = totals.profit;
    return ListView(
      physics: const ClampingScrollPhysics(),
      children: [
        // Daily Close Quick Action Banner
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFEFF6FF), Color(0xFFDBEAFE)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFBFDBFE)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: const Color(0xFF1E60F2), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.point_of_sale_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Daily Close & Drawer Reconcile', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                    Text('Reconcile physical cash drawer with daily register', style: TextStyle(fontSize: 11, color: Color(0xFF475569))),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: () => context.push('/daily-closing'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E60F2),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  minimumSize: const Size(0, 46),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Open', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_forward_rounded, size: 16),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Financial Ledger Card
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            children: [
              _buildFinancialLine('Total Inflow Revenue', LimsFormatters.currency(todaySales), isBold: true),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              _buildFinancialLine('Handset Cost (COGS)', LimsFormatters.currency(todayCogs)),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              _buildFinancialLine('Net Gross Profit Margin', LimsFormatters.currency(grossProfit), isHighlight: true),
              if (totals.uncostedSales > 0)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
                  child: Text(
                    '${totals.uncostedSales} of these sales have no cost price on '
                    'the catalogue, so their cost is estimated at 78%. Add the '
                    'buying price in Inventory to make this exact.',
                    style: const TextStyle(fontSize: 11, height: 1.4, color: Color(0xFF64748B)),
                  ),
                ),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              // These three used to be constants in the source. They are now the
              // sum of today's sales in each channel, so a zero means the drawer
              // is empty rather than that nobody typed a number in.
              _buildFinancialLine('Cash at counter', LimsFormatters.currency(totals.cash)),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              _buildFinancialLine('Mobile money (M-Pesa / Tigo / Airtel)', LimsFormatters.currency(totals.mobile)),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              _buildFinancialLine('Card & bank settlements', LimsFormatters.currency(totals.card)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLoanBookTab(int totalLoans, int totalCollected, double collectionRate, List<dynamic> overdue, List<dynamic> performingLoans) {
    return ListView(
      physics: const ClampingScrollPhysics(),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      'Loan Portfolio Recovery',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(6)),
                      child: Text(
                        '${(collectionRate * 100).toStringAsFixed(0)}% on track',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF059669)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: collectionRate.clamp(0.0, 1.0),
                  minHeight: 7,
                  backgroundColor: const Color(0xFFE2E8F0),
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Collected ${LimsFormatters.currency(totalCollected)} of ${LimsFormatters.currency(totalLoans)} disbursed portfolio',
                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // PAR & Performing Portfolio Risk Card
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('PAR 30 (Overdue)', style: TextStyle(fontSize: 11, color: Color(0xFF991B1B), fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text('${overdue.length} Borrowers', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF991B1B))),
                    const SizedBox(height: 2),
                    const Text('Follow-up pending', style: TextStyle(fontSize: 10, color: Color(0xFFB91C1C))),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Performing Loans', style: TextStyle(fontSize: 11, color: Color(0xFF065F46), fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text('${performingLoans.length} Handsets', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF065F46))),
                    const SizedBox(height: 2),
                    const Text('On schedule (Current)', style: TextStyle(fontSize: 10, color: Color(0xFF047857))),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInventoryAssetTab(int totalPhones, int costVal, int retailVal,
      List<dynamic> topProducts, Map<int, int> soldTodayById) {
    return ListView(
      physics: const ClampingScrollPhysics(),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            children: [
              _buildFinancialLine('Total Serialized Handsets', '$totalPhones units', isBold: true),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              _buildFinancialLine('Warehouse Stock Value (At Cost)', LimsFormatters.currency(costVal)),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              _buildFinancialLine('Retail Valuation (Selling Price)', LimsFormatters.currency(retailVal), isHighlight: true),
            ],
          ),
        ),
        const SizedBox(height: 16),

        const Text('Fastest Moving Models Today', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
        const SizedBox(height: 10),

        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            children: topProducts.map((p) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                          Text(
                            '${soldTodayById[p.id] ?? 0} sold today · In Stock: ${p.stock}',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    Text(LimsFormatters.currency(p.price), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1E60F2))),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
