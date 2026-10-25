import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'press_scale.dart';

/// Standard surface used for cards across the app.
///
/// Gives every card the same radius, hairline border and soft shadow, and adds
/// a press-down micro-interaction when [onTap] is provided.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.onLongPress,
    this.radius = AppTheme.radiusLg,
    this.color = Colors.white,
    this.showBorder = true,
    this.shadows,
    this.width,
    this.height,
    this.clipBehavior = Clip.antiAlias,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double radius;
  final Color color;
  final bool showBorder;
  final List<BoxShadow>? shadows;
  final double? width;
  final double? height;
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      width: width,
      height: height,
      margin: margin,
      padding: padding,
      clipBehavior: clipBehavior,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: showBorder ? Border.all(color: AppColors.borderLight) : null,
        boxShadow: shadows ?? AppTheme.shadowSm,
      ),
      child: child,
    );

    if (onTap == null && onLongPress == null) return card;

    return PressScale(onTap: onTap, onLongPress: onLongPress, child: card);
  }
}
