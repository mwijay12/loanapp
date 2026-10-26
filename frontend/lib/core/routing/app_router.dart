// `Widget`/`BuildContext` are named directly by `_standalone` below. This file
// previously imported no Flutter library at all and only appeared to resolve,
// so the analyzer reported `Undefined class 'Widget'` as a hard error.
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/stock/presentation/stock_screen.dart';
import '../../features/loans/presentation/loans_screen.dart';
import '../../features/reports/presentation/reports_screen.dart';
import '../../features/account/presentation/account_screen.dart';
import '../../features/ai/presentation/ai_screen.dart';
import '../../features/scanner/presentation/scan_screen.dart';
import '../../features/sales/presentation/sell_loan_screen.dart';
import '../../features/inventory/presentation/receive_stock_screen.dart';
import '../../features/transfers/presentation/transfer_screen.dart';
import '../../features/attendance/presentation/attendance_screen.dart';
import '../../features/reports/presentation/daily_closing_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/admin/presentation/admin_dashboard_screen.dart';
import '../../features/admin/presentation/branch_performance_screen.dart';
import '../../features/loans/presentation/borrower_loan_details_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/scanner/presentation/device_imei_inspector_screen.dart';
import '../../features/petty_cash/presentation/petty_cash_screen.dart';
import '../constants/app_constants.dart';
import '../data/inventory_provider.dart';
import '../services/onboarding_prefs.dart';
import '../data/mock_lims_data.dart';
import '../widgets/app_shell.dart';
import '../widgets/back_guard.dart';

/// Where the app boots.
///
/// This used to be '/home', which dropped every visitor straight into the
/// signed-out shell: the header rendered "Signed out" with a `noSession` role
/// pill, because no session had been established yet. A showcase must open on
/// the login screen.
final initialRouteProvider = Provider<String>((ref) {
  return ref.watch(seenOnboardingProvider) ? '/login' : '/onboarding';
});

/// Routes reachable without a session.
const Set<String> _publicRoutes = <String>{'/login', '/onboarding'};

/// Exposed for tests: a guard that omits /onboarding bounces first-run visitors.
const Set<String> kPublicRoutes = _publicRoutes;

/// One screen that lives outside the shell.
///
/// Wrapped so a back gesture on it returns to the shell instead of closing the
/// app when the screen was opened as the first entry on the stack.
Widget _standalone(Widget screen, {String fallback = '/home'}) =>
    BackGuard(child: screen, fallback: fallback);

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: ref.watch(initialRouteProvider),
    // Auth guard. `UserRoles.noSession` is the fail-closed default, so anything
    // that is not a real role is treated as signed out. Enforcement in the UI is
    // cosmetic; the database is the real boundary once RLS lands.
    redirect: (context, state) {
      final role = ref.read(userRoleProvider);
      final signedIn =
          role != UserRoles.noSession && role != UserRoles.pending;
      final path = state.matchedLocation;
      final isPublic = _publicRoutes.contains(path);

      if (!signedIn && !isPublic) return '/login';
      if (signedIn && path == '/login') return '/home';
      return null;
    },
    // A stale link, a saved tab or a printed QR code can point at a route that
    // no longer exists. That used to dead-end on a "Page Not Found" screen with
    // no way back; now it simply returns to the shell.
    onException: (context, state, router) => router.go('/home'),
    routes: [
      GoRoute(
        path: '/',
        redirect: (context, state) => '/home',
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/home',
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/stock',
            builder: (context, state) => const StockScreen(),
          ),
          GoRoute(
            path: '/loans',
            builder: (context, state) => const LoansScreen(),
          ),
          GoRoute(
            path: '/reports',
            builder: (context, state) => const ReportsScreen(),
          ),
          GoRoute(
            path: '/account',
            builder: (context, state) => const AccountScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/ai',
        builder: (context, state) => _standalone(const AIScreen()),
      ),
      GoRoute(
        path: '/scan',
        builder: (context, state) => _standalone(const ScanScreen()),
      ),
      // `/scanner` was pushed from four dashboards and never existed, so every
      // tap landed on "Page Not Found". The call sites are fixed; this keep-old
      // alias stays so a stale link, a saved tab or a QR code cannot 404 again.
      GoRoute(
        path: '/scanner',
        redirect: (context, state) => '/scan',
      ),
      GoRoute(
        path: '/sell-loan',
        builder: (context, state) {
          final type = state.uri.queryParameters['type'];
          final model = state.uri.queryParameters['model'];
          final imei = state.uri.queryParameters['imei'];
          return _standalone(SellLoanScreen(
            initialTransaction: type,
            initialPhoneModel: model,
            initialImei: imei,
          ));
        },
      ),
      GoRoute(
        path: '/imei-inspector',
        builder: (context, state) {
          final imei = state.uri.queryParameters['imei'];
          return _standalone(DeviceImeiInspectorScreen(initialImei: imei));
        },
      ),
      GoRoute(
        path: '/receive',
        builder: (context, state) => _standalone(const ReceiveStockScreen()),
      ),
      GoRoute(
        path: '/transfer',
        builder: (context, state) => _standalone(const TransferScreen()),
      ),
      GoRoute(
        path: '/attendance',
        builder: (context, state) => _standalone(const AttendanceScreen()),
      ),
      GoRoute(
        path: '/petty-cash',
        builder: (context, state) => _standalone(const PettyCashScreen()),
      ),
      GoRoute(
        path: '/daily-closing',
        builder: (context, state) => _standalone(const DailyClosingScreen()),
      ),
      GoRoute(
        path: '/admin',
        builder: (context, state) => _standalone(AdminDashboardScreen(
          initialTab: state.uri.queryParameters['tab'],
        )),
      ),
      GoRoute(
        path: '/branch-performance',
        builder: (context, state) => _standalone(const BranchPerformanceScreen()),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => _standalone(const NotificationsScreen()),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => _standalone(const SettingsScreen()),
      ),
      GoRoute(
        path: '/loan-details',
        builder: (context, state) {
          final loan = state.extra as LoanItem?;
          final loanId = state.uri.queryParameters['id'] ?? (loan != null ? loan.id : '');
          return _standalone(
            BorrowerLoanDetailsScreen(loanId: loanId, initialLoan: loan),
            fallback: '/loans',
          );
        },
      ),
    ],
  );
});
