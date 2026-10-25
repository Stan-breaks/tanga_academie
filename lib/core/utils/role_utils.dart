import 'package:flutter/material.dart';
import 'package:tanga_acadamie/core/theme/app_colors.dart';

/// Returns the display colour associated with a user role string.
Color roleColor(String? role) {
  switch (role) {
    case 'admin':
      return AppColors.secondary;
    case 'instructor':
      return AppColors.success;
    case 'student':
      return AppColors.primary;
    default:
      return AppColors.textSecondary;
  }
}
