import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/routing/app_router.dart';
import 'core/theme/app_localizations.dart';
import 'core/theme/app_theme.dart';

/// Dev-only entrypoint: renders the real router with the real theme, but boots
/// straight into the app instead of the login screen.
///
/// Run the whole app without credentials:
///   flutter run -d chrome -t lib/dev_preview.dart
///
/// Switch screens by editing [previewRoute] — the shell and its navigation bar
/// are the production widgets, so what you see here is what ships.
const String previewRoute = '/home';

void main() {
  runApp(
    ProviderScope(
      overrides: [initialRouteProvider.overrideWithValue(previewRoute)],
      child: const _DevPreviewApp(),
    ),
  );
}

class _DevPreviewApp extends ConsumerWidget {
  const _DevPreviewApp();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'LIMS Design Preview',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      locale: const Locale('en'),
      supportedLocales: const [Locale('en'), Locale('sw')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
    );
  }
}