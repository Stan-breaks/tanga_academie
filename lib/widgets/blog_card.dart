import 'package:flutter/material.dart';
import 'package:tanga_acadamie/api_config.dart';
import 'package:tanga_acadamie/models/blog.dart';
import 'package:tanga_acadamie/core/language/language_provider.dart';
import 'package:tanga_acadamie/core/theme/app_colors.dart';
import 'package:tanga_acadamie/core/theme/app_theme.dart';
import 'package:tanga_acadamie/core/widgets/app_network_image.dart';
import 'package:tanga_acadamie/core/widgets/press_scale.dart';

/// A compact blog card for the horizontal scroll section on the explore page.
class BlogCard extends StatelessWidget {
  final Blog blog;
  final VoidCallback onTap;

  const BlogCard({super.key, required this.blog, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final imageUrl = ApiConfig.getImageUrl(blog.featuredImage);
    final hasImage = imageUrl.isNotEmpty;
    final date = _formatDate(blog.createdAt);

    final screenWidth = MediaQuery.sizeOf(context).width;
    final cardWidth = (screenWidth * 0.62).clamp(200.0, 320.0);

    return PressScale(
      onTap: onTap,
      child: Container(
        width: cardWidth,
        margin: const EdgeInsets.only(right: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(color: AppColors.borderLight),
          boxShadow: AppTheme.shadowSm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover image
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppTheme.radiusLg)),
              child: Stack(
                children: [
                  hasImage
                      ? AppNetworkImage(
                          url: imageUrl,
                          width: double.infinity,
                          height: 120,
                          fit: BoxFit.cover,
                          errorWidget: _buildImagePlaceholder(),
                        )
                      : _buildImagePlaceholder(),
                  // Category badge
                  if (blog.category.isNotEmpty)
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary700,
                          borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                        ),
                        child: Text(
                          blog.category,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  // Gradient overlay
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withAlpha(90),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      blog.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        height: 1.3,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Excerpt
                    if (blog.excerpt.isNotEmpty)
                      Expanded(
                        child: Text(
                          blog.excerpt,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                            height: 1.4,
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    // Author & date row
                    Row(
                      children: [
                        Icon(Icons.person_outline,
                            size: 14, color: AppColors.textLight),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            blog.author?.fullName ??
                                (isFr ? 'Anonyme' : 'Anonymous'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.calendar_today_outlined,
                            size: 12, color: AppColors.textLight),
                        const SizedBox(width: 3),
                        Text(
                          date,
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.textLight,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      width: double.infinity,
      height: 120,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary100,
            AppColors.primary400,
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.article_outlined,
          size: 40,
          color: Colors.white.withAlpha(180),
        ),
      ),
    );
  }

  String _formatDate(String isoDate) {
    if (isoDate.isEmpty) return '';
    try {
      final dt = DateTime.parse(isoDate);
      final months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
    } catch (_) {
      return '';
    }
  }
}
