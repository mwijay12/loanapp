import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

/// LIMS design system.
///
/// Every screen consumes these tokens. Change a token here and the whole app
/// follows — that is the point of this file. Do not hardcode hex values in
/// screens; add a token instead.
///
/// Token names below `AppTheme` are load-bearing: the existing feature screens
/// reference them by name. Renaming one is a breaking change across ~20 files.
class AppTheme {
  AppTheme._();

  // ------------------------------------------------------------------ brand
  // Vibrant Blue ramp from LIMS prototype (#1B6EF3 / #0B4FCE). Clean, modern, trustworthy.
  static const Color brand50 = Color(0xFFF4F9FF);
  static const Color brand100 = Color(0xFFE9F2FF);
  static const Color brand200 = Color(0xFFCEE1FE);
  static const Color brand300 = Color(0xFFA1C6FD);
  static const Color brand400 = Color(0xFF5B9EFA);
  static const Color brand500 = Color(0xFF2E7BF5);
  static const Color brand600 = Color(0xFF1B6EF3); // Main vibrant blue
  static const Color brand700 = Color(0xFF0B4FCE); // Deep accent blue
  static const Color brand800 = Color(0xFF0A3EA3);
  static const Color brand900 = Color(0xFF082E78);

  // Secondary accents
  static const Color accent300 = Color(0xFFA5B4FC);
  static const Color accent500 = Color(0xFF7C5CFC); // Violet soft accent
  static const Color accent700 = Color(0xFF5B34EA);

  // ---------------------------------------------------------- legacy aliases
  // Kept so existing screens keep compiling seamlessly.
  static const Color primaryColor = brand600;
  static const Color primaryDark = brand700;
  static const Color primaryLight = brand100;
  static const Color secondaryColor = Color(0xFF7C5CFC);
  static const Color secondaryLight = Color(0xFFF0EBFF);
  static const Color warningColor = Color(0xFFF79009);
  static const Color warningLight = Color(0xFFFEF3E4);
  static const Color errorColor = Color(0xFFF43F5E);
  static const Color errorLight = Color(0xFFFFEDF1);
  static const Color successColor = Color(0xFF12B76A);
  static const Color successLight = Color(0xFFE7F8F0);
  static const Color infoColor = brand600;
  static const Color infoLight = brand100;

  // -------------------------------------------------------------- neutrals
  // Matching prototype palette: --bg:#F2F7FE; --card:#FFFFFF; --ink:#0D1B34; --muted:#68758C;
  static const Color ink900 = Color(0xFF0D1B34); // Deep Navy ink
  static const Color ink700 = Color(0xFF26334D);
  static const Color ink500 = Color(0xFF68758C); // Muted slate
  static const Color ink600 = Color(0xFF4A5568); // Semantic mid slate
  static const Color ink400 = Color(0xFF94A3B8);
  static const Color ink300 = Color(0xFFCBD5E1);

  static const Color canvas = Color(0xFFF2F7FE); // Prototype soft blue-grey canvas
  static const Color surfaceMuted = Color(0xFFF8FAFC);

  static const Color background = canvas;
  static const Color surface = Color(0xFFFFFFFF); // Crisp white card surface
  static const Color textPrimary = ink900;
  static const Color textSecondary = Color(0xFF68758C);
  static const Color textTertiary = Color(0xFF94A3B8);
  static const Color border = Color(0xFFE2E8F0);
  static const Color cardBorder = Color(0xFFE2E8F0);
  static const Color divider = Color(0xFFEDF2F7);
  static const Color sheetHandle = Color(0xFFD4E0F0);

  // ---------------------------------------------------------- status tokens
  static const Color available = Color(0xFF12B76A);
  static const Color availableBg = Color(0xFFE7F8F0);
  static const Color sold = Color(0xFF68758C);
  static const Color soldBg = Color(0xFFF1F5F9);
  static const Color transferred = Color(0xFF1B6EF3);
  static const Color transferredBg = Color(0xFFE9F2FF);
  static const Color damaged = Color(0xFFF43F5E);
  static const Color damagedBg = Color(0xFFFFEDF1);
  static const Color returned = Color(0xFFF79009);
  static const Color returnedBg = Color(0xFFFEF3E4);

  // ------------------------------------------------------- pastel icon beds
  static const Color pastelMint = Color(0xFFE7F8F0);
  static const Color pastelLavender = Color(0xFFF0EBFF);
  static const Color pastelBlue = Color(0xFFE9F2FF);
  static const Color pastelOrange = Color(0xFFFEF3E4);
  static const Color pastelRed = Color(0xFFFFEDF1);
  static const Color pastelCyan = Color(0xFFE0F7FA);

  static const Color iconBlue = Color(0xFF1B6EF3);
  static const Color iconGreen = Color(0xFF12B76A);
  static const Color iconOrange = Color(0xFFF79009);
  static const Color iconNavy = Color(0xFF0D1B34);
  static const Color iconRed = Color(0xFFF43F5E);
  static const Color iconCyan = Color(0xFF00ACC1);

  // -------------------------------------------------------------- gradients
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2E7BF5), Color(0xFF0B4FCE)],
    stops: [0.0, 1.0],
  );

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0B4FCE), Color(0xFF1B6EF3), Color(0xFF5B9EFA)],
    stops: [0.0, 0.55, 1.0],
  );

  static const LinearGradient successGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF12B76A), Color(0xFF34D399)],
  );

  static const LinearGradient cardSheen = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFFFFF), Color(0xFFF8FAFC)],
  );

  static const LinearGradient dangerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF43F5E), Color(0xFFFB7185)],
  );

  // ---------------------------------------------------------------- shadows
  // Soft, crisp blue/slate tinted shadows from prototype: 0 6px 24px rgba(15,52,120,.07)
  static const List<BoxShadow> shadowXs = [
    BoxShadow(color: Color(0x0A0F3478), blurRadius: 4, offset: Offset(0, 1)),
  ];

  static const List<BoxShadow> shadowSm = [
    BoxShadow(color: Color(0x0F0F3478), blurRadius: 10, offset: Offset(0, 3)),
    BoxShadow(color: Color(0x080F3478), blurRadius: 3, offset: Offset(0, 1)),
  ];

  static const List<BoxShadow> shadowMd = [
    BoxShadow(color: Color(0x120F3478), blurRadius: 20, offset: Offset(0, 6)),
    BoxShadow(color: Color(0x0A0F3478), blurRadius: 6, offset: Offset(0, 2)),
  ];

  static const List<BoxShadow> shadowLg = [
    BoxShadow(color: Color(0x1F0F3478), blurRadius: 36, offset: Offset(0, 14)),
    BoxShadow(color: Color(0x0D0F3478), blurRadius: 10, offset: Offset(0, 4)),
  ];

  static const List<BoxShadow> shadowBrand = [
    BoxShadow(color: Color(0x401B6EF3), blurRadius: 22, offset: Offset(0, 8)),
  ];

  // ------------------------------------------------------- radii & spacing
  static const double rXs = 8;
  static const double rSm = 12;
  static const double rMd = 16;
  static const double rLg = 22;
  static const double rXl = 28;

  static BorderRadius get brSm => BorderRadius.circular(rSm);
  static BorderRadius get brMd => BorderRadius.circular(rMd);
  static BorderRadius get brLg => BorderRadius.circular(rLg);
  static BorderRadius get brXl => BorderRadius.circular(rXl);

  static const double spaceXs = 4;
  static const double spaceSm = 8;
  static const double spaceMd = 16;
  static const double spaceLg = 24;
  static const double spaceXl = 32;
  static const double pagePad = 20;

  // ----------------------------------------------------------------- motion
  static const Duration fast = Duration(milliseconds: 140);
  static const Duration base = Duration(milliseconds: 240);
  static const Duration slow = Duration(milliseconds: 420);

  static const Curve easeOut = Curves.easeOutCubic;
  static const Curve easeInOut = Curves.easeInOutCubic;
  static const Curve spring = Curves.easeOutBack;

  // ------------------------------------------------------------------ theme
  static const String _fontFamily = 'Roboto';

  static ThemeData get lightTheme {
    final ColorScheme scheme =
        ColorScheme.fromSeed(
          seedColor: brand600,
          brightness: Brightness.light,
        ).copyWith(
          primary: brand600,
          onPrimary: Colors.white,
          primaryContainer: brand100,
          onPrimaryContainer: brand800,
          secondary: accent500,
          onSecondary: Colors.white,
          secondaryContainer: pastelLavender,
          onSecondaryContainer: const Color(0xFF2E1065),
          error: errorColor,
          onError: Colors.white,
          errorContainer: errorLight,
          onErrorContainer: const Color(0xFF881337),
          surface: surface,
          onSurface: ink900,
          surfaceContainerLowest: surface,
          surfaceContainerLow: surfaceMuted,
          surfaceContainer: canvas,
          surfaceContainerHigh: const Color(0xFFE2E8F0),
          surfaceContainerHighest: const Color(0xFFCBD5E1),
          onSurfaceVariant: textSecondary,
          outline: border,
          outlineVariant: divider,
          inverseSurface: ink900,
          onInverseSurface: const Color(0xFFF8FAFC),
        );

    return ThemeData(
      useMaterial3: true,
      fontFamily: _fontFamily,
      colorScheme: scheme,
      scaffoldBackgroundColor: canvas,
      splashFactory: InkSparkle.splashFactory,

      // M3 tints every surface by elevation. Control depth ourselves.
      canvasColor: canvas,
      cardColor: surface,
      dividerColor: divider,
      disabledColor: ink300,
      hintColor: textTertiary,
      shadowColor: const Color(0x140F3478),

      textTheme: _textTheme,
      primaryTextTheme: _textTheme,

      appBarTheme: const AppBarTheme(
        backgroundColor: canvas,
        surfaceTintColor: Colors.transparent,
        foregroundColor: ink900,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: ink900, size: 22),
        titleTextStyle: TextStyle(
          fontFamily: _fontFamily,
          fontSize: 19,
          fontWeight: FontWeight.w700,
          color: ink900,
          letterSpacing: -0.3,
        ),
      ),

      cardTheme: CardThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        shadowColor: const Color(0x120A1712),
        elevation: 1,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(rLg),
          side: const BorderSide(color: border),
        ),
      ),

      // Premium CTAs carry their own colour glow instead of a black drop shadow.
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: brand700,
          foregroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          disabledBackgroundColor: const Color(0xFFC7D6CF),
          disabledForegroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(rMd)),
          textStyle: const TextStyle(
            fontFamily: _fontFamily,
            fontSize: 15.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.1,
          ),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: brand700,
          foregroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(rMd)),
          textStyle: const TextStyle(
            fontFamily: _fontFamily,
            fontSize: 15.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: brand800,
          backgroundColor: surface,
          surfaceTintColor: Colors.transparent,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          side: const BorderSide(color: border, width: 1.4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(rMd)),
          textStyle: const TextStyle(
            fontFamily: _fontFamily,
            fontSize: 15.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: brand700,
          textStyle: const TextStyle(
            fontFamily: _fontFamily,
            fontSize: 14.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceMuted,
        isDense: false,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: _inputBorder(border),
        enabledBorder: _inputBorder(border),
        disabledBorder: _inputBorder(divider),
        focusedBorder: _inputBorder(brand600, width: 1.8),
        errorBorder: _inputBorder(errorColor),
        focusedErrorBorder: _inputBorder(errorColor, width: 1.8),
        labelStyle: const TextStyle(
          fontFamily: _fontFamily,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: textSecondary,
        ),
        floatingLabelStyle: const TextStyle(
          fontFamily: _fontFamily,
          fontSize: 13.5,
          fontWeight: FontWeight.w700,
          color: brand700,
        ),
        hintStyle: const TextStyle(
          fontFamily: _fontFamily,
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: textTertiary,
        ),
        errorStyle: const TextStyle(
          fontFamily: _fontFamily,
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: errorColor,
        ),
        prefixIconColor: ink400,
        suffixIconColor: ink400,
        counterStyle: const TextStyle(fontSize: 11.5, color: textTertiary),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: brand100,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(rSm),
        ),
        elevation: 0,
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontFamily: _fontFamily,
            fontSize: 11.5,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? brand700 : ink400,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 23,
            color: selected ? brand700 : ink400,
          );
        }),
      ),

      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: brand700,
        unselectedItemColor: ink400,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: TextStyle(
          fontFamily: _fontFamily,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: TextStyle(
          fontFamily: _fontFamily,
          fontSize: 11.5,
          fontWeight: FontWeight.w500,
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: surfaceMuted,
        selectedColor: brand100,
        disabledColor: divider,
        surfaceTintColor: Colors.transparent,
        side: const BorderSide(color: border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        labelStyle: const TextStyle(
          fontFamily: _fontFamily,
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: ink700,
        ),
        secondaryLabelStyle: const TextStyle(
          fontFamily: _fontFamily,
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: brand800,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        showCheckmark: false,
      ),

      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return brand100;
            return surface;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return brand800;
            return ink500;
          }),
          side: const WidgetStatePropertyAll(BorderSide(color: border)),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(
              fontFamily: _fontFamily,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(rSm)),
          ),
        ),
      ),

      listTileTheme: const ListTileThemeData(
        iconColor: ink500,
        textColor: ink900,
        titleTextStyle: TextStyle(
          fontFamily: _fontFamily,
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: ink900,
        ),
        subtitleTextStyle: TextStyle(
          fontFamily: _fontFamily,
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: textSecondary,
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        minVerticalPadding: 12,
      ),

      tabBarTheme: const TabBarThemeData(
        labelColor: brand800,
        unselectedLabelColor: ink400,
        indicatorColor: brand700,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: Colors.transparent,
        labelStyle: TextStyle(
          fontFamily: _fontFamily,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: TextStyle(
          fontFamily: _fontFamily,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(rXl)),
        titleTextStyle: const TextStyle(
          fontFamily: _fontFamily,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: ink900,
        ),
        contentTextStyle: const TextStyle(
          fontFamily: _fontFamily,
          fontSize: 14.5,
          height: 1.5,
          color: textSecondary,
        ),
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalElevation: 0,
        showDragHandle: true,
        dragHandleColor: Color(0xFFD5E0DA),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(rXl)),
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: ink900,
        contentTextStyle: const TextStyle(
          fontFamily: _fontFamily,
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Color(0xFFEAF2EE),
        ),
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        insetPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(rMd)),
        actionTextColor: accent300,
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: brand600,
        linearTrackColor: divider,
        circularTrackColor: divider,
        linearMinHeight: 6,
      ),

      dividerTheme: const DividerThemeData(
        color: divider,
        thickness: 1,
        space: 1,
      ),

      iconTheme: const IconThemeData(color: ink700, size: 22),

      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: ink900,
          borderRadius: BorderRadius.circular(rXs),
        ),
        textStyle: const TextStyle(
          fontFamily: _fontFamily,
          fontSize: 12,
          color: Colors.white,
        ),
      ),

      popupMenuTheme: PopupMenuThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 3,
        shadowColor: const Color(0x1A0A1712),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(rMd)),
        textStyle: const TextStyle(
          fontFamily: _fontFamily,
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: ink900,
        ),
      ),

      scrollbarTheme: const ScrollbarThemeData(
        thickness: WidgetStatePropertyAll(4),
        radius: Radius.circular(999),
        thumbColor: WidgetStatePropertyAll(Color(0xFFC3D2CB)),
        crossAxisMargin: 2,
      ),

      // A quiet fade with a short upward drift instead of the default zoom. Set
      // on the theme rather than per-route, so a screen added later gets the
      // same motion without remembering to ask for it. iOS keeps Cupertino: it
      // carries the edge-swipe back gesture a custom builder would remove.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: LimsPageTransitionsBuilder(),
          TargetPlatform.fuchsia: LimsPageTransitionsBuilder(),
          TargetPlatform.linux: LimsPageTransitionsBuilder(),
          TargetPlatform.windows: LimsPageTransitionsBuilder(),
          TargetPlatform.macOS: LimsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }

  static OutlineInputBorder _inputBorder(Color color, {double width = 1.2}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(rMd),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  // Typography: one scale, tight tracking on display sizes, generous leading on
  // body copy. Font-weight carries hierarchy instead of size jumps.
  static const TextTheme _textTheme = TextTheme(
    displaySmall: TextStyle(
      fontFamily: _fontFamily,
      fontSize: 34,
      height: 1.15,
      fontWeight: FontWeight.w800,
      color: ink900,
      letterSpacing: -0.9,
    ),
    headlineLarge: TextStyle(
      fontFamily: _fontFamily,
      fontSize: 27,
      height: 1.2,
      fontWeight: FontWeight.w800,
      color: ink900,
      letterSpacing: -0.6,
    ),
    headlineMedium: TextStyle(
      fontFamily: _fontFamily,
      fontSize: 23,
      height: 1.22,
      fontWeight: FontWeight.w700,
      color: ink900,
      letterSpacing: -0.45,
    ),
    headlineSmall: TextStyle(
      fontFamily: _fontFamily,
      fontSize: 20,
      height: 1.25,
      fontWeight: FontWeight.w700,
      color: ink900,
      letterSpacing: -0.3,
    ),
    titleLarge: TextStyle(
      fontFamily: _fontFamily,
      fontSize: 18,
      height: 1.3,
      fontWeight: FontWeight.w700,
      color: ink900,
      letterSpacing: -0.2,
    ),
    titleMedium: TextStyle(
      fontFamily: _fontFamily,
      fontSize: 15.5,
      height: 1.35,
      fontWeight: FontWeight.w700,
      color: ink900,
    ),
    titleSmall: TextStyle(
      fontFamily: _fontFamily,
      fontSize: 13.5,
      height: 1.35,
      fontWeight: FontWeight.w700,
      color: ink700,
    ),
    bodyLarge: TextStyle(
      fontFamily: _fontFamily,
      fontSize: 15.5,
      height: 1.5,
      fontWeight: FontWeight.w400,
      color: ink900,
    ),
    bodyMedium: TextStyle(
      fontFamily: _fontFamily,
      fontSize: 14,
      height: 1.5,
      fontWeight: FontWeight.w400,
      color: ink700,
    ),
    bodySmall: TextStyle(
      fontFamily: _fontFamily,
      fontSize: 12.5,
      height: 1.45,
      fontWeight: FontWeight.w400,
      color: textSecondary,
    ),
    labelLarge: TextStyle(
      fontFamily: _fontFamily,
      fontSize: 14,
      fontWeight: FontWeight.w700,
      color: ink900,
      letterSpacing: 0.1,
    ),
    labelMedium: TextStyle(
      fontFamily: _fontFamily,
      fontSize: 12.5,
      fontWeight: FontWeight.w700,
      color: ink500,
      letterSpacing: 0.2,
    ),
    labelSmall: TextStyle(
      fontFamily: _fontFamily,
      fontSize: 11,
      fontWeight: FontWeight.w700,
      color: ink400,
      letterSpacing: 0.6,
    ),
  );
}

/// A quiet page transition: 240 ms fade with a 3.5% upward drift.
///
/// The default Android transition slides the whole page in from the right, which
/// on a POS screen with a dark header reads as a shove. This one keeps the
/// content in place and lets it settle, so a cashier moving between the till,
/// stock and loans sees the same screen arrive rather than a new one fly in.
class LimsPageTransitionsBuilder extends PageTransitionsBuilder {
  const LimsPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.035),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}
