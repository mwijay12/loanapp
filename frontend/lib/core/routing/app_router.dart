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
import '../constants/app_constants.dart';
import '../data/inventory_provider.dart';
import '../data/mock_lims_data.dart';
import '../widgets/app_shell.dart';

/// Where the app boots.
///
/// This used to be '/home', which dropped every visitor straight into the
/// signed-out shell: the header rendered "Signed out" with a `noSession` role
/// pill, because no session had been established yet. A showcase must open on
/// the login screen.
final initialRouteProvider = Provider<String>((ref) => '/login');

/// Routes reachable without a session.
const Set<String> _publicRoutes = <String>{'/login', '/onboarding'};

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
        builder: (context, state) => const AIScreen(),
      ),
      GoRoute(
        path: '/scan',
        builder: (context, state) => const ScanScreen(),
      ),
      GoRoute(
        path: '/sell-loan',
        builder: (context, state) {
          final type = state.uri.queryParameters['type'];
          final model = state.uri.queryParameters['model'];
          final imei = state.uri.queryParameters['imei'];
          return SellLoanScreen(
            initialTransaction: type,
            initialPhoneModel: model,
            initialImei: imei,
          );
        },
      ),
      GoRoute(
        path: '/imei-inspector',
        builder: (context, state) {
          final imei = state.uri.queryParameters['imei'];
          return DeviceImeiInspectorScreen(initialImei: imei);
        },
      ),
      GoRoute(
        path: '/receive',
        builder: (context, state) => const ReceiveStockScreen(),
      ),
      GoRoute(
        path: '/transfer',
        builder: (context, state) => const TransferScreen(),
      ),
      GoRoute(
        path: '/attendance',
        builder: (context, state) => const AttendanceScreen(),
      ),
      GoRoute(
        path: '/daily-closing',
        builder: (context, state) => const DailyClosingScreen(),
      ),
      GoRoute(
        path: '/admin',
        builder: (context, state) => AdminDashboardScreen(
          initialTab: state.uri.queryParameters['tab'],
        ),
      ),
      GoRoute(
        path: '/branch-performance',
        builder: (context, state) => const BranchPerformanceScreen(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/loan-details',
        builder: (context, state) {
          final loan = state.extra as LoanItem?;
          final loanId = state.uri.queryParameters['id'] ?? (loan != null ? loan.id : '');
          return BorrowerLoanDetailsScreen(loanId: loanId, initialLoan: loan);
        },
      ),
    ],
  );
});
