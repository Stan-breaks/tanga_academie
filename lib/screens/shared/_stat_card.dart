import 'package:flutter/material.dart';
import 'package:tanga_acadamie/core/theme/app_colors.dart';
import 'package:tanga_acadamie/core/theme/app_theme.dart';

/// A gradient stat card for displaying statistics.
///
/// Defaults to the brand violet gradient; pass [gradientColors] for other
/// brand tones (see [AppColors.secondaryGradient] etc.).
class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData? icon;
  final List<Color>? gradientColors;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    this.icon,
    this.gradientColors,
  });

  /// Foreground that stays readable on [colors].
  ///
  /// Amber / mint / yellow gradients are too light for white text and the
  /// violet / pink ones are too dark for ink, so the decision is driven by the
  /// lightest stop of the gradient.
  static Color onColorFor(List<Color> colors) {
    final lightest = colors
        .map((c) => c.computeLuminance())
        .reduce((a, b) => a > b ? a : b);
    return lightest > 0.45 ? AppColors.textDark : Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    final colors = gradientColors ?? AppColors.primaryGradient;
    final onColor = onColorFor(colors);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        boxShadow: [
          BoxShadow(
            color: colors.last.withAlpha(70),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Soft decorative circles for depth.
          Positioned(
            right: -26,
            bottom: -34,
            child: _bubble(112, 18, onColor),
          ),
          Positioned(
            right: 30,
            top: -30,
            child: _bubble(62, 12, onColor),
          ),
          Padding(
            padding: const EdgeInsets.all(AppTheme.spaceLg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.max,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: onColor.withAlpha(225),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          height: 1.2,
                        ),
                      ),
                    ),
                    if (icon != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: onColor.withAlpha(46),
                          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                        ),
                        child: Icon(icon, color: onColor, size: 17),
                      ),
                    ],
                  ],
                ),
                const Spacer(),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: onColor,
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                    height: 1.05,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bubble(double size, int alpha, Color onColor) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: onColor.withAlpha(alpha),
        shape: BoxShape.circle,
      ),
    );
  }
}
