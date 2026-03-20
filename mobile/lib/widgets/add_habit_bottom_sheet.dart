import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/app_colors.dart';
import '../core/theme_extensions.dart';
import '../providers/app_providers.dart';

class HabitDraft {
  final String name;
  final String? description;
  final String category;
  final int cooldownDays;
  final int dailyTarget;
  final String? targetTime;
  final String? reminderTime;
  final String? folder;

  const HabitDraft({
    required this.name,
    this.description,
    this.category = 'health',
    this.cooldownDays = 1,
    this.dailyTarget = 1,
    this.targetTime,
    this.reminderTime,
    this.folder,
  });
}

Future<bool> showAddHabitBottomSheet({
  required BuildContext context,
  required WidgetRef ref,
  HabitDraft? draft,
  String title = 'Новая привычка',
}) async {
  final nameController = TextEditingController(text: draft?.name ?? '');
  final descriptionController = TextEditingController(
    text: draft?.description ?? '',
  );
  var selectedCategory = draft?.category ?? 'health';
  var cooldownDays = draft?.cooldownDays ?? 1;
  var dailyTarget = draft?.dailyTarget ?? 1;
  TimeOfDay? targetTime = _parseTimeOfDay(draft?.targetTime);
  TimeOfDay? reminderTime = _parseTimeOfDay(draft?.reminderTime);
  List<String> suggestions = [];
  var isSubmitting = false;

  // Extract existing folder names from all habits
  final allHabits = ref.read(habitsProvider).valueOrNull ?? [];
  final existingFolders = <String>{};
  for (final h in allHabits) {
    final f = extractFolderFromDescription(h.description);
    if (f != null && f.isNotEmpty) existingFolders.add(f);
  }
  String? selectedFolder = draft?.folder ?? (draft?.description != null
      ? extractFolderFromDescription(draft!.description!)
      : null);

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

  Future<void> loadSuggestions(
      String category, StateSetter setSheetState) async {
    try {
      final api = ref.read(apiServiceProvider);
      final result = await api.getHabitSuggestions(category);
      setSheetState(() => suggestions = result);
    } catch (_) {
      setSheetState(() => suggestions = []);
    }
  }

  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) {
      return StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          if (suggestions.isEmpty) {
            loadSuggestions(selectedCategory, setSheetState);
          }

          return Padding(
            padding: EdgeInsets.fromLTRB(
              24,
              24,
              24,
              MediaQuery.of(sheetContext).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Название привычки',
                      hintText: 'Например: Утренняя зарядка',
                      prefixIcon: Icon(Icons.edit),
                    ),
                    autofocus: draft == null,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descriptionController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Описание (необязательно)',
                      prefixIcon: Icon(Icons.description_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Категория',
                      style: TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: categories.entries.map((entry) {
                      final isSelected = selectedCategory == entry.key;
                      return ChoiceChip(
                        label: Text(entry.value,
                            style: const TextStyle(fontSize: 12)),
                        selected: isSelected,
                        selectedColor: AppColors.primary.withValues(alpha: 0.2),
                        onSelected: (_) {
                          setSheetState(() {
                            selectedCategory = entry.key;
                            suggestions = [];
                          });
                          loadSuggestions(entry.key, setSheetState);
                        },
                      );
                    }).toList(),
                  ),
                  if (suggestions.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(
                      'Рекомендации',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                        color: sheetContext.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: suggestions.map((suggestion) {
                        return ActionChip(
                          label: Text(suggestion,
                              style: const TextStyle(fontSize: 12)),
                          onPressed: () {
                            setSheetState(() {
                              nameController.text = suggestion;
                              nameController.selection =
                                  TextSelection.fromPosition(
                                TextPosition(offset: suggestion.length),
                              );
                            });
                          },
                          backgroundColor:
                              AppColors.primary.withValues(alpha: 0.08),
                        );
                      }).toList(),
                    ),
                  ],
                  const SizedBox(height: 16),
                  const Text('Частота выполнения',
                      style: TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: cooldownOptions.entries.map((entry) {
                      final isSelected = cooldownDays == entry.key;
                      return ChoiceChip(
                        label: Text(entry.value,
                            style: const TextStyle(fontSize: 12)),
                        selected: isSelected,
                        selectedColor: AppColors.primary.withValues(alpha: 0.2),
                        onSelected: (_) =>
                            setSheetState(() => cooldownDays = entry.key),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  const Text('Раз в день',
                      style: TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [1, 2, 3, 5, 10].map((target) {
                      final isSelected = dailyTarget == target;
                      return ChoiceChip(
                        label: Text(
                          target == 1 ? '1 (обычная)' : '$target раз',
                          style: const TextStyle(fontSize: 12),
                        ),
                        selected: isSelected,
                        selectedColor: AppColors.primary.withValues(alpha: 0.2),
                        onSelected: (_) =>
                            setSheetState(() => dailyTarget = target),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final picked = await showTimePicker(
                              context: sheetContext,
                              initialTime: targetTime ??
                                  const TimeOfDay(hour: 9, minute: 0),
                            );
                            if (picked != null) {
                              setSheetState(() => targetTime = picked);
                            }
                          },
                          icon: const Icon(Icons.schedule, size: 18),
                          label: Text(
                            targetTime != null
                                ? 'Выполнять: ${targetTime!.format(sheetContext)}'
                                : 'Время выполнения',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final picked = await showTimePicker(
                              context: sheetContext,
                              initialTime: reminderTime ??
                                  const TimeOfDay(hour: 8, minute: 30),
                            );
                            if (picked != null) {
                              setSheetState(() => reminderTime = picked);
                            }
                          },
                          icon: const Icon(Icons.notifications_outlined,
                              size: 18),
                          label: Text(
                            reminderTime != null
                                ? 'Напомнить: ${reminderTime!.format(sheetContext)}'
                                : 'Напоминание',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('Папка (необязательно)',
                      style: TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('Без папки',
                            style: TextStyle(fontSize: 12)),
                        selected: selectedFolder == null,
                        selectedColor: AppColors.primary.withValues(alpha: 0.2),
                        onSelected: (_) =>
                            setSheetState(() => selectedFolder = null),
                      ),
                      ...existingFolders.map((folder) => ChoiceChip(
                            label: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.folder_rounded,
                                    size: 14, color: AppColors.primary),
                                const SizedBox(width: 4),
                                Text(folder,
                                    style: const TextStyle(fontSize: 12)),
                              ],
                            ),
                            selected: selectedFolder == folder,
                            selectedColor:
                                AppColors.primary.withValues(alpha: 0.2),
                            onSelected: (_) =>
                                setSheetState(() => selectedFolder = folder),
                          )),
                      ActionChip(
                        avatar: const Icon(Icons.create_new_folder_outlined,
                            size: 14),
                        label: const Text('Создать папку',
                            style: TextStyle(fontSize: 12)),
                        onPressed: () async {
                          final result = await _showCreateFolderDialog(
                              sheetContext, existingFolders.toList());
                          if (result != null && result.isNotEmpty) {
                            existingFolders.add(result);
                            setSheetState(() => selectedFolder = result);
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              final name = nameController.text.trim();
                              if (name.isEmpty) return;

                              final existingHabits =
                                  ref.read(habitsProvider).valueOrNull ?? [];
                              if (existingHabits.any((h) =>
                                  h.name.toLowerCase() == name.toLowerCase())) {
                                if (!sheetContext.mounted) return;
                                ScaffoldMessenger.of(sheetContext).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        'Привычка с таким названием уже существует'),
                                  ),
                                );
                                return;
                              }

                              setSheetState(() => isSubmitting = true);
                              try {
                                final rawDesc =
                                    descriptionController.text.trim();
                                final finalDesc = setFolderInDescription(
                                    rawDesc, selectedFolder);
                                await ref
                                    .read(habitsProvider.notifier)
                                    .createHabit({
                                  'name': name,
                                  'description': finalDesc,
                                  'category': selectedCategory,
                                  'frequency': 'daily',
                                  'cooldown_days': cooldownDays,
                                  'daily_target': dailyTarget,
                                  'target_time': _formatTimeOfDay(targetTime),
                                  'reminder_time':
                                      _formatTimeOfDay(reminderTime),
                                });
                                if (ctx.mounted) Navigator.pop(ctx, true);
                              } catch (e) {
                                if (!sheetContext.mounted) return;
                                ScaffoldMessenger.of(sheetContext).showSnackBar(
                                  SnackBar(content: Text('Ошибка: $e')),
                                );
                              } finally {
                                if (sheetContext.mounted) {
                                  setSheetState(() => isSubmitting = false);
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: isSubmitting
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Добавить',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );

  return saved == true;
}

TimeOfDay? _parseTimeOfDay(String? value) {
  if (value == null || !value.contains(':')) return null;
  final parts = value.split(':');
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts.length > 1 ? parts[1] : '0');
  if (hour == null || minute == null) return null;
  return TimeOfDay(hour: hour, minute: minute);
}

String? _formatTimeOfDay(TimeOfDay? value) {
  if (value == null) return null;
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

Future<String?> _showCreateFolderDialog(
    BuildContext context, List<String> existingFolders) async {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Новая папка'),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'Название папки',
          prefixIcon: Icon(Icons.folder_rounded),
        ),
        textCapitalization: TextCapitalization.sentences,
        onSubmitted: (_) {
          final name = controller.text.trim();
          if (name.isNotEmpty) Navigator.pop(ctx, name);
        },
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена')),
        FilledButton(
          onPressed: () {
            final name = controller.text.trim();
            if (name.isNotEmpty) Navigator.pop(ctx, name);
          },
          child: const Text('Создать'),
        ),
      ],
    ),
  );
}

/// Public helper to pick/create a folder.
/// Returns: null if cancelled, '' (empty string) if "Без папки" selected,
/// or folder name string if a folder is chosen/created.
Future<String?> showFolderPickerSheet({
  required BuildContext context,
  required List<String> existingFolders,
  String? currentFolder,
}) async {
  String? selected = currentFolder;
  final newFolders = List<String>.from(existingFolders);

  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => StatefulBuilder(
      builder: (sheetCtx, setState) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
              20, 8, 20, MediaQuery.viewInsetsOf(ctx).bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Выбери папку',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Без папки'),
                    selected: selected == '',
                    selectedColor: AppColors.primary.withValues(alpha: 0.2),
                    onSelected: (_) => setState(() => selected = ''),
                  ),
                  ...newFolders.map((f) => ChoiceChip(
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.folder_rounded,
                                size: 14, color: AppColors.primary),
                            const SizedBox(width: 4),
                            Text(f),
                          ],
                        ),
                        selected: selected == f,
                        selectedColor: AppColors.primary.withValues(alpha: 0.2),
                        onSelected: (_) => setState(() => selected = f),
                      )),
                  ActionChip(
                    avatar: const Icon(Icons.create_new_folder_outlined,
                        size: 14),
                    label: const Text('Создать'),
                    onPressed: () async {
                      final result =
                          await _showCreateFolderDialog(ctx, newFolders);
                      if (result != null && result.isNotEmpty) {
                        newFolders.add(result);
                        setState(() => selected = result);
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: selected == null
                      ? null
                      : () => Navigator.pop(ctx, selected),
                  child: const Text('Применить'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
