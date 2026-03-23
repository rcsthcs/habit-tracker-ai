import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../core/app_colors.dart';
import '../core/theme_extensions.dart';
import '../models/detailed_analytics.dart';
import '../providers/app_providers.dart';
import '../widgets/add_habit_bottom_sheet.dart';
import '../widgets/shimmer_loader.dart';
import 'achievements_screen.dart';

class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analyticsAsync = ref.watch(analyticsProvider);
    final recommendationsAsync = ref.watch(recommendationsProvider);
    final achievementsAsync = ref.watch(achievementsProvider);
    final detailedAsync = ref.watch(detailedAnalyticsProvider);
    final isDark = context.isDark;

    return Scaffold(
      appBar: AppBar(title: const Text('Прогресс')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(analyticsProvider);
          ref.invalidate(recommendationsProvider);
          ref.invalidate(achievementsProvider);
          ref.invalidate(detailedAnalyticsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ─── Achievements mini-row ───
            achievementsAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (achievements) {
                final unlocked = achievements.where((a) => a.unlocked).toList();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Достижения (${unlocked.length}/${achievements.length})',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const AchievementsScreen())),
                          child: const Text('Все →',
                              style: TextStyle(fontSize: 13)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 80, // Увеличим высоту для нового дизайна
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: achievements.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (ctx, i) {
                          final a = achievements[i];
                          final unlocked = a.unlocked;
                          return AspectRatio(
                            aspectRatio: 1,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: unlocked
                                    ? LinearGradient(
                                        colors: isDark
                                            ? const [
                                                Color(0xFF7B73FF),
                                                Color(0xFF4A42CC),
                                              ]
                                            : const [
                                                Color(0xFF8E84FF),
                                                Color(0xFF6C63FF),
                                              ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      )
                                    : LinearGradient(
                                        colors: isDark
                                            ? const [
                                                Color(0xFF24253D),
                                                Color(0xFF1A1A2E),
                                              ]
                                            : const [
                                                Color(0xFFFFFFFF),
                                                Color(0xFFF4F1FF),
                                              ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: unlocked
                                      ? AppColors.primary.withValues(
                                          alpha: isDark ? 0.55 : 0.24,
                                        )
                                      : context.dividerColor.withValues(
                                          alpha: isDark ? 0.9 : 0.65,
                                        ),
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: unlocked
                                        ? AppColors.primary.withValues(
                                            alpha: isDark ? 0.22 : 0.16,
                                          )
                                        : Colors.black.withValues(
                                            alpha: isDark ? 0.16 : 0.04,
                                          ),
                                    blurRadius: unlocked ? 16 : 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 42,
                                    height: 42,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: unlocked
                                          ? Colors.white.withValues(alpha: 0.16)
                                          : context.surfaceColor.withValues(
                                              alpha: isDark ? 0.8 : 0.95,
                                            ),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Opacity(
                                      opacity: unlocked ? 1.0 : 0.8,
                                      child: Text(
                                        a.icon,
                                        style: TextStyle(
                                          fontSize: 24,
                                          color: unlocked
                                              ? Colors.white
                                              : context.textPrimary,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                    ),
                                    child: Text(
                                      a.title,
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                        color: unlocked
                                            ? Colors.white
                                            : context.textPrimary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                );
              },
            ),

            // ─── Analytics section ───
            analyticsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Ошибка: $e'),
              data: (analytics) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Stats cards row
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _StatCard(
                        icon: Icons.check_circle,
                        label: 'Сегодня',
                        value:
                            '${analytics.todayCompleted}/${analytics.todayTotal}',
                        color: AppColors.success,
                      ),
                      _StatCard(
                        icon: Icons.local_fire_department,
                        label: 'Лучшая серия',
                        value: '${analytics.currentBestStreak} дн.',
                        color: Colors.orange,
                      ),
                      _StatCard(
                        icon: Icons.pie_chart,
                        label: 'Общий %',
                        value:
                            '${analytics.overallCompletionRate.toStringAsFixed(0)}%',
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Weekly chart
                  const Text('Последние 7 дней',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 200,
                    child: BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: 100,
                        barTouchData: BarTouchData(enabled: true),
                        titlesData: FlTitlesData(
                          show: true,
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                const days = [
                                  'Пн',
                                  'Вт',
                                  'Ср',
                                  'Чт',
                                  'Пт',
                                  'Сб',
                                  'Вс'
                                ];
                                final today = DateTime.now().weekday;
                                final idx = (today - 7 + value.toInt()) % 7;
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    days[idx < 0 ? idx + 7 : idx],
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                );
                              },
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 32,
                              getTitlesWidget: (v, _) => Text(
                                '${v.toInt()}%',
                                style: const TextStyle(fontSize: 10),
                              ),
                            ),
                          ),
                          topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                        ),
                        borderData: FlBorderData(show: false),
                        gridData: const FlGridData(show: false),
                        barGroups: List.generate(
                          analytics.weeklyCompletion.length,
                          (i) => BarChartGroupData(
                            x: i,
                            barRods: [
                              BarChartRodData(
                                toY: analytics.weeklyCompletion[i],
                                color: analytics.weeklyCompletion[i] >= 70
                                    ? AppColors.success
                                    : analytics.weeklyCompletion[i] >= 40
                                        ? AppColors.warning
                                        : AppColors.error,
                                width: 20,
                                borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(6)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Best / worst habits
                  if (analytics.mostConsistentHabit != null)
                    AiTipCard(
                      title: '⭐ Самая стабильная',
                      message: analytics.mostConsistentHabit!,
                      icon: Icons.emoji_events,
                      color: AppColors.success,
                    ),
                  if (analytics.mostStruggledHabit != null)
                    AiTipCard(
                      title: '💪 Нужно внимание',
                      message: analytics.mostStruggledHabit!,
                      icon: Icons.fitness_center,
                      color: AppColors.warning,
                    ),
                  if (analytics.optimalTime != null)
                    AiTipCard(
                      title: '⏰ Оптимальное время',
                      message:
                          'Ты наиболее продуктивен в ${analytics.optimalTime}',
                      icon: Icons.schedule,
                      color: AppColors.primary,
                    ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ─── Detailed analytics: Heatmap + Categories ───
            detailedAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (detailed) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Heatmap
                  const Text('Активность за 30 дней',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  _buildHeatmap(context, detailed),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _HeatmapLegend(
                          color: AppColors.success, label: 'Всё выполнено'),
                      const SizedBox(width: 12),
                      _HeatmapLegend(
                          color: AppColors.error.withValues(alpha: 0.4),
                          label: 'Есть пропуски'),
                      const SizedBox(width: 12),
                      _HeatmapLegend(
                          color: Colors.grey.withValues(alpha: 0.15),
                          label: 'Нет данных'),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Stat summary
                  // Stat summary
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                            icon: Icons.check,
                            label: 'Выполнено',
                            value: '${detailed.totalCompleted}',
                            color: AppColors.success),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _StatCard(
                            icon: Icons.calendar_today,
                            label: 'Дней активности',
                            value: '${detailed.daysActive}',
                            color: AppColors.primary),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _StatCard(
                            icon: Icons.edit_note,
                            label: 'Всего записей',
                            value: '${detailed.totalLogged}',
                            color: Colors.orange),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Category pie chart
                  if (detailed.categoryStats.isNotEmpty) ...[
                    const Text('По категориям',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 200,
                      child: PieChart(
                        PieChartData(
                          sectionsSpace: 2,
                          centerSpaceRadius: 40,
                          sections: _buildPieSections(detailed.categoryStats),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: detailed.categoryStats.asMap().entries.map((e) {
                        return _PieLegend(
                          color:
                              _categoryColors[e.key % _categoryColors.length],
                          label:
                              '${_categoryLabel(e.value.category)} (${e.value.count})',
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Trend (last 30 days)
                  if (detailed.trend90d.length > 1) ...[
                    const Text('Тренд за 30 дней',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 150,
                      child: LineChart(
                        LineChartData(
                          gridData: const FlGridData(show: false),
                          titlesData: const FlTitlesData(show: false),
                          borderData: FlBorderData(show: false),
                          lineBarsData: [
                            LineChartBarData(
                              spots: detailed.trend90d
                                  .asMap()
                                  .entries
                                  .map((e) => FlSpot(e.key.toDouble(), e.value))
                                  .toList(),
                              isCurved: true,
                              color: AppColors.primary,
                              barWidth: 3,
                              dotData: const FlDotData(show: false),
                              belowBarData: BarAreaData(
                                show: true,
                                color: AppColors.primary.withValues(alpha: 0.1),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ],
              ),
            ),

            // AI-рекомендации
            const Text('✨ AI-рекомендации',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            recommendationsAsync.when(
              loading: () => const ShimmerLoader(
                shape: ShimmerShape.listTile,
                count: 2,
              ),
              error: (e, _) =>
                  Text('Не удалось загрузить рекомендации: ${e.toString()}'),
              data: (recs) => Column(
                children: [
                  if (recs.motivationMessage.isNotEmpty)
                    _MotivationCard(message: recs.motivationMessage),
                  const SizedBox(height: 12),
                  ...recs.tips.map((tip) => AiTipCard(
                        title: '💡 Совет от AI',
                        message: tip,
                        icon: Icons.lightbulb_outline,
                      )),
                  ...recs.recommendations.map(
                    (rec) => AiTipCard(
                      title: rec['title'] ?? '',
                      message: rec['reason'] ?? '',
                      isRecommendation: true,
                      icon: Icons.add_task,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeatmap(BuildContext context, DetailedAnalytics detailed) {
    final heatmap = detailed.heatmap;
    final dailyBreakdown = detailed.dailyBreakdown;
    final now = DateTime.now();
    final days = List.generate(30, (i) {
      final date = now.subtract(Duration(days: 29 - i));
      return DateTime(date.year, date.month, date.day);
    });

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: days.map((dateObj) {
        final dateStr =
            '${dateObj.year}-${dateObj.month.toString().padLeft(2, '0')}-${dateObj.day.toString().padLeft(2, '0')}';
        final val = heatmap[dateStr];
        Color color;
        if (val == true) {
          color = AppColors.success;
        } else if (val == false) {
          color = AppColors.error.withOpacity(0.5);
        } else {
          color = Colors.grey.withValues(alpha: 0.15);
        }
        final parts = dateStr.split('-');
        final day = parts.length >= 3 ? parts[2] : '';
        return Tooltip(
          message: 'Нажми для деталей: $dateStr',
          child: GestureDetector(
            onTap: () {
              final detail = dailyBreakdown[dateStr];
              final completed = detail?.completed ?? const <String>[];
              final missed = detail?.missed ?? const <String>[];

              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                builder: (_) => Padding(
                  padding: EdgeInsets.fromLTRB(16, 20, 16,
                      MediaQuery.of(context).viewInsets.bottom + 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          'Детали за $dateStr',
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 20),
                      _PastDaySection(
                        title: 'Выполнено',
                        icon: Icons.check_circle_outline_rounded,
                        color: AppColors.success,
                        items: completed,
                        emptyText: 'В этот день не было выполненных привычек.',
                      ),
                      const SizedBox(height: 16),
                      _PastDaySection(
                        title: 'Пропущено',
                        icon: Icons.highlight_off_rounded,
                        color: AppColors.error,
                        items: missed,
                        emptyText: 'Отличная работа! Пропусков нет.',
                      ),
                    ],
                  ),
                ),
              );
            },
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Center(
                child: Text(day,
                    style: TextStyle(
                      fontSize: 8,
                      color: val == true ? Colors.white : context.textSecondary,
                    )),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  static const _categoryColors = [
    Color(0xFF6C63FF),
    Color(0xFF03DAC6),
    Color(0xFFFF9800),
    Color(0xFF4CAF50),
    Color(0xFFF44336),
    Color(0xFF9C27B0),
    Color(0xFF2196F3),
    Color(0xFFFF5722),
    Color(0xFF795548),
    Color(0xFF607D8B),
  ];

  List<PieChartSectionData> _buildPieSections(List<dynamic> stats) {
    return stats.asMap().entries.map((e) {
      final s = e.value;
      return PieChartSectionData(
        value: s.count.toDouble(),
        color: _categoryColors[e.key % _categoryColors.length],
        radius: 60,
        title: '${s.count}',
        titleStyle: const TextStyle(
            fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
      );
    }).toList();
  }

  String _categoryLabel(String category) {
    const labels = {
      'health': '❤️ Здоровье',
      'fitness': '💪 Фитнес',
      'nutrition': '🥗 Питание',
      'mindfulness': '🧘 Осознанность',
      'productivity': '⚡ Продуктивность',
      'learning': '📚 Обучение',
      'social': '🤝 Общение',
      'sleep': '😴 Сон',
      'finance': '💰 Финансы',
      'other': '📦 Другое',
    };
    return labels[category] ?? category;
  }
}

class _MotivationCard extends StatelessWidget {
  final String message;
  const _MotivationCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withOpacity(0.1),
            AppColors.secondary.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.2, end: 0);
  }
}

class _PastDaySection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<String> items;
  final String emptyText;

  const _PastDaySection({
    required this.title,
    required this.icon,
    required this.color,
    required this.items,
    required this.emptyText,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 8),
            Text(
              '$title (${items.length})',
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: context.textPrimary),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: context.surfaceColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.dividerColor),
          ),
          child: items.isEmpty
              ? Text(
                  emptyText,
                  style: TextStyle(color: context.textSecondary, fontSize: 13),
                )
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: items
                      .map(
                        (item) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            item,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: color,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: context.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeatmapLegend extends StatelessWidget {
  final Color color;
  final String label;
  const _HeatmapLegend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(fontSize: 10, color: context.textSecondary)),
      ],
    );
  }
}

class _PieLegend extends StatelessWidget {
  final Color color;
  final String label;
  const _PieLegend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}

class AiTipCard extends ConsumerWidget {
  const AiTipCard({
    super.key,
    required this.title,
    required this.message,
    this.icon,
    this.color,
    this.isRecommendation = false,
  });

  final String title;
  final String message;
  final IconData? icon;
  final Color? color;
  final bool isRecommendation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final effectiveIcon = icon ?? Icons.lightbulb_outline;
    final effectiveColor = color ?? AppColors.primary;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: context.dividerColor),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: isRecommendation
            ? () => showAddHabitBottomSheet(
                  context: context,
                  ref: ref,
                  title: 'Новая привычка',
                  draft: HabitDraft(
                    name: title,
                    description: message,
                  ),
                )
            : null,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: effectiveColor.withOpacity(0.1),
                child: Icon(effectiveIcon, color: effectiveColor),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(
                      message,
                      style:
                          TextStyle(fontSize: 13, color: context.textSecondary),
                    ),
                  ],
                ),
              ),
              if (isRecommendation) ...[
                const SizedBox(width: 8),
                const Icon(Icons.add_circle_outline_rounded),
              ]
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.2, end: 0);
  }
}
