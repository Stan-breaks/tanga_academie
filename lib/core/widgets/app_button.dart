import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Standard primary button.
class AppPrimaryButton extends StatelessWidget {
  const AppPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppTheme.buttonHeight,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: AppTheme.primaryButtonStyle(),
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 20),
                    const SizedBox(width: 8),
                  ],
                  Text(label, style: AppTheme.buttonTextStyle),
                ],
              ),
      ),
    );
  }
}

/// Standard outline (secondary) button.
class AppOutlineButton extends StatelessWidget {
  const AppOutlineButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppTheme.buttonHeight,
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: AppTheme.outlineButtonStyle(),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20),
              const SizedBox(width: 8),
            ],
            Text(label, style: AppTheme.buttonTextStyle),
          ],
        ),
      ),
    );
  }
}
