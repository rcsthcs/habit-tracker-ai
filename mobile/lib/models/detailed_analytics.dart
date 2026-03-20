class CategoryStat {
  final String category;
  final int count;
  final double completionRate;

  CategoryStat({
    required this.category,
    required this.count,
    required this.completionRate,
  });

  factory CategoryStat.fromJson(Map<String, dynamic> json) {
    return CategoryStat(
      category: json['category'],
      count: json['count'],
      completionRate: (json['completion_rate'] ?? 0.0).toDouble(),
    );
  }
}

class HourStat {
  final int hour;
  final int count;

  HourStat({required this.hour, required this.count});

  factory HourStat.fromJson(Map<String, dynamic> json) {
    return HourStat(
      hour: json['hour'],
      count: json['count'],
    );
  }
}

class DayHabitBreakdown {
  final List<String> completed;
  final List<String> missed;

  DayHabitBreakdown({
    required this.completed,
    required this.missed,
  });

  factory DayHabitBreakdown.fromJson(Map<String, dynamic> json) {
    return DayHabitBreakdown(
      completed:
          (json['completed'] as List? ?? []).map((e) => e.toString()).toList(),
      missed: (json['missed'] as List? ?? []).map((e) => e.toString()).toList(),
    );
  }
}

class DetailedAnalytics {
  final Map<String, bool?> heatmap;
  final List<CategoryStat> categoryStats;
  final List<HourStat> hourlyDistribution;
  final List<double> trend90d;
  final int totalCompleted;
  final int totalLogged;
  final int daysActive;
  final Map<String, DayHabitBreakdown> dailyBreakdown;

  DetailedAnalytics({
    required this.heatmap,
    required this.categoryStats,
    required this.hourlyDistribution,
    required this.trend90d,
    required this.totalCompleted,
    required this.totalLogged,
    required this.daysActive,
    required this.dailyBreakdown,
  });

  factory DetailedAnalytics.fromJson(Map<String, dynamic> json) {
    final heatmapRaw = json['heatmap'] as Map<String, dynamic>? ?? {};
    final heatmap =
        heatmapRaw.map((key, value) => MapEntry(key, value as bool?));

    final dailyBreakdownRaw =
        json['daily_breakdown'] as Map<String, dynamic>? ?? {};
    final dailyBreakdown = dailyBreakdownRaw.map(
      (key, value) => MapEntry(
        key,
        DayHabitBreakdown.fromJson(value as Map<String, dynamic>),
      ),
    );

    return DetailedAnalytics(
      heatmap: heatmap,
      categoryStats: (json['category_stats'] as List? ?? [])
          .map((e) => CategoryStat.fromJson(e))
          .toList(),
      hourlyDistribution: (json['hourly_distribution'] as List? ?? [])
          .map((e) => HourStat.fromJson(e))
          .toList(),
      trend90d: (json['trend_90d'] as List? ?? [])
          .map((e) => (e as num).toDouble())
          .toList(),
      totalCompleted: json['total_completed'] ?? 0,
      totalLogged: json['total_logged'] ?? 0,
      daysActive: json['days_active'] ?? 0,
      dailyBreakdown: dailyBreakdown,
    );
  }
}
