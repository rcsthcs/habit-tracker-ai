import 'package:flutter/material.dart';
import '../models/habit.dart';
import '../core/theme.dart';

class HabitCard extends StatelessWidget {
  final Habit habit;
  final bool isCompletedToday;
  final VoidCallback onToggle;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const HabitCard({
    super.key,
    required this.habit,
    required this.isCompletedToday,
    required this.onToggle,
    required this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final card = Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Checkbox
              GestureDetector(
                onTap: onToggle,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isCompletedToday
                        ? habit.colorValue
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: habit.colorValue,
                      width: 2,
                    ),
                  ),
                  child: isCompletedToday
                      ? const Icon(Icons.check, color: Colors.white, size: 20)
                      : null,
                ),
              ),
              const SizedBox(width: 16),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      habit.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        decoration: isCompletedToday
                            ? TextDecoration.lineThrough
                            : null,
                        color: isCompletedToday
                            ? AppTheme.textSecondary
                            : AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (habit.currentStreak > 0) ...[
                          Icon(Icons.local_fire_department,
                              size: 14, color: Colors.orange[700]),
                          const SizedBox(width: 2),
                          Text(
                            '${habit.currentStreak} дн.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        Icon(Icons.pie_chart,
                            size: 14, color: AppTheme.textSecondary),
                        const SizedBox(width: 2),
                        Text(
                          '${habit.completionRate.toStringAsFixed(0)}%',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        if (habit.targetTime != null) ...[
                          const SizedBox(width: 12),
                          Icon(Icons.schedule,
                              size: 14, color: AppTheme.textSecondary),
                          const SizedBox(width: 2),
                          Text(
                            habit.targetTime!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // Category color dot + cooldown indicator
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: habit.colorValue,
                      shape: BoxShape.circle,
                    ),
                  ),
                  if (habit.cooldownDays > 1) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${habit.cooldownDays}д',
                      style: const TextStyle(
                          fontSize: 9, color: AppTheme.textSecondary),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (onDelete != null) {
      return Dismissible(
        key: ValueKey(habit.id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 24),
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
          decoration: BoxDecoration(
            color: AppTheme.errorColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.delete, color: Colors.white),
        ),
        confirmDismiss: (_) async {
          return await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Удалить привычку?'),
              content: Text('«${habit.name}» будет удалена.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Отмена')),
                TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Удалить',
                        style: TextStyle(color: AppTheme.errorColor))),
              ],
            ),
          );
        },
        onDismissed: (_) => onDelete!(),
        child: card,
      );
    }

    return card;
  }
}

