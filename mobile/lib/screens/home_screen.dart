import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/app_animations.dart';
import '../core/app_colors.dart';
import '../core/theme_extensions.dart';
import '../models/habit.dart';
import '../providers/app_providers.dart';
import '../widgets/add_habit_bottom_sheet.dart';
import '../widgets/habit_card.dart';
import '../widgets/shimmer_loader.dart';
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
  bool _selectionMode = false;
  final Set<int> _selectedHabitIds = {};
  String _selectedGroupKey = 'all';

  static const double _habitListBottomPadding = 116;

  int? _parseHour(String? hhmm) {
    if (hhmm == null || hhmm.isEmpty || !hhmm.contains(':')) return null;
    return int.tryParse(hhmm.split(':').first);
  }

  String _inferAutoGroup(Habit habit) {
    final category = habit.category.toLowerCase();
    final lowerName = habit.name.toLowerCase();
    final lowerDescription = habit.description.toLowerCase();

    if (category == 'sleep' || lowerName.contains('сон')) return 'sleep_well';
    if (category == 'productivity' || category == 'learning') return 'focus';
    if (category == 'health' ||
        category == 'fitness' ||
        category == 'nutrition') {
      return 'health';
    }

    if (lowerDescription.contains('папка:')) {
      const marker = 'папка:';
      final idx = lowerDescription.indexOf(marker);
      if (idx >= 0) {
        final value = lowerDescription.substring(idx + marker.length).trim();
        if (value.isNotEmpty) return 'custom:$value';
      }
    }
    return 'other';
  }

  String _groupLabel(String groupKey) {
    switch (groupKey) {
      case 'all':
        return 'Все';
      case 'sleep_well':
        return 'Для хорошего сна';
      case 'focus':
        return 'Фокус и рост';
      case 'health':
        return 'Здоровый ритм';
      case 'other':
        return 'Разное';
      default:
        if (groupKey.startsWith('custom:')) {
          return groupKey.substring('custom:'.length);
        }
        return groupKey;
    }
  }

  List<Habit> _applyTimeFilter(List<Habit> habits, int tabIndex) {
    if (tabIndex == 0) return habits;
    return habits.where((h) {
      final hour = _parseHour(h.targetTime);
      if (hour == null) return false;
      if (tabIndex == 1) return hour < 12;
      if (tabIndex == 2) return hour >= 12 && hour < 18;
      return hour >= 18;
    }).toList();
  }

  List<Habit> _applyGroupFilter(List<Habit> habits, String selectedGroup) {
    if (selectedGroup == 'all') return habits;
    return habits.where((h) => _inferAutoGroup(h) == selectedGroup).toList();
  }

  Future<void> _moveSelectedToFolder(List<Habit> allHabits) async {
    if (_selectedHabitIds.isEmpty) return;

    // Extract existing folder names
    final existingFolders = <String>{};
    for (final h in allHabits) {
      final f = extractFolderFromDescription(h.description);
      if (f != null && f.isNotEmpty) existingFolders.add(f);
    }

    final result = await showFolderPickerSheet(
      context: context,
      existingFolders: existingFolders.toList(),
      currentFolder: null,
    );
    if (result == null || !mounted) return;

    final folderName = result.isEmpty ? null : result;
    final ids = _selectedHabitIds.toList();

    await ref.read(habitsProvider.notifier).moveHabitsToFolder(ids, folderName);

    if (!mounted) return;
    setState(() {
      _selectedHabitIds.clear();
      _selectionMode = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(folderName == null
            ? 'Привычки убраны из папок'
            : 'Перемещено в папку «$folderName»'),
      ),
    );
  }

  Future<void> _deleteSelectedHabits() async {

    final shouldDelete = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Удалить выбранные привычки?'),
            content: Text('Будут удалены: ${_selectedHabitIds.length} шт.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Отмена'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Удалить'),
              ),
            ],
          ),
        ) ??
        false;

    if (!shouldDelete) return;

    final ids = _selectedHabitIds.toList();
    for (final id in ids) {
      await ref.read(habitsProvider.notifier).deleteHabit(id);
    }

    if (!mounted) return;
    setState(() {
      _selectedHabitIds.clear();
      _selectionMode = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Выбранные привычки удалены')),
    );
  }

  void _onHabitLongPress(int habitId) {
    HapticFeedback.mediumImpact();
    setState(() {
      _selectionMode = true;
      if (_selectedHabitIds.contains(habitId)) {
        _selectedHabitIds.remove(habitId);
      } else {
        _selectedHabitIds.add(habitId);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(habitsProvider.notifier).loadHabits());
  }

  Future<void> _showAddHabitDialog() async {
    await showAddHabitBottomSheet(context: context, ref: ref);
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
            Text(_selectionMode
                ? 'Выбрано: ${_selectedHabitIds.length}'
                : 'Мои привычки'),
            if (authState.user != null)
              Text(
                'Привет, ${authState.user!.username} 👋',
                style: TextStyle(fontSize: 13, color: context.textSecondary),
              ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: _selectionMode ? 'Отменить выбор' : 'Выбрать несколько',
            onPressed: () {
              setState(() {
                _selectionMode = !_selectionMode;
                if (!_selectionMode) _selectedHabitIds.clear();
              });
            },
            icon: Icon(_selectionMode ? Icons.close : Icons.checklist_rounded),
          ),
          if (_selectionMode)
            IconButton(
              tooltip: 'Переместить в папку',
              onPressed: _selectedHabitIds.isEmpty
                  ? null
                  : () => _moveSelectedToFolder(habitsAsync.valueOrNull ?? []),
              icon: const Icon(Icons.drive_file_move_rounded),
            ),
          if (_selectionMode)
            IconButton(
              tooltip: 'Удалить выбранные',
              onPressed:
                  _selectedHabitIds.isEmpty ? null : _deleteSelectedHabits,
              icon: const Icon(Icons.delete_sweep_rounded),
            ),
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
        loading: () => const ShimmerLoader(shape: ShimmerShape.card, count: 7),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: context.errorColor),
              const SizedBox(height: 16),
              Text('Ошибка загрузки: $e'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.read(habitsProvider.notifier).loadHabits(),
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
                  Icon(Icons.add_task, size: 72, color: context.textSecondary),
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

          final todayCompleted = habits.where((h) => h.completedToday).length;
          final progress =
              habits.isEmpty ? 0.0 : todayCompleted / habits.length;

          // Sort: uncompleted first, then completed
          final sortedHabits = List<Habit>.from(habits)
            ..sort((a, b) {
              if (a.completedToday == b.completedToday) return 0;
              return a.completedToday ? 1 : -1;
            });

          final availableGroups = <String>{'all'};
          for (final habit in sortedHabits) {
            availableGroups.add(_inferAutoGroup(habit));
          }
          if (!availableGroups.contains(_selectedGroupKey)) {
            _selectedGroupKey = 'all';
          }

          final bottomSafePadding =
              MediaQuery.paddingOf(context).bottom + _habitListBottomPadding;

          return DefaultTabController(
            length: 4,
            child: RefreshIndicator(
              onRefresh: () => ref.read(habitsProvider.notifier).loadHabits(),
              child: NestedScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                headerSliverBuilder: (context, innerBoxIsScrolled) {
                  return [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 64,
                              height: 64,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  TweenAnimationBuilder<double>(
                                    duration: const Duration(milliseconds: 650),
                                    curve: Curves.easeOutCubic,
                                    tween:
                                        Tween<double>(begin: 0, end: progress),
                                    builder: (context, animatedValue, _) {
                                      return CircularProgressIndicator(
                                        value: animatedValue,
                                        strokeWidth: 6,
                                        backgroundColor: AppColors.primary
                                            .withValues(alpha: 0.15),
                                        color: progress >= 1.0
                                            ? AppColors.success
                                            : AppColors.primary,
                                      );
                                    },
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
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
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
                      )
                          .animate()
                          .fadeIn(
                            duration: AppAnimations.normal.inMilliseconds.ms,
                            curve: AppAnimations.enterCurve,
                          )
                          .slideY(begin: 0.08, curve: AppAnimations.enterCurve),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: SizedBox(
                          height: 44,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            children: [
                              _QuickAction(
                                icon: Icons.mood,
                                label: 'Настроение',
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFFFF9800),
                                    Color(0xFFFF5722)
                                  ],
                                ),
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const MoodScreen(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              _QuickAction(
                                icon: Icons.flag,
                                label: 'Челленджи',
                                gradient: AppColors.primaryGradient,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const ChallengesScreen(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              _QuickAction(
                                icon: Icons.auto_awesome,
                                label: 'Отчёт',
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF4FC3F7),
                                    Color(0xFF2196F3)
                                  ],
                                ),
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const WeeklyReportScreen(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ).animate().fadeIn(
                              delay: 80.ms,
                              duration: AppAnimations.fast.inMilliseconds.ms,
                              curve: AppAnimations.enterCurve,
                            ),
                      ),
                    ),
                    if (progress >= 1.0)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
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
                      ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.only(top: progress >= 1.0 ? 8 : 12),
                        child: SizedBox(
                          height: 40,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            children: availableGroups.map((groupKey) {
                              final isSelected = groupKey == _selectedGroupKey;
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: Text(_groupLabel(groupKey)),
                                  selected: isSelected,
                                  onSelected: (_) {
                                    setState(() {
                                      _selectedGroupKey = groupKey;
                                    });
                                  },
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _SliverTabBarDelegate(
                        child: Container(
                          color: context.backgroundColor,
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                          child: const TabBar(
                            isScrollable: true,
                            tabs: [
                              Tab(text: 'Все'),
                              Tab(text: 'Утро'),
                              Tab(text: 'День'),
                              Tab(text: 'Вечер'),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ];
                },
                body: TabBarView(
                  children: List.generate(4, (tabIndex) {
                    final byTime = _applyTimeFilter(sortedHabits, tabIndex);
                    final visible =
                        _applyGroupFilter(byTime, _selectedGroupKey);

                    if (visible.isEmpty) {
                      return ListView(
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        padding: EdgeInsets.only(bottom: bottomSafePadding),
                        children: [
                          SizedBox(
                              height: MediaQuery.sizeOf(context).height * 0.18),
                          Center(
                            child: Text(
                              'Нет привычек в этом разделе',
                              style: TextStyle(color: context.textSecondary),
                            ),
                          ),
                        ],
                      );
                    }

                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      padding:
                          EdgeInsets.only(bottom: bottomSafePadding, top: 4),
                      children: visible.asMap().entries.map((entry) {
                        final index = entry.key;
                        final habit = entry.value;
                        if (_selectionMode) {
                          final selected = _selectedHabitIds.contains(habit.id);
                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            child: CheckboxListTile(
                              value: selected,
                              onChanged: (v) {
                                setState(() {
                                  if (v == true) {
                                    _selectedHabitIds.add(habit.id);
                                  } else {
                                    _selectedHabitIds.remove(habit.id);
                                  }
                                });
                              },
                              title: Text(habit.name),
                              subtitle: Text(
                                '${_groupLabel(_inferAutoGroup(habit))} • ${habit.targetTime ?? 'без времени'}',
                              ),
                            ),
                          ).animate().fadeIn(
                                delay: (index * 35).ms,
                                duration: AppAnimations.fast.inMilliseconds.ms,
                                curve: AppAnimations.enterCurve,
                              );
                        }

                        return HabitCard(
                          habit: habit,
                          isCompletedToday: habit.completedToday,
                          onToggle: () {
                            if (habit.dailyTarget > 1) {
                              if (!habit.completedToday) {
                                ref
                                    .read(habitsProvider.notifier)
                                    .toggleHabit(habit.id, true);
                              }
                            } else {
                              ref.read(habitsProvider.notifier).toggleHabit(
                                    habit.id,
                                    !habit.completedToday,
                                  );
                            }
                          },
                          onDelete: () {
                            ref
                                .read(habitsProvider.notifier)
                                .deleteHabit(habit.id);
                          },
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => HabitDetailScreen(habit: habit),
                              ),
                            );
                          },
                          onLongPress: () => _onHabitLongPress(habit.id),
                        )
                            .animate()
                            .fadeIn(
                              delay: (index * 40).ms,
                              duration: AppAnimations.fast.inMilliseconds.ms,
                              curve: AppAnimations.enterCurve,
                            )
                            .slideX(
                              begin: 0.04,
                              end: 0,
                              curve: AppAnimations.enterCurve,
                            );
                      }).toList(),
                    );
                  }),
                ),
              ),
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
                color: (gradient as LinearGradient)
                    .colors
                    .first
                    .withValues(alpha: 0.3),
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

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;

  const _SliverTabBarDelegate({required this.child});

  @override
  double get minExtent => 68;

  @override
  double get maxExtent => 68;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return child;
  }

  @override
  bool shouldRebuild(covariant _SliverTabBarDelegate oldDelegate) {
    return oldDelegate.child != child;
  }
}
