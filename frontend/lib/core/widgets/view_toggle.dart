import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../services/haptics.dart';
import '../theme/app_theme.dart';

/// How a collection is drawn: one row per item, or cards in a two-column grid.
enum CollectionView { list, grid }

/// The list / grid switch.
///
/// One control, used by Inventory and Loans, so a cashier learns it once. It
/// reports the change to the caller and gives a short haptic tick, because on a
/// phone the thumb cannot see the icon it just hit.
class ViewToggle extends StatelessWidget {
  const ViewToggle({
    super.key,
    required this.view,
    required this.onChanged,
    required this.locale,
  });

  final CollectionView view;
  final ValueChanged<CollectionView> onChanged;
  final Locale locale;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F3478),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Segment(
            icon: Icons.view_agenda_rounded,
            label: tr(locale, 'view.list'),
            selected: view == CollectionView.list,
            onTap: () => _pick(CollectionView.list),
          ),
          _Segment(
            icon: Icons.grid_view_rounded,
            label: tr(locale, 'view.grid'),
            selected: view == CollectionView.grid,
            onTap: () => _pick(CollectionView.grid),
          ),
        ],
      ),
    );
  }

  void _pick(CollectionView next) {
    if (next == view) return;
    Haptics.select();
    onChanged(next);
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          width: 32,
          height: 30,
          decoration: BoxDecoration(
            color: selected ? AppTheme.brand600 : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(
            icon,
            size: 17,
            color: selected ? Colors.white : const Color(0xFF94A3B8),
          ),
        ),
      ),
    );
  }
}
