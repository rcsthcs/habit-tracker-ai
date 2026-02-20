import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';
import '../models/habit.dart';
import '../providers/app_providers.dart';
import '../widgets/habit_card.dart';
import 'habit_detail_screen.dart';

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
    String? targetTime;

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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Новая привычка',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
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
                          AppTheme.primaryColor.withOpacity(0.2),
                      onSelected: (_) {
                        setSheetState(() => selectedCategory = e.key);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (nameController.text.isEmpty) return;
                      await ref.read(habitsProvider.notifier).createHabit({
                        'name': nameController.text,
                        'category': selectedCategory,
                        'frequency': 'daily',
                      });
                      if (mounted) Navigator.pop(ctx);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Добавить',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
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
                style: const TextStyle(
                    fontSize: 13, color: AppTheme.textSecondary),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authProvider.notifier).logout(),
          ),
        ],
      ),
      body: habitsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppTheme.errorColor),
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
                  const Icon(Icons.add_task,
                      size: 72, color: AppTheme.textSecondary),
                  const SizedBox(height: 16),
                  const Text('Пока нет привычек',
                      style: TextStyle(
                          fontSize: 18, color: AppTheme.textSecondary)),
                  const SizedBox(height: 8),
                  const Text('Добавь первую и начни свой путь! 🚀',
                      style: TextStyle(color: AppTheme.textSecondary)),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _showAddHabitDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Добавить привычку'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            );
          }

          final todayCompleted =
              habits.where((h) => h.currentStreak > 0).length;
          final progress =
              habits.isEmpty ? 0.0 : todayCompleted / habits.length;

          return RefreshIndicator(
            onRefresh: () =>
                ref.read(habitsProvider.notifier).loadHabits(),
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              children: [
                // Progress header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Сегодня: $todayCompleted из ${habits.length}',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 8,
                          backgroundColor:
                              AppTheme.primaryColor.withOpacity(0.15),
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Habit list
                ...habits.map((habit) => HabitCard(
                      habit: habit,
                      isCompletedToday: habit.currentStreak > 0,
                      onToggle: () {
                        ref.read(habitsProvider.notifier).toggleHabit(
                            habit.id, habit.currentStreak == 0);
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



