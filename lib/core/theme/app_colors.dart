import 'package:flutter/material.dart';

/// App-wide color constants for consistent theming.
///
/// These mirror the marketing website's Tailwind palette so the app and the
/// site look like one product:
///   primary   #5F2DED  (web `primaryColor`)
///   secondary #F2277E  (web `secondaryColor`)
///   accent    #FFB31F  (web amber accent)
///   ink/body  #222222 / #5F6C76
///   background #FBFBFB (web `bodyBg`)
class AppColors {
  AppColors._();

  // ── Brand ──────────────────────────────────────
  static const Color primary = Color(0xFF5F2DED);
  static const Color primaryLight = Color(0xFF8F6DF2);
  static const Color primaryDark = Color(0xFF401BA3);

  /// Pink brand accent — use sparingly (badges, highlights, gradients).
  static const Color secondary = Color(0xFFF2277E);
  static const Color secondaryLight = Color(0xFFF87BB1);
  static const Color secondaryDark = Color(0xFFA91453);

  /// Amber accent (web `#FFB31F`).
  static const Color accent = Color(0xFFFFB31F);
  static const Color accentDark = Color(0xFFF09E00);

  // ── Primary ramp ───────────────────────────────
  static const Color primary50 = Color(0xFFF3F0FE);
  static const Color primary100 = Color(0xFFE7E0FD);
  static const Color primary200 = Color(0xFFCFC2FB);
  static const Color primary300 = Color(0xFFB49EF8);
  static const Color primary400 = Color(0xFF8F6DF2);
  static const Color primary500 = Color(0xFF5F2DED);
  static const Color primary600 = Color(0xFF4F22C9);
  static const Color primary700 = Color(0xFF401BA3);
  static const Color primary800 = Color(0xFF33157F);
  static const Color primary900 = Color(0xFF280F5E);

  // ── Secondary (pink) ramp ──────────────────────
  static const Color secondary50 = Color(0xFFFEEDF4);
  static const Color secondary100 = Color(0xFFFDD5E6);
  static const Color secondary200 = Color(0xFFFBAACD);
  static const Color secondary300 = Color(0xFFF87BB1);
  static const Color secondary400 = Color(0xFFF54D95);
  static const Color secondary500 = Color(0xFFF2277E);
  static const Color secondary600 = Color(0xFFD31A68);
  static const Color secondary700 = Color(0xFFA91453);
  static const Color secondary800 = Color(0xFF7F0F3E);
  static const Color secondary900 = Color(0xFF560A2A);

  // ── Status ─────────────────────────────────────
  static const Color success = Color(0xFF44CEA9);
  static const Color success50 = Color(0xFFEAFBF5);
  static const Color success100 = Color(0xFFD0F5E9);
  static const Color success200 = Color(0xFFA3EBD4);
  static const Color success300 = Color(0xFF6FDCBB);
  static const Color success400 = Color(0xFF44CEA9);
  static const Color success500 = Color(0xFF2FB894);
  static const Color success600 = Color(0xFF239378);
  static const Color success700 = Color(0xFF1B745F);
  static const Color success800 = Color(0xFF145648);
  static const Color success900 = Color(0xFF0E3C33);

  static const Color error = Color(0xFFFF2828);
  static const Color error50 = Color(0xFFFFEDED);
  static const Color error100 = Color(0xFFFFD6D6);
  static const Color error200 = Color(0xFFFFADAD);
  static const Color error300 = Color(0xFFFF8080);
  static const Color error400 = Color(0xFFFF5252);
  static const Color error500 = Color(0xFFFF2828);
  static const Color error600 = Color(0xFFE01B1B);
  static const Color error700 = Color(0xFFB31414);
  static const Color error800 = Color(0xFF850E0E);
  static const Color error900 = Color(0xFF590808);

  static const Color warning = Color(0xFFFFB31F);
  static const Color warning50 = Color(0xFFFFF8E8);
  static const Color warning100 = Color(0xFFFFEFC9);
  static const Color warning200 = Color(0xFFFFDF94);
  static const Color warning300 = Color(0xFFFFCB5E);
  static const Color warning400 = Color(0xFFFFB31F);
  static const Color warning500 = Color(0xFFF09E00);
  static const Color warning600 = Color(0xFFC68100);
  static const Color warning700 = Color(0xFF9B6400);
  static const Color warning800 = Color(0xFF704800);
  static const Color warning900 = Color(0xFF472D00);

  static const Color info = Color(0xFF465FE9);

  // ── Text ───────────────────────────────────────
  /// Headings / strong text.
  static const Color textDark = Color(0xFF222222);
  static const Color textPrimary = Color(0xFF191B1E);
  static const Color textSecondary = Color(0xFF5F6C76);
  static const Color textLight = Color(0xFF7B8696);
  static const Color textHint = Color(0xFFA2A9B6);

  // ── Surfaces ───────────────────────────────────
  static const Color cardBg = Colors.white;
  static const Color surface = Colors.white;
  static const Color surfaceLight = Color(0xFFF7F8FD);
  static const Color surfaceVariant = Color(0xFFF0F1F3);
  static const Color background = Color(0xFFFBFBFB);

  // ── Borders ────────────────────────────────────
  static const Color border = Color(0xFFE5E5E5);
  static const Color borderLight = Color(0xFFEEEEEE);

  // ── Gradients ──────────────────────────────────
  static const List<Color> primaryGradient = [
    Color(0xFF7B4DF6),
    Color(0xFF4F22C9),
  ];

  /// Violet → pink. Use for hero surfaces only.
  static const List<Color> brandGradient = [
    Color(0xFF5F2DED),
    Color(0xFFF2277E),
  ];

  static const List<Color> secondaryGradient = [
    Color(0xFFF2277E),
    Color(0xFFC4165F),
  ];

  static const List<Color> accentGradient = [
    Color(0xFFFFC44D),
    Color(0xFFF09E00),
  ];

  static const List<Color> successGradient = [
    Color(0xFF6FDCBB),
    Color(0xFF239378),
  ];

  static const List<Color> warningGradient = [
    Color(0xFFFFCB5E),
    Color(0xFFC68100),
  ];

  static const List<Color> infoGradient = [
    Color(0xFF6E82EE),
    Color(0xFF2A40B8),
  ];

  /// Kept for backwards compatibility; prefer [secondaryGradient].
  static const List<Color> purpleGradient = [
    Color(0xFF8F6DF2),
    Color(0xFF401BA3),
  ];

  // ── Shadows ────────────────────────────────────
  static Color shadowLight = const Color(0xFF5F2DED).withAlpha(10);
  static Color shadowMedium = const Color(0xFF5F2DED).withAlpha(18);
  static Color shadowDark = const Color(0xFF2B1B5E).withAlpha(30);
}
