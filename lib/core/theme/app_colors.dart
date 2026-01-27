import 'package:flutter/material.dart';

/// App-wide color constants for consistent theming
class AppColors {
  AppColors._();

  // Primary colors
  static const Color primary = Colors.blueAccent;
  static const Color primaryLight = Color(0xFF82B1FF);
  static const Color primaryDark = Color(0xFF304FFE);
  static const Color accent = Color(0xFF448AFF);

  // Status colors
  static const Color success = Color(0xFF4CAF50);
  static const Color error = Color(0xFFE53935);
  static const Color warning = Color(0xFFFFA726);
  static const Color info = Colors.blue;

  // Text colors
  static const Color textDark = Color(0xFF37474F);
  static const Color textLight = Color(0xFF78909C);
  static Color textPrimary = Colors.grey.shade900;
  static Color textSecondary = Colors.grey.shade600;
  static Color textHint = Colors.grey.shade400;

  // Surface colors
  static const Color cardBg = Colors.white;
  static const Color surface = Colors.white;
  static const Color surfaceLight = Color(0xFFF5F7FA);
  static Color surfaceVariant = Colors.grey.shade100;
  static Color background = Colors.grey.shade50;

  // Gradients
  static List<Color> primaryGradient = [
    primaryLight,
    primary,
  ];

  static List<Color> successGradient = [
    Colors.green.shade400,
    Colors.green.shade700,
  ];

  static List<Color> warningGradient = [
    Colors.orange.shade400,
    Colors.orange.shade700,
  ];

  static List<Color> purpleGradient = [
    Colors.purple.shade400,
    Colors.purple.shade700,
  ];

  static List<Color> infoGradient = [
    Colors.blue.shade400,
    Colors.blue.shade700,
  ];

  // Shadow colors
  static Color shadowLight = Colors.black.withAlpha(8);
  static Color shadowMedium = Colors.black.withAlpha(15);
  static Color shadowDark = Colors.black.withAlpha(30);
}
