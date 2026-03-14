import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/theme_extensions.dart';

class StreakBadge extends StatelessWidget {
  final int streak;
  final double size;

  const StreakBadge({super.key, required this.streak, this.size = 48});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: streak >= 7
              ? [Colors.orange, Colors.deepOrange]
              : [AppColors.primary, AppColors.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(size / 3),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            streak >= 7 ? Icons.local_fire_department : Icons.bolt,
            color: Colors.white,
            size: size * 0.35,
          ),
          Text(
            '$streak',
            style: TextStyle(
              color: Colors.white,
              fontSize: size * 0.25,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class AiTipCard extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;
  final Color? color;

  const AiTipCard({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.lightbulb_outline,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final tipColor = color ?? AppColors.primary;
    return Card(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [tipColor.withValues(alpha: 0.08), tipColor.withValues(alpha: 0.02)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: tipColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: tipColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: tipColor)),
                  const SizedBox(height: 4),
                  Text(message,
                      style: TextStyle(
                          fontSize: 13, color: context.textSecondary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

