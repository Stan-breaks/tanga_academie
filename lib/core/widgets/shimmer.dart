import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Animates a shimmering highlight across its [child].
///
/// Wrap a tree of [ShimmerBox]es to build skeleton loaders:
///
/// ```dart
/// Shimmer(child: Column(children: [ShimmerBox(height: 16)]))
/// ```
class Shimmer extends StatefulWidget {
  const Shimmer({
    super.key,
    required this.child,
    this.baseColor = const Color(0xFFEDEDF3),
    this.highlightColor = const Color(0xFFF9FAFF),
  });

  final Widget child;
  final Color baseColor;
  final Color highlightColor;

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value * 2 - 1;
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment(t * 2 - 1, -0.4),
            end: Alignment(t * 2 + 1, 0.4),
            colors: [widget.baseColor, widget.highlightColor, widget.baseColor],
            stops: const [0.3, 0.5, 0.7],
          ).createShader(bounds),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// A single rounded block used inside a [Shimmer] skeleton.
class ShimmerBox extends StatelessWidget {
  const ShimmerBox({
    super.key,
    this.width,
    this.height = 14,
    this.radius = 8,
    this.shape = BoxShape.rectangle,
    this.color = const Color(0xFFEDEDF3),
  });

  final double? width;
  final double height;
  final double radius;
  final BoxShape shape;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        shape: shape,
        borderRadius: shape == BoxShape.circle
            ? null
            : BorderRadius.circular(radius),
      ),
    );
  }
}

/// Skeleton matching the shape of `CourseCard`'s image + text block.
///
/// The banner height mirrors [CourseCard] (58% of the card width, clamped), so
/// the skeleton lines up with the real cards in any grid. The text block is
/// wrapped in [Expanded] with small fixed blocks so it never overflows the
/// (grid-imposed) cell height.
class CourseCardSkeleton extends StatelessWidget {
  const CourseCardSkeleton({super.key, this.imageHeight = 120});

  final double imageHeight;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final banner = width.isFinite
            ? (width * 0.58).clamp(88.0, 170.0)
            : imageHeight;

        return Shimmer(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderLight),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerBox(width: double.infinity, height: banner, radius: 0),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        ShimmerBox(width: 52, height: 9, radius: 4),
                        ShimmerBox(width: double.infinity, height: 12),
                        ShimmerBox(width: 104, height: 12),
                        ShimmerBox(width: 72, height: 10),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Row of skeleton course cards, for grid placeholders.
class CourseGridSkeleton extends StatelessWidget {
  const CourseGridSkeleton({super.key, this.count = 4, this.columns = 2});

  final int count;
  final int columns;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        childAspectRatio: 0.82,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
      ),
      itemCount: count,
      itemBuilder: (_, _) => const CourseCardSkeleton(),
    );
  }
}
