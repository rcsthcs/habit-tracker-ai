import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../core/app_spacing.dart';

/// Shimmer skeleton loader for various content shapes.
class ShimmerLoader extends StatelessWidget {
  final ShimmerShape shape;
  final double? width;
  final double? height;
  final int count;

  const ShimmerLoader({
    super.key,
    this.shape = ShimmerShape.card,
    this.width,
    this.height,
    this.count = 3,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.grey.shade800 : Colors.grey.shade200;
    final highlightColor = isDark ? Colors.grey.shade700 : Colors.grey.shade100;

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: Column(
        children: List.generate(count, (i) {
          switch (shape) {
            case ShimmerShape.card:
              return _shimmerCard();
            case ShimmerShape.listTile:
              return _shimmerListTile();
            case ShimmerShape.circle:
              return _shimmerCircle();
            case ShimmerShape.text:
              return _shimmerText();
          }
        }),
      ),
    );
  }

  Widget _shimmerCard() {
    return Container(
      width: width ?? double.infinity,
      height: height ?? 80,
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
    );
  }

  Widget _shimmerListTile() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  height: 14,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 120,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _shimmerCircle() {
    return Container(
      width: width ?? 64,
      height: height ?? 64,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _shimmerText() {
    return Container(
      width: width ?? 200,
      height: height ?? 14,
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

enum ShimmerShape { card, listTile, circle, text }
