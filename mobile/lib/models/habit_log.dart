class HabitLog {
  final int id;
  final int habitId;
  final DateTime date;
  final bool completed;
  final DateTime? completedAt;
  final String? note;
  final String? skippedReason;
  final DateTime createdAt;

  HabitLog({
    required this.id,
    required this.habitId,
    required this.date,
    required this.completed,
    this.completedAt,
    this.note,
    this.skippedReason,
    required this.createdAt,
  });

  factory HabitLog.fromJson(Map<String, dynamic> json) {
    return HabitLog(
      id: json['id'],
      habitId: json['habit_id'],
      date: DateTime.parse(json['date']),
      completed: json['completed'] ?? false,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'])
          : null,
      note: json['note'],
      skippedReason: json['skipped_reason'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}

