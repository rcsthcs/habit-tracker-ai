class ChatHabitSuggestion {
  final String title;
  final String category;
  final String frequency;
  final String? timeOfDay;
  final String? reason;
  final String? description;
  final int cooldownDays;
  final int dailyTarget;
  final String? targetTime;
  final String? reminderTime;
  final String? groupName;

  ChatHabitSuggestion({
    required this.title,
    required this.category,
    this.frequency = 'Каждый день',
    this.timeOfDay,
    this.reason,
    this.description,
    this.cooldownDays = 1,
    this.dailyTarget = 1,
    this.targetTime,
    this.reminderTime,
    this.groupName,
  });

  factory ChatHabitSuggestion.fromJson(Map<String, dynamic> json) {
    return ChatHabitSuggestion(
      title: (json['title'] ?? '').toString(),
      category: (json['category'] ?? 'other').toString(),
      frequency: (json['frequency'] ?? 'Каждый день').toString(),
      timeOfDay: (json['time_of_day'] ?? json['timeOfDay'])?.toString(),
      reason: json['reason']?.toString(),
      description: json['description']?.toString(),
      cooldownDays: (json['cooldown_days'] as num?)?.toInt() ?? 1,
      dailyTarget: (json['daily_target'] as num?)?.toInt() ?? 1,
      targetTime: json['target_time']?.toString(),
      reminderTime: json['reminder_time']?.toString(),
      groupName: json['group_name']?.toString(),
    );
  }
}

class ChatSession {
  final String chatId;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int messageCount;
  final String? preview;

  ChatSession({
    required this.chatId,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.messageCount = 0,
    this.preview,
  });

  factory ChatSession.fromJson(Map<String, dynamic> json) {
    return ChatSession(
      chatId: (json['chat_id'] ?? json['id'] ?? '').toString(),
      title: (json['title'] ?? 'Новый чат').toString(),
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      messageCount: (json['message_count'] as num?)?.toInt() ?? 0,
      preview: json['preview']?.toString(),
    );
  }
}

class ChatMessage {
  final int? id;
  final String? sessionId;
  final String role;
  final String content;
  final DateTime timestamp;
  final List<ChatHabitSuggestion> suggestedHabits;
  final String? suggestedBundleName;

  ChatMessage({
    this.id,
    this.sessionId,
    required this.role,
    required this.content,
    required this.timestamp,
    this.suggestedHabits = const [],
    this.suggestedBundleName,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'],
      sessionId: json['session_id']?.toString(),
      role: json['role'],
      content: json['content'],
      timestamp: DateTime.parse(json['timestamp']),
      suggestedHabits: (json['suggested_habits'] as List<dynamic>?)
              ?.map((j) => ChatHabitSuggestion.fromJson(j))
              .where((s) => s.title.trim().isNotEmpty)
              .toList() ??
          const [],
      suggestedBundleName:
          (json['suggested_bundle_name'] ?? json['folderName'])?.toString(),
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
      overallCompletionRate:
          (json['overall_completion_rate'] ?? 0.0).toDouble(),
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
      tips:
          (json['tips'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
              [],
      motivationMessage: json['motivation_message'] ?? '',
    );
  }
}
