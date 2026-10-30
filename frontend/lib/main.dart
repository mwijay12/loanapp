import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/app_localizations.dart';
import 'core/routing/app_router.dart';
import 'core/services/onboarding_prefs.dart';
import 'core/services/app_permissions_service.dart';
import 'core/widgets/responsive.dart';
import 'core/l10n/locale_provider.dart';

import 'core/services/api_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // A build with a project behind it always initialises Supabase — the demo flag
  // included. The demo accounts are real auth users and every row lives in the
  // database, so skipping this block left auth.uid() null and every policy denied
  // the reads: a full shop that rendered empty.
  //
  // With no project configured the app stays offline: sign-in falls back to the
  // bundled demo accounts and the screens show what they can.
  if (SupabaseConfig.isConfigured) {
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
                  'Configuration problem:\n$e',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ),
      );
      return;
    }
  }

  // Read once, before the router exists: a first run opens the introduction, a
  // later run opens sign-in.
  final seenOnboarding = await OnboardingPrefs.hasSeen();
  final savedLocale = await LocaleStore.load();
  runApp(
    ProviderScope(
      overrides: [
        seenOnboardingProvider.overrideWithValue(seenOnboarding),
        localeProvider.overrideWith((ref) => savedLocale),
      ],
      child: const LoanInventoryApp(),
    ),
  );
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

        // The app fills the window. It used to be boxed into a 430px "phone
        // mockup" centred on a lavender backdrop whenever the window was wider
        // than 520px, which is why a 1920px screen showed a phone column with
        // ~758px of empty background either side. A desktop is not a phone with
        // more paper around it; the width belongs to the content.
        //
        // Width is now a layout decision inside AppShell (sidebar above 900px,
        // dock below it, content clamped by LimsBreakpoints.maxContentWidth),
        // so this builder only owns text scaling.
        return content;
      },
    );
  }
}
