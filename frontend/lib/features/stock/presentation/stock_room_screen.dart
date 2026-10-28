import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/inventory_provider.dart';
import '../../../core/data/mock_lims_data.dart';
import '../../../core/data/store_movement.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../../core/l10n/strings.dart';
import '../../../core/services/api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/live_status_pill.dart';

/// What the storekeeper can honestly say about his own shop.
///
/// The "Borrowers & Active Contracts" tab reads `loans`, and RLS keeps a
/// Storekeeper out of that table. He therefore saw three zeros and the sentence
/// "No borrower matches your search" — three claims about his shop that came
/// from a door he was never given the key to.
///
/// This screen asks only tables his role can read: `product_units` for what is
/// physically on his shelf or out of it, `stock_receipts`/`stock_receipt_lines`
/// for what arrived, and the local product catalogue for what is running low.
/// Every number on it is either a real count, an explicit "we could not ask",
/// or "there is no database behind this build" — never a zero standing in for a
/// failure.
class StockRoomScreen extends ConsumerStatefulWidget {
  const StockRoomScreen({super.key});

  @override
  ConsumerState<StockRoomScreen> createState() => _StockRoomScreenState();
}

class _StockRoomScreenState extends ConsumerState<StockRoomScreen> {
  final ApiService _api = ApiService();

  bool _loading = true;
  String? _unitsError;
  String? _deliveriesError;

  List<Map<String, dynamic>> _inStock = const [];
  List<Map<String, dynamic>> _onLoan = const [];
  List<StockMovement> _deliveries = const [];

  @override
  void initState() {
    super.initState();
    // Deliberately no Timer.periodic: a repeating timer outlives the widget in a
    // widget test, and every screen in this repo that used one made the test
    // suite hang instead of fail.
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  /// Reads the two shelves and the delivery ledger for the active branch.
  ///
  /// `listBranchUnits` answers [] when a read fails, so an empty list is not on
  /// its own proof that the shop is empty; `getRecentStoreMovements` rethrows,
  /// so it needs a guard of its own.
  Future<void> _load() async {
    final branch = ref.read(activeBranchProvider);
    if (!mounted) return;
    setState(() {
      _loading = true;
      _unitsError = null;
      _deliveriesError = null;
    });

    var inStock = <Map<String, dynamic>>[];
    var onLoan = <Map<String, dynamic>>[];
    var deliveries = <StockMovement>[];
    String? unitsError;
    String? deliveriesError;

    if (_api.isConfigured) {
      try {
        final shelves = await Future.wait([
          _api.listBranchUnits(branch: branch, statuses: const ['in_stock']),
          _api.listBranchUnits(branch: branch, statuses: const ['on_loan']),
        ]);
        inStock = shelves[0];
        onLoan = shelves[1];
      } catch (e) {
        unitsError = 'We could not read the serials held at $branch.';
        debugPrint('LIMS: stock room units failed -> $e');
      }

      try {
        deliveries = await _api.getRecentStoreMovements(branch: branch);
      } catch (e) {
        deliveriesError = 'We could not read deliveries for $branch.';
        debugPrint('LIMS: stock room deliveries failed -> $e');
      }
    }

    if (!mounted) return;
    setState(() {
      _inStock = inStock;
      _onLoan = onLoan;
      _deliveries = deliveries;
      _unitsError = unitsError;
      _deliveriesError = deliveriesError;
      _loading = false;
    });
  }

  /// True only when the database answered: not loading, no error, configured.
  bool get _serialsAnswered =>
      _api.isConfigured && !_loading && _unitsError == null;

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final branch = ref.watch(activeBranchProvider);
    final products = ref.watch(inventoryProvider);

    if (!_api.isConfigured) {
      return Scaffold(
        backgroundColor: AppTheme.canvas,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
                child: _header(branch),
              ),
              const Expanded(
                child: EmptyState(
                  icon: Icons.storage_rounded,
                  title: 'No database behind this build',
                  message:
                      'This copy of LIMS was built without a Supabase URL and '
                      'key, so there is no stock book to read. A count here '
                      'would be invented, so the screen shows none.',
                ),
              ),
            ],
          ),
        ),
      );
    }

    final restock = products.where((p) => p.stock <= p.min).toList()
      ..sort((a, b) => (a.stock - a.min).compareTo(b.stock - b.min));

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 110),
          children: [
            _header(branch),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _KpiTile(
                    label: 'At this branch',
                    value: _serialsAnswered ? '${_inStock.length}' : '—',
                    icon: Icons.inventory_2_rounded,
                    color: AppTheme.brand600,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _KpiTile(
                    label: 'Out of the shop',
                    value: _serialsAnswered ? '${_onLoan.length}' : '—',
                    icon: Icons.north_east_rounded,
                    color: AppTheme.warningColor,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _KpiTile(
                    label: 'Needs restock',
                    value: '${restock.length}',
                    icon: Icons.priority_high_rounded,
                    color: AppTheme.errorColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _sectionTitle('Out of the shop'),
            _outOfShopSection(locale),
            const SizedBox(height: 20),
            _sectionTitle('Needs attention'),
            _needsAttentionSection(restock),
            const SizedBox(height: 20),
            _sectionTitle('Recent deliveries'),
            _deliveriesSection(locale),
          ],
        ),
      ),
    );
  }

  Widget _header(String branch) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Store operations',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.ink500,
                ),
              ),
              const SizedBox(height: 2),
              const FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  'Stock Room',
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    color: AppTheme.ink900,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                branch,
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
        const SizedBox(width: 8),
        const LiveStatusPill(),
      ],
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.2,
          color: AppTheme.ink900,
        ),
      ),
    );
  }

  /// Units whose custody is outside the shop.
  ///
  /// COMPLIANCE: this list carries the model, the serial and how long the unit
  /// has been away — and never a borrower name, phone number or NIDA number.
  /// Custody of a serial is stock information the Storekeeper owns; the identity
  /// of the borrower is not his to read, and `loans` is closed to his role.
  Widget _outOfShopSection(Locale locale) {
    if (_loading) return const _ReadingNote();
    if (_unitsError != null) {
      return _FailedNote(
        message: _unitsError!,
        retryLabel: tr(locale, 'common.retry'),
        onRetry: _load,
      );
    }
    if (_onLoan.isEmpty) {
      return const _SectionEmpty(
        icon: Icons.inventory_2_outlined,
        title: 'Every serial is in the shop',
        message:
            'No unit at this branch is marked as out on loan. If a handset has '
            'left and this still reads zero, it was never recorded out.',
      );
    }

    final shown = _onLoan.take(8).toList();
    return Column(
      children: [
        for (final unit in shown) _unitRow(unit),
        if (_onLoan.length > shown.length)
          _Caption('and ${_onLoan.length - shown.length} more out of the shop'),
        const _Caption(
            'Serials and days out only — borrower details stay private.'),
      ],
    );
  }

  Widget _needsAttentionSection(List<ProductItem> low) {
    if (low.isEmpty) {
      return const _SectionEmpty(
        icon: Icons.check_circle_outline_rounded,
        title: 'Nothing below its minimum',
        message:
            'Every model in the catalogue is at or above the level the shop '
            'wants to keep on the shelf.',
      );
    }

    final shown = low.take(6).toList();
    return Column(
      children: [
        for (final product in shown) _productRow(product),
        if (low.length > shown.length)
          _Caption('and ${low.length - shown.length} more below their minimum'),
      ],
    );
  }

  Widget _deliveriesSection(Locale locale) {
    if (_loading) return const _ReadingNote();
    if (_deliveriesError != null) {
      return _FailedNote(
        message: _deliveriesError!,
        retryLabel: tr(locale, 'common.retry'),
        onRetry: _load,
      );
    }
    if (_deliveries.isEmpty) {
      return const _SectionEmpty(
        icon: Icons.local_shipping_outlined,
        title: 'No delivery on record',
        message:
            'Nothing has been booked in at this branch, or the stock arrived '
            'before this ledger existed.',
      );
    }
    return Column(children: [for (final m in _deliveries) _deliveryRow(m)]);
  }

  Widget _unitRow(Map<String, dynamic> unit) {
    final model = (unit['model'] as String?)?.trim() ?? '';
    final title = model.isEmpty ? 'Model not recorded' : model;
    final imei = _groupedImei((unit['imei'] ?? '').toString());
    final when = _parseDate(unit['received_at']);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: const BoxDecoration(
              color: AppTheme.warningLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.north_east_rounded,
              size: 16,
              color: AppTheme.warningColor,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.ink900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  imei,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                    color: AppTheme.ink500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _stamp(when),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.ink400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _productRow(ProductItem product) {
    final out = product.stock <= 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: out ? AppTheme.errorLight : AppTheme.warningLight,
              shape: BoxShape.circle,
            ),
            child: Icon(
              out
                  ? Icons.remove_shopping_cart_rounded
                  : Icons.warning_amber_rounded,
              size: 16,
              color: out ? AppTheme.errorColor : AppTheme.warningColor,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.ink900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${product.sku} · ${product.stock} on hand, minimum ${product.min}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.ink500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: out ? AppTheme.errorLight : AppTheme.warningLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              out ? 'Out' : 'Low',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: out ? AppTheme.errorColor : AppTheme.warningColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _deliveryRow(StockMovement movement) {
    final units = movement.units == 1 ? '1 unit' : '${movement.units} units';
    final what = movement.lines.isEmpty
        ? (movement.invoiceNo?.trim().isNotEmpty ?? false
            ? 'Invoice ${movement.invoiceNo}'
            : 'No lines keyed')
        : movement.summary;
    final from = movement.fromBranch?.trim().isNotEmpty ?? false
        ? 'from ${movement.fromBranch}'
        : (movement.supplierName?.trim().isNotEmpty ?? false
            ? 'from ${movement.supplierName}'
            : 'no supplier keyed');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: const BoxDecoration(
              color: AppTheme.successLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.local_shipping_rounded,
              size: 16,
              color: AppTheme.successColor,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_sourceLabel(movement.source)} · $units',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.ink900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$what · $from',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.ink500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _stamp(movement.receivedAt),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.ink400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _sourceLabel(String source) {
    if (source == 'supplier') return 'Supplier delivery';
    if (source == 'transfer') return 'Transfer in';
    if (source == 'return') return 'Return to shop';
    return source.trim().isEmpty ? 'Delivery' : source;
  }

  DateTime? _parseDate(Object? raw) {
    if (raw == null) return null;
    return DateTime.tryParse(raw.toString())?.toLocal();
  }

  /// An IMEI is read aloud and typed in groups; a bare 15-digit run is a
  /// transcription error waiting to happen.
  String _groupedImei(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (raw.isEmpty) return 'No serial on file';
    if (digits.isEmpty || digits.length != raw.length) return raw;
    final parts = <String>[];
    for (var i = 0; i < digits.length; i += 4) {
      final end = i + 4 > digits.length ? digits.length : i + 4;
      parts.add(digits.substring(i, end));
    }
    return parts.join(' ');
  }

  static const List<String> _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  String _stamp(DateTime? when) {
    if (when == null) return 'No arrival date on file';
    final day = '${when.day} ${_months[when.month - 1]} ${when.year}';
    return 'Received $day · ${_ago(when)}';
  }

  String _ago(DateTime when) {
    final days = DateTime.now().difference(when).inDays;
    if (days <= 0) return 'today';
    if (days == 1) return '1 day ago';
    if (days < 30) return '$days days ago';
    final months = days ~/ 30;
    if (months < 12) return months == 1 ? '1 month ago' : '$months months ago';
    final years = days ~/ 365;
    return years <= 1 ? '1 year ago' : '$years years ago';
  }
}

/// One number, its label, and the colour of the thing it counts.
class _KpiTile extends StatelessWidget {
  const _KpiTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 11, 10, 11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w900,
              height: 1.1,
              color: AppTheme.ink900,
            ),
          ),
          const SizedBox(height: 2),
          SizedBox(
            height: 25,
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 9.5,
                height: 1.25,
                fontWeight: FontWeight.w600,
                color: AppTheme.ink500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A section that has an answer, and the answer is nothing.
class _SectionEmpty extends StatelessWidget {
  const _SectionEmpty({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 15, 14, 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppTheme.ink400),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.ink900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 11.5,
                    height: 1.35,
                    color: AppTheme.ink500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A section we could not ask about.
class _FailedNote extends StatelessWidget {
  const _FailedNote({
    required this.message,
    required this.retryLabel,
    required this.onRetry,
  });

  final String message;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
      decoration: BoxDecoration(
        color: AppTheme.errorLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFECDD3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.cloud_off_rounded,
              size: 18, color: AppTheme.errorColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'This did not load',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF9F1239),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 11.5,
                    height: 1.35,
                    color: Color(0xFF9F1239),
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.errorColor,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              retryLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

/// The question is still out; the answer is not zero yet.
class _ReadingNote extends StatelessWidget {
  const _ReadingNote();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Reading the stock book…',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: AppTheme.ink500),
            ),
          ),
        ],
      ),
    );
  }
}

/// A small line under a list that was cut short, or that needs qualifying.
class _Caption extends StatelessWidget {
  const _Caption(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 2),
      child: Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 10.5,
          height: 1.35,
          fontWeight: FontWeight.w500,
          color: AppTheme.ink400,
        ),
      ),
    );
  }
}
