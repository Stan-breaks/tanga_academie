import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tanga_acadamie/core/theme/app_colors.dart';
import 'package:tanga_acadamie/core/theme/app_theme.dart';

/// Contract tests for the brand theme.
///
/// The palette is shared with the marketing site
/// (`tailwind.config.js` → primaryColor/secondaryColor/…), so these values are
/// deliberately pinned: changing one here silently breaks brand consistency
/// between the app and the website.
void main() {
  group('palette matches the website brand', () {
    test('core brand colours', () {
      expect(AppColors.primary, const Color(0xFF5F2DED));
      expect(AppColors.secondary, const Color(0xFFF2277E));
      expect(AppColors.accent, const Color(0xFFFFB31F));
      expect(AppColors.success, const Color(0xFF44CEA9));
    });

    test('neutral / text colours', () {
      expect(AppColors.textDark, const Color(0xFF222222));
      expect(AppColors.textSecondary, const Color(0xFF5F6C76));
      expect(AppColors.background, const Color(0xFFFBFBFB));
      expect(AppColors.border, const Color(0xFFE5E5E5));
    });

    test('no legacy Material blue remains in the palette', () {
      const legacy = <Color>[
        Color(0xFF2196F3),
        Color(0xFF448AFF),
        Color(0xFF1976D2),
        Color(0xFF64B5F6),
      ];
      expect(legacy.contains(AppColors.primary), isFalse);
      expect(legacy.contains(AppColors.secondary), isFalse);
    });
  });

  group('AppTheme.light()', () {
    final theme = AppTheme.light();

    test('wires the brand colours into the Material colour scheme', () {
      expect(theme.colorScheme.primary, AppColors.primary);
      expect(theme.colorScheme.secondary, AppColors.secondary);
      expect(theme.colorScheme.tertiary, AppColors.accent);
      expect(theme.colorScheme.error, AppColors.error);
      expect(theme.scaffoldBackgroundColor, AppColors.background);
    });

    test('uses the Hind typeface everywhere', () {
      expect(AppTheme.fontFamily, 'Hind');
      expect(theme.textTheme.bodyMedium?.fontFamily, 'Hind');
      expect(theme.textTheme.titleLarge?.fontFamily, 'Hind');
      expect(theme.textTheme.displayLarge?.fontFamily, 'Hind');
    });

    test('inputs are not filled by default', () {
      // Fields such as the chat composer sit inside their own rounded
      // container; a themed fill would paint a square background inside it.
      expect(theme.inputDecorationTheme.filled, isNot(true));
      expect(theme.inputDecorationTheme.fillColor, AppColors.surfaceLight);
    });

    test('the primary button style is brand coloured', () {
      final style = AppTheme.primaryButtonStyle();
      expect(
        style.backgroundColor?.resolve(<WidgetState>{}),
        AppColors.primary,
      );
      expect(style.foregroundColor?.resolve(<WidgetState>{}), Colors.white);
    });
  });
}
