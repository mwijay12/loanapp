import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/app_localizations.dart';
import 'core/routing/app_router.dart';
import 'core/services/onboarding_prefs.dart';
import 'core/services/app_permissions_service.dart';
import 'core/widgets/responsive.dart';
import 'features/account/presentation/account_screen.dart';

import 'core/constants/app_constants.dart';
import 'core/services/api_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Demo builds run entirely on bundled mock data: no Supabase, no secrets,
  // and therefore nothing to leak if the link is shared publicly.
  if (AppConstants.demoMode) {
    // Read once, before the router exists: a first run opens the introduction, a
  // later run opens sign-in.
  final seenOnboarding = await OnboardingPrefs.hasSeen();
  runApp(
    ProviderScope(
      overrides: [seenOnboardingProvider.overrideWithValue(seenOnboarding)],
      child: const LoanInventoryApp(),
    ),
  );
    return;
  }

  // P0: init() throws when --dart-define config is missing. Fail loud with a
  // readable screen instead of running misconfigured or red-screening.
  try {
    await ApiService().init();
  } catch (e) {
    runApp(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Configuration missing:\n$e',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
    return;
  }

  runApp(const ProviderScope(child: LoanInventoryApp()));
}

class LoanInventoryApp extends ConsumerStatefulWidget {
  const LoanInventoryApp({super.key});

  @override
  ConsumerState<LoanInventoryApp> createState() => _LoanInventoryAppState();
}

class _LoanInventoryAppState extends ConsumerState<LoanInventoryApp> {
  @override
  void initState() {
    super.initState();
    // Ruhusa za Android (kamera, GPS, notifications, simu/SMS, files)
    // zinaombwa MAPEEMA — mara tu app inapofunguka — ili mtumiaji
    // asiulizwe katikati ya scan, clock-in au kuuza.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      AppPermissionsService.requestEarlyPermissions(
        context,
        showRationale: false,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final locale = ref.watch(localeProvider);

    return MaterialApp.router(
      title: 'Loan & Inventory',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      locale: locale,
      supportedLocales: const [
        Locale('en'),
        Locale('sw'),
      ],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
      // Hakuna overscroll glow/bounce popote — scroll inasimama imara.
      scrollBehavior: const NoGlowScrollBehavior(),
      builder: (context, child) {
        // Bana text-scale (0.85–1.15) ili font kubwa za system
        // zisivunje layout / zisilete overflow kwenye simu ndogo.
        final mq = MediaQuery.of(context);
        final clamped = mq.textScaler.clamp(
          minScaleFactor: 0.85,
          maxScaleFactor: 1.15,
        );
        final content = MediaQuery(
          data: mq.copyWith(textScaler: clamped),
          child: child ?? const SizedBox.shrink(),
        );

        return LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth > 520) {
              return Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFE9F1FD), Color(0xFFDCE8FA)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                alignment: Alignment.center,
                child: Container(
                  width: 430,
                  height: constraints.maxHeight,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0D1B34).withValues(alpha: 0.16),
                        blurRadius: 40,
                        offset: const Offset(0, 16),
                      ),
                      BoxShadow(
                        color: const Color(0xFF1B6EF3).withValues(alpha: 0.08),
                        blurRadius: 18,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: content,
                ),
              );
            }
            return content;
          },
        );
      },
    );
  }
}
