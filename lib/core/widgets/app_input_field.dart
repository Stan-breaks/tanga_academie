import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/app_colors.dart';

/// Standard input field used across the entire app.
class AppInputField extends StatelessWidget {
  const AppInputField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.obscureText = false,
    this.suffixIcon,
    this.enabled = true,
    this.maxLines = 1,
    this.hint,
    this.hasError = false,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffixIcon;
  final bool enabled;
  final int maxLines;
  final String? hint;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.inputDecoration(hasError: hasError),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        enabled: enabled,
        maxLines: maxLines,
        style: AppTheme.bodyStyle.copyWith(fontSize: 15),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: AppTheme.captionStyle.copyWith(fontSize: 14),
          hintStyle: AppTheme.captionStyle,
          prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          contentPadding: AppTheme.inputContentPadding,
          floatingLabelBehavior: FloatingLabelBehavior.auto,
        ),
      ),
    );
  }
}
