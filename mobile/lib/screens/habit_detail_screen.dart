import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../core/app_colors.dart';
import '../core/theme_extensions.dart';
import '../models/habit.dart';
import '../models/habit_log.dart';
import '../providers/app_providers.dart';
import '../widgets/streak_badge.dart';
import 'edit_habit_screen.dart';

class HabitDetailScreen extends ConsumerStatefulWidget {
  final Habit habit;

  const HabitDetailScreen({super.key, required this.habit});

  @override
  ConsumerState<HabitDetailScreen> createState() => _HabitDetailScreenState();
}

class _HabitDetailScreenState extends ConsumerState<HabitDetailScreen> {
  List<HabitLog> _logs = [];
  bool _loading = true;
  late Habit _habit;

  @override
  void initState() {
    super.initState();
    _habit = widget.habit;
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    try {
      final api = ref.read(apiServiceProvider);
      final logs = await api.getHabitLogs(_habit.id, days: 60);
      setState(() {
        _logs = logs;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _toggleToday() async {
    try {
      await ref.read(habitsProvider.notifier).toggleHabit(
          _habit.id, !_habit.completedToday);
      // Reload habit data
      final api = ref.read(apiServiceProvider);
      final habits = await api.getHabits();
      final updated = habits.firstWhere((h) => h.id == _habit.id, orElse: () => _habit);
      setState(() => _habit = updated);
      await _loadLogs();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final habit = _habit;

    return Scaffold(
      appBar: AppBar(
        title: Text(habit.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: AppColors.primary),
            onPressed: () async {
              final updated = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) => EditHabitScreen(habit: _habit),
                ),
              );
              if (updated == true) {
                // Reload habit data after edit
                final api = ref.read(apiServiceProvider);
                final habits = await api.getHabits();
                final h = habits.firstWhere((h) => h.id == _habit.id,
                    orElse: () => _habit);
                setState(() => _habit = h);
                await _loadLogs();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.error),
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
                  // Today toggle button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _toggleToday,
                      icon: Icon(habit.completedToday
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked),
                      label: Text(
                        habit.completedToday
                            ? 'Выполнено сегодня ✅'
                            : 'Отметить выполненным',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: habit.completedToday
                            ? AppColors.success
                            : AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

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
                              style: TextStyle(
                                  color: context.textSecondary, fontSize: 14),
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
                                  icon: Icons.emoji_events,
                                  value: '${habit.bestStreak}',
                                  label: 'лучшая',
                                  color: Colors.amber,
                                ),
                                const SizedBox(width: 16),
                                _MiniStat(
                                  icon: Icons.pie_chart,
                                  value:
                                      '${habit.completionRate.toStringAsFixed(0)}%',
                                  label: 'выполнение',
                                  color: AppColors.primary,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Habit info card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Информация',
                              style: TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 12),
                          _InfoRow(
                            icon: Icons.repeat,
                            label: 'Частота',
                            value: _cooldownLabel(habit.cooldownDays),
                          ),
                          if (habit.targetTime != null)
                            _InfoRow(
                              icon: Icons.schedule,
                              label: 'Время выполнения',
                              value: habit.targetTime!,
                            ),
                          if (habit.reminderTime != null)
                            _InfoRow(
                              icon: Icons.notifications_outlined,
                              label: 'Напоминание',
                              value: habit.reminderTime!,
                            ),
                          if (habit.description.isNotEmpty)
                            _InfoRow(
                              icon: Icons.description_outlined,
                              label: 'Описание',
                              value: habit.description,
                            ),
                          _InfoRow(
                            icon: Icons.calendar_today,
                            label: 'Создана',
                            value:
                                '${habit.createdAt.day}.${habit.createdAt.month.toString().padLeft(2, '0')}.${habit.createdAt.year}',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

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
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text('Пока нет записей',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: context.textSecondary)),
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
          color = _habit.colorValue;
        } else if (completed == false) {
          color = AppColors.error.withValues(alpha: 0.3);
        } else {
          color = Colors.grey.withValues(alpha: 0.15);
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
                  color: completed == true ? Colors.white : context.textSecondary,
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
                  ? AppColors.success
                  : rate >= 40
                      ? AppColors.warning
                      : AppColors.error.withValues(alpha: 0.7),
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
            'Привычка "${_habit.name}" и вся история будут удалены.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Отмена')),
          TextButton(
            onPressed: () async {
              await ref
                  .read(habitsProvider.notifier)
                  .deleteHabit(_habit.id);
              if (context.mounted) {
                Navigator.pop(context); // dialog
                Navigator.pop(context); // detail screen
              }
            },
            child: const Text('Удалить',
                style: TextStyle(color: AppColors.error)),
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

  String _cooldownLabel(int days) {
    switch (days) {
      case 1:
        return 'Каждый день';
      case 2:
        return 'Через день';
      case 3:
        return 'Раз в 3 дня';
      case 7:
        return 'Раз в неделю';
      default:
        return 'Раз в $days дн.';
    }
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
                TextStyle(color: context.textSecondary, fontSize: 12)),
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
        color: log.completed ? AppColors.success : AppColors.error,
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
                  TextStyle(color: context.textSecondary, fontSize: 12),
            )
          : null,
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: context.textSecondary),
          const SizedBox(width: 10),
          Text(label,
              style: TextStyle(
                  fontSize: 13, color: context.textSecondary)),
          const Spacer(),
          Flexible(
            child: Text(value,
                textAlign: TextAlign.end,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}
