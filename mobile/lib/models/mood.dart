/// Mood log model for tracking daily mood.
class MoodLog {
  final int? id;
  final int? userId;
  final DateTime date;
  final double score;
  final String? note;
  final String? tags;
  final double? energyLevel;
  final double? stressLevel;
  final DateTime? createdAt;

  MoodLog({
    this.id,
    this.userId,
    required this.date,
    required this.score,
    this.note,
    this.tags,
    this.energyLevel,
    this.stressLevel,
    this.createdAt,
  });

  factory MoodLog.fromJson(Map<String, dynamic> json) {
    return MoodLog(
      id: json['id'],
      userId: json['user_id'],
      date: DateTime.parse(json['date']),
      score: (json['score'] as num).toDouble(),
      note: json['note'],
      tags: json['tags'],
      energyLevel: json['energy_level'] != null
          ? (json['energy_level'] as num).toDouble()
          : null,
      stressLevel: json['stress_level'] != null
          ? (json['stress_level'] as num).toDouble()
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String().split('T')[0],
        'score': score,
        if (note != null) 'note': note,
        if (tags != null) 'tags': tags,
        if (energyLevel != null) 'energy_level': energyLevel,
        if (stressLevel != null) 'stress_level': stressLevel,
      };
}

/// Mood-habit correlation result.
class MoodHabitCorrelation {
  final int habitId;
  final String habitName;
  final double correlation;
  final String interpretation;
  final String description;

  MoodHabitCorrelation({
    required this.habitId,
    required this.habitName,
    required this.correlation,
    required this.interpretation,
    required this.description,
  });

  factory MoodHabitCorrelation.fromJson(Map<String, dynamic> json) {
    return MoodHabitCorrelation(
      habitId: json['habit_id'],
      habitName: json['habit_name'],
      correlation: (json['correlation'] as num).toDouble(),
      interpretation: json['interpretation'],
      description: json['description'],
    );
  }
}

/// Mood analytics response.
class MoodAnalytics {
  final double? avgMood7d;
  final double? avgMood30d;
  final String moodTrend;
  final String? bestDay;
  final String? worstDay;
  final List<MoodHabitCorrelation> correlations;
  final List<MoodLog> moodHistory;

  MoodAnalytics({
    this.avgMood7d,
    this.avgMood30d,
    required this.moodTrend,
    this.bestDay,
    this.worstDay,
    required this.correlations,
    required this.moodHistory,
  });

  factory MoodAnalytics.fromJson(Map<String, dynamic> json) {
    return MoodAnalytics(
      avgMood7d: json['avg_mood_7d'] != null
          ? (json['avg_mood_7d'] as num).toDouble()
          : null,
      avgMood30d: json['avg_mood_30d'] != null
          ? (json['avg_mood_30d'] as num).toDouble()
          : null,
      moodTrend: json['mood_trend'],
      bestDay: json['best_day'],
      worstDay: json['worst_day'],
      correlations: (json['correlations'] as List)
          .map((e) => MoodHabitCorrelation.fromJson(e))
          .toList(),
      moodHistory: (json['mood_history'] as List)
          .map((e) => MoodLog.fromJson(e))
          .toList(),
    );
  }
}
