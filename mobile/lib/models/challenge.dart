/// Challenge model.
class Challenge {
  final int id;
  final int userId;
  final String type;
  final String status;
  final String title;
  final String description;
  final int? targetHabitId;
  final int targetCount;
  final int currentCount;
  final String rewardText;
  final DateTime startDate;
  final DateTime endDate;
  final DateTime? completedAt;
  final DateTime createdAt;
  final double progressPct;

  Challenge({
    required this.id,
    required this.userId,
    required this.type,
    required this.status,
    required this.title,
    required this.description,
    this.targetHabitId,
    required this.targetCount,
    required this.currentCount,
    required this.rewardText,
    required this.startDate,
    required this.endDate,
    this.completedAt,
    required this.createdAt,
    this.progressPct = 0,
  });

  bool get isActive => status == 'active';
  bool get isCompleted => status == 'completed';

  factory Challenge.fromJson(Map<String, dynamic> json) {
    return Challenge(
      id: json['id'],
      userId: json['user_id'],
      type: json['type'],
      status: json['status'],
      title: json['title'],
      description: json['description'],
      targetHabitId: json['target_habit_id'],
      targetCount: json['target_count'],
      currentCount: json['current_count'],
      rewardText: json['reward_text'] ?? '',
      startDate: DateTime.parse(json['start_date']),
      endDate: DateTime.parse(json['end_date']),
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'])
          : null,
      createdAt: DateTime.parse(json['created_at']),
      progressPct: (json['progress_pct'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// Streak recovery info.
class StreakRecovery {
  final int habitId;
  final String habitName;
  final int lostStreak;
  final String recoveryMessage;
  final Challenge? challenge;

  StreakRecovery({
    required this.habitId,
    required this.habitName,
    required this.lostStreak,
    required this.recoveryMessage,
    this.challenge,
  });

  factory StreakRecovery.fromJson(Map<String, dynamic> json) {
    return StreakRecovery(
      habitId: json['habit_id'],
      habitName: json['habit_name'],
      lostStreak: json['lost_streak'],
      recoveryMessage: json['recovery_message'],
      challenge: json['challenge'] != null
          ? Challenge.fromJson(json['challenge'])
          : null,
    );
  }
}

/// Weekly report model.
class WeeklyReport {
  final int id;
  final int userId;
  final DateTime weekStart;
  final DateTime weekEnd;
  final int totalHabits;
  final int completedCount;
  final double completionRate;
  final String? bestHabit;
  final String? worstHabit;
  final int longestStreak;
  final double? moodAvg;
  final String? aiSummary;
  final List<String> aiTips;
  final DateTime createdAt;

  WeeklyReport({
    required this.id,
    required this.userId,
    required this.weekStart,
    required this.weekEnd,
    required this.totalHabits,
    required this.completedCount,
    required this.completionRate,
    this.bestHabit,
    this.worstHabit,
    required this.longestStreak,
    this.moodAvg,
    this.aiSummary,
    required this.aiTips,
    required this.createdAt,
  });

  factory WeeklyReport.fromJson(Map<String, dynamic> json) {
    return WeeklyReport(
      id: json['id'],
      userId: json['user_id'],
      weekStart: DateTime.parse(json['week_start']),
      weekEnd: DateTime.parse(json['week_end']),
      totalHabits: json['total_habits'],
      completedCount: json['completed_count'],
      completionRate: (json['completion_rate'] as num).toDouble(),
      bestHabit: json['best_habit'],
      worstHabit: json['worst_habit'],
      longestStreak: json['longest_streak'],
      moodAvg: json['mood_avg'] != null
          ? (json['mood_avg'] as num).toDouble()
          : null,
      aiSummary: json['ai_summary'],
      aiTips: json['ai_tips'] != null ? List<String>.from(json['ai_tips']) : [],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
