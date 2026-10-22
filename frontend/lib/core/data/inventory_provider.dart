import 'package:flutter/material.dart' show Color;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_constants.dart';
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

  void updateStock(int id, int delta) {
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

  void toggleFavorite(int id) {
    state = [
      for (final p in state)
        if (p.id == id) p.copyWith(fav: !p.fav) else p,
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
            final newPaidPct = (l.paid + ((paymentAmount / l.amount) * 100).round()).clamp(0, 100);
            final isCleared = newPaidPct >= 100;
            return l.copyWith(
              paid: newPaidPct,
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
// when someone edited it by hand.
final todaySalesTotalProvider =
    Provider<int>((ref) => ref.watch(salesTodayTotalProvider));

final todayTransactionsCountProvider =
    Provider<int>((ref) => ref.watch(salesTodayCountProvider));

/// Attendance & Shift Management
class AttendanceNotifier extends StateNotifier<List<AttendanceRecord>> {
  AttendanceNotifier() : super(List.from(MockLimsData.attendanceLogs));

  void clockIn({
    required String staffId,
    required String staffName,
    required String role,
    required String branch,
    String? customTime,
  }) {
    final now = DateTime.now();
    final timeStr = customTime ??
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} ${now.hour >= 12 ? 'PM' : 'AM'}';
    final isLate = now.hour > 8 || (now.hour == 8 && now.minute > 15);
    final record = AttendanceRecord(
      id: 'ATT-${now.millisecondsSinceEpoch.toString().substring(5)}',
      staffId: staffId,
      staffName: staffName,
      role: role,
      branch: branch,
      date: 'Today, ${now.day} Oct ${now.year}',
      clockInTime: timeStr,
      clockOutTime: null,
      status: isLate ? 'Late (${now.minute}m)' : 'Present',
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

  void clockOut(String recordId) {
    final now = DateTime.now();
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} ${now.hour >= 12 ? 'PM' : 'AM'}';
    state = [
      for (final r in state)
        if (r.id == recordId)
          r.copyWith(
            clockOutTime: timeStr,
            status: 'Completed',
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
final todayGrossProfitProvider = Provider<int>((ref) {
  final products = ref.watch(inventoryProvider);
  return products.fold<int>(0, (sum, p) {
    final cost = p.costPrice ?? (p.price * 0.78).round();
    final profitPerUnit = (p.price - cost);
    return sum + (profitPerUnit * p.soldToday);
  });
});

