import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../core/app_colors.dart';
import '../core/theme_extensions.dart';
import '../models/achievement.dart';
import '../providers/app_providers.dart';

class AchievementsScreen extends ConsumerWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final achievementsAsync = ref.watch(achievementsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Достижения')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(achievementsProvider),
        child: achievementsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Ошибка: $e')),
          data: (achievements) {
            final unlocked = achievements.where((a) => a.unlocked).length;
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Center(
                  child: Column(
                    children: [
                      Text(
                        '$unlocked / ${achievements.length}',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'достижений разблокировано',
                        style: TextStyle(
                          color: context.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: achievements.isEmpty
                        ? 0
                        : unlocked / achievements.length,
                    minHeight: 8,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 24),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.8,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: achievements.length,
                  itemBuilder: (ctx, i) =>
                      _AchievementCard(achievement: achievements[i], index: i),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _AchievementCard extends StatelessWidget {
  final Achievement achievement;
  final int index;

  const _AchievementCard({required this.achievement, this.index = 0});

  @override
  Widget build(BuildContext context) {
    final unlocked = achievement.unlocked;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final unlockedGradient = isDark
        ? const [Color(0xFF7B73FF), Color(0xFF4A42CC)]
        : const [Color(0xFF8E84FF), Color(0xFF6C63FF)];
    final lockedGradient = isDark
        ? const [Color(0xFF24253D), Color(0xFF181A2D)]
        : const [Color(0xFFFFFFFF), Color(0xFFF4F1FF)];
    final lockedIconBackground = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : AppColors.lightSurfaceVariant;

    final card = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: unlocked ? unlockedGradient : lockedGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: unlocked
                ? AppColors.primary.withValues(alpha: isDark ? 0.26 : 0.18)
                : Colors.black.withValues(alpha: isDark ? 0.16 : 0.06),
            blurRadius: unlocked ? 18 : 10,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(
          color: unlocked
              ? AppColors.primary.withValues(alpha: isDark ? 0.58 : 0.28)
              : context.dividerColor.withValues(alpha: isDark ? 0.9 : 0.6),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _showDetail(context),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: unlocked
                        ? Colors.white.withValues(alpha: 0.14)
                        : lockedIconBackground,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: unlocked
                          ? Colors.white.withValues(alpha: 0.16)
                          : context.dividerColor.withValues(alpha: 0.55),
                    ),
                  ),
                  child: Opacity(
                    opacity: unlocked ? 1.0 : 0.78,
                    child: Text(
                      achievement.icon,
                      style: TextStyle(
                        fontSize: 28,
                        color: unlocked ? Colors.white : context.textPrimary,
                        shadows: unlocked
                            ? const [
                                Shadow(
                                  color: Colors.black26,
                                  blurRadius: 10,
                                  offset: Offset(0, 3),
                                ),
                              ]
                            : const [],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  achievement.title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: unlocked ? Colors.white : context.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  unlocked && achievement.unlockedAt != null
                      ? '${achievement.unlockedAt!.day}.${achievement.unlockedAt!.month.toString().padLeft(2, '0')}.${achievement.unlockedAt!.year}'
                      : 'Не получено',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: unlocked
                        ? Colors.white.withValues(alpha: 0.84)
                        : context.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: unlocked
                        ? Colors.white.withValues(alpha: 0.14)
                        : Colors.white.withValues(alpha: isDark ? 0.04 : 0.65),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        unlocked
                            ? Icons.check_circle_rounded
                            : Icons.lock_outline_rounded,
                        size: 14,
                        color: unlocked ? Colors.white : context.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        unlocked ? 'Разблокировано' : 'В процессе',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color:
                              unlocked ? Colors.white : context.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return card
        .animate()
        .fadeIn(delay: (index * 50).ms, duration: 300.ms)
        .slideY(begin: 0.1, end: 0, curve: Curves.easeOutCubic)
        .scale(begin: const Offset(0.95, 0.95), curve: Curves.easeOutCubic);
  }

  void _showDetail(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(achievement.icon, style: const TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            Text(
              achievement.title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              achievement.description,
              textAlign: TextAlign.center,
              style: TextStyle(color: context.textSecondary, fontSize: 15),
            ),
            const SizedBox(height: 20),
            if (achievement.unlocked)
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, color: AppColors.success, size: 18),
                  SizedBox(width: 6),
                  Text(
                    'Разблокировано!',
                    style: TextStyle(
                      color: AppColors.success,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ],
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock, color: context.textSecondary, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'Ещё не получено',
                    style: TextStyle(
                      color: context.textSecondary,
                      fontWeight: FontWeight.w500,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }
}
