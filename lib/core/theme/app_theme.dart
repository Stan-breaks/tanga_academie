import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  // ── Border radius ──────────────────────────────
  static const double radiusXs  = 6.0;
  static const double radiusSm  = 8.0;
  static const double radiusMd  = 12.0;
  static const double radiusLg  = 16.0;
  static const double radiusXl  = 20.0;
  static const double radiusRound = 24.0;
  static const double radiusFull  = 100.0;

  // ── Spacing ────────────────────────────────────
  static const double spaceXs  = 4.0;
  static const double spaceSm  = 8.0;
  static const double spaceMd  = 12.0;
  static const double spaceLg  = 16.0;
  static const double spaceXl  = 20.0;
  static const double spaceXxl = 24.0;
  static const double space2xl = 32.0;
  static const double space3xl = 40.0;

  // ── Screen / card padding ──────────────────────
  static const EdgeInsets screenPadding =
      EdgeInsets.symmetric(horizontal: 24);
  static const EdgeInsets cardPadding  = EdgeInsets.all(20);
  static const EdgeInsets sectionPadding = EdgeInsets.all(16);

  // ── Button ─────────────────────────────────────
  static const double buttonHeight     = 52.0;
  static const double buttonHeightSm   = 44.0;
  static const double buttonBorderRadius = radiusMd; // 12

  // ── Input field ────────────────────────────────
  static const double inputBorderRadius = radiusMd; // 12
  static const EdgeInsets inputContentPadding =
      EdgeInsets.symmetric(horizontal: 16, vertical: 16);

  // ── Font ───────────────────────────────────────
  /// Body/heading family, matching the website (`--font-hind`).
  static const String fontFamily = 'Hind';

  // ── Shadows ────────────────────────────────────
  static List<BoxShadow> shadowSm = [
    BoxShadow(color: AppColors.shadowLight,  blurRadius: 8,  offset: const Offset(0, 2)),
  ];

  static List<BoxShadow> shadowMd = [
    BoxShadow(color: AppColors.shadowMedium, blurRadius: 12, offset: const Offset(0, 4)),
  ];

  static List<BoxShadow> shadowLg = [
    BoxShadow(color: AppColors.shadowDark,   blurRadius: 20, offset: const Offset(0, 8)),
  ];

  // ── Text styles ────────────────────────────────
  static const TextStyle displayStyle = TextStyle(
    fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textDark, height: 1.3,
  );
  static const TextStyle headlineStyle = TextStyle(
    fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textDark,
  );
  static const TextStyle titleStyle = TextStyle(
    fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textDark,
  );
  static const TextStyle subtitleStyle = TextStyle(
    fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textDark,
  );
  static const TextStyle bodyStyle = TextStyle(
    fontSize: 14, fontWeight: FontWeight.normal, color: AppColors.textDark,
  );
  static TextStyle bodySecondaryStyle = TextStyle(
    fontSize: 14, fontWeight: FontWeight.normal, color: AppColors.textSecondary,
  );
  static const TextStyle labelStyle = TextStyle(
    fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textDark,
  );
  static TextStyle captionStyle = TextStyle(
    fontSize: 12, color: AppColors.textSecondary,
  );
  static const TextStyle buttonTextStyle = TextStyle(
    fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0.3,
  );

  // ── Input decoration ───────────────────────────
  static BoxDecoration inputDecoration({
    Color? borderColor,
    bool hasError = false,
  }) {
    return BoxDecoration(
      color: AppColors.surfaceLight,
      borderRadius: BorderRadius.circular(inputBorderRadius),
      border: Border.all(
        color: hasError
            ? AppColors.error
            : borderColor ?? AppColors.border,
      ),
    );
  }

  // ── Card decoration ────────────────────────────
  static BoxDecoration cardDecoration({
    double borderRadius = radiusLg,
    Color? color,
    List<BoxShadow>? boxShadow,
  }) {
    return BoxDecoration(
      color: color ?? AppColors.surface,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(color: AppColors.borderLight),
      boxShadow: boxShadow ?? shadowSm,
    );
  }

  // ── Elevated card decoration ───────────────────
  static BoxDecoration elevatedCardDecoration({
    double borderRadius = radiusXl,
  }) {
    return BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(color: AppColors.borderLight),
      boxShadow: shadowMd,
    );
  }

  // ── Primary button style ───────────────────────
  static ButtonStyle primaryButtonStyle({bool fullWidth = true}) {
    return ElevatedButton.styleFrom(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      disabledBackgroundColor: AppColors.primary.withAlpha(120),
      disabledForegroundColor: Colors.white70,
      elevation: 0,
      minimumSize: fullWidth ? const Size(double.infinity, buttonHeight) : null,
      fixedSize: fullWidth ? null : const Size.fromHeight(buttonHeight),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(buttonBorderRadius),
      ),
    );
  }

  // ── Outline button style ───────────────────────
  static ButtonStyle outlineButtonStyle() {
    return OutlinedButton.styleFrom(
      foregroundColor: AppColors.primary,
      side: const BorderSide(color: AppColors.primary, width: 1.5),
      minimumSize: const Size(double.infinity, buttonHeight),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(buttonBorderRadius),
      ),
    );
  }

  // ── Gradient decoration ────────────────────────
  static BoxDecoration primaryGradientDecoration({
    double borderRadius = radiusLg,
    List<BoxShadow>? boxShadow,
  }) {
    return BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: AppColors.primaryGradient,
      ),
      borderRadius: BorderRadius.circular(borderRadius),
      boxShadow: boxShadow ?? shadowMd,
    );
  }

  // ════════════════════════════════════════════════
  //  Global ThemeData
  // ════════════════════════════════════════════════

  /// Type scale used across the app. Colors are applied by [light].
  static const TextTheme baseTextTheme = TextTheme(
    displayLarge: TextStyle(fontSize: 34, fontWeight: FontWeight.w700, height: 1.18, letterSpacing: -0.5),
    displayMedium: TextStyle(fontSize: 30, fontWeight: FontWeight.w700, height: 1.2, letterSpacing: -0.4),
    displaySmall: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, height: 1.22, letterSpacing: -0.3),
    headlineLarge: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, height: 1.25, letterSpacing: -0.2),
    headlineMedium: TextStyle(fontSize: 21, fontWeight: FontWeight.w700, height: 1.28),
    headlineSmall: TextStyle(fontSize: 19, fontWeight: FontWeight.w600, height: 1.3),
    titleLarge: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, height: 1.35),
    titleMedium: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600, height: 1.35),
    titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, height: 1.35),
    bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, height: 1.5),
    bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, height: 1.5),
    bodySmall: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w400, height: 1.45),
    labelLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0.1),
    labelMedium: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, letterSpacing: 0.1),
    labelSmall: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, letterSpacing: 0.2),
  );

  static const Color _ink = AppColors.textDark;

  static ColorScheme colorScheme() {
    return ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      primaryContainer: AppColors.primary100,
      onPrimaryContainer: AppColors.primary800,
      secondary: AppColors.secondary,
      onSecondary: Colors.white,
      secondaryContainer: AppColors.secondary50,
      onSecondaryContainer: AppColors.secondary700,
      tertiary: AppColors.accent,
      onTertiary: const Color(0xFF3D2A00),
      tertiaryContainer: AppColors.warning100,
      onTertiaryContainer: AppColors.warning800,
      error: AppColors.error,
      onError: Colors.white,
      errorContainer: AppColors.error50,
      onErrorContainer: AppColors.error700,
      surface: AppColors.surface,
      onSurface: _ink,
      onSurfaceVariant: AppColors.textSecondary,
      outline: AppColors.border,
      outlineVariant: AppColors.borderLight,
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: AppColors.surfaceLight,
      surfaceContainer: AppColors.surfaceVariant,
      surfaceContainerHigh: AppColors.surfaceVariant,
      inverseSurface: const Color(0xFF22222A),
      onInverseSurface: Colors.white,
    );
  }

  /// The app-wide [ThemeData]. Register with `MaterialApp(theme: AppTheme.light())`.
  static ThemeData light() {
    final scheme = colorScheme();
    final text = baseTextTheme.apply(
      fontFamily: fontFamily,
      bodyColor: _ink,
      displayColor: _ink,
    );

    const buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(buttonBorderRadius)),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: fontFamily,
      textTheme: text,
      primaryTextTheme: text.apply(
        displayColor: Colors.white,
        bodyColor: Colors.white,
      ),
      scaffoldBackgroundColor: AppColors.background,
      canvasColor: AppColors.background,
      dividerColor: AppColors.borderLight,

      // ── App bar ──
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: _ink,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        centerTitle: false,
        titleSpacing: 16,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: _ink,
        ),
        iconTheme: IconThemeData(color: _ink, size: 22),
        actionsIconTheme: IconThemeData(color: _ink, size: 22),
      ),

      // ── Cards ──
      cardTheme: CardThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shadowColor: AppColors.shadowMedium,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          side: const BorderSide(color: AppColors.borderLight),
        ),
      ),

      // ── Bottom navigation (M3) ──
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 3,
        shadowColor: AppColors.shadowMedium,
        height: 68,
        indicatorColor: AppColors.primary100,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
              size: 23,
              color: states.contains(WidgetState.selected)
                  ? AppColors.primary
                  : AppColors.textLight,
            )),
        labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
              fontFamily: fontFamily,
              fontSize: 12,
              fontWeight: states.contains(WidgetState.selected)
                  ? FontWeight.w600
                  : FontWeight.w500,
              color: states.contains(WidgetState.selected)
                  ? AppColors.primary
                  : AppColors.textLight,
            )),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textLight,
        selectedLabelStyle: TextStyle(fontFamily: fontFamily, fontSize: 12, fontWeight: FontWeight.w600),
        unselectedLabelStyle: TextStyle(fontFamily: fontFamily, fontSize: 12, fontWeight: FontWeight.w500),
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),

      // ── Inputs ──
      inputDecorationTheme: InputDecorationThemeData(
        // Left unfilled on purpose: most fields already sit inside a styled
        // Container, and a themed fill would paint a square background inside
        // their rounded corners. Fields that want the brand tint opt in with
        // `filled: true`, which then picks up `fillColor` below.
        fillColor: AppColors.surfaceLight,
        contentPadding: inputContentPadding,
        hintStyle: const TextStyle(
          fontFamily: fontFamily,
          color: AppColors.textHint,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        labelStyle: const TextStyle(
          fontFamily: fontFamily,
          color: AppColors.textSecondary,
          fontSize: 14,
        ),
        floatingLabelStyle: const TextStyle(
          fontFamily: fontFamily,
          color: AppColors.primary,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        errorStyle: const TextStyle(
          fontFamily: fontFamily,
          color: AppColors.error,
          fontSize: 12,
        ),
        prefixIconColor: AppColors.textLight,
        suffixIconColor: AppColors.textLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputBorderRadius),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputBorderRadius),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputBorderRadius),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputBorderRadius),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputBorderRadius),
          borderSide: const BorderSide(color: AppColors.error, width: 1.6),
        ),
      ),

      // ── Buttons ──
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.primary.withAlpha(90),
          disabledForegroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(64, buttonHeight),
          shape: buttonShape,
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.primary.withAlpha(90),
          disabledForegroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(64, buttonHeight),
          shape: buttonShape,
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.border),
          minimumSize: const Size(64, buttonHeightSm),
          shape: buttonShape,
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(radiusLg)),
        ),
      ),

      // ── Chips ──
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceVariant,
        selectedColor: AppColors.primary100,
        disabledColor: AppColors.surfaceVariant,
        labelStyle: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 12.5,
          fontWeight: FontWeight.w500,
          color: AppColors.textSecondary,
        ),
        secondaryLabelStyle: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: AppColors.primary700,
        ),
        side: const BorderSide(color: AppColors.borderLight),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),

      // ── Feedback ──
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF22222A),
        contentTextStyle: const TextStyle(
          fontFamily: fontFamily,
          color: Colors.white,
          fontSize: 13.5,
        ),
        actionTextColor: AppColors.primary200,
        behavior: SnackBarBehavior.floating,
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusXl),
        ),
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: _ink,
        ),
        contentTextStyle: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 14,
          color: AppColors.textSecondary,
          height: 1.5,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: AppColors.border,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(radiusRound),
          ),
        ),
      ),

      // ── Misc ──
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: AppColors.primary100,
        circularTrackColor: AppColors.primary50,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.borderLight,
        thickness: 1,
        space: 1,
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textLight,
        indicatorColor: AppColors.primary,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: AppColors.textSecondary,
        textColor: _ink,
        titleTextStyle: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: _ink,
        ),
        subtitleTextStyle: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 12.5,
          color: AppColors.textSecondary,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
      ),
      iconTheme: const IconThemeData(color: AppColors.textSecondary, size: 22),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? Colors.white : Colors.white),
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? AppColors.primary
                : AppColors.surfaceVariant),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? Colors.transparent
                : AppColors.border),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? AppColors.primary
                : Colors.transparent),
        checkColor: const WidgetStatePropertyAll(Colors.white),
        side: const BorderSide(color: AppColors.textHint, width: 1.6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusXs),
        ),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? AppColors.primary
                : AppColors.textHint),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: AppColors.primary,
        thumbColor: AppColors.primary,
        inactiveTrackColor: AppColors.primary100,
        overlayColor: Color(0x1F5F2DED),
      ),

      // ── Motion ──
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.fuchsia: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}
