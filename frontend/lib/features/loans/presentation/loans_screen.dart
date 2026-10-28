import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/data/inventory_provider.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../../core/l10n/strings.dart';
import '../../../core/data/mock_lims_data.dart';
import '../../../core/services/haptics.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/view_toggle.dart';
import 'borrower_loan_details_screen.dart';

class LoansScreen extends ConsumerStatefulWidget {
  const LoansScreen({super.key});

  @override
  ConsumerState<LoansScreen> createState() => _LoansScreenState();
}

class _LoansScreenState extends ConsumerState<LoansScreen> {
  String _searchQuery = '';
  String _selectedFilter = 'all'; // 'all', 'overdue', 'current', 'locked'

  /// Rows or cards. A loan officer scanning forty borrowers wants names in a
  /// column; an owner looking for who is behind wants the cards. Both are one
  /// tap apart, and the choice is not remembered across visits.
  CollectionView _view = CollectionView.list;

  /// Opening a loan goes to the counters' real flow.
  ///
  /// This screen used to own a second, smaller loan form that invented what it
  /// did not know: an IMEI built from the millisecond clock, a customer named
  /// 'Juma Ally' when the field was empty, a fixed Kariakoo address, and a NIDA
  /// number that was really a literal string. None of it was written to the
  /// database, so a "disbursed" handset left no record. The POS flow is the one
  /// that persists, prints and reconciles; there is no reason for a copy of it
  /// that lies.
  void _openNewLoanSheet() => context.push('/sell-loan?type=LOAN');

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final allLoans = ref.watch(loansProvider);

    // A Storekeeper can reach this route through a saved tab, a browser back
    // gesture or a link, even though the dock no longer offers it to him.
    // `loans_read` (2026_10_20_01_rls_policies.sql:133-136) refuses his rows and
    // the repository answers with an empty list, so without this guard he reads
    // three zeros and the sentence "No borrower matches your search" — an
    // apology that blames his typing for a door that was never his. The role,
    // not the search box, is the fact worth printing.
    final role = ref.watch(userRoleProvider);
    if (!UserRoles.canViewLoans(role)) {
      return Scaffold(
        backgroundColor: AppTheme.canvas,
        body: SafeArea(
          child: EmptyState(
            icon: Icons.lock_outline_rounded,
            title: tr(locale, 'loans.lockedTitle'),
            message: trf(
                locale, 'loans.lockedBody', {'role': tr(locale, UserRoles.labelKey(role))}),
            actionLabel: tr(locale, 'loans.lockedAction'),
            onAction: () => context.go('/stock-room'),
          ),
        ),
      );
    }

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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr(locale, 'loans.eyebrow'),
                        style: const TextStyle(
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
                          tr(locale, 'loans.title'),
                          style: const TextStyle(
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
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.add_rounded, size: 16, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(
                          tr(locale, 'loans.issue'),
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800),
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
                    label: tr(locale, 'loans.kpiActive'),
                    value: '$activeCount',
                    icon: Icons.handshake_rounded,
                    iconColor: AppTheme.brand600,
                    bgColor: AppTheme.brand100,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildSummaryCard(
                    label: tr(locale, 'loans.kpiOverdue'),
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
                    label: tr(locale, 'loans.kpiOnSchedule'),
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
                  hintText: tr(locale, 'loans.search'),
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
                  _filterChip('all', trf(locale, 'loans.filterAll', {'n': activeCount})),
                  const SizedBox(width: 8),
                  _filterChip('overdue', trf(locale, 'loans.filterOverdue', {'n': overdueCount})),
                  const SizedBox(width: 8),
                  _filterChip('current', trf(locale, 'loans.filterCurrent', {'n': currentCount})),
                ],
              ),
            ),
            const SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    tr(locale, 'loans.listTitle'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.ink900,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    trf(locale, 'loans.total', {'n': filteredLoans.length}),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.ink500),
                  ),
                ),
                const SizedBox(width: 8),
                ViewToggle(
                  view: _view,
                  locale: locale,
                  onChanged: (v) => setState(() => _view = v),
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
                      Text(
                        tr(locale, 'loans.empty'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppTheme.ink500),
                      ),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: () => setState(() {
                          _searchQuery = '';
                          _selectedFilter = 'all';
                        }),
                        child: Text(tr(locale, 'loans.showAll')),
                      ),
                    ],
                  ),
                ),
              )
            else if (_view == CollectionView.grid)
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.84,
                ),
                itemCount: filteredLoans.length,
                itemBuilder: (_, i) => _buildLoanTile(filteredLoans[i], locale),
              )
            else
              ...filteredLoans.map((l) => _buildLoanCard(l, locale)),
          ],
        ),
      ),
    );
  }

  void _openLoan(LoanItem l) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => BorrowerLoanDetailsScreen(loanId: l.id, initialLoan: l),
      ),
    );
  }

  /// One card in the two-column loan grid: who, what they hold, how far paid.
  Widget _buildLoanTile(LoanItem l, Locale locale) {
    final isOverdue = l.status == 'overdue';
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isOverdue ? const Color(0xFFFECDD3) : const Color(0xFFE9EFF7),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C0F3478),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            Haptics.tap();
            _openLoan(l);
          },
          onLongPress: () {
            Haptics.longPress();
            _showLoanPeek(l, locale);
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: l.grad,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          l.initials,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (isOverdue)
                      Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFEDF1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'OVERDUE',
                          style: TextStyle(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.errorColor,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 9),
                Text(
                  l.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                    color: AppTheme.ink900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l.item,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.ink500,
                  ),
                ),
                const Spacer(),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: l.paidPercent / 100.0,
                    minHeight: 5,
                    backgroundColor: const Color(0xFFE9F2FF),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isOverdue ? AppTheme.errorColor : AppTheme.brand600,
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${l.paidPercent}% · Salio ${l.formattedRemainingAmount}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: l.remainingAmount > 0
                        ? AppTheme.errorColor
                        : AppTheme.successColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// What a long press on a loan row opens: the same facts the row carries, in
  /// one panel, plus the way into the file.
  void _showLoanPeek(LoanItem l, Locale locale) {
    final isOverdue = l.status == 'overdue';
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 16),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                tr(locale, 'loans.peekTitle'),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF9AA8BF),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: l.grad),
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
                        Text(
                          l.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.ink900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l.phone.isEmpty ? l.item : '${l.item} · ${l.phone}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.ink500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isOverdue
                          ? const Color(0xFFFFEDF1)
                          : const Color(0xFFE7F8F0),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isOverdue ? 'Overdue' : 'Current',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: isOverdue
                            ? AppTheme.errorColor
                            : AppTheme.successColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _peekStat(
                      label: 'Imelipwa',
                      value: '${l.paidPercent}%',
                    ),
                  ),
                  Expanded(
                    child: _peekStat(
                      label: 'Salio',
                      value: l.formattedRemainingAmount,
                      color: l.remainingAmount > 0
                          ? AppTheme.errorColor
                          : AppTheme.successColor,
                    ),
                  ),
                  Expanded(
                    child: _peekStat(label: 'Due', value: l.due),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _openLoan(l);
                  },
                  icon: const Icon(Icons.folder_open_rounded, size: 17),
                  label: Text(
                    tr(locale, 'loans.viewDossier'),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.brand600,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(tr(locale, 'common.close')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _peekStat({required String label, required String value, Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Color(0xFF9AA8BF),
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            maxLines: 1,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: color ?? AppTheme.ink900,
            ),
          ),
        ),
      ],
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

  Widget _buildLoanCard(LoanItem l, Locale locale) {
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
            Haptics.tap();
            _openLoan(l);
          },
          onLongPress: () {
            Haptics.longPress();
            _showLoanPeek(l, locale);
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
                              value: l.paidPercent / 100.0,
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
                                  '${l.paidPercent}% imelipwa',
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // The label can be long (EN "View borrower dossier & schedule",
                    // SW "Fungua wasifu na ratiba"), so it must be allowed to
                    // shrink instead of pushing the arrow out of the card.
                    Flexible(
                      child: Text(
                        tr(locale, 'loans.viewDossier'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.brand600),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_forward_ios_rounded, size: 11, color: AppTheme.brand600),
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
