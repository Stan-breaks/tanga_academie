import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'shimmer.dart';

/// Network image with disk/memory caching, a shimmer placeholder and a
/// brand-coloured fallback when the image is missing or fails to load.
class AppNetworkImage extends StatelessWidget {
  const AppNetworkImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.radius = 0,
    this.memCacheWidth,
    this.placeholderIcon = Icons.school_outlined,
    this.errorWidget,
  });

  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final double radius;

  /// Decode the image at this width (in physical pixels) to save memory.
  final int? memCacheWidth;
  final IconData placeholderIcon;

  /// Overrides the default gradient fallback.
  final Widget? errorWidget;

  bool get _hasUrl => url.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final Widget image = _hasUrl
        ? CachedNetworkImage(
            imageUrl: url,
            width: width,
            height: height,
            fit: fit,
            memCacheWidth: memCacheWidth,
            fadeInDuration: const Duration(milliseconds: 220),
            fadeOutDuration: const Duration(milliseconds: 120),
            placeholder: (context, _) => _placeholder(),
            errorWidget: (context, _, _) => errorWidget ?? _fallback(),
          )
        : (errorWidget ?? _fallback());

    if (radius <= 0) return image;
    return ClipRRect(borderRadius: BorderRadius.circular(radius), child: image);
  }

  Widget _placeholder() {
    Widget inner = const ColoredBox(color: Color(0xFFEDEDF3));
    if (width != null || height != null) {
      inner = SizedBox(width: width, height: height, child: inner);
    } else {
      inner = SizedBox.expand(child: inner);
    }
    return Shimmer(child: inner);
  }

  Widget _fallback() {
    final content = DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: AppColors.primaryGradient,
        ),
      ),
      child: Center(
        child: Icon(
          placeholderIcon,
          size: 34,
          color: Colors.white.withAlpha(190),
        ),
      ),
    );

    if (width == null && height == null) return content;
    return SizedBox(width: width, height: height, child: content);
  }
}
