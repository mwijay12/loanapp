import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/inventory_provider.dart';
import '../../../core/data/lims_repository.dart';
import '../../../core/data/product_art.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../../core/l10n/strings.dart';
import '../../../core/widgets/phone_deals_carousel.dart';
import '../../../core/widgets/ui_kit.dart';

/// The offers rail on the till home.
///
/// It used to live inside the old cashier body and disappeared when the role
/// homes were rebuilt. It is back on the counter home because it is the only
/// place a cashier sees what the shop owner wants pushed today.
///
/// Ordering is honest about its two sources:
///  1. handsets the owner switched **on offer** (`products.on_offer`), and
///  2. everything else, most stock first — the models actually sitting on the
///     shelf, which is what the owner is trying to move.
/// Only the first group is labelled "on offer". The deposit and weekly figures
/// come from [LoanQuote.calculate], the same engine the loan screen quotes with,
/// so a card never advertises a payment the counter would not honour.
class FeaturedDealsSection extends ConsumerWidget {
  const FeaturedDealsSection({super.key, this.limit = 5});

  final int limit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final phones = ref
        .watch(inventoryProvider)
        .where((p) =>
            p.cat == 'phones' &&
            p.stock > 0 &&
            p.status != 'out' &&
            // Only feature phones with high-quality real assets
            p.name != 'Infinix Zero 40')
        .toList()
      ..sort((a, b) {
        if (a.onOffer != b.onOffer) return a.onOffer ? -1 : 1;
        return b.stock.compareTo(a.stock);
      });

    if (phones.isEmpty) return const SizedBox.shrink();

    final deals = <FeaturedPhoneDeal>[];
    for (final p in phones.take(limit)) {
      final quote = LoanQuote.calculate(
        cashPrice: p.price,
        downPayment: 0,
        tenureWeeks: 8,
      );
      deals.add(
        FeaturedPhoneDeal(
          id: 'deal_${p.id}',
          title: p.name,
          subtitle:
              '${tr(locale, 'deals.deposit')} ${LimsFormatters.currencyCompact(quote.downPayment)}'
              ' · ${LimsFormatters.currencyCompact(quote.weeklyInstallment)}${tr(locale, 'deals.perWeek')}',
          // The count moved onto the spec line, so the badge says the state
          // only. Two places quoting "27" on a 168px card was noise.
          badge: p.onOffer
              ? tr(locale, 'deals.onOffer')
              : tr(locale, 'deals.inStockLabel'),
          badgeBg: p.onOffer ? const Color(0x33F59E0B) : const Color(0x3322D3EE),
          badgeTextColor:
              p.onOffer ? const Color(0xFFFDE68A) : const Color(0xFFA5F3FC),
          gradient: p.grad,
          glowColor: p.grad.first,
          imageAsset: p.imageAsset ??
              ProductArt.resolve(brand: p.brand, name: p.name, category: p.cat),
          imageUrl: p.imageUrl,
          product: p,
          spec: p.variant.isNotEmpty ? p.variant : p.sku,
          units: trf(locale, 'deals.units', {'n': p.stock}),
          cashPrice: LimsFormatters.currencyCompact(p.price),
          monthlyDue:
              '${LimsFormatters.currencyCompact(quote.weeklyInstallment)}${tr(locale, 'deals.perWeek')}',
          actionLabel: tr(locale, 'home.issueLoan'),
          onTap: () => context.push(
            '/sell-loan?type=LOAN&model=${Uri.encodeComponent(p.name)}',
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.local_fire_department_rounded,
                size: 18, color: Color(0xFFEF4444)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                tr(locale, 'home.featured'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.swipe_rounded, size: 12, color: Color(0xFFDC2626)),
                  const SizedBox(width: 4),
                  Text(
                    tr(locale, 'home.swipe'),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFDC2626),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        PhoneDealsCarousel(deals: deals),
      ],
    );
  }
}
