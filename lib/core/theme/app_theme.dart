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
            : borderColor ?? Colors.grey.shade200,
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
      boxShadow: shadowMd,
    );
  }

  // ── Primary button style ───────────────────────
  static ButtonStyle primaryButtonStyle({bool fullWidth = true}) {
    return ElevatedButton.styleFrom(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      disabledBackgroundColor: AppColors.primary.withAlpha(150),
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
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: AppColors.primaryGradient,
      ),
      borderRadius: BorderRadius.circular(borderRadius),
      boxShadow: boxShadow ?? shadowMd,
    );
  }
}
