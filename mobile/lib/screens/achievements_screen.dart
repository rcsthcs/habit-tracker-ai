import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
                // Header
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
                      Text('достижений разблокировано',
                          style: TextStyle(
                              color: context.textSecondary, fontSize: 14)),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // Progress bar
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
                // Grid
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 1.1,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: achievements.length,
                  itemBuilder: (ctx, i) =>
                      _AchievementCard(achievement: achievements[i]),
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

  const _AchievementCard({required this.achievement});

  @override
  Widget build(BuildContext context) {
    final unlocked = achievement.unlocked;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      elevation: unlocked ? 3 : 1,
      color: unlocked
          ? (isDark ? AppColors.darkSurface : AppColors.lightSurface)
          : (isDark ? Colors.grey[850] : Colors.grey[100]),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showDetail(context),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                achievement.icon,
                style: TextStyle(
                  fontSize: 36,
                  color: unlocked ? null : Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                achievement.title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: unlocked ? context.textPrimary : Colors.grey,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                achievement.description,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: unlocked ? context.textSecondary : Colors.grey[400],
                ),
              ),
              if (unlocked && achievement.unlockedAt != null) ...[
                const SizedBox(height: 4),
                Text(
                  '${achievement.unlockedAt!.day}.${achievement.unlockedAt!.month.toString().padLeft(2, '0')}.${achievement.unlockedAt!.year}',
                  style: const TextStyle(
                      fontSize: 10, color: AppColors.success),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showDetail(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(achievement.icon, style: const TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text(achievement.title,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(achievement.description,
                textAlign: TextAlign.center,
                style: TextStyle(color: context.textSecondary)),
            const SizedBox(height: 12),
            if (achievement.unlocked)
              const Text('✅ Разблокировано!',
                  style: TextStyle(
                      color: AppColors.success,
                      fontWeight: FontWeight.w600))
            else
              Text('🔒 Ещё не получено',
                  style: TextStyle(color: context.textSecondary)),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Закрыть')),
        ],
      ),
    );
  }
}

