import 'package:flutter/material.dart';
import 'package:tanga_acadamie/api_config.dart';
import 'package:tanga_acadamie/core/theme/app_colors.dart';

/// Reusable gradient avatar widget used throughout the app
class GradientAvatar extends StatelessWidget {
  final String? imageUrl;
  final String name;
  final double size;
  final List<Color>? gradientColors;
  final double borderWidth;

  const GradientAvatar({
    super.key,
    this.imageUrl,
    required this.name,
    this.size = 48,
    this.gradientColors,
    this.borderWidth = 0,
  });

  @override
  Widget build(BuildContext context) {
    final colors = gradientColors ?? AppColors.primaryGradient;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        border: borderWidth > 0
            ? Border.all(color: Colors.white, width: borderWidth)
            : null,
        boxShadow: [
          BoxShadow(
            color: colors.first.withAlpha(80),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: imageUrl != null && imageUrl!.isNotEmpty
          ? ClipOval(
              child: Image.network(
                imageUrl!.startsWith('http')
                    ? imageUrl!
                    : '${ApiConfig.baseUrl}$imageUrl',
                fit: BoxFit.cover,
                errorBuilder: (_, error, stack) => _buildInitial(initial, colors),
              ),
            )
          : _buildInitial(initial, colors),
    );
  }

  Widget _buildInitial(String initial, List<Color> colors) {
    return Center(
      child: Text(
        initial,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: size * 0.4,
        ),
      ),
    );
  }
}
