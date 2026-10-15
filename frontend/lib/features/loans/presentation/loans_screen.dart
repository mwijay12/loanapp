import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/inventory_provider.dart';
import '../../../core/data/mock_lims_data.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ui_kit.dart';
import 'borrower_loan_details_screen.dart';

class LoansScreen extends ConsumerStatefulWidget {
  const LoansScreen({super.key});

  @override
  ConsumerState<LoansScreen> createState() => _LoansScreenState();
}

class _LoansScreenState extends ConsumerState<LoansScreen> {
  String _searchQuery = '';
  String _selectedFilter = 'all'; // 'all', 'overdue', 'current', 'locked'

  void _openNewLoanSheet() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final nidaCtrl = TextEditingController();
    final downCtrl = TextEditingController(text: '600,000');
    final totalAmountCtrl = TextEditingController(text: '2,400,000');
    String selectedPhone = 'iPhone 15 Pro Max 256GB';

    LimsBottomSheet.show(
      context: context,
      title: 'Sajili Mkopo Mpya (Disburse Loan)',
      subtitle: 'Sajili mkopaji na mkataba wa mauzo ya mkopo kaunta',
      child: StatefulBuilder(
        builder: (ctx, setModalState) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F9FF),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        gradient: AppTheme.brandGradient,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Center(
                        child: Icon(Icons.phone_android_rounded, color: Colors.white, size: 20),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedPhone,
                          isExpanded: true,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.ink900),
                          items: const [
                            DropdownMenuItem(value: 'iPhone 15 Pro Max 256GB', child: Text('iPhone 15 Pro Max 256GB')),
                            DropdownMenuItem(value: 'Galaxy S24 Ultra 256GB', child: Text('Galaxy S24 Ultra 256GB')),
                            DropdownMenuItem(value: 'Tecno Camon 30 Premier', child: Text('Tecno Camon 30 Premier')),
                            DropdownMenuItem(value: 'Redmi Note 13 Pro 5G', child: Text('Redmi Note 13 Pro 5G')),
                          ],
                          onChanged: (v) {
                            if (v != null) {
                              setModalState(() {
                                selectedPhone = v;
                                if (v.contains('iPhone')) {
                                  totalAmountCtrl.text = '2,400,000';
                                  downCtrl.text = '600,000';
                                } else if (v.contains('Galaxy')) {
                                  totalAmountCtrl.text = '1,850,000';
                                  downCtrl.text = '462,500';
                                } else {
                                  totalAmountCtrl.text = '750,000';
                                  downCtrl.text = '187,500';
                                }
                              });
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _buildField(nameCtrl, 'Full Borrower Name (e.g. Juma Ally)', Icons.person_outline_rounded),
              const SizedBox(height: 10),
              _buildField(phoneCtrl, 'Borrower Phone (+255 7XX XXX XXX)', Icons.phone_outlined, keyboardType: TextInputType.phone),
              const SizedBox(height: 10),
              _buildField(nidaCtrl, 'NIDA National ID (20 Digits)', Icons.badge_outlined),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildField(totalAmountCtrl, 'Total Loan Price', Icons.price_change_outlined, keyboardType: TextInputType.number),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildField(downCtrl, 'Initial Deposit (25%)', Icons.payments_outlined, keyboardType: TextInputType.number),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.brand50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.verified_user_rounded, size: 16, color: AppTheme.brand600),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Borrower & Guarantor have signed hire-purchase contract terms (PDPA compliant).',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.brand600),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () {
                    final customerName = nameCtrl.text.trim().isEmpty ? 'Juma Ally' : nameCtrl.text.trim();
                    final rawTotal = int.tryParse(totalAmountCtrl.text.replaceAll(',', '').trim()) ?? 2400000;
                    final rawDeposit = int.tryParse(downCtrl.text.replaceAll(',', '').trim()) ?? 600000;
                    final paidPct = ((rawDeposit / rawTotal) * 100).round().clamp(10, 100);

                    final newLoan = LoanItem(
                      id: 'LIMS-LN-${(1000 + DateTime.now().millisecond % 9000)}',
                      name: customerName,
                      item: selectedPhone,
                      amount: rawTotal,
                      paid: paidPct,
                      due: 'Due in 7 days',
                      status: 'current',
                      grad: const [Color(0xFF1B6EF3), Color(0xFF0A49B8)],
                      phone: phoneCtrl.text.trim().isEmpty ? '0754 892 314' : phoneCtrl.text.trim(),
                      nida: nidaCtrl.text.trim().isEmpty ? '19900812-11101-00001-24' : nidaCtrl.text.trim(),
                      location: 'Kariakoo, Dar es Salaam',
                      imei: '35${DateTime.now().millisecondsSinceEpoch.toString().substring(0, 13)}',
                      totalDeposit: rawDeposit,
                      isKnoxLocked: false,
                    );

                    ref.read(loansProvider.notifier).addLoan(newLoan);
                    ref.read(activitiesProvider.notifier).addActivity(
                      ActivityItem(
                        icon: Icons.assignment_ind_rounded,
                        iconColor: const Color(0xFF7C5CFC),
                        bgColor: const Color(0xFFF0EBFF),
                        title: 'Loan Disbursed · $customerName',
                        description: '$selectedPhone · Deposit TZS ${LimsFormatters.formatNumber(rawDeposit)}',
                        time: 'Just now',
                      ),
                    );

                    Navigator.pop(ctx);
                    LimsToast.show(context, 'Loan for $customerName approved & recorded in active ledger!', isSuccess: true);
                  },
                  icon: const Icon(Icons.check_circle_rounded, size: 20),
                  label: const Text('Approve & Issue Handset', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.brand600,
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

  Widget _buildField(TextEditingController controller, String hint, IconData icon, {TextInputType? keyboardType}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF4F9FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppTheme.ink900),
        decoration: InputDecoration(
          icon: Icon(icon, size: 18, color: AppTheme.ink500),
          border: InputBorder.none,
          hintText: hint,
          hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF9AA8BF), fontWeight: FontWeight.w500),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allLoans = ref.watch(loansProvider);

    // Filter & Search
    final filteredLoans = allLoans.where((l) {
      final matchesSearch = _searchQuery.isEmpty ||
          l.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          l.phone.contains(_searchQuery) ||
          l.item.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          l.imei.contains(_searchQuery);

      if (!matchesSearch) return false;

      if (_selectedFilter == 'overdue') return l.status == 'overdue';
      if (_selectedFilter == 'current') return l.status == 'current';
      return true;
    }).toList();

    final activeCount = allLoans.length;
    final overdueCount = allLoans.where((l) => l.status == 'overdue').length;
    final currentCount = allLoans.where((l) => l.status == 'current').length;

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 110),
          children: [
            // Header
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Credit & Borrower Portfolio',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.ink500,
                        ),
                      ),
                      SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Borrowers & Active Contracts',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                            color: AppTheme.ink900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: _openNewLoanSheet,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.brand600,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x1F1B6EF3),
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_rounded, size: 16, color: Colors.white),
                        SizedBox(width: 4),
                        Text(
                          'Toa Mkopo',
                          style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 3 Summary Metric Cards
            Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    label: 'Wakopaji Hai',
                    value: '$activeCount',
                    icon: Icons.handshake_rounded,
                    iconColor: AppTheme.brand600,
                    bgColor: AppTheme.brand100,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildSummaryCard(
                    label: 'Wenye Deni',
                    value: '$overdueCount',
                    icon: Icons.warning_amber_rounded,
                    iconColor: AppTheme.errorColor,
                    bgColor: const Color(0xFFFFEDF1),
                    valueColor: AppTheme.errorColor,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildSummaryCard(
                    label: 'On Schedule',
                    value: '$currentCount',
                    icon: Icons.check_circle_rounded,
                    iconColor: const Color(0xFF027A48),
                    bgColor: const Color(0xFFECFDF5),
                    valueColor: const Color(0xFF027A48),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Search Bar
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: const [
                  BoxShadow(color: Color(0x060F3478), blurRadius: 10, offset: Offset(0, 2)),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: TextField(
                onChanged: (v) => setState(() => _searchQuery = v),
                decoration: InputDecoration(
                  icon: const Icon(Icons.search_rounded, color: AppTheme.ink500, size: 20),
                  border: InputBorder.none,
                  hintText: 'Tafuta mteja, namba ya simu au IMEI...',
                  hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF9AA8BF)),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded, size: 16),
                          onPressed: () => setState(() => _searchQuery = ''),
                        )
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _filterChip('all', 'All Loans ($activeCount)'),
                  const SizedBox(width: 8),
                  _filterChip('overdue', 'Overdue ($overdueCount)'),
                  const SizedBox(width: 8),
                  _filterChip('current', 'On Schedule ($currentCount)'),
                ],
              ),
            ),
            const SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'Orodha ya Mikopo na Vifaa',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.ink900,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Jumla: ${filteredLoans.length}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.ink500),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Loans List
            if (filteredLoans.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      const Icon(Icons.search_off_rounded, size: 44, color: Color(0xFFCBD5E1)),
                      const SizedBox(height: 10),
                      const Text(
                        'Hakuna mkopaji anayelingana na utafutaji wako',
                        style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppTheme.ink500),
                      ),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: () => setState(() {
                          _searchQuery = '';
                          _selectedFilter = 'all';
                        }),
                        child: const Text('Onyesha Wote'),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...filteredLoans.map((l) => _buildLoanCard(l)),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String id, String label) {
    final isSelected = _selectedFilter == id;
    return InkWell(
      onTap: () => setState(() => _selectedFilter = id),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.brand600 : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? AppTheme.brand600 : const Color(0xFFE2E8F0)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? Colors.white : AppTheme.ink700,
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard({
    required String label,
    required String value,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    Color? valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C0F3478),
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppTheme.ink500,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: valueColor ?? AppTheme.ink900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoanCard(LoanItem l) {
    final isOverdue = l.status == 'overdue';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: l.status == 'overdue' ? const Color(0xFFFECDD3) : const Color(0xFFE2E8F0),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C0F3478),
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (ctx) => BorrowerLoanDetailsScreen(loanId: l.id, initialLoan: l),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: l.grad,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: Text(
                          l.initials,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  l.name,
                                  style: const TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.ink900,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              if (l.status == 'overdue')
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFEDF1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.warning_amber_rounded, size: 10, color: AppTheme.errorColor),
                                      SizedBox(width: 2),
                                      Text(
                                        'OVERDUE',
                                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: AppTheme.errorColor),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${l.item} · ${l.phone}',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.ink500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(99),
                            child: LinearProgressIndicator(
                              value: l.paid / 100.0,
                              minHeight: 5,
                              backgroundColor: const Color(0xFFE9F2FF),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                isOverdue ? AppTheme.errorColor : AppTheme.brand600,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Text(
                                  '${l.paid}% imelipwa',
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF9AA8BF),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  'Salio: ${l.formattedRemainingAmount}',
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: l.remainingAmount > 0 ? AppTheme.errorColor : AppTheme.successColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          l.shortAmount,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.ink900,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isOverdue ? const Color(0xFFFFEDF1) : const Color(0xFFE7F8F0),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isOverdue ? 'Overdue' : 'Current',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: isOverdue ? const Color(0xFFF43F5E) : const Color(0xFF12B76A),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l.due,
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF9AA8BF),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 6),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'View Borrower Dossier & Schedule',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.brand600),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_forward_ios_rounded, size: 11, color: AppTheme.brand600),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
