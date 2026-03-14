import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/app_colors.dart';
import '../models/habit.dart';
import '../providers/app_providers.dart';

class EditHabitScreen extends ConsumerStatefulWidget {
  final Habit habit;

  const EditHabitScreen({super.key, required this.habit});

  @override
  ConsumerState<EditHabitScreen> createState() => _EditHabitScreenState();
}

class _EditHabitScreenState extends ConsumerState<EditHabitScreen> {
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late String _selectedCategory;
  late int _cooldownDays;
  late int _dailyTarget;
  TimeOfDay? _targetTime;
  TimeOfDay? _reminderTime;
  bool _saving = false;

  final _categories = {
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

  final _cooldownOptions = {
    1: 'Каждый день',
    2: 'Через день',
    3: 'Раз в 3 дня',
    7: 'Раз в неделю',
  };

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.habit.name);
    _descriptionController =
        TextEditingController(text: widget.habit.description);
    _selectedCategory = widget.habit.category;
    _cooldownDays = widget.habit.cooldownDays;
    _dailyTarget = widget.habit.dailyTarget;
    _targetTime = _parseTime(widget.habit.targetTime);
    _reminderTime = _parseTime(widget.habit.reminderTime);
  }

  TimeOfDay? _parseTime(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return null;
    final parts = timeStr.split(':');
    if (parts.length >= 2) {
      return TimeOfDay(
          hour: int.tryParse(parts[0]) ?? 0,
          minute: int.tryParse(parts[1]) ?? 0);
    }
    return null;
  }

  String? _formatTime(TimeOfDay? t) =>
      t != null
          ? '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}'
          : null;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) return;
    setState(() => _saving = true);

    try {
      final api = ref.read(apiServiceProvider);
      await api.updateHabit(widget.habit.id, {
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'category': _selectedCategory,
        'cooldown_days': _cooldownDays,
        'daily_target': _dailyTarget,
        'target_time': _formatTime(_targetTime),
        'reminder_time': _formatTime(_reminderTime),
      });
      await ref.read(habitsProvider.notifier).loadHabits();
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка сохранения: $e')),
        );
      }
    }
    setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Редактировать привычку'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Сохранить',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Name
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Название привычки',
              prefixIcon: Icon(Icons.edit),
            ),
          ),
          const SizedBox(height: 16),

          // Description
          TextField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              labelText: 'Описание (необязательно)',
              prefixIcon: Icon(Icons.description_outlined),
            ),
            maxLines: 3,
            minLines: 1,
          ),
          const SizedBox(height: 20),

          // Category
          const Text('Категория',
              style: TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _categories.entries.map((e) {
              final isSelected = _selectedCategory == e.key;
              return ChoiceChip(
                label: Text(e.value, style: const TextStyle(fontSize: 12)),
                selected: isSelected,
                selectedColor: AppColors.primary.withValues(alpha: 0.2),
                onSelected: (_) =>
                    setState(() => _selectedCategory = e.key),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          // Cooldown
          const Text('Частота выполнения',
              style: TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _cooldownOptions.entries.map((e) {
              final isSelected = _cooldownDays == e.key;
              return ChoiceChip(
                label: Text(e.value, style: const TextStyle(fontSize: 12)),
                selected: isSelected,
                selectedColor: AppColors.primary.withValues(alpha: 0.2),
                onSelected: (_) =>
                    setState(() => _cooldownDays = e.key),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          // Daily target
          const Text('Раз в день',
              style: TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [1, 2, 3, 5, 10].map((t) {
              final isSelected = _dailyTarget == t;
              return ChoiceChip(
                label: Text(
                  t == 1 ? '1 (обычная)' : '$t раз',
                  style: const TextStyle(fontSize: 12),
                ),
                selected: isSelected,
                selectedColor: AppColors.primary.withValues(alpha: 0.2),
                onSelected: (_) => setState(() => _dailyTarget = t),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          // Time pickers
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime:
                          _targetTime ?? const TimeOfDay(hour: 9, minute: 0),
                    );
                    if (time != null) {
                      setState(() => _targetTime = time);
                    }
                  },
                  icon: const Icon(Icons.schedule, size: 18),
                  label: Text(
                    _targetTime != null
                        ? 'Выполнять: ${_targetTime!.format(context)}'
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
                      initialTime: _reminderTime ??
                          const TimeOfDay(hour: 8, minute: 30),
                    );
                    if (time != null) {
                      setState(() => _reminderTime = time);
                    }
                  },
                  icon: const Icon(Icons.notifications_outlined, size: 18),
                  label: Text(
                    _reminderTime != null
                        ? 'Напомнить: ${_reminderTime!.format(context)}'
                        : 'Напоминание',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Clear times
          if (_targetTime != null || _reminderTime != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => setState(() {
                  _targetTime = null;
                  _reminderTime = null;
                }),
                icon: const Icon(Icons.clear, size: 16),
                label: const Text('Сбросить время',
                    style: TextStyle(fontSize: 12)),
              ),
            ),
        ],
      ),
    );
  }
}

