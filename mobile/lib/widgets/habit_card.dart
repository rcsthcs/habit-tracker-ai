import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/habit.dart';
import '../core/app_colors.dart';
import '../core/theme_extensions.dart';

class HabitCard extends StatefulWidget {
  final Habit habit;
  final bool isCompletedToday;
  final VoidCallback onToggle;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onDelete;

  const HabitCard({
    super.key,
    required this.habit,
    required this.isCompletedToday,
    required this.onToggle,
    required this.onTap,
    this.onLongPress,
    this.onDelete,
  });

  @override
  State<HabitCard> createState() => _HabitCardState();
}

class _HabitCardState extends State<HabitCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _checkController;
  late Animation<double> _scaleAnim;
  bool _toggling = false;

  @override
  void initState() {
    super.initState();
    _checkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _scaleAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.3), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 1.0), weight: 50),
    ]).animate(
        CurvedAnimation(parent: _checkController, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _checkController.dispose();
    super.dispose();
  }

  void _handleToggle() {
    if (_toggling) return;
    _toggling = true;
    HapticFeedback.lightImpact();
    if (!widget.isCompletedToday) {
      _checkController.forward(from: 0);
    }
    widget.onToggle();
    // Debounce: prevent rapid taps for 600ms
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) _toggling = false;
    });
  }

  Widget _buildMultiCounter() {
    final completions = widget.habit.todayCompletions;
    final target = widget.habit.dailyTarget;
    final done = completions >= target;
    final progress = target > 0 ? (completions / target).clamp(0.0, 1.0) : 0.0;
    return SizedBox(
      width: 40,
      height: 40,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 38,
            height: 38,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 3,
              backgroundColor: widget.habit.colorValue.withValues(alpha: 0.2),
              valueColor: AlwaysStoppedAnimation(
                done ? context.successColor : widget.habit.colorValue,
              ),
            ),
          ),
          done
              ? Icon(Icons.check_rounded, color: context.successColor, size: 18)
              : Text(
                  '$completions/$target',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: widget.habit.colorValue,
                  ),
                ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final card = RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Container(
          decoration: BoxDecoration(
            color: context.isDark
                ? AppColors.darkSurfaceVariant
                : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: widget.isCompletedToday
                  ? context.successColor.withValues(alpha: 0.25)
                  : context.dividerColor,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black
                    .withValues(alpha: context.isDark ? 0.25 : 0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTap,
              onLongPress: widget.onLongPress,
              borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        // Animated checkbox / counter
                        GestureDetector(
                          onTap: _handleToggle,
                          child: ScaleTransition(
                            scale: _scaleAnim,
                            child: widget.habit.dailyTarget > 1
                                ? _buildMultiCounter()
                                : AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeOutCubic,
                                    width: 34,
                                    height: 34,
                                    decoration: BoxDecoration(
                                      gradient: widget.isCompletedToday
                                          ? LinearGradient(
                                              colors: [
                                                widget.habit.colorValue,
                                                widget.habit.colorValue
                                                    .withValues(alpha: 0.7),
                                              ],
                                            )
                                          : null,
                                      color: widget.isCompletedToday
                                          ? null
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: widget.habit.colorValue,
                                        width: 2,
                                      ),
                                      boxShadow: widget.isCompletedToday
                                          ? [
                                              BoxShadow(
                                                color: widget.habit.colorValue
                                                    .withValues(alpha: 0.3),
                                                blurRadius: 8,
                                              ),
                                            ]
                                          : null,
                                    ),
                                    child: widget.isCompletedToday
                                        ? const Icon(Icons.check_rounded,
                                            color: Colors.white, size: 20)
                                        : null,
                                  ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        // Info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.habit.name,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  decoration: widget.isCompletedToday
                                      ? TextDecoration.lineThrough
                                      : null,
                                  color: widget.isCompletedToday
                                      ? context.textSecondary
                                      : context.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Row(
                                children: [
                                  if (widget.habit.currentStreak > 0) ...[
                                    _StreakPill(
                                        streak: widget.habit.currentStreak),
                                    const SizedBox(width: 8),
                                  ],
                                  Icon(Icons.pie_chart_rounded,
                                      size: 13, color: context.textSecondary),
                                  const SizedBox(width: 3),
                                  Text(
                                    '${widget.habit.completionRate.toStringAsFixed(0)}%',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: context.textSecondary),
                                  ),
                                  if (widget.habit.targetTime != null) ...[
                                    const SizedBox(width: 8),
                                    Icon(Icons.schedule_rounded,
                                        size: 13, color: context.textSecondary),
                                    const SizedBox(width: 3),
                                    Text(
                                      widget.habit.targetTime!,
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: context.textSecondary),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Category indicator
                        Container(
                          width: 4,
                          height: 36,
                          decoration: BoxDecoration(
                            color: widget.habit.colorValue,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ],
                    ),
                  ),
            ),
          ),
        ),
      ),
    );

    if (widget.onDelete != null) {
      return Dismissible(
        key: ValueKey(widget.habit.id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 24),
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
          decoration: BoxDecoration(
            gradient: AppColors.accentGradient,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.delete_rounded, color: Colors.white),
        ),
        confirmDismiss: (_) async {
          return await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Удалить привычку?'),
              content: Text('«${widget.habit.name}» будет удалена.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Отмена')),
                TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text('Удалить',
                        style: TextStyle(color: context.errorColor))),
              ],
            ),
          );
        },
        onDismissed: (_) => widget.onDelete!(),
        child: card,
      );
    }

    return card;
  }
}

class _StreakPill extends StatelessWidget {
  final int streak;
  const _StreakPill({required this.streak});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: streak >= 7
              ? [Colors.orange, Colors.deepOrange]
              : [
                  AppColors.primary.withValues(alpha: 0.15),
                  AppColors.secondary.withValues(alpha: 0.1)
                ],
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.local_fire_department,
              size: 12, color: streak >= 7 ? Colors.white : Colors.orange[700]),
          const SizedBox(width: 2),
          Text(
            '$streak дн.',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: streak >= 7 ? Colors.white : Colors.orange[700],
            ),
          ),
        ],
      ),
    );
  }
}
