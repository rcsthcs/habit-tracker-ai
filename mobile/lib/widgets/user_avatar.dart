import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/config.dart';

/// Reusable avatar widget — shows cached network image or initials fallback.
class UserAvatar extends StatelessWidget {
  final String? avatarUrl;
  final String name;
  final double radius;
  final bool showBorder;

  const UserAvatar({
    super.key,
    this.avatarUrl,
    required this.name,
    this.radius = 24,
    this.showBorder = false,
  });

  @override
  Widget build(BuildContext context) {
    final fullUrl = AppConfig.fullAvatarUrl(avatarUrl);
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: fullUrl == null ? AppColors.primaryGradient : null,
        border: showBorder
            ? Border.all(
                color: isDark ? AppColors.darkDivider : Colors.white,
                width: 3,
              )
            : null,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: fullUrl != null
          ? ClipOval(
              child: CachedNetworkImage(
                imageUrl: fullUrl,
                width: radius * 2,
                height: radius * 2,
                fit: BoxFit.cover,
                memCacheWidth: (radius * 2 * 2).toInt(), // 2x for retina
                memCacheHeight: (radius * 2 * 2).toInt(),
                placeholder: (_, __) => _InitialFallback(
                  initial: initial,
                  radius: radius,
                ),
                errorWidget: (_, __, ___) => _InitialFallback(
                  initial: initial,
                  radius: radius,
                ),
              ),
            )
          : Center(
              child: Text(
                initial,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: radius * 0.7,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
    );
  }
}

class _InitialFallback extends StatelessWidget {
  final String initial;
  final double radius;

  const _InitialFallback({required this.initial, required this.radius});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.primaryGradient,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            color: Colors.white,
            fontSize: radius * 0.7,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
