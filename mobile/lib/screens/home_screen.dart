import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/app_colors.dart';
import '../core/theme_extensions.dart';
import '../models/habit.dart';
import '../providers/app_providers.dart';
import '../widgets/habit_card.dart';
import '../widgets/user_avatar.dart';
import 'habit_detail_screen.dart';
import 'mood_screen.dart';
import 'challenges_screen.dart';
import 'weekly_report_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(habitsProvider.notifier).loadHabits());
  }

  void _showAddHabitDialog() {
    final nameController = TextEditingController();
    String selectedCategory = 'health';
    int cooldownDays = 1;
    int dailyTarget = 1;
    TimeOfDay? targetTime;
    TimeOfDay? reminderTime;
    List<String> suggestions = [];
    bool isSubmitting = false;

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

    Future<void> loadSuggestions(String category, StateSetter setSheetState) async {
      try {
        final api = ref.read(apiServiceProvider);
        final result = await api.getHabitSuggestions(category);
        setSheetState(() => suggestions = result);
      } catch (_) {
        setSheetState(() => suggestions = []);
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(builder: (context, setSheetState) {
          // Load suggestions on first build
          if (suggestions.isEmpty) {
            loadSuggestions(selectedCategory, setSheetState);
          }

          return Padding(
            padding: EdgeInsets.fromLTRB(
                24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Новая привычка',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),

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
                        label: Text(e.value, style: const TextStyle(fontSize: 12)),
                        selected: isSelected,
                        selectedColor:
                            AppColors.primary.withValues(alpha: 0.2),
                        onSelected: (_) {
                          setSheetState(() {
                            selectedCategory = e.key;
                            suggestions = [];
                          });
                          loadSuggestions(e.key, setSheetState);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Name suggestions
                  if (suggestions.isNotEmpty) ...[
                    Text('Рекомендации',
                        style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                            color: context.textSecondary)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: suggestions.map((s) {
                        return ActionChip(
                          label: Text(s, style: const TextStyle(fontSize: 12)),
                          onPressed: () {
                            setSheetState(() {
                              nameController.text = s;
                              nameController.selection = TextSelection.fromPosition(
                                TextPosition(offset: s.length),
                              );
                            });
                          },
                          backgroundColor: AppColors.primary.withValues(alpha: 0.08),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Name input
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Название привычки',
                      hintText: 'Например: Утренняя зарядка',
                      prefixIcon: Icon(Icons.edit),
                    ),
                    autofocus: true,
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
                        label: Text(e.value, style: const TextStyle(fontSize: 12)),
                        selected: isSelected,
                        selectedColor: AppColors.primary.withValues(alpha: 0.2),
                        onSelected: (_) {
                          setSheetState(() => cooldownDays = e.key);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Daily target (multi-completion)
                  const Text('Раз в день',
                      style: TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [1, 2, 3, 5, 10].map((t) {
                      final isSelected = dailyTarget == t;
                      return ChoiceChip(
                        label: Text(
                          t == 1 ? '1 (обычная)' : '$t раз',
                          style: const TextStyle(fontSize: 12),
                        ),
                        selected: isSelected,
                        selectedColor: AppColors.primary.withValues(alpha: 0.2),
                        onSelected: (_) {
                          setSheetState(() => dailyTarget = t);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Time pickers
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final time = await showTimePicker(
                              context: context,
                              initialTime: targetTime ?? const TimeOfDay(hour: 9, minute: 0),
                            );
                            if (time != null) {
                              setSheetState(() => targetTime = time);
                            }
                          },
                          icon: const Icon(Icons.schedule, size: 18),
                          label: Text(
                            targetTime != null
                                ? 'Выполнять: ${targetTime!.format(context)}'
                                : 'Время выполнения',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final time = await showTimePicker(
                              context: context,
                              initialTime: reminderTime ?? const TimeOfDay(hour: 8, minute: 30),
                            );
                            if (time != null) {
                              setSheetState(() => reminderTime = time);
                            }
                          },
                          icon: const Icon(Icons.notifications_outlined, size: 18),
                          label: Text(
                            reminderTime != null
                                ? 'Напомнить: ${reminderTime!.format(context)}'
                                : 'Напоминание',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Submit
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: isSubmitting ? null : () async {
                        final name = nameController.text.trim();
                        if (name.isEmpty) return;

                        // Check for duplicate habit names
                        final existingHabits = ref.read(habitsProvider).valueOrNull ?? [];
                        if (existingHabits.any((h) => h.name.toLowerCase() == name.toLowerCase())) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Привычка с таким названием уже существует')),
                          );
                          return;
                        }

                        setSheetState(() => isSubmitting = true);
                        String? formatTime(TimeOfDay? t) =>
                            t != null
                                ? '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}'
                                : null;

                        try {
                          await ref.read(habitsProvider.notifier).createHabit({
                            'name': name,
                            'category': selectedCategory,
                            'frequency': 'daily',
                            'cooldown_days': cooldownDays,
                            'daily_target': dailyTarget,
                            'target_time': formatTime(targetTime),
                            'reminder_time': formatTime(reminderTime),
                          });
                          if (mounted) Navigator.pop(ctx);
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Ошибка: $e')),
                            );
                          }
                        } finally {
                          if (mounted) setSheetState(() => isSubmitting = false);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: isSubmitting
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
                            )
                          : const Text('Добавить',
                          style: TextStyle(fontWeight: FontWeight.w600)),
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

  @override
  Widget build(BuildContext context) {
    final habitsAsync = ref.watch(habitsProvider);
    final authState = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Мои привычки'),
            if (authState.user != null)
              Text(
                'Привет, ${authState.user!.username} 👋',
                style: TextStyle(
                    fontSize: 13, color: context.textSecondary),
              ),
          ],
        ),
        actions: [
          if (authState.user != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: UserAvatar(
                avatarUrl: authState.user!.avatarUrl,
                name: authState.user!.username,
                radius: 18,
              ),
            ),
        ],
      ),
      body: habitsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: context.errorColor),
              const SizedBox(height: 16),
              Text('Ошибка загрузки: $e'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () =>
                    ref.read(habitsProvider.notifier).loadHabits(),
                child: const Text('Повторить'),
              ),
            ],
          ),
        ),
        data: (habits) {
          if (habits.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_task,
                      size: 72, color: context.textSecondary),
                  const SizedBox(height: 16),
                  Text('Пока нет привычек',
                      style: TextStyle(
                          fontSize: 18, color: context.textSecondary)),
                  const SizedBox(height: 8),
                  Text('Добавь первую и начни свой путь! 🚀',
                      style: TextStyle(color: context.textSecondary)),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _showAddHabitDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Добавить привычку'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            );
          }

          final todayCompleted =
              habits.where((h) => h.completedToday).length;
          final progress =
              habits.isEmpty ? 0.0 : todayCompleted / habits.length;

          // Sort: uncompleted first, then completed
          final sortedHabits = List<Habit>.from(habits)
            ..sort((a, b) {
              if (a.completedToday == b.completedToday) return 0;
              return a.completedToday ? 1 : -1;
            });

          return RefreshIndicator(
            onRefresh: () =>
                ref.read(habitsProvider.notifier).loadHabits(),
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              children: [
                // Progress header with circular indicator
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 64,
                        height: 64,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            CircularProgressIndicator(
                              value: progress,
                              strokeWidth: 6,
                              backgroundColor:
                                  AppColors.primary.withValues(alpha: 0.15),
                              color: progress >= 1.0
                                  ? AppColors.success
                                  : AppColors.primary,
                            ),
                            Center(
                              child: Text(
                                '${(progress * 100).toInt()}%',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: progress >= 1.0
                                      ? AppColors.success
                                      : AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$todayCompleted из ${habits.length} выполнено',
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              progress >= 1.0
                                  ? '🎉 Отличная работа! Всё выполнено!'
                                  : progress >= 0.5
                                      ? '💪 Хороший прогресс, продолжай!'
                                      : 'Начни свой день правильно!',
                              style: TextStyle(
                                fontSize: 13,
                                color: progress >= 1.0
                                    ? AppColors.success
                                    : context.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Quick AI actions
                SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      _QuickAction(
                        icon: Icons.mood,
                        label: 'Настроение',
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF9800), Color(0xFFFF5722)],
                        ),
                        onTap: () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => const MoodScreen())),
                      ),
                      const SizedBox(width: 8),
                      _QuickAction(
                        icon: Icons.flag,
                        label: 'Челленджи',
                        gradient: AppColors.primaryGradient,
                        onTap: () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => const ChallengesScreen())),
                      ),
                      const SizedBox(width: 8),
                      _QuickAction(
                        icon: Icons.auto_awesome,
                        label: 'Отчёт',
                        gradient: const LinearGradient(
                          colors: [Color(0xFF4FC3F7), Color(0xFF2196F3)],
                        ),
                        onTap: () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => const WeeklyReportScreen())),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Celebration card when 100%
                if (progress >= 1.0)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Card(
                      color: AppColors.success.withValues(alpha: 0.1),
                      child: const Padding(
                        padding: EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Text('🏆', style: TextStyle(fontSize: 32)),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Все привычки на сегодня выполнены! Ты молодец! 🚀',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (progress >= 1.0) const SizedBox(height: 8),
                // Habit list (uncompleted first)
                ...sortedHabits.map((habit) => HabitCard(
                      habit: habit,
                      isCompletedToday: habit.completedToday,
                      onToggle: () {
                        if (habit.dailyTarget > 1) {
                          // Multi-completion: always add +1 unless already done
                          if (!habit.completedToday) {
                            ref.read(habitsProvider.notifier).toggleHabit(
                                habit.id, true);
                          }
                        } else {
                          ref.read(habitsProvider.notifier).toggleHabit(
                              habit.id, !habit.completedToday);
                        }
                      },
                      onDelete: () {
                        ref.read(habitsProvider.notifier).deleteHabit(habit.id);
                      },
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                HabitDetailScreen(habit: habit),
                          ),
                        );
                      },
                    )),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddHabitDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Gradient gradient;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: (gradient as LinearGradient).colors.first.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

