class FriendInfo {
  final int friendshipId;
  final int userId;
  final String username;
  final String? avatarUrl;
  final String? friendshipStatus;
  final String? createdAt;

  FriendInfo({
    required this.friendshipId,
    required this.userId,
    required this.username,
    this.avatarUrl,
    this.friendshipStatus,
    this.createdAt,
  });

  factory FriendInfo.fromJson(Map<String, dynamic> json) {
    return FriendInfo(
      friendshipId: json['friendship_id'] ?? 0,
      userId: json['user_id'],
      username: json['username'],
      avatarUrl: json['avatar_url'],
      friendshipStatus: json['friendship_status'],
      createdAt: json['created_at'],
    );
  }
}

class FriendProgress {
  final int userId;
  final String username;
  final String? avatarUrl;
  final int totalHabits;
  final int activeHabits;
  final int bestStreak;
  final double overallCompletionRate;
  final int todayCompleted;
  final int todayTotal;

  FriendProgress({
    required this.userId,
    required this.username,
    this.avatarUrl,
    required this.totalHabits,
    required this.activeHabits,
    required this.bestStreak,
    required this.overallCompletionRate,
    required this.todayCompleted,
    required this.todayTotal,
  });

  factory FriendProgress.fromJson(Map<String, dynamic> json) {
    return FriendProgress(
      userId: json['user_id'],
      username: json['username'],
      avatarUrl: json['avatar_url'],
      totalHabits: json['total_habits'],
      activeHabits: json['active_habits'],
      bestStreak: json['best_streak'],
      overallCompletionRate:
          (json['overall_completion_rate'] ?? 0.0).toDouble(),
      todayCompleted: json['today_completed'],
      todayTotal: json['today_total'],
    );
  }
}

class UserSearchResult {
  final int id;
  final String username;
  final String? avatarUrl;
  final String? friendshipStatus;
  final int? friendshipId;

  UserSearchResult({
    required this.id,
    required this.username,
    this.avatarUrl,
    this.friendshipStatus,
    this.friendshipId,
  });

  factory UserSearchResult.fromJson(Map<String, dynamic> json) {
    return UserSearchResult(
      id: json['id'],
      username: json['username'],
      avatarUrl: json['avatar_url'],
      friendshipStatus: json['friendship_status'],
      friendshipId: json['friendship_id'],
    );
  }
}
