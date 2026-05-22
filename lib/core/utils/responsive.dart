import 'package:flutter/material.dart';

class Responsive {
  Responsive._();

  static const double _tabletBreakpoint = 600;
  static const double _largeTabletBreakpoint = 900;

  static double width(BuildContext context) =>
      MediaQuery.sizeOf(context).width;

  static double height(BuildContext context) =>
      MediaQuery.sizeOf(context).height;

  static bool isTablet(BuildContext context) =>
      width(context) >= _tabletBreakpoint;

  static bool isLargeTablet(BuildContext context) =>
      width(context) >= _largeTabletBreakpoint;

  /// 2 on phone, 3 on tablet, 4 on large tablet
  static int gridColumns(BuildContext context) {
    final w = width(context);
    if (w >= _largeTabletBreakpoint) return 4;
    if (w >= _tabletBreakpoint) return 3;
    return 2;
  }

  /// Returns scaled value — slightly larger on tablet/desktop
  static double scale(BuildContext context, double value) {
    final w = width(context);
    if (w >= _largeTabletBreakpoint) return value * 1.25;
    if (w >= _tabletBreakpoint) return value * 1.1;
    return value;
  }

  /// Horizontal padding — more breathing room on wide screens
  static double horizontalPadding(BuildContext context) =>
      isTablet(context) ? 32.0 : 16.0;

  /// Max content width for centred layouts (login, forms)
  static double maxContentWidth(BuildContext context) =>
      isTablet(context) ? 520.0 : double.infinity;

  /// Pick a value based on device class
  static T adaptive<T>(
    BuildContext context, {
    required T mobile,
    required T tablet,
    T? largeTablet,
  }) {
    if (isLargeTablet(context)) return largeTablet ?? tablet;
    if (isTablet(context)) return tablet;
    return mobile;
  }
}
