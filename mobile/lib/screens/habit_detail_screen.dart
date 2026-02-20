import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../core/theme.dart';
import '../models/habit.dart';
import '../models/habit_log.dart';
import '../providers/app_providers.dart';
import '../widgets/streak_badge.dart';

class HabitDetailScreen extends ConsumerStatefulWidget {
  final Habit habit;

  const HabitDetailScreen({super.key, required this.habit});

  @override
  ConsumerState<HabitDetailScreen> createState() => _HabitDetailScreenState();
}

class _HabitDetailScreenState extends ConsumerState<HabitDetailScreen> {
  List<HabitLog> _logs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    try {
      final api = ref.read(apiServiceProvider);
      final logs = await api.getHabitLogs(widget.habit.id, days: 60);
      setState(() {
        _logs = logs;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final habit = widget.habit;

    return Scaffold(
      appBar: AppBar(
        title: Text(habit.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppTheme.errorColor),
            onPressed: () => _confirmDelete(context),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadLogs,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Stats header
                  Row(
                    children: [
                      StreakBadge(streak: habit.currentStreak, size: 64),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              habit.name,
                              style: const TextStyle(
                                  fontSize: 22, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _categoryLabel(habit.category),
                              style: const TextStyle(
                                  color: AppTheme.textSecondary, fontSize: 14),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                _MiniStat(
                                  icon: Icons.local_fire_department,
                                  value: '${habit.currentStreak}',
                                  label: 'серия',
                                  color: Colors.orange,
                                ),
                                const SizedBox(width: 16),
                                _MiniStat(
                                  icon: Icons.pie_chart,
                                  value:
                                      '${habit.completionRate.toStringAsFixed(0)}%',
                                  label: 'выполнение',
                                  color: AppTheme.primaryColor,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // Calendar heatmap (last 30 days)
                  const Text('Последние 30 дней',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  _buildCalendarHeatmap(),
                  const SizedBox(height: 28),

                  // Weekly chart
                  const Text('Выполнение по дням недели',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 180,
                    child: BarChart(_buildWeeklyChart()),
                  ),
                  const SizedBox(height: 28),

                  // Log history
                  const Text('История',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  ..._logs.take(20).map((log) => _LogTile(log: log)),
                  if (_logs.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child: Text('Пока нет записей',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppTheme.textSecondary)),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildCalendarHeatmap() {
    final now = DateTime.now();
    final days = List.generate(30, (i) {
      final date = now.subtract(Duration(days: 29 - i));
      return DateTime(date.year, date.month, date.day);
    });

    final logDates = <String, bool>{};
    for (final log in _logs) {
      final key =
          '${log.date.year}-${log.date.month}-${log.date.day}';
      logDates[key] = log.completed;
    }

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: days.map((day) {
        final key = '${day.year}-${day.month}-${day.day}';
        final completed = logDates[key];
        Color color;
        if (completed == true) {
          color = widget.habit.colorValue;
        } else if (completed == false) {
          color = AppTheme.errorColor.withOpacity(0.3);
        } else {
          color = Colors.grey.withOpacity(0.15);
        }

        return Tooltip(
          message: '${day.day}.${day.month} — ${completed == true ? "✅" : completed == false ? "❌" : "—"}',
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: Text(
                '${day.day}',
                style: TextStyle(
                  fontSize: 10,
                  color: completed == true ? Colors.white : AppTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  BarChartData _buildWeeklyChart() {
    final dayNames = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    final dayCounts = List.filled(7, 0);
    final dayTotals = List.filled(7, 0);

    for (final log in _logs) {
      final dow = log.date.weekday - 1; // 0=Mon
      dayTotals[dow]++;
      if (log.completed) dayCounts[dow]++;
    }

    return BarChartData(
      alignment: BarChartAlignment.spaceAround,
      maxY: 100,
      titlesData: FlTitlesData(
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (v, _) => Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(dayNames[v.toInt()],
                  style: const TextStyle(fontSize: 11)),
            ),
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 30,
            getTitlesWidget: (v, _) =>
                Text('${v.toInt()}%', style: const TextStyle(fontSize: 10)),
          ),
        ),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      borderData: FlBorderData(show: false),
      gridData: const FlGridData(show: false),
      barGroups: List.generate(7, (i) {
        final rate =
            dayTotals[i] > 0 ? dayCounts[i] / dayTotals[i] * 100 : 0.0;
        return BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: rate,
              color: rate >= 70
                  ? AppTheme.successColor
                  : rate >= 40
                      ? AppTheme.warningColor
                      : AppTheme.errorColor.withOpacity(0.7),
              width: 22,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(6)),
            ),
          ],
        );
      }),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Удалить привычку?'),
        content: Text(
            'Привычка "${widget.habit.name}" и вся история будут удалены.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Отмена')),
          TextButton(
            onPressed: () async {
              await ref
                  .read(habitsProvider.notifier)
                  .deleteHabit(widget.habit.id);
              if (context.mounted) {
                Navigator.pop(context); // dialog
                Navigator.pop(context); // detail screen
              }
            },
            child: const Text('Удалить',
                style: TextStyle(color: AppTheme.errorColor)),
          ),
        ],
      ),
    );
  }

  String _categoryLabel(String category) {
    const labels = {
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
    return labels[category] ?? category;
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _MiniStat({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(value,
            style: TextStyle(
                fontWeight: FontWeight.bold, color: color, fontSize: 14)),
        const SizedBox(width: 2),
        Text(label,
            style:
                const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
      ],
    );
  }
}

class _LogTile extends StatelessWidget {
  final HabitLog log;

  const _LogTile({required this.log});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: Icon(
        log.completed ? Icons.check_circle : Icons.cancel,
        color: log.completed ? AppTheme.successColor : AppTheme.errorColor,
        size: 22,
      ),
      title: Text(
        '${log.date.day}.${log.date.month.toString().padLeft(2, '0')}.${log.date.year}',
        style: const TextStyle(fontSize: 14),
      ),
      subtitle: log.note != null && log.note!.isNotEmpty
          ? Text(log.note!, style: const TextStyle(fontSize: 12))
          : null,
      trailing: log.completedAt != null
          ? Text(
              '${log.completedAt!.hour}:${log.completedAt!.minute.toString().padLeft(2, '0')}',
              style:
                  const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            )
          : null,
    );
  }
}

