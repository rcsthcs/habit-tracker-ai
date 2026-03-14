import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../core/app_colors.dart';
import '../core/theme_extensions.dart';
import '../providers/app_providers.dart';
import '../widgets/streak_badge.dart';
import 'achievements_screen.dart';

class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analyticsAsync = ref.watch(analyticsProvider);
    final recommendationsAsync = ref.watch(recommendationsProvider);
    final achievementsAsync = ref.watch(achievementsProvider);
    final detailedAsync = ref.watch(detailedAnalyticsProvider);

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
                        Text('Достижения (${unlocked.length}/${achievements.length})',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600)),
                        TextButton(
                          onPressed: () => Navigator.push(context,
                              MaterialPageRoute(builder: (_) => const AchievementsScreen())),
                          child: const Text('Все →', style: TextStyle(fontSize: 13)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 70,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: achievements.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (ctx, i) {
                          final a = achievements[i];
                          return Container(
                            width: 60,
                            decoration: BoxDecoration(
                              color: a.unlocked
                                  ? AppColors.primary.withValues(alpha: 0.1)
                                  : Colors.grey[100],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(a.icon,
                                    style: TextStyle(
                                        fontSize: 24,
                                        color: a.unlocked ? null : Colors.grey)),
                                const SizedBox(height: 2),
                                Text(a.title,
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize: 9,
                                        color: a.unlocked
                                            ? context.textPrimary
                                            : Colors.grey)),
                              ],
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
                        color: AppColors.success,
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
                        color: AppColors.primary,
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
                  const Text('Активность за 90 дней',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  _buildHeatmap(context, detailed.heatmap),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _HeatmapLegend(color: AppColors.success, label: 'Всё выполнено'),
                      const SizedBox(width: 12),
                      _HeatmapLegend(color: AppColors.error.withValues(alpha: 0.4), label: 'Есть пропуски'),
                      const SizedBox(width: 12),
                      _HeatmapLegend(color: Colors.grey.withValues(alpha: 0.15), label: 'Нет данных'),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Stat summary
                  Row(
                    children: [
                      _StatCard(icon: Icons.check, label: 'Выполнено',
                          value: '${detailed.totalCompleted}', color: AppColors.success),
                      const SizedBox(width: 12),
                      _StatCard(icon: Icons.calendar_today, label: 'Дней активности',
                          value: '${detailed.daysActive}', color: AppColors.primary),
                      const SizedBox(width: 12),
                      _StatCard(icon: Icons.edit_note, label: 'Всего записей',
                          value: '${detailed.totalLogged}', color: Colors.orange),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Category pie chart
                  if (detailed.categoryStats.isNotEmpty) ...[
                    const Text('По категориям',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
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
                          color: _categoryColors[e.key % _categoryColors.length],
                          label: '${_categoryLabel(e.value.category)} (${e.value.count})',
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Trend 90d
                  if (detailed.trend90d.length > 1) ...[
                    const Text('Тренд за 90 дней',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
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
                              spots: detailed.trend90d.asMap().entries
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

            // ─── Recommendations section ───
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
                  if (recs.motivationMessage.isNotEmpty)
                    Card(
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: LinearGradient(
                            colors: [
                              AppColors.primary.withValues(alpha: 0.1),
                              AppColors.secondary.withValues(alpha: 0.05),
                            ],
                          ),
                        ),
                        child: Text(recs.motivationMessage,
                            style: const TextStyle(fontSize: 15)),
                      ),
                    ),
                  const SizedBox(height: 12),
                  ...recs.tips.map((tip) => AiTipCard(
                        title: '💡 Совет',
                        message: tip,
                      )),
                  ...recs.recommendations.map((rec) => Card(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => _showAddFromRecommendation(
                              context, ref, rec['title'] ?? '', rec['reason'] ?? ''),
                          child: ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: AppColors.primary,
                              child: Icon(Icons.add, color: Colors.white),
                            ),
                            title: Text(rec['title'] ?? ''),
                            subtitle: Text(rec['reason'] ?? '',
                                style: const TextStyle(fontSize: 12)),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.add, size: 14,
                                      color: AppColors.primary),
                                  SizedBox(width: 2),
                                  Text('Добавить',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          ),
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

  void _showAddFromRecommendation(
      BuildContext context, WidgetRef ref, String title, String reason) {
    final nameController = TextEditingController(text: title);
    String selectedCategory = 'health';
    int cooldownDays = 1;

    final categories = {
      'health': '🏥 Здоровье',
      'fitness': '💪 Фитнес',
      'nutrition': '🥗 Питание',
      'mindfulness': '🧘 Осознанность',
      'productivity': '📋 Продуктивность',
      'learning': '📚 Обучение',
      'social': '👥 Социальное',
      'sleep': '😴 Сон',
      'finance': '💰 Финансы',
      'other': '📌 Другое',
    };

    final cooldownOptions = {
      1: 'Каждый день',
      2: 'Через день',
      3: 'Раз в 3 дня',
      7: 'Раз в неделю',
    };

    // Try to guess category from title/reason
    final lowerTitle = title.toLowerCase() + ' ' + reason.toLowerCase();
    if (lowerTitle.contains('спорт') ||
        lowerTitle.contains('фитнес') ||
        lowerTitle.contains('зарядк')) {
      selectedCategory = 'fitness';
    } else if (lowerTitle.contains('книг') || lowerTitle.contains('учи')) {
      selectedCategory = 'learning';
    } else if (lowerTitle.contains('медита') || lowerTitle.contains('осознан')) {
      selectedCategory = 'mindfulness';
    } else if (lowerTitle.contains('еда') ||
        lowerTitle.contains('вод') ||
        lowerTitle.contains('питан')) {
      selectedCategory = 'nutrition';
    } else if (lowerTitle.contains('сон') || lowerTitle.contains('спать')) {
      selectedCategory = 'sleep';
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(builder: (context, setSheetState) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
                24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Добавить рекомендацию как привычку',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (reason.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.lightbulb_outline,
                              size: 18, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(reason,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: context.textSecondary)),
                          ),
                        ],
                      ),
                    ),

                  // Name (editable)
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Название привычки',
                      prefixIcon: Icon(Icons.edit),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Category
                  const Text('Категория',
                      style: TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: categories.entries.map((e) {
                      final isSelected = selectedCategory == e.key;
                      return ChoiceChip(
                        label:
                            Text(e.value, style: const TextStyle(fontSize: 12)),
                        selected: isSelected,
                        selectedColor: AppColors.primary.withValues(alpha: 0.2),
                        onSelected: (_) {
                          setSheetState(() => selectedCategory = e.key);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Cooldown
                  const Text('Частота выполнения',
                      style: TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: cooldownOptions.entries.map((e) {
                      final isSelected = cooldownDays == e.key;
                      return ChoiceChip(
                        label:
                            Text(e.value, style: const TextStyle(fontSize: 12)),
                        selected: isSelected,
                        selectedColor: AppColors.primary.withValues(alpha: 0.2),
                        onSelected: (_) {
                          setSheetState(() => cooldownDays = e.key);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  // Submit
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        if (nameController.text.trim().isEmpty) return;
                        await ref.read(habitsProvider.notifier).createHabit({
                          'name': nameController.text.trim(),
                          'category': selectedCategory,
                          'frequency': 'daily',
                          'cooldown_days': cooldownDays,
                        });
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Привычка добавлена! ✅'),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.check),
                      label: const Text('Добавить привычку',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  Widget _buildHeatmap(BuildContext context, Map<String, bool?> heatmap) {
    final sortedDates = heatmap.keys.toList()..sort();
    return Wrap(
      spacing: 3,
      runSpacing: 3,
      children: sortedDates.map((dateStr) {
        final val = heatmap[dateStr];
        Color color;
        if (val == true) {
          color = AppColors.success;
        } else if (val == false) {
          color = AppColors.error.withValues(alpha: 0.4);
        } else {
          color = Colors.grey.withValues(alpha: 0.15);
        }
        final parts = dateStr.split('-');
        final day = parts.length >= 3 ? parts[2] : '';
        return Tooltip(
          message: dateStr,
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
        );
      }).toList(),
    );
  }

  static const _categoryColors = [
    Color(0xFF6C63FF), Color(0xFF03DAC6), Color(0xFFFF9800),
    Color(0xFF4CAF50), Color(0xFFF44336), Color(0xFF9C27B0),
    Color(0xFF2196F3), Color(0xFFFF5722), Color(0xFF795548),
    Color(0xFF607D8B),
  ];

  List<PieChartSectionData> _buildPieSections(List<dynamic> stats) {
    return stats.asMap().entries.map((e) {
      final s = e.value;
      return PieChartSectionData(
        value: s.count.toDouble(),
        color: _categoryColors[e.key % _categoryColors.length],
        radius: 50,
        title: '${s.count}',
        titleStyle: const TextStyle(
            fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
      );
    }).toList();
  }

  String _categoryLabel(String category) {
    const labels = {
      'health': '❤️ Здоровье', 'fitness': '💪 Фитнес',
      'nutrition': '🥗 Питание', 'mindfulness': '🧘 Осознанность',
      'productivity': '⚡ Продуктивность', 'learning': '📚 Обучение',
      'social': '🤝 Общение', 'sleep': '😴 Сон',
      'finance': '💰 Финансы', 'other': '📦 Другое',
    };
    return labels[category] ?? category;
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
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 11, color: context.textSecondary)),
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
        Container(width: 12, height: 12,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 10, color: context.textSecondary)),
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
        Container(width: 10, height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}

