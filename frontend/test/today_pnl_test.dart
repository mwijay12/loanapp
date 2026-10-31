import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loan_inventory_app/core/data/inventory_provider.dart';
import 'package:loan_inventory_app/core/data/mock_lims_data.dart';
import 'package:loan_inventory_app/core/data/sales_provider.dart';

ProductItem _phone({int id = 1, int soldToday = 49}) => ProductItem(
      id: id,
      name: 'iPhone 15',
      variant: 'IP15',
      sku: 'IP15-128',
      price: 1000,
      stock: 5,
      min: 2,
      cat: 'phones',
      status: 'in',
      onLoan: 0,
      grad: const [Colors.blue, Colors.indigo],
      soldToday: soldToday,
      costPrice: 700,
    );

ProviderContainer _c({required List<SaleRecord> sales, int soldToday = 49}) {
  final c = ProviderContainer(overrides: [
    salesProvider.overrideWith((ref) => SalesNotifier(sales)),
    inventoryProvider.overrideWith(
        (ref) => InventoryNotifier([_phone(soldToday: soldToday)])),
  ]);
  addTearDown(c.dispose);
  return c;
}

SaleRecord _sale({
  int total = 1000,
  String? channel = 'cash',
  int? productId = 1,
  DateTime? at,
}) =>
    SaleRecord(
      receiptNo: 'R1',
      total: total,
      paid: total,
      kind: 'cash',
      soldAt: at ?? DateTime.now(),
      paymentChannel: channel,
      productId: productId,
    );

void main() {
  test('no sales today means no profit, whatever the sold counter says', () {
    final c = _c(sales: const [], soldToday: 49);
    final pnl = c.read(reportTotalsProvider(ReportRange.today));
    expect(pnl.revenue, 0);
    expect(pnl.cogs, 0);
    expect(pnl.profit, 0);
  });

  test('one sale today is costed against the product, not a 24% guess', () {
    final c = _c(sales: [_sale()]);
    final pnl = c.read(reportTotalsProvider(ReportRange.today));
    expect(pnl.revenue, 1000);
    expect(pnl.cogs, 700);
    expect(pnl.profit, 300);
  });

  test("a sale from yesterday does not count", () {
    final c = _c(sales: [
      _sale(at: DateTime.now().subtract(const Duration(days: 1))),
    ]);
    expect(c.read(reportTotalsProvider(ReportRange.today)).revenue, 0);
  });

  test('a sale with no catalogue row is costed conservatively', () {
    final c = _c(sales: [_sale(productId: 99)]);
    final pnl = c.read(reportTotalsProvider(ReportRange.today));
    expect(pnl.cogs, 780);
    expect(pnl.profit, 220);
  });

  test('a sale from last night in Dar es Salaam is not today, wherever the '
      'device thinks it is', () {
    // 21:53 UTC yesterday is 00:53 EAT today's morning? No: 21:53 UTC + 3h is
    // 00:53 the next day, which IS today in Dar. Use 19:53 UTC instead: 22:53
    // EAT the previous evening, and 03:53 the next morning on a device set to
    // Asia/Shanghai. The shop had closed; the report must not count it.
    final eatNow = DateTime.now().toUtc().add(const Duration(hours: 3));
    final lastNight = DateTime.utc(eatNow.year, eatNow.month, eatNow.day)
        .subtract(const Duration(hours: 4, minutes: 7)); // 19:53 UTC yesterday
    final c = _c(sales: [_sale(total: 2950000, at: lastNight)]);
    expect(c.read(reportTotalsProvider(ReportRange.today)).revenue, 0);
    expect(c.read(reportTotalsProvider(ReportRange.today)).cash, 0);
  });

  test('the channel split separates cash, mobile money and card', () {
    final c = _c(sales: [
      _sale(total: 100, channel: 'cash'),
      _sale(total: 200, channel: 'mpesa'),
      _sale(total: 400, channel: 'card ••••5678'),
      _sale(total: 800, channel: 'drawer'),
    ]);
    final split = c.read(reportTotalsProvider(ReportRange.today));
    expect(split.cash, 100);
    expect(split.mobile, 200);
    expect(split.card, 400);
    expect(split.other, 800);
  });
}
