import 'package:flutter/material.dart';
import 'package:tanga_acadamie/api_config.dart';
import 'package:tanga_acadamie/core/language/language_provider.dart';
import 'package:tanga_acadamie/core/theme/app_colors.dart';
import 'package:tanga_acadamie/core/theme/app_theme.dart';
import 'package:tanga_acadamie/core/widgets/app_network_image.dart';
import 'package:tanga_acadamie/core/widgets/press_scale.dart';

class CourseCard extends StatelessWidget {
  final Map<String, dynamic> course;
  final VoidCallback onTap;

  /// When provided, the banner is wrapped in a [Hero] with this tag so it can
  /// animate into the course detail page. Must be unique per screen.
  final Object? heroTag;

  const CourseCard({
    super.key,
    required this.course,
    required this.onTap,
    this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final maxHeight = constraints.maxHeight;
        final dpr = MediaQuery.maybeOf(context)?.devicePixelRatio ?? 2.0;

        // Banner is 58% of the card width when the card can size itself.
        final natural = (width * 0.58).clamp(88.0, 170.0);

        // Space the text block (title + instructor + meta row + padding) needs.
        // Measured with the bundled Hind font; kept slightly generous so the
        // leftover is absorbed by the spacer rather than overflowing.
        const textReserve = 112.0;

        // In a grid the cell height is imposed, so the banner absorbs the slack
        // and the card always fills its cell exactly.
        final bounded = maxHeight.isFinite;
        final imageHeight = bounded
            ? (maxHeight - textReserve).clamp(maxHeight * 0.3, maxHeight * 0.65)
            : natural;

        return _buildCard(context, imageHeight, (width * dpr).round(), bounded);
      },
    );
  }

  Widget _buildCard(
    BuildContext context,
    double imageHeight,
    int decodeWidth,
    bool bounded,
  ) {
    final imageUrl = ApiConfig.getImageUrl(
      course['bannerImage']?.toString() ?? '',
    );
    final bool hasValidImage =
        imageUrl.isNotEmpty && Uri.tryParse(imageUrl)?.hasAbsolutePath == true;

    final progress = (((course['progress'] ?? 0) as num) / 100).clamp(0.0, 1.0);
    final offerType = (course['offerType'] ?? 'premium').toString();
    final price = (course['price'] as num?) ?? 0;
    final discountedPrice = course['discountedPrice'] as num?;
    final rating = (course['rating'] as num?) ?? 0;
    final enrollmentCount = (course['enrollmentCount'] as num?) ?? 0;
    final category = (course['category'] ?? (isFr ? 'Cours' : 'Course'))
        .toString();
    final instructor = _instructorName(course['instructor']);

    final isFree = offerType == 'free';

    Widget banner = Stack(
      fit: StackFit.passthrough,
      children: [
        SizedBox(
          width: double.infinity,
          height: imageHeight,
          child: hasValidImage
              ? AppNetworkImage(
                  url: imageUrl,
                  width: double.infinity,
                  height: imageHeight,
                  memCacheWidth: decodeWidth,
                )
              : _placeholder(),
        ),

        // Bottom scrim so badges/category stay readable on any image.
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: imageHeight * 0.55,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black.withAlpha(140)],
              ),
            ),
          ),
        ),

        if (isFree || offerType == 'freemium')
          Positioned(
            top: 10,
            left: 10,
            child: _badge(
              isFree
                  ? (isFr ? 'GRATUIT' : 'FREE')
                  : (isFr ? 'DÉCOUVERTE' : 'PREVIEW'),
              isFree ? AppColors.success : AppColors.accent,
            ),
          ),

        Positioned(
          left: 10,
          right: 10,
          bottom: 10,
          child: Row(
            children: [
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(235),
                    borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                  ),
                  child: Text(
                    category.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: AppColors.primary700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        if (progress > 0)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              backgroundColor: Colors.white.withAlpha(90),
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.primary,
              ),
            ),
          ),
      ],
    );

    if (heroTag != null) {
      banner = Hero(tag: heroTag!, child: banner);
    }

    final Widget infoBlock = Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            (course['title'] ?? (isFr ? 'Cours sans titre' : 'Untitled Course'))
                .toString(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              height: 1.25,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 4),
          if (instructor.isNotEmpty)
            Text(
              instructor,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: AppColors.textLight),
            ),
          // Inside a grid cell the card has a fixed height: push the
          // meta row to the bottom so the card never looks bottom-heavy.
          if (bounded) const Spacer() else const SizedBox(height: 8),
          Row(
            children: [
              if (progress > 0) ...[
                const Icon(
                  Icons.play_circle_fill_rounded,
                  size: 14,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 4),
                Text(
                  '${(progress * 100).round()}%',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary700,
                  ),
                ),
              ] else if (rating > 0) ...[
                const Icon(
                  Icons.star_rounded,
                  size: 15,
                  color: AppColors.accent,
                ),
                const SizedBox(width: 3),
                Text(
                  rating.toStringAsFixed(1),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ] else ...[
                const Icon(
                  Icons.groups_rounded,
                  size: 14,
                  color: AppColors.textLight,
                ),
                const SizedBox(width: 4),
                Text(
                  '$enrollmentCount',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
              const Spacer(),
              _price(price, discountedPrice, isFr),
            ],
          ),
        ],
      ),
    );

    return PressScale(
      onTap: onTap,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(color: AppColors.borderLight),
          boxShadow: AppTheme.shadowSm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            banner,
            // When the height is imposed (grids) let the info block fill the
            // remainder so nothing is clipped; otherwise size to content.
            if (bounded) Expanded(child: infoBlock) else infoBlock,
          ],
        ),
      ),
    );
  }

  Widget _price(num price, num? discountedPrice, bool isFr) {
    if (price == 0 && discountedPrice == null) {
      return const Text(
        'Gratuit',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.success,
        ),
      );
    }

    if (discountedPrice != null && discountedPrice != price) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${discountedPrice.toStringAsFixed(0)}\$',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.primary700,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '${price.toStringAsFixed(0)}\$',
            style: const TextStyle(
              fontSize: 10,
              decoration: TextDecoration.lineThrough,
              color: AppColors.textHint,
            ),
          ),
        ],
      );
    }

    return Text(
      '${price.toStringAsFixed(0)}\$',
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppColors.primary700,
      ),
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(40),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  Widget _placeholder() {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: AppColors.primaryGradient,
        ),
      ),
      child: Center(
        child: Icon(Icons.school_outlined, size: 32, color: Colors.white70),
      ),
    );
  }

  String _instructorName(dynamic instructor) {
    if (instructor is! Map) return '';
    final first = instructor['firstName']?.toString() ?? '';
    final last = instructor['lastName']?.toString() ?? '';
    final name = '$first $last'.trim();
    return name;
  }
}
