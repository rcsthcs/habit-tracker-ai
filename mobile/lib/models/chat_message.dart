class ChatMessage {
  final int? id;
  final String role;
  final String content;
  final DateTime timestamp;

  ChatMessage({
    this.id,
    required this.role,
    required this.content,
    required this.timestamp,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'],
      role: json['role'],
      content: json['content'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }

  bool get isUser => role == 'user';
  bool get isAssistant => role == 'assistant';
}

class Analytics {
  final int totalHabits;
  final int activeHabits;
  final int todayCompleted;
  final int todayTotal;
  final double overallCompletionRate;
  final int longestStreak;
  final int currentBestStreak;
  final String? mostConsistentHabit;
  final String? mostStruggledHabit;
  final String? optimalTime;
  final List<double> weeklyCompletion;

  Analytics({
    required this.totalHabits,
    required this.activeHabits,
    required this.todayCompleted,
    required this.todayTotal,
    required this.overallCompletionRate,
    required this.longestStreak,
    required this.currentBestStreak,
    this.mostConsistentHabit,
    this.mostStruggledHabit,
    this.optimalTime,
    required this.weeklyCompletion,
  });

  factory Analytics.fromJson(Map<String, dynamic> json) {
    return Analytics(
      totalHabits: json['total_habits'] ?? 0,
      activeHabits: json['active_habits'] ?? 0,
      todayCompleted: json['today_completed'] ?? 0,
      todayTotal: json['today_total'] ?? 0,
      overallCompletionRate: (json['overall_completion_rate'] ?? 0.0).toDouble(),
      longestStreak: json['longest_streak'] ?? 0,
      currentBestStreak: json['current_best_streak'] ?? 0,
      mostConsistentHabit: json['most_consistent_habit'],
      mostStruggledHabit: json['most_struggled_habit'],
      optimalTime: json['optimal_time'],
      weeklyCompletion: (json['weekly_completion'] as List<dynamic>?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          [],
    );
  }
}

class Recommendations {
  final List<Map<String, dynamic>> recommendations;
  final List<String> tips;
  final String motivationMessage;

  Recommendations({
    required this.recommendations,
    required this.tips,
    required this.motivationMessage,
  });

  factory Recommendations.fromJson(Map<String, dynamic> json) {
    return Recommendations(
      recommendations: (json['recommendations'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e))
              .toList() ??
          [],
      tips: (json['tips'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      motivationMessage: json['motivation_message'] ?? '',
    );
  }
}

