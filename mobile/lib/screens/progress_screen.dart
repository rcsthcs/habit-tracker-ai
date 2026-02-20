import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../core/theme.dart';
import '../providers/app_providers.dart';
import '../widgets/streak_badge.dart';

class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analyticsAsync = ref.watch(analyticsProvider);
    final recommendationsAsync = ref.watch(recommendationsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Прогресс')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(analyticsProvider);
          ref.invalidate(recommendationsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Analytics section
            analyticsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Ошибка: $e'),
              data: (analytics) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Stats cards row
                  Row(
                    children: [
                      _StatCard(
                        icon: Icons.check_circle,
                        label: 'Сегодня',
                        value:
                            '${analytics.todayCompleted}/${analytics.todayTotal}',
                        color: AppTheme.successColor,
                      ),
                      const SizedBox(width: 12),
                      _StatCard(
                        icon: Icons.local_fire_department,
                        label: 'Лучшая серия',
                        value: '${analytics.currentBestStreak} дн.',
                        color: Colors.orange,
                      ),
                      const SizedBox(width: 12),
                      _StatCard(
                        icon: Icons.pie_chart,
                        label: 'Общий %',
                        value:
                            '${analytics.overallCompletionRate.toStringAsFixed(0)}%',
                        color: AppTheme.primaryColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Weekly chart
                  const Text('Последние 7 дней',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
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
                                  'Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'
                                ];
                                final today = DateTime.now().weekday;
                                final idx =
                                    (today - 7 + value.toInt()) % 7;
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
                                    ? AppTheme.successColor
                                    : analytics.weeklyCompletion[i] >= 40
                                        ? AppTheme.warningColor
                                        : AppTheme.errorColor,
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
                      color: AppTheme.successColor,
                    ),
                  if (analytics.mostStruggledHabit != null)
                    AiTipCard(
                      title: '💪 Нужно внимание',
                      message: analytics.mostStruggledHabit!,
                      icon: Icons.fitness_center,
                      color: AppTheme.warningColor,
                    ),
                  if (analytics.optimalTime != null)
                    AiTipCard(
                      title: '⏰ Оптимальное время',
                      message:
                          'Ты наиболее продуктивен в ${analytics.optimalTime}',
                      icon: Icons.schedule,
                      color: AppTheme.primaryColor,
                    ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Recommendations section
            const Text('AI-рекомендации',
                style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            recommendationsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Ошибка: $e'),
              data: (recs) => Column(
                children: [
                  // Motivation
                  if (recs.motivationMessage.isNotEmpty)
                    Card(
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: LinearGradient(
                            colors: [
                              AppTheme.primaryColor.withOpacity(0.1),
                              AppTheme.secondaryColor.withOpacity(0.05),
                            ],
                          ),
                        ),
                        child: Text(recs.motivationMessage,
                            style: const TextStyle(fontSize: 15)),
                      ),
                    ),
                  const SizedBox(height: 12),
                  // Tips
                  ...recs.tips.map((tip) => AiTipCard(
                        title: '💡 Совет',
                        message: tip,
                      )),
                  // Habit recommendations
                  ...recs.recommendations.map((rec) => Card(
                        child: ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: AppTheme.primaryColor,
                            child:
                                Icon(Icons.add, color: Colors.white),
                          ),
                          title: Text(rec['title'] ?? ''),
                          subtitle: Text(rec['reason'] ?? '',
                              style: const TextStyle(fontSize: 12)),
                          trailing: const Icon(Icons.chevron_right),
                        ),
                      )),
                ],
              ),
            ),
          ],
        ),
      ),
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
    return Expanded(
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(value,
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: color)),
              const SizedBox(height: 2),
              Text(label,
                  style: const TextStyle(
                      fontSize: 11, color: AppTheme.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }
}

