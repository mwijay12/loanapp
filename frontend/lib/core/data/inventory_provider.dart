import 'package:flutter/material.dart' show Color;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_constants.dart';
import 'attendance_clock.dart';
import 'mock_lims_data.dart';
import 'sales_provider.dart';

/// User Role State — SERVER-OWNED, read-only projection.
/// P0: the client can never invent or switch roles. The role starts as
/// [UserRoles.noSession] (most restrictive) and is set exactly once per login
/// from the server profile via [hydrateFromSession]. No client-side role
/// writer exists.
class UserRoleNotifier extends StateNotifier<String> {
  UserRoleNotifier() : super(UserRoles.noSession);

  /// One-way hydration from the server session.
  ///
  /// Unknown or empty values are rejected outright so the state stays on the
  /// restrictive [UserRoles.noSession] sentinel. [UserRoles.pending] is a real
  /// state (invited, no access yet) and is preserved as-is — the router guard
  /// is what keeps a pending user out of the app.
  void hydrateFromSession(String? serverRole) {
    final role = UserRoles.normalize(serverRole);
    if (role == null || role == UserRoles.noSession) return;
    state = role;
  }

  void clearSession() => state = UserRoles.noSession;
}

final userRoleProvider = StateNotifierProvider<UserRoleNotifier, String>((ref) {
  return UserRoleNotifier();
});

/// The staff profile behind the current session.
///
/// SECURITY: this used to fall back to `allStaff.first`, which silently handed
/// every unresolved session the first mock record — a Super Admin. The
/// attendance and home screens then rendered elevated capabilities before any
/// role was established. There is no fallback now: an unmatched session gets a
/// locked-out placeholder with every capability denied, and its role is the
/// real session role (or `Pending`, never an elevated one).
/// Name of the person who signed in, set at login.
///
/// Without it the header picked the first staff row with the matching role, so a
/// male storekeeper was shown the female store manager's name and portrait. A role
/// is a permission level, not an identity.
final signedInNameProvider = StateProvider<String?>((ref) => null);

/// The branch this person is assigned to, from `profiles.branch_name`.
///
/// The app used to set the terminal to [AppConstants.launchBranch] at start-up
/// and leave it there, so a Mbagala manager was shown whatever the launch
/// branch happened to be. Assignment is a server fact; the active terminal is
/// only allowed to differ from it for a Super Admin.
final signedInBranchProvider = StateProvider<String?>((ref) => null);

/// The signed-in person's own portrait, from `profiles.avatar_asset`.
///
/// It is overlaid on their staff row rather than written into `staff`, so a
/// person can change their own photo without being granted write access to the
/// staff directory.
final signedInAvatarProvider = StateProvider<String?>((ref) => null);

final activeStaffMemberProvider = Provider<StaffMember>((ref) {
  final currentRole = ref.watch(userRoleProvider);
  final allStaff = ref.watch(staffProvider);
  final signedInName = ref.watch(signedInNameProvider);
  final signedInBranch = ref.watch(signedInBranchProvider);
  final signedInAvatar = ref.watch(signedInAvatarProvider);
  final normalizedRole = UserRoles.normalize(currentRole);

  StaffMember? resolved;

  if (signedInName != null && signedInName.trim().isNotEmpty) {
    final wanted = signedInName.trim().toLowerCase();
    for (final member in allStaff) {
      if (member.name.trim().toLowerCase() == wanted) {
        resolved = member;
        break;
      }
    }
  }

  if (resolved == null && normalizedRole != null) {
    for (final member in allStaff) {
      if (UserRoles.normalize(member.role) == normalizedRole) {
        resolved = member;
        break;
      }
    }
  }

  final member = resolved ??
      StaffMember(
        id: 'noSession',
        name: signedInName ?? 'Signed out',
        role: normalizedRole ?? UserRoles.pending,
        email: '',
        phone: '',
        branch: signedInBranch ?? ref.watch(activeBranchProvider),
        staffCode: '—',
        supervisorPin: '',
        status: 'Inactive',
        canDisburseLoans: false,
        canKnoxLock: false,
        canViewMargins: false,
        canEditStock: false,
        canApproveOverrides: false,
        lastActive: '—',
        grad: const [Color(0xFF94A3B8), Color(0xFF64748B)],
      );

  // The session's own facts win over the row. A staff row can be missing (a
  // profile with no matching `staff` record) or stale, but the branch on the
  // profile and the photo the person just chose are what this person is.
  final branch = (signedInBranch ?? '').trim();
  return member.copyWith(
    branch: branch.isEmpty ? member.branch : branch,
    avatarAsset: (signedInAvatar ?? '').trim().isEmpty
        ? member.avatarAsset
        : signedInAvatar,
  );
});

/// Staff & RBAC Management State
class StaffNotifier extends StateNotifier<List<StaffMember>> {
  StaffNotifier([List<StaffMember> seed = const []]) : super(List.from(seed));

  /// Swap the whole directory for what the database returned.
  void replaceAll(List<StaffMember> members) {
    state = List.from(members);
  }

  void addStaff(StaffMember member) {
    state = [member, ...state];
  }

  void updateStaff(StaffMember member) {
    state = [
      for (final s in state)
        if (s.id == member.id) member else s,
    ];
  }

  /// A staff row from the live stream. Idempotent: a suspension applied at one
  /// branch reaches every other screen once, and its redelivery changes nothing.
  void mergeRow(StaffMember member) {
    if (!state.any((s) => s.id == member.id)) {
      state = [...state, member];
      return;
    }
    updateStaff(member);
  }

  void removeRow(String id) {
    state = [
      for (final s in state)
        if (s.id != id) s,
    ];
  }

  void toggleStatus(String id) {
    state = [
      for (final s in state)
        if (s.id == id)
          s.copyWith(status: s.status == 'Active' ? 'Suspended' : 'Active')
        else
          s,
    ];
  }

  void updateRole(String id, String newRole) {
    state = [
      for (final s in state)
        if (s.id == id) s.copyWith(role: newRole) else s,
    ];
  }

  void togglePermission(String id, String permKey) {
    state = [
      for (final s in state)
        if (s.id == id)
          () {
            switch (permKey) {
              case 'canDisburseLoans':
                return s.copyWith(canDisburseLoans: !s.canDisburseLoans);
              case 'canKnoxLock':
                return s.copyWith(canKnoxLock: !s.canKnoxLock);
              case 'canViewMargins':
                return s.copyWith(canViewMargins: !s.canViewMargins);
              case 'canEditStock':
                return s.copyWith(canEditStock: !s.canEditStock);
              case 'canApproveOverrides':
                return s.copyWith(canApproveOverrides: !s.canApproveOverrides);
              default:
                return s;
            }
          }()
        else
          s,
    ];
  }
}

final staffProvider = StateNotifierProvider<StaffNotifier, List<StaffMember>>((ref) {
  return StaffNotifier();
});

/// Active Branch State (default: the launch branch, Mbagala).
///
/// The guard lives here rather than only in the widget that opens a picker: the
/// branch drives stock, loans, reports and receipts, so "who may move the
/// terminal" is a rule of the state, not of one button. A Branch Manager can
/// call `setBranch` as often as they like and the value stays on their own
/// branch.
class ActiveBranchNotifier extends StateNotifier<String> {
  ActiveBranchNotifier(this._ref) : super(AppConstants.launchBranch);

  final Ref _ref;

  /// Move the terminal. Returns false when the caller's role is not allowed to,
  /// so the screen can say so instead of showing a switch that did not happen.
  bool setBranch(String branch) {
    if (!UserRoles.canSwitchBranch(_ref.read(userRoleProvider))) return false;
    state = branch;
    return true;
  }

  /// Adopt the branch the person is assigned to. Allowed for every role,
  /// because this is not a choice - it is the session telling the app who it is.
  void adoptAssignedBranch(String? branch) {
    final name = (branch ?? '').trim();
    state = name.isEmpty ? AppConstants.launchBranch : name;
  }
}

final activeBranchProvider =
    StateNotifierProvider<ActiveBranchNotifier, String>((ref) {
  return ActiveBranchNotifier(ref);
});

/// Reactive Inventory State
class InventoryNotifier extends StateNotifier<List<ProductItem>> {
  InventoryNotifier([List<ProductItem> seed = const []]) : super(List.from(seed));

  /// Swap the whole catalogue for rows loaded from the backend.
  void replaceAll(List<ProductItem> items) {
    state = List.from(items);
  }

  void addProduct(ProductItem item) {
    state = [item, ...state];
  }

  void updateProductImage(int id, {String? imageAsset, String? imageUrl}) {
    state = [
      for (final p in state)
        if (p.id == id)
          p.copyWith(
            imageAsset: imageAsset,
            imageUrl: imageUrl,
          )
        else
          p,
    ];
  }

  /// Moves the on-screen count by [delta].
  ///
  /// **In-memory only.** Nothing here reaches Postgres: this list is a projection
  /// of `products`, and the writer is
  /// [SupabaseSource.adjustStock]. The reason the
  /// name says "units" and not "stock" is the bug it replaces. This method used to
  /// be `updateStock(id, delta)`, and two screens passed the *new total* into
  /// `delta`: 24 units plus a delivery of 1 became `24 + 25 = 49`, then 98. The
  /// owner's 100 handsets were lost a second way on top of never being written.
  ///
  /// So: call [addStockUnits]/[reduceStockUnits] for what arrived or left,
  /// [setStockTotal] for a number the database just confirmed — never this with a
  /// total.
  void applyStockDelta(int id, int delta) {
    state = [
      for (final p in state)
        if (p.id == id)
          p.copyWith(
            stock: (p.stock + delta).clamp(0, 9999),
            status: (p.stock + delta) <= 0
                ? 'out'
                : (p.stock + delta) <= p.min
                    ? 'low'
                    : 'in',
          )
        else
          p,
    ];
  }

  /// Goods arrived. Mirrors what the database was just told.
  void addStockUnits(int id, int units) {
    if (units <= 0) return;
    applyStockDelta(id, units);
  }

  /// Goods left the shelf outside a sale: damage, a correction, a return.
  void reduceStockUnits(int id, int units) {
    if (units <= 0) return;
    applyStockDelta(id, -units);
  }

  /// Paints the count from a value Postgres returned.
  ///
  /// This is the only place a total is legitimate, precisely because the total came
  /// from the row and not from arithmetic on this side.
  void setStockTotal(int id, int stock) {
    state = [
      for (final p in state)
        if (p.id == id)
          p.copyWith(
            stock: stock.clamp(0, 9999),
            status: stock <= 0 ? 'out' : (stock <= p.min ? 'low' : 'in'),
          )
        else
          p,
    ];
  }

  void sellProduct(int id, {int quantity = 1, bool isLoan = false}) {
    state = [
      for (final p in state)
        if (p.id == id)
          p.copyWith(
            stock: (p.stock - quantity).clamp(0, 9999),
            soldToday: isLoan ? p.soldToday : p.soldToday + quantity,
            onLoan: isLoan ? p.onLoan + quantity : p.onLoan,
            status: (p.stock - quantity) <= 0
                ? 'out'
                : (p.stock - quantity) <= p.min
                    ? 'low'
                    : 'in',
          )
        else
          p,
    ];
  }

  /// Marks a handset as "on offer" for the till home.
  ///
  /// This only moves the in-memory row. The caller is responsible for writing
  /// `products.on_offer`, because a flag that reaches one device and not the
  /// database is exactly the kind of thing that looks saved and is not.
  void setOffer(int id, bool onOffer) {
    state = [
      for (final p in state)
        if (p.id == id) p.copyWith(onOffer: onOffer) else p,
    ];
  }

  void toggleFavorite(int id) {
    state = [
      for (final p in state)
        if (p.id == id) p.copyWith(fav: !p.fav) else p,
    ];
  }

  /// Puts one server row into the catalogue without touching the others.
  ///
  /// This is what makes a stock change at another branch land in under a second
  /// instead of at the next reload. Two rules matter:
  ///
  ///  * **Idempotent.** Postgres can deliver the same UPDATE twice, and a socket
  ///    rejoin can redeliver the tail of a burst. Replacing by id means the
  ///    second copy is harmless; `addProduct` would have shown the handset twice
  ///    and doubled the stock count.
  ///  * **No reordering on update.** A row that only changed `stock` stays where
  ///    the shopkeeper left it. A genuinely new row goes to the front, matching
  ///    `addProduct`.
  void mergeRow(ProductItem item) {
    final exists = state.any((p) => p.id == item.id);
    if (!exists) {
      state = [item, ...state];
      return;
    }
    state = [
      for (final p in state)
        if (p.id == item.id) item else p,
    ];
  }

  /// Drops a product that was deleted at the database. Without this a deleted
  /// handset keeps being sellable on a screen that looks live.
  void removeRow(int id) {
    state = [
      for (final p in state)
        if (p.id != id) p,
    ];
  }
}

final inventoryProvider = StateNotifierProvider<InventoryNotifier, List<ProductItem>>((ref) {
  return InventoryNotifier();
});

/// Reactive Loans State
class LoansNotifier extends StateNotifier<List<LoanItem>> {
  LoansNotifier([List<LoanItem> seed = const []]) : super(List.from(seed));

  void replaceAll(List<LoanItem> items) {
    state = List.from(items);
  }

  void addLoan(LoanItem loan) {
    state = [loan, ...state];
  }

  /// Applies one `loans` row from the live stream: a payment recorded on a
  /// handset moves `paid_percent` on the admin's screen without a reload.
  /// Idempotent by id, and an update never moves the row.
  void mergeRow(LoanItem loan) {
    if (!state.any((l) => l.id == loan.id)) {
      state = [loan, ...state];
      return;
    }
    state = [
      for (final l in state)
        if (l.id == loan.id) loan else l,
    ];
  }

  void removeRow(String id) {
    state = [
      for (final l in state)
        if (l.id != id) l,
    ];
  }

  void toggleKnoxLock(String loanIdOrName, bool isLocked) {
    state = [
      for (final l in state)
        if (l.id == loanIdOrName || l.name.toLowerCase() == loanIdOrName.toLowerCase())
          l.copyWith(isKnoxLocked: isLocked)
        else
          l,
    ];
  }

  void recordPayment(String nameOrId, int paymentAmount, {LoanPaymentRecord? record}) {
    final now = DateTime.now();
    final defaultRecord = record ??
        LoanPaymentRecord(
          id: 'PM-${now.millisecondsSinceEpoch.toString().substring(7)}',
          date: 'Just now',
          amount: paymentAmount,
          channel: 'M-Pesa Lipa Namba',
          refNumber: 'MP${now.millisecondsSinceEpoch.toString().substring(5)}',
          receiptNumber: 'RCP-TZ-${now.millisecondsSinceEpoch.toString().substring(9)}',
        );

    state = [
      for (final l in state)
        if (l.id == nameOrId || l.name.toLowerCase() == nameOrId.toLowerCase())
          () {
            // Money first, percentage second.
            //
            // The old line rounded the instalment straight into a percentage:
            // `l.paid + round(payment / amount * 100)`. At TZS 1,000 on a 2.4M
            // loan that is 0.04%, which rounds to 0 — the payment was recorded
            // in the history, the balance did not move, and the till looked
            // like it had swallowed the money. The exact figure is now kept on
            // the loan and the percentage is derived from it.
            final received = (l.totalPaidAmount + paymentAmount).clamp(0, l.amount);
            final newPaidPct =
                l.amount <= 0 ? 0 : ((received * 100) / l.amount).round().clamp(0, 100);
            final isCleared = received >= l.amount;
            return l.copyWith(
              paid: newPaidPct,
              paidAmountOverride: received,
              due: isCleared ? 'Paid in Full' : 'Due next week',
              status: isCleared ? 'cleared' : (l.status == 'overdue' ? 'current' : l.status),
              isKnoxLocked: isCleared ? false : l.isKnoxLocked,
              payments: [defaultRecord, ...l.payments],
            );
          }()
        else
          l,
    ];
  }
}

final loansProvider = StateNotifierProvider<LoansNotifier, List<LoanItem>>((ref) {
  return LoansNotifier();
});

/// Reactive Activity Feed
class ActivitiesNotifier extends StateNotifier<List<ActivityItem>> {
  ActivitiesNotifier([List<ActivityItem> seed = const []]) : super(List.from(seed));

  void replaceAll(List<ActivityItem> items) {
    state = List.from(items);
  }

  void addActivity(ActivityItem activity) {
    state = [activity, ...state];
  }
}

final activitiesProvider = StateNotifierProvider<ActivitiesNotifier, List<ActivityItem>>((ref) {
  return ActivitiesNotifier();
});

/// Computed KPIs
final totalStockCountProvider = Provider<int>((ref) {
  final products = ref.watch(inventoryProvider);
  return products.fold<int>(0, (sum, p) => sum + p.stock);
});

final totalPhonesCountProvider = Provider<int>((ref) {
  final products = ref.watch(inventoryProvider);
  return products
      .where((p) => p.cat == 'phones')
      .fold<int>(0, (sum, p) => sum + p.stock);
});

final lowStockCountProvider = Provider<int>((ref) {
  final products = ref.watch(inventoryProvider);
  return products.where((p) => p.status == 'low' || p.stock <= p.min).length;
});

final activeLoansTotalProvider = Provider<int>((ref) {
  final loans = ref.watch(loansProvider);
  return loans.fold<int>(0, (sum, l) => sum + l.amount);
});

// Kept as aliases so existing screens keep compiling, but the numbers now come
// from the sales ledger. `products.soldToday` was a stored column that only moved
// when someone edits it by hand.
final todaySalesTotalProvider =
    Provider<int>((ref) => ref.watch(salesTodayTotalProvider));

final todaySalesValueProvider =
    Provider<int>((ref) => ref.watch(salesTodayValueProvider));

final todayTransactionsCountProvider =
    Provider<int>((ref) => ref.watch(salesTodayCountProvider));

/// Attendance & Shift Management
class AttendanceNotifier extends StateNotifier<List<AttendanceRecord>> {
  AttendanceNotifier() : super(List.from(MockLimsData.attendanceLogs));

  /// Records a clock-in.
  ///
  /// [instant] defaults to the wall clock and exists so a test can punch in at
  /// 22:16 UTC without waiting for it. Everything the row prints is derived
  /// from [attendance_clock] so the ledger, the roster and the PDF agree.
  void clockIn({
    required String staffId,
    required String staffName,
    required String role,
    required String branch,
    DateTime? instant,
  }) {
    final now = instant ?? DateTime.now();
    final record = AttendanceRecord(
      id: 'ATT-${now.millisecondsSinceEpoch.toString().substring(5)}',
      staffId: staffId,
      staffName: staffName,
      role: role,
      branch: branch,
      date: attendanceDateLabel(now),
      clockInTime: attendanceTimeLabel(now),
      clockOutTime: null,
      status: attendanceStatusFor(now),
      shiftHours: 0.1,
      isGeofenceVerified: true,
      verifiedBy: 'Store GPS & Pin Validated',
    );
    state = [record, ...state];
  }

  void startBreak(String recordId) {
    state = [
      for (final r in state)
        if (r.id == recordId) r.copyWith(status: 'On Break') else r,
    ];
  }

  void endBreak(String recordId) {
    state = [
      for (final r in state)
        if (r.id == recordId) r.copyWith(status: 'Present') else r,
    ];
  }

  void clockOut(String recordId, {DateTime? instant}) {
    final now = instant ?? DateTime.now();
    final timeStr = attendanceTimeLabel(now);
    state = [
      for (final r in state)
        if (r.id == recordId)
          r.copyWith(
            clockOutTime: timeStr,
            status: 'Completed',
            // Still a placeholder: the row stores clock-in as display text, so
            // hours worked cannot be derived from it. Needs a clock-in instant
            // on AttendanceRecord before this can be computed.
            shiftHours: 8.5,
          )
        else
          r,
    ];
  }
}

final attendanceProvider = StateNotifierProvider<AttendanceNotifier, List<AttendanceRecord>>((ref) {
  return AttendanceNotifier();
});

/// Total Inventory Valuation at Cost Price (TZS)
final totalInventoryCostProvider = Provider<int>((ref) {
  final products = ref.watch(inventoryProvider);
  return products.fold<int>(0, (sum, p) => sum + ((p.costPrice ?? (p.price * 0.78).round()) * p.stock));
});

/// Total Inventory Valuation at Retail / Selling Price (TZS)
final totalInventoryRetailValueProvider = Provider<int>((ref) {
  final products = ref.watch(inventoryProvider);
  return products.fold<int>(0, (sum, p) => sum + (p.price * p.stock));
});

/// Gross Profit Margin Earned Today (TZS)
/// Which period the financial report is showing.
enum ReportRange { today, week, month }

/// One period's money, from one set of rows.
class ReportTotals {
  const ReportTotals({
    required this.revenue,
    required this.cogs,
    this.uncostedSales = 0,
    required this.cash,
    required this.mobile,
    required this.card,
    required this.other,
  });

  final int revenue;
  final int cogs;
  /// Revenue less what the handsets cost. Never a percentage guess.
  int get profit => revenue - cogs;

  /// Sales with no cost price on the catalogue row, costed at 78% of what they
  /// sold for. Stated on the report rather than hidden, because a margin built
  /// on estimates should say so.
  final int uncostedSales;

  final int cash;
  final int mobile;
  final int card;
  final int other;

  /// The first day included, in the shop's timezone.
  static DateTime startOf(ReportRange range) {
    final now = eatTodayDate;
    switch (range) {
      case ReportRange.today:
        return now;
      case ReportRange.week:
        // Monday, because a Tanzanian trading week opens on Monday.
        return now.subtract(Duration(days: now.weekday - 1));
      case ReportRange.month:
        return DateTime(now.year, now.month, 1);
    }
  }
}

/// The report's numbers for [range].
///
/// The date chips used to change a string and nothing else: "Month to Date"
/// showed today's figures. They now select a real window, and every line on the
/// statement comes from the same sales rows so revenue, cost and margin cannot
/// contradict each other. The day boundary is EAT, not the device's timezone.
final reportTotalsProvider =
    Provider.family<ReportTotals, ReportRange>((ref, range) {
  final sales = ref.watch(salesProvider);
  final products = ref.watch(inventoryProvider);
  // Only products that actually carry a cost price. Filling the gap with a
  // share of the retail price charged the full unit price against a discounted
  // sale, which is how a month of takings came out with cost at 3x revenue.
  // Anything without a recorded cost is costed as 78% of what it actually sold
  // for, which is an estimate and says so on the statement.
  final costById = <int, int>{
    for (final p in products)
      if (p.costPrice != null) p.id: p.costPrice!,
  };
  var uncosted = 0;
  final from = ReportTotals.startOf(range);

  var revenue = 0, cogs = 0, cash = 0, mobile = 0, card = 0, other = 0;
  for (final s in sales) {
    if (eatDateOf(s.soldAt).isBefore(from)) continue;
    revenue += s.total;
    final unitCost = s.productId == null ? null : costById[s.productId];
    if (unitCost == null) uncosted++;
    cogs += unitCost ?? (s.total * 0.78).round();
    final c = (s.paymentChannel ?? '').toLowerCase();
    if (c.startsWith('card')) {
      card += s.total;
    } else if (c.contains('pesa') || c.contains('tigo') || c.contains('airtel')) {
      mobile += s.total;
    } else if (c == 'cash') {
      cash += s.total;
    } else {
      other += s.total;
    }
  }
  return ReportTotals(
    revenue: revenue,
    cogs: cogs,
    uncostedSales: uncosted,
    cash: cash,
    mobile: mobile,
    card: card,
    other: other,
  );
});

/// Today, for callers that only ever want the day.
ReportTotals get todayTotalsPlaceholder => const ReportTotals(
      revenue: 0,
      cogs: 0,
      cash: 0,
      mobile: 0,
      card: 0,
      other: 0,
    );

final todayPnlProvider = Provider<ReportTotals>(
    (ref) => ref.watch(reportTotalsProvider(ReportRange.today)));

final todayGrossProfitProvider = Provider<int>((ref) {
  final products = ref.watch(inventoryProvider);
  return products.fold<int>(0, (sum, p) {
    final cost = p.costPrice ?? (p.price * 0.78).round();
    final profitPerUnit = (p.price - cost);
    return sum + (profitPerUnit * p.soldToday);
  });
});

