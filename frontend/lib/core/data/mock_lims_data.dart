import 'package:flutter/material.dart';
import 'product_art.dart';

class ProductItem {
  final int id;
  final String name;
  final String variant;
  final String sku;
  final int price;
  int stock;
  final int min;
  final String cat; // 'phones', 'acc', 'laptops'
  final List<Color> grad;
  String status; // 'in', 'low', 'out'
  final int soldToday;
  final int onLoan;
  bool fav;
  /// "On offer": the shop owner has put this handset in front of the cashier
  /// on the till home, usually because it has been sitting on the shelf.
  /// Persisted as `products.on_offer`; see migration 2026_10_22_05.
  bool onOffer;
  final String? brand;
  final String? imei1;
  final String? imei2;
  final int? costPrice;
  final int? loanPrice;
  final String? imageAsset;
  final String? imageUrl;

  /// Which branch holds this stock. Null on rows written before stock was
  /// recorded per branch; those units are counted at the branch the catalogue
  /// was seeded from rather than silently disappearing from every total.
  final String? branchId;
  final List<String> availableImages;

  ProductItem({
    required this.id,
    required this.name,
    required this.variant,
    required this.sku,
    required this.price,
    required this.stock,
    required this.min,
    required this.cat,
    required this.grad,
    required this.status,
    required this.soldToday,
    required this.onLoan,
    this.fav = false,
    this.onOffer = false,
    this.brand,
    this.imei1,
    this.imei2,
    this.costPrice,
    this.loanPrice,
    this.imageAsset,
    this.imageUrl,
    this.branchId,
    this.availableImages = const [],
  });

  ProductItem copyWith({
    int? id,
    String? name,
    String? variant,
    String? sku,
    int? price,
    int? stock,
    int? min,
    String? cat,
    List<Color>? grad,
    String? status,
    int? soldToday,
    int? onLoan,
    bool? fav,
    bool? onOffer,
    String? brand,
    String? imei1,
    String? imei2,
    int? costPrice,
    int? loanPrice,
    String? imageAsset,
    String? imageUrl,
    List<String>? availableImages,
  }) {
    return ProductItem(
      id: id ?? this.id,
      name: name ?? this.name,
      variant: variant ?? this.variant,
      sku: sku ?? this.sku,
      price: price ?? this.price,
      stock: stock ?? this.stock,
      min: min ?? this.min,
      cat: cat ?? this.cat,
      grad: grad ?? this.grad,
      status: status ?? this.status,
      soldToday: soldToday ?? this.soldToday,
      onLoan: onLoan ?? this.onLoan,
      fav: fav ?? this.fav,
      onOffer: onOffer ?? this.onOffer,
      brand: brand ?? this.brand,
      imei1: imei1 ?? this.imei1,
      imei2: imei2 ?? this.imei2,
      costPrice: costPrice ?? this.costPrice,
      loanPrice: loanPrice ?? this.loanPrice,
      imageAsset: imageAsset ?? this.imageAsset,
      imageUrl: imageUrl ?? this.imageUrl,
      availableImages: availableImages ?? this.availableImages,
    );
  }

  String get formattedPrice {
    final s = price.toString();
    final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return 'TZS ${s.replaceAllMapped(reg, (Match m) => '${m[1]},')}';
  }

  String get shortPrice {
    if (price >= 1000000) {
      final m = (price / 1000000.0).toStringAsFixed(2);
      return 'TZS ${m.replaceAll(RegExp(r'\.?0+$'), '')}M';
    }
    if (price >= 1000) {
      return 'TZS ${(price / 1000).toStringAsFixed(0)}K';
    }
    return 'TZS $price';
  }
}

class LoanPaymentRecord {
  final String id;
  final String date;
  final int amount;
  final String channel; // 'M-Pesa', 'Tigo Pesa', 'Airtel Money', 'Cash Drawer'
  final String refNumber;
  final String receiptNumber;

  LoanPaymentRecord({
    required this.id,
    required this.date,
    required this.amount,
    required this.channel,
    required this.refNumber,
    required this.receiptNumber,
  });

  String get formattedAmount {
    final s = amount.toString();
    final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return 'TZS ${s.replaceAllMapped(reg, (Match m) => '${m[1]},')}';
  }
}

class LoanItem {
  final String id;
  final String name;
  final String item;
  final int amount;
  int paid; // percentage 0..100
  final String due;
  final String status; // 'current', 'overdue', 'cleared'

  /// When the next instalment falls due. `due` above is the note shown on the
  /// card ("Due in 4 days"); this is the date the arithmetic uses, so ageing a
  /// loan does not depend on a sentence somebody typed.
  final DateTime? dueDate;
  final List<Color> grad;
  final String phone;
  final String nida;
  final String location;
  final String businessAddress;
  final String imei;
  final String guarantorName;
  final String guarantorPhone;
  final String guarantorRelation;
  bool isKnoxLocked;
  final int totalDeposit;
  final int weeklyInstallment;
  final int installmentWeeks;
  final List<LoanPaymentRecord> payments;

  /// Exact money received, once the counter has rung up a repayment.
  ///
  /// [paid] is an integer percentage of [amount], so a TZS 1,000 instalment on
  /// a TZS 2,400,000 loan is 0.04% and rounds back to the percentage it started
  /// from: the money was received, the record was written, and the balance did
  /// not move. When a repayment is recorded we keep the exact figure here and
  /// read the balance from it. Loans that only ever carried a percentage
  /// (seeded rows, or rows loaded from `paid_percent`) keep using [paid], so no
  /// existing figure changes.
  ///
  /// This is in-memory only: the ledger stores `paid_percent`, so the shilling
  /// residue is lost on reload until repayments are stored as rows of their own.
  final int? paidAmountOverride;

  LoanItem({
    String? id,
    required this.name,
    required this.item,
    required this.amount,
    required this.paid,
    required this.due,
    required this.status,
    this.dueDate,
    required this.grad,
    String? phone,
    String? nida,
    String? location,
    String? businessAddress,
    String? imei,
    String? guarantorName,
    String? guarantorPhone,
    String? guarantorRelation,
    bool? isKnoxLocked,
    int? totalDeposit,
    int? weeklyInstallment,
    int? installmentWeeks,
    List<LoanPaymentRecord>? payments,
    this.paidAmountOverride,
  })  : // A blank column means "not recorded", never "here is a plausible
        // Tanzanian phone number". These fallbacks used to be a real-looking
        // phone, NIDA number, IMEI, guarantor and Kariakoo address, so a loan row
        // with empty columns displayed a complete invented identity — and a text
        // reminder would have opened a stranger's number.
        id = id ?? 'LIMS-LN-${(1000 + (name.hashCode.abs() % 9000))}',
        phone = phone ?? '',
        nida = nida ?? '',
        location = location ?? '',
        businessAddress = businessAddress ?? '',
        imei = imei ?? '',
        guarantorName = guarantorName ?? '',
        guarantorPhone = guarantorPhone ?? '',
        guarantorRelation = guarantorRelation ?? '',
        isKnoxLocked = isKnoxLocked ?? (status == 'overdue'),
        totalDeposit = totalDeposit ?? 0,
        weeklyInstallment = weeklyInstallment ?? 0,
        installmentWeeks = installmentWeeks ?? 0,
        payments = payments ?? [];

  /// Money received so far, in whole shillings.
  ///
  /// Prefers the exact figure kept by [recordPayment] and falls back to the
  /// stored percentage. See [LoanBalance] for why the percentage is taken of
  /// [amount] and not of the deposit-adjusted balance.
  int get totalPaidAmount =>
      (paidAmountOverride ?? (amount * (paid / 100.0)).round())
          .clamp(0, amount);

  int get remainingAmount => (amount - totalPaidAmount).clamp(0, amount);

  /// The percentage the screens draw, computed from money so a small instalment
  /// still moves the bar by the shilling it was worth.
  int get paidPercent =>
      amount <= 0 ? 0 : ((totalPaidAmount * 100) / amount).round().clamp(0, 100);

  String get formattedAmount {
    final s = amount.toString();
    final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return 'TZS ${s.replaceAllMapped(reg, (Match m) => '${m[1]},')}';
  }

  String get formattedTotalPaidAmount {
    final s = totalPaidAmount.toString();
    final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return 'TZS ${s.replaceAllMapped(reg, (Match m) => '${m[1]},')}';
  }

  String get formattedRemainingAmount {
    final s = remainingAmount.toString();
    final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return 'TZS ${s.replaceAllMapped(reg, (Match m) => '${m[1]},')}';
  }

  String get formattedDeposit {
    final s = totalDeposit.toString();
    final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return 'TZS ${s.replaceAllMapped(reg, (Match m) => '${m[1]},')}';
  }

  String get formattedWeeklyInstallment {
    final s = weeklyInstallment.toString();
    final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return 'TZS ${s.replaceAllMapped(reg, (Match m) => '${m[1]},')}';
  }

  String get shortAmount {
    if (amount >= 1000000) {
      final m = (amount / 1000000.0).toStringAsFixed(2);
      return 'TZS ${m.replaceAll(RegExp(r'\.?0+$'), '')}M';
    }
    return 'TZS $amount';
  }

  String get initials {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}';
    }
    return name.isNotEmpty ? name[0] : 'L';
  }

  LoanItem copyWith({
    String? id,
    String? name,
    String? item,
    int? amount,
    int? paid,
    String? due,
    String? status,
    List<Color>? grad,
    String? phone,
    String? nida,
    String? location,
    String? businessAddress,
    String? imei,
    String? guarantorName,
    String? guarantorPhone,
    String? guarantorRelation,
    bool? isKnoxLocked,
    int? totalDeposit,
    int? weeklyInstallment,
    int? installmentWeeks,
    List<LoanPaymentRecord>? payments,
    int? paidAmountOverride,
  }) {
    return LoanItem(
      id: id ?? this.id,
      name: name ?? this.name,
      item: item ?? this.item,
      amount: amount ?? this.amount,
      paid: paid ?? this.paid,
      due: due ?? this.due,
      status: status ?? this.status,
      grad: grad ?? this.grad,
      phone: phone ?? this.phone,
      nida: nida ?? this.nida,
      location: location ?? this.location,
      businessAddress: businessAddress ?? this.businessAddress,
      imei: imei ?? this.imei,
      guarantorName: guarantorName ?? this.guarantorName,
      guarantorPhone: guarantorPhone ?? this.guarantorPhone,
      guarantorRelation: guarantorRelation ?? this.guarantorRelation,
      isKnoxLocked: isKnoxLocked ?? this.isKnoxLocked,
      totalDeposit: totalDeposit ?? this.totalDeposit,
      weeklyInstallment: weeklyInstallment ?? this.weeklyInstallment,
      installmentWeeks: installmentWeeks ?? this.installmentWeeks,
      payments: payments ?? this.payments,
      paidAmountOverride: paidAmountOverride ?? this.paidAmountOverride,
    );
  }
}

class ActivityItem {
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final String title;
  final String description;
  final String time;

  ActivityItem({
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    required this.title,
    required this.description,
    required this.time,
  });
}

class StaffMember {
  final String id;
  final String name;
  /// Canonical role string — see [UserRoles] in core/constants/app_constants.dart.
  /// Never store a legacy alias here: 'Inventory Officer' and 'Staff' were
  /// retired in favour of 'Storekeeper' and 'Counter Cashier'.
  final String role;
  final String email;
  final String phone;
  final String branch;
  final String staffCode;
  final String supervisorPin; // server-issued per-staff PIN; never a shared default
  final String status; // 'Active', 'Suspended'
  final bool canDisburseLoans;
  final bool canKnoxLock;
  final bool canViewMargins;
  final bool canEditStock;
  final bool canApproveOverrides;
  /// Portrait chosen for this person, from `staff.avatar_asset`. Null falls back
  /// to the role portrait, then to initials.
  final String? avatarAsset;
  final String lastActive;
  final List<Color> grad;

  StaffMember({
    required this.id,
    required this.name,
    required this.role,
    required this.email,
    required this.phone,
    required this.branch,
    required this.staffCode,
    this.supervisorPin = '',
    this.status = 'Active',
    this.canDisburseLoans = true,
    this.canKnoxLock = true,
    this.canViewMargins = true,
    this.canEditStock = true,
    this.canApproveOverrides = false,
    this.avatarAsset,
    this.lastActive = 'Active now',
    required this.grad,
  });

  String get initials {
    final p = name.split(' ');
    if (p.length >= 2) return '${p[0][0]}${p[1][0]}';
    return name.isNotEmpty ? name[0] : 'S';
  }

  StaffMember copyWith({
    String? id,
    String? name,
    String? role,
    String? email,
    String? phone,
    String? branch,
    String? staffCode,
    String? supervisorPin,
    String? status,
    bool? canDisburseLoans,
    bool? canKnoxLock,
    bool? canViewMargins,
    bool? canEditStock,
    bool? canApproveOverrides,
    String? lastActive,
    String? avatarAsset,
    List<Color>? grad,
  }) {
    return StaffMember(
      id: id ?? this.id,
      name: name ?? this.name,
      role: role ?? this.role,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      branch: branch ?? this.branch,
      staffCode: staffCode ?? this.staffCode,
      supervisorPin: supervisorPin ?? this.supervisorPin,
      status: status ?? this.status,
      canDisburseLoans: canDisburseLoans ?? this.canDisburseLoans,
      canKnoxLock: canKnoxLock ?? this.canKnoxLock,
      canViewMargins: canViewMargins ?? this.canViewMargins,
      canEditStock: canEditStock ?? this.canEditStock,
      canApproveOverrides: canApproveOverrides ?? this.canApproveOverrides,
      lastActive: lastActive ?? this.lastActive,
      avatarAsset: avatarAsset ?? this.avatarAsset,
      grad: grad ?? this.grad,
    );
  }
}

class StaffItem {
  final String name;
  final String role;
  final String status;
  final Color statusColor;
  final List<Color> grad;

  StaffItem({
    required this.name,
    required this.role,
    required this.status,
    required this.statusColor,
    required this.grad,
  });

  String get initials {
    final p = name.split(' ');
    if (p.length >= 2) return '${p[0][0]}${p[1][0]}';
    return name.isNotEmpty ? name[0] : 'S';
  }
}

class MockLimsData {
  static final List<ProductItem> products = [
    ProductItem(
      id: 1,
      name: 'iPhone 15 Pro Max',
      brand: 'Apple',
      variant: '256GB · Natural Titanium',
      sku: 'IP15PM-256-NT',
      price: 3850000,
      stock: 24,
      min: 8,
      cat: 'phones',
      grad: const [Color(0xFF1B6EF3), Color(0xFF0A49B8)],
      status: 'in',
      soldToday: 5,
      onLoan: 6,
      fav: true,
      imageAsset: 'assets/images/blue_iphones_duo.png',
      availableImages: const [
        'assets/images/blue_iphones_duo.png',
        'https://images.unsplash.com/photo-1695048133142-1a20484d2569?w=600&auto=format&fit=crop&q=80',
        'https://images.unsplash.com/photo-1610945265064-0e34e5519bbf?w=600&auto=format&fit=crop&q=80',
      ],
    ),
    ProductItem(
      id: 2,
      name: 'Galaxy S24 Ultra',
      brand: 'Samsung',
      variant: '256GB · Titanium Gray',
      sku: 'SGS24U-256-TG',
      price: 3420000,
      stock: 18,
      min: 6,
      cat: 'phones',
      grad: const [Color(0xFF6366F1), Color(0xFF4338CA)],
      status: 'in',
      soldToday: 3,
      onLoan: 4,
      fav: false,
      imageAsset: 'assets/images/samsung_galaxy_ultra.png',
      imageUrl: 'https://images.unsplash.com/photo-1610945265064-0e34e5519bbf?w=600&auto=format&fit=crop&q=80',
      availableImages: const [
        'assets/images/samsung_galaxy_ultra.png',
        'https://images.unsplash.com/photo-1610945265064-0e34e5519bbf?w=600&auto=format&fit=crop&q=80',
        'assets/images/blue_iphones_duo.png',
      ],
    ),
    ProductItem(
      id: 3,
      name: 'Redmi Note 13 Pro',
      brand: 'Xiaomi',
      variant: '256GB · Midnight Black',
      sku: 'RN13P-256-MB',
      price: 985000,
      stock: 42,
      min: 10,
      cat: 'phones',
      grad: const [Color(0xFF0EA5E9), Color(0xFF0369A1)],
      status: 'in',
      soldToday: 8,
      onLoan: 2,
      fav: false,
      imageAsset: 'assets/images/redmi_note_13_pro.png',
      imageUrl: 'https://images.unsplash.com/photo-1598327105666-5b89351aff97?w=600&auto=format&fit=crop&q=80',
      availableImages: const [
        'assets/images/redmi_note_13_pro.png',
        'https://images.unsplash.com/photo-1598327105666-5b89351aff97?w=600&auto=format&fit=crop&q=80',
      ],
    ),
    ProductItem(
      id: 4,
      name: 'Tecno Camon 30 Premier',
      brand: 'Tecno',
      variant: '256GB · Serenity Blue',
      sku: 'TC30P-256-SB',
      price: 735000,
      stock: 35,
      min: 10,
      cat: 'phones',
      grad: const [Color(0xFF06B6D4), Color(0xFF0E7490)],
      status: 'in',
      soldToday: 6,
      onLoan: 3,
      fav: false,
      imageAsset: 'assets/images/tecno_camon_30.png',
      imageUrl: 'https://images.unsplash.com/photo-1511707171634-5f897ff02aa9?w=600&auto=format&fit=crop&q=80',
      availableImages: const [
        'assets/images/tecno_camon_30.png',
        'https://images.unsplash.com/photo-1511707171634-5f897ff02aa9?w=600&auto=format&fit=crop&q=80',
      ],
    ),
    ProductItem(
      id: 5,
      name: 'AirPods Pro (2nd Gen)',
      brand: 'Apple',
      imageAsset: ProductArt.earbuds,
      variant: 'USB-C · White',
      sku: 'APP2-USB-W',
      price: 430000,
      stock: 5,
      min: 10,
      cat: 'acc',
      grad: const [Color(0xFFF472B6), Color(0xFFDB2777)],
      status: 'low',
      soldToday: 4,
      onLoan: 0,
      fav: true,
      imageUrl: 'https://images.unsplash.com/photo-1600294037681-c80b4cb5b434?w=600&auto=format&fit=crop&q=80',
    ),
    ProductItem(
      id: 6,
      name: 'Galaxy A55',
      brand: 'Samsung',
      imageAsset: ProductArt.samsung,
      variant: '128GB · Awesome Navy',
      sku: 'SGA55-128-NV',
      price: 1260000,
      stock: 4,
      min: 8,
      cat: 'phones',
      grad: const [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
      status: 'low',
      soldToday: 2,
      onLoan: 1,
      fav: false,
      imageUrl: 'https://images.unsplash.com/photo-1598327105666-5b89351aff97?w=600&auto=format&fit=crop&q=80',
    ),
    ProductItem(
      id: 7,
      name: 'iPhone 15',
      brand: 'Apple',
      variant: '128GB · Starlight',
      sku: 'IP15-128-ST',
      price: 2950000,
      stock: 16,
      min: 6,
      cat: 'phones',
      grad: const [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
      status: 'in',
      soldToday: 4,
      onLoan: 2,
      fav: false,
      imageAsset: 'assets/images/blue_iphones_duo.png',
      availableImages: const [
        'assets/images/blue_iphones_duo.png',
        'https://images.unsplash.com/photo-1695048133142-1a20484d2569?w=600&auto=format&fit=crop&q=80',
      ],
    ),
    ProductItem(
      id: 9,
      name: 'itel Vision 3 Plus',
      brand: 'itel',
      imageAsset: ProductArt.itel,
      variant: '64GB · Blue',
      sku: 'IV3P-64-BL',
      price: 285000,
      stock: 0,
      min: 8,
      cat: 'phones',
      grad: const [Color(0xFF94A3B8), Color(0xFF64748B)],
      status: 'out',
      soldToday: 0,
      onLoan: 0,
      fav: false,
    ),
    ProductItem(
      id: 10,
      name: 'Power Bank 20,000mAh',
      imageAsset: ProductArt.powerBank,
      variant: '22.5W · Black',
      sku: 'PB20K-22W-BK',
      price: 89000,
      stock: 53,
      min: 15,
      cat: 'acc',
      grad: const [Color(0xFFF59E0B), Color(0xFFD97706)],
      status: 'in',
      soldToday: 9,
      onLoan: 0,
      fav: false,
    ),
    ProductItem(
      id: 11,
      name: 'Smart Watch X2',
      imageAsset: ProductArt.watch,
      variant: 'AMOLED · 46mm',
      sku: 'SWX2-AM-46',
      price: 210000,
      stock: 12,
      min: 6,
      cat: 'acc',
      grad: const [Color(0xFFEC4899), Color(0xFFBE185D)],
      status: 'in',
      soldToday: 3,
      onLoan: 0,
      fav: false,
    ),
    ProductItem(
      id: 12,
      name: 'HP Laptop 15s',
      brand: 'HP',
      imageAsset: ProductArt.laptop,
      variant: 'Ryzen 5 · 8GB / 512GB',
      sku: 'HPL15S-R5-8512',
      price: 2150000,
      stock: 6,
      min: 4,
      cat: 'laptops',
      grad: const [Color(0xFF64748B), Color(0xFF334155)],
      status: 'in',
      soldToday: 1,
      onLoan: 1,
      fav: false,
    ),
  ];

  static final List<LoanItem> loans = [
    LoanItem(
      id: 'LIMS-LN-4081',
      name: 'John Mwalimu',
      item: 'iPhone 15 Pro Max 256GB',
      amount: 2400000,
      paid: 60,
      due: 'Due in 4 days',
      status: 'current',
      grad: const [Color(0xFF1B6EF3), Color(0xFF0A49B8)],
      phone: '0754 892 314',
      nida: '19880415-11104-00003-19',
      location: 'Kariakoo, Msimbazi St, Dar es Salaam',
      businessAddress: 'Machinga Complex, Floor 2, Kibanda #14',
      imei: '356984112048591',
      guarantorName: 'Rashid Mwalimu (Kaka)',
      guarantorPhone: '0713 884 102',
      guarantorRelation: 'Kaka Mkubwa (Blood Relative)',
      isKnoxLocked: false,
      totalDeposit: 600000,
      weeklyInstallment: 225000,
      installmentWeeks: 8,
      payments: [
        LoanPaymentRecord(
          id: 'PM-901',
          date: '28 Sep 2026, 09:30 AM',
          amount: 225000,
          channel: 'M-Pesa Lipa Namba',
          refNumber: 'MP89201948',
          receiptNumber: 'RCP-TZ-8910',
        ),
        LoanPaymentRecord(
          id: 'PM-902',
          date: '21 Sep 2026, 02:15 PM',
          amount: 225000,
          channel: 'M-Pesa Lipa Namba',
          refNumber: 'MP87621094',
          receiptNumber: 'RCP-TZ-8842',
        ),
        LoanPaymentRecord(
          id: 'PM-903',
          date: '14 Sep 2026, 11:00 AM',
          amount: 225000,
          channel: 'Cash Drawer',
          refNumber: 'CSH-REC-441',
          receiptNumber: 'RCP-TZ-8750',
        ),
        LoanPaymentRecord(
          id: 'PM-904',
          date: '07 Sep 2026, 10:45 AM',
          amount: 225000,
          channel: 'Airtel Money',
          refNumber: 'AT55192038',
          receiptNumber: 'RCP-TZ-8692',
        ),
      ],
    ),
    LoanItem(
      id: 'LIMS-LN-4082',
      name: 'Amina Komba',
      item: 'Galaxy S24 Ultra 256GB',
      amount: 1850000,
      paid: 35,
      due: 'Overdue 2 days',
      status: 'overdue',
      grad: const [Color(0xFFF472B6), Color(0xFFDB2777)],
      phone: '0784 219 832',
      nida: '19930722-12108-00002-21',
      location: 'Kinondoni Manyanya, Dar es Salaam',
      businessAddress: 'Mwananyamala Market, Stand #08',
      imei: '354891108234901',
      guarantorName: 'Zainab Komba (Mama Mdogo)',
      guarantorPhone: '0654 332 119',
      guarantorRelation: 'Mama Mdogo',
      isKnoxLocked: true,
      totalDeposit: 462500,
      weeklyInstallment: 173438,
      installmentWeeks: 8,
      payments: [
        LoanPaymentRecord(
          id: 'PM-801',
          date: '16 Sep 2026, 04:20 PM',
          amount: 173438,
          channel: 'Tigo Pesa',
          refNumber: 'TG77218930',
          receiptNumber: 'RCP-TZ-8711',
        ),
        LoanPaymentRecord(
          id: 'PM-802',
          date: '09 Sep 2026, 01:10 PM',
          amount: 173438,
          channel: 'M-Pesa Lipa Namba',
          refNumber: 'MP86102948',
          receiptNumber: 'RCP-TZ-8640',
        ),
      ],
    ),
    LoanItem(
      id: 'LIMS-LN-4083',
      name: 'Peter Msechu',
      item: 'Redmi Note 12 128GB',
      amount: 620000,
      paid: 80,
      due: 'Due in 12 days',
      status: 'current',
      grad: const [Color(0xFF0EA5E9), Color(0xFF0369A1)],
      phone: '0655 491 203',
      nida: '19951103-14102-00005-18',
      location: 'Sinza Mori, Dar es Salaam',
      businessAddress: 'Sinza Pharmacy & Cosmetics',
      imei: '869201048821039',
      guarantorName: 'Kelvin Msechu (Kaka)',
      guarantorPhone: '0714 559 881',
      guarantorRelation: 'Kaka',
      isKnoxLocked: false,
      totalDeposit: 155000,
      weeklyInstallment: 58125,
      installmentWeeks: 8,
      payments: [
        LoanPaymentRecord(
          id: 'PM-701',
          date: '25 Sep 2026, 03:00 PM',
          amount: 58125,
          channel: 'M-Pesa Lipa Namba',
          refNumber: 'MP88910283',
          receiptNumber: 'RCP-TZ-8890',
        ),
        LoanPaymentRecord(
          id: 'PM-702',
          date: '18 Sep 2026, 11:30 AM',
          amount: 58125,
          channel: 'Cash Drawer',
          refNumber: 'CSH-REC-502',
          receiptNumber: 'RCP-TZ-8820',
        ),
      ],
    ),
    LoanItem(
      id: 'LIMS-LN-4084',
      name: 'Neema Lyimo',
      item: 'iPhone 15 128GB',
      amount: 2900000,
      paid: 45,
      due: 'Due in 6 days',
      status: 'current',
      grad: const [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
      phone: '0718 332 940',
      nida: '19910218-11105-00001-26',
      location: 'Mikocheni B, Dar es Salaam',
      businessAddress: 'Neema Beauty Parlour & Spa',
      imei: '357891102948201',
      guarantorName: 'David Lyimo (Mume)',
      guarantorPhone: '0754 112 400',
      guarantorRelation: 'Mume (Spouse)',
      isKnoxLocked: false,
      totalDeposit: 725000,
      weeklyInstallment: 271875,
      installmentWeeks: 8,
      payments: [
        LoanPaymentRecord(
          id: 'PM-601',
          date: '22 Sep 2026, 05:40 PM',
          amount: 271875,
          channel: 'M-Pesa Lipa Namba',
          refNumber: 'MP88129034',
          receiptNumber: 'RCP-TZ-8860',
        ),
        LoanPaymentRecord(
          id: 'PM-602',
          date: '15 Sep 2026, 10:15 AM',
          amount: 271875,
          channel: 'CRDB Bank Transfer',
          refNumber: 'CRDB-TX-9901',
          receiptNumber: 'RCP-TZ-8790',
        ),
      ],
    ),
    LoanItem(
      id: 'LIMS-LN-4085',
      name: 'Baraka Mushi',
      item: 'Tecno Camon 30 256GB',
      amount: 540000,
      paid: 20,
      due: 'Overdue 5 days',
      status: 'overdue',
      grad: const [Color(0xFFF59E0B), Color(0xFFD97706)],
      phone: '0767 554 119',
      nida: '19890930-13101-00004-12',
      location: 'Buguruni Chama, Dar es Salaam',
      businessAddress: 'Kituo cha Bodaboda Buguruni',
      imei: '861940294810293',
      guarantorName: 'Godfrey Mushi (Kaka)',
      guarantorPhone: '0688 221 904',
      guarantorRelation: 'Kaka',
      isKnoxLocked: true,
      totalDeposit: 135000,
      weeklyInstallment: 50625,
      installmentWeeks: 8,
      payments: [
        LoanPaymentRecord(
          id: 'PM-501',
          date: '08 Sep 2026, 08:30 AM',
          amount: 50625,
          channel: 'M-Pesa Lipa Namba',
          refNumber: 'MP85901238',
          receiptNumber: 'RCP-TZ-8620',
        ),
      ],
    ),
  ];

  static final List<ActivityItem> activities = [
    ActivityItem(
      icon: Icons.account_balance_wallet_rounded,
      iconColor: const Color(0xFF12B76A),
      bgColor: const Color(0xFFE7F8F0),
      title: 'Sale completed — iPhone 15 Pro Max',
      description: 'TZS 3,850,000 · Cash',
      time: '10:42 AM',
    ),
    ActivityItem(
      icon: Icons.handshake_rounded,
      iconColor: const Color(0xFFF43F5E),
      bgColor: const Color(0xFFFFEDF1),
      title: 'Loan disbursed — John Mwalimu',
      description: 'TZS 2,400,000 · 6 months',
      time: '9:15 AM',
    ),
    ActivityItem(
      icon: Icons.archive_rounded,
      iconColor: const Color(0xFF1B6EF3),
      bgColor: const Color(0xFFE9F2FF),
      title: 'Stock received — 20 units',
      description: 'From Dar es Salaam Hub',
      time: '8:30 AM',
    ),
    ActivityItem(
      icon: Icons.swap_horiz_rounded,
      iconColor: const Color(0xFF7C5CFC),
      bgColor: const Color(0xFFF0EBFF),
      title: 'Transfer sent — 5 units',
      description: 'To Kariakoo Branch',
      time: 'Yesterday',
    ),
  ];

  static final List<StaffItem> staff = [
    StaffItem(
      name: 'Neema Julius',
      role: 'Store Manager',
      status: 'Clocked in · 08:02',
      statusColor: const Color(0xFF12B76A),
      grad: const [Color(0xFF1B6EF3), Color(0xFF0A49B8)],
    ),
    StaffItem(
      name: 'Baraka Mushi',
      role: 'Sales Associate',
      status: 'Clocked in · 08:11',
      statusColor: const Color(0xFF12B76A),
      grad: const [Color(0xFF0EA5E9), Color(0xFF0369A1)],
    ),
    StaffItem(
      name: 'Amina Komba',
      role: 'Sales Associate',
      status: 'Late · 09:15',
      statusColor: const Color(0xFFF79009),
      grad: const [Color(0xFFF472B6), Color(0xFFDB2777)],
    ),
    StaffItem(
      name: 'Peter Msechu',
      role: 'Warehouse',
      status: 'On break',
      statusColor: const Color(0xFF1B6EF3),
      grad: const [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
    ),
    StaffItem(
      name: 'Zawadi Nnaji',
      role: 'Cashier',
      status: 'Absent today',
      statusColor: const Color(0xFF94A3B8),
      grad: const [Color(0xFF94A3B8), Color(0xFF64748B)],
    ),
  ];

  static final List<StaffMember> staffMembers = [
    StaffMember(
      id: 'STF-01',
      name: 'David Erick Mwijage',
      role: 'Super Admin',
      email: 'mwijage@limstanzania.co.tz',
      phone: '0755 120 488',
      branch: 'HQ Central · All Branches',
      staffCode: 'ADM-001',
      supervisorPin: '9900',
      status: 'Active',
      canDisburseLoans: true,
      canKnoxLock: true,
      canViewMargins: true,
      canEditStock: true,
      canApproveOverrides: true,
      lastActive: 'Active now',
      grad: const [Color(0xFF1B6EF3), Color(0xFF0A49B8)],
    ),
    StaffMember(
      id: 'STF-02',
      name: 'Neema Julius',
      role: 'Branch Manager',
      email: 'neema.j@limstanzania.co.tz',
      phone: '0754 892 314',
      branch: 'Kariakoo Main Branch',
      staffCode: 'MGR-104',
      supervisorPin: '',
      status: 'Active',
      canDisburseLoans: true,
      canKnoxLock: true,
      canViewMargins: true,
      canEditStock: true,
      canApproveOverrides: true,
      lastActive: 'Active now',
      grad: const [Color(0xFF7C5CFC), Color(0xFF5B3EE8)],
    ),
    StaffMember(
      id: 'STF-03',
      name: 'Baraka Mushi',
      role: 'Loan Officer',
      email: 'baraka.m@limstanzania.co.tz',
      phone: '0767 554 119',
      branch: 'Kariakoo Main Branch',
      staffCode: 'LNO-208',
      supervisorPin: '4410',
      status: 'Active',
      canDisburseLoans: true,
      canKnoxLock: true,
      canViewMargins: false,
      canEditStock: false,
      canApproveOverrides: false,
      lastActive: '12 mins ago',
      grad: const [Color(0xFF12B76A), Color(0xFF0E9355)],
    ),
    StaffMember(
      id: 'STF-04',
      name: 'Zawadi Nnaji',
      role: 'Counter Cashier',
      email: 'zawadi.n@limstanzania.co.tz',
      phone: '0714 883 201',
      branch: 'Kariakoo Main Branch',
      staffCode: 'CSH-305',
      supervisorPin: '1120',
      status: 'Active',
      canDisburseLoans: false,
      canKnoxLock: false,
      canViewMargins: false,
      canEditStock: false,
      canApproveOverrides: false,
      lastActive: '5 mins ago',
      grad: const [Color(0xFFF79009), Color(0xFFDC7702)],
    ),
    StaffMember(
      id: 'STF-05',
      name: 'Peter Msechu',
      role: 'Storekeeper',
      email: 'peter.m@limstanzania.co.tz',
      phone: '0655 491 203',
      branch: 'Mbezi Hub Branch',
      staffCode: 'INV-402',
      supervisorPin: '3390',
      status: 'Active',
      canDisburseLoans: false,
      canKnoxLock: false,
      canViewMargins: true,
      canEditStock: true,
      canApproveOverrides: false,
      lastActive: '1 hour ago',
      grad: const [Color(0xFF0EA5E9), Color(0xFF0284C7)],
    ),
  ];

  static final List<AttendanceRecord> attendanceLogs = [
    AttendanceRecord(
      id: 'ATT-20261002-01',
      staffId: 'STF-02',
      staffName: 'Neema Julius',
      role: 'Branch Manager',
      branch: 'Kariakoo Main Branch',
      date: 'Fri, 02 Oct 2026',
      clockInTime: '07:48 AM',
      clockOutTime: null,
      status: 'Present',
      shiftHours: 6.8,
      verifiedBy: 'HQ Biometrics & GPS',
    ),
    AttendanceRecord(
      id: 'ATT-20261002-02',
      staffId: 'STF-03',
      staffName: 'Baraka Mushi',
      role: 'Loan Officer',
      branch: 'Kariakoo Main Branch',
      date: 'Fri, 02 Oct 2026',
      clockInTime: '07:55 AM',
      clockOutTime: null,
      status: 'Present',
      shiftHours: 6.7,
      verifiedBy: 'Neema Julius (Supervisor)',
    ),
    AttendanceRecord(
      id: 'ATT-20261002-03',
      staffId: 'STF-05',
      staffName: 'Peter Msechu',
      role: 'Storekeeper',
      branch: 'Central Warehouse',
      date: 'Fri, 02 Oct 2026',
      clockInTime: '08:12 AM',
      clockOutTime: null,
      status: 'Late (12m)',
      shiftHours: 6.4,
      verifiedBy: 'Neema Julius (Supervisor)',
    ),
    AttendanceRecord(
      id: 'ATT-20261002-04',
      staffId: 'STF-04',
      staffName: 'Zawadi Nnaji',
      role: 'Counter Cashier',
      branch: 'Kariakoo Main Branch',
      date: 'Fri, 02 Oct 2026',
      clockInTime: '07:58 AM',
      clockOutTime: null,
      status: 'Present',
      shiftHours: 6.6,
      verifiedBy: 'Neema Julius (Supervisor)',
    ),
    AttendanceRecord(
      id: 'ATT-20261001-01',
      staffId: 'STF-04',
      staffName: 'Zawadi Nnaji',
      role: 'Counter Cashier',
      branch: 'Kariakoo Main Branch',
      date: 'Thu, 01 Oct 2026',
      clockInTime: '08:00 AM',
      clockOutTime: '05:30 PM',
      status: 'Completed',
      shiftHours: 8.5,
      verifiedBy: 'Neema Julius (Supervisor)',
    ),
    AttendanceRecord(
      id: 'ATT-20261001-02',
      staffId: 'STF-03',
      staffName: 'Baraka Mushi',
      role: 'Loan Officer',
      branch: 'Kariakoo Main Branch',
      date: 'Thu, 01 Oct 2026',
      clockInTime: '07:50 AM',
      clockOutTime: '06:00 PM',
      status: 'Overtime (1h)',
      shiftHours: 9.2,
      verifiedBy: 'Neema Julius (Supervisor)',
    ),
  ];
}

class AttendanceRecord {
  final String id;
  final String staffId;
  final String staffName;
  final String role;
  final String branch;
  final String date;
  final String clockInTime;
  final String? clockOutTime;
  final String status; // 'Present', 'Late (12m)', 'On Break', 'Completed', 'Overtime (1h)'
  final double shiftHours;
  final bool isGeofenceVerified;
  final String verifiedBy;

  AttendanceRecord({
    required this.id,
    required this.staffId,
    required this.staffName,
    required this.role,
    required this.branch,
    required this.date,
    required this.clockInTime,
    this.clockOutTime,
    required this.status,
    required this.shiftHours,
    this.isGeofenceVerified = true,
    this.verifiedBy = 'Supervisor verified',
  });

  AttendanceRecord copyWith({
    String? id,
    String? staffId,
    String? staffName,
    String? role,
    String? branch,
    String? date,
    String? clockInTime,
    String? clockOutTime,
    String? status,
    double? shiftHours,
    bool? isGeofenceVerified,
    String? verifiedBy,
  }) {
    return AttendanceRecord(
      id: id ?? this.id,
      staffId: staffId ?? this.staffId,
      staffName: staffName ?? this.staffName,
      role: role ?? this.role,
      branch: branch ?? this.branch,
      date: date ?? this.date,
      clockInTime: clockInTime ?? this.clockInTime,
      clockOutTime: clockOutTime ?? this.clockOutTime,
      status: status ?? this.status,
      shiftHours: shiftHours ?? this.shiftHours,
      isGeofenceVerified: isGeofenceVerified ?? this.isGeofenceVerified,
      verifiedBy: verifiedBy ?? this.verifiedBy,
    );
  }
}
