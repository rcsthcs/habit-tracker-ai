import 'dart:ui';

class Habit {
  final int id;
  final int userId;
  final String name;
  final String description;
  final String category;
  final String frequency;
  final int cooldownDays;
  final int dailyTarget;
  final String? targetTime;
  final String? reminderTime;
  final String color;
  final String icon;
  final bool isActive;
  final DateTime createdAt;
  final int currentStreak;
  final int bestStreak;
  final bool completedToday;
  final int todayCompletions;
  final double completionRate;

  Habit({
    required this.id,
    required this.userId,
    required this.name,
    required this.description,
    required this.category,
    required this.frequency,
    this.cooldownDays = 1,
    this.dailyTarget = 1,
    this.targetTime,
    this.reminderTime,
    required this.color,
    required this.icon,
    required this.isActive,
    required this.createdAt,
    this.currentStreak = 0,
    this.bestStreak = 0,
    this.completedToday = false,
    this.todayCompletions = 0,
    this.completionRate = 0.0,
  });

  factory Habit.fromJson(Map<String, dynamic> json) {
    return Habit(
      id: json['id'],
      userId: json['user_id'],
      name: json['name'],
      description: json['description'] ?? '',
      category: json['category'] ?? 'other',
      frequency: json['frequency'] ?? 'daily',
      cooldownDays: json['cooldown_days'] ?? 1,
      dailyTarget: json['daily_target'] ?? 1,
      targetTime: json['target_time'],
      reminderTime: json['reminder_time'],
      color: json['color'] ?? '#4CAF50',
      icon: json['icon'] ?? 'check_circle',
      isActive: json['is_active'] ?? true,
      createdAt: DateTime.parse(json['created_at']),
      currentStreak: json['current_streak'] ?? 0,
      bestStreak: json['best_streak'] ?? 0,
      completedToday: json['completed_today'] ?? false,
      todayCompletions: json['today_completions'] ?? 0,
      completionRate: (json['completion_rate'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toCreateJson() {
    return {
      'name': name,
      'description': description,
      'category': category,
      'frequency': frequency,
      'cooldown_days': cooldownDays,
      'daily_target': dailyTarget,
      'target_time': targetTime,
      'reminder_time': reminderTime,
      'color': color,
      'icon': icon,
    };
  }

  Color get colorValue {
    try {
      return Color(int.parse(color.replaceFirst('#', '0xFF')));
    } catch (_) {
      return const Color(0xFF4CAF50);
    }
  }
}
