import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/config.dart';
import '../models/user.dart';
import '../models/habit.dart';
import '../models/habit_log.dart';
import '../models/chat_message.dart';
import '../models/achievement.dart';
import '../models/friendship.dart';
import '../models/notification_item.dart';
import '../models/detailed_analytics.dart';
import '../models/mood.dart';
import '../models/challenge.dart';

class ApiService {
  late final Dio _dio;
  String? _token;

  ApiService() {
    final baseUrl = kIsWeb ? AppConfig.baseUrlWeb : AppConfig.baseUrl;
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: AppConfig.requestTimeout,
      receiveTimeout: AppConfig.requestTimeout,
      headers: {'Content-Type': 'application/json'},
    ));
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (_token != null) {
          options.headers['Authorization'] = 'Bearer $_token';
        }
        handler.next(options);
      },
      onError: (error, handler) {
        debugPrint('API Error: ${error.message}');
        handler.next(error);
      },
    ));
  }

  Future<void> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
  }

  Future<void> _saveToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  Future<void> clearToken() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }

  bool get isLoggedIn => _token != null;

  // ─── Auth ───

  Future<User> register(String username, String email, String password) async {
    final response = await _dio.post('/auth/register', data: {
      'username': username,
      'email': email,
      'password': password,
    });
    return User.fromJson(response.data);
  }

  Future<String> login(String username, String password) async {
    final response = await _dio.post('/auth/login',
        data: 'username=$username&password=$password',
        options: Options(contentType: 'application/x-www-form-urlencoded'));
    final token = response.data['access_token'];
    await _saveToken(token);
    return token;
  }

  Future<String> loginWithGoogle(String idToken) async {
    final response = await _dio.post('/auth/google', data: {
      'id_token': idToken,
    });
    final token = response.data['access_token'];
    await _saveToken(token);
    return token;
  }

  Future<User> getMe() async {
    final response = await _dio.get('/auth/me');
    return User.fromJson(response.data);
  }

  Future<User> updateProfile(Map<String, dynamic> data) async {
    final response = await _dio.patch('/auth/me', data: data);
    return User.fromJson(response.data);
  }

  Future<User> uploadAvatar(File imageFile) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        imageFile.path,
        filename: imageFile.path.split('/').last,
      ),
    });
    final response = await _dio.post('/auth/me/avatar', data: formData);
    return User.fromJson(response.data);
  }

  Future<void> changePassword(String currentPassword, String newPassword) async {
    await _dio.post('/auth/change-password', data: {
      'current_password': currentPassword,
      'new_password': newPassword,
    });
  }

  // ─── Habits ───

  Future<List<Habit>> getHabits() async {
    final response = await _dio.get('/habits/');
    return (response.data as List).map((j) => Habit.fromJson(j)).toList();
  }

  Future<Habit> createHabit(Map<String, dynamic> data) async {
    final response = await _dio.post('/habits/', data: data);
    return Habit.fromJson(response.data);
  }

  Future<Habit> updateHabit(int id, Map<String, dynamic> data) async {
    final response = await _dio.put('/habits/$id', data: data);
    return Habit.fromJson(response.data);
  }

  Future<void> deleteHabit(int id) async {
    await _dio.delete('/habits/$id');
  }

  // ─── Habit Suggestions ───

  Future<List<String>> getHabitSuggestions(String category) async {
    final response = await _dio.get('/habits/suggestions/$category');
    return List<String>.from(response.data['suggestions']);
  }

  // ─── Habit Logs ───

  Future<HabitLog> logHabit(int habitId, DateTime date, bool completed,
      {String? note}) async {
    final response = await _dio.post('/habits/log', data: {
      'habit_id': habitId,
      'date': date.toIso8601String().split('T')[0],
      'completed': completed,
      'note': note,
    });
    return HabitLog.fromJson(response.data);
  }

  Future<List<HabitLog>> getHabitLogs(int habitId, {int days = 30}) async {
    final response =
        await _dio.get('/habits/$habitId/logs', queryParameters: {'days': days});
    return (response.data as List).map((j) => HabitLog.fromJson(j)).toList();
  }

  // ─── Analytics ───

  Future<Analytics> getAnalytics() async {
    final response = await _dio.get('/analytics/');
    return Analytics.fromJson(response.data);
  }

  // ─── Recommendations ───

  Future<Recommendations> getRecommendations() async {
    final response = await _dio.get('/recommendations/');
    return Recommendations.fromJson(response.data);
  }

  // ─── Chat ───

  Future<ChatMessage> sendChatMessage(String content) async {
    final response = await _dio.post('/chat/',
        data: {'content': content},
        options: Options(receiveTimeout: AppConfig.chatTimeout));
    return ChatMessage.fromJson(response.data);
  }

  Future<List<ChatMessage>> getChatHistory({int limit = 50}) async {
    final response =
        await _dio.get('/chat/history', queryParameters: {'limit': limit});
    return (response.data as List)
        .map((j) => ChatMessage.fromJson(j))
        .toList();
  }

  // ─── Notifications ───

  Future<List<NotificationItem>> getNotifications({bool unreadOnly = false}) async {
    final response = await _dio.get('/notifications/',
        queryParameters: {'unread_only': unreadOnly});
    return (response.data as List)
        .map((e) => NotificationItem.fromJson(e))
        .toList();
  }

  Future<int> getUnreadNotificationCount() async {
    final response = await _dio.get('/notifications/unread-count');
    return response.data['unread_count'] ?? 0;
  }

  Future<void> markNotificationRead(int id) async {
    await _dio.patch('/notifications/$id/read');
  }

  Future<void> markAllNotificationsRead() async {
    await _dio.patch('/notifications/read-all');
  }

  Future<void> deleteNotification(int id) async {
    await _dio.delete('/notifications/$id');
  }

  Future<void> clearAllNotifications() async {
    await _dio.delete('/notifications/');
  }

  // ─── Friends ───

  Future<List<UserSearchResult>> searchUsers(String query) async {
    final response = await _dio.get('/friends/search',
        queryParameters: {'q': query});
    return (response.data as List)
        .map((e) => UserSearchResult.fromJson(e))
        .toList();
  }

  Future<void> sendFriendRequest(int friendId) async {
    await _dio.post('/friends/request/$friendId');
  }

  Future<void> acceptFriendRequest(int friendshipId) async {
    await _dio.post('/friends/accept/$friendshipId');
  }

  Future<void> rejectFriendRequest(int friendshipId) async {
    await _dio.post('/friends/reject/$friendshipId');
  }

  Future<void> cancelFriendRequest(int friendshipId) async {
    await _dio.delete('/friends/request/$friendshipId');
  }

  Future<List<FriendInfo>> getSentRequests() async {
    final response = await _dio.get('/friends/sent-requests');
    return (response.data as List)
        .map((e) => FriendInfo.fromJson(e))
        .toList();
  }

  Future<void> removeFriend(int friendId) async {
    await _dio.delete('/friends/$friendId');
  }

  Future<List<FriendInfo>> getFriends() async {
    final response = await _dio.get('/friends/');
    return (response.data as List)
        .map((e) => FriendInfo.fromJson(e))
        .toList();
  }

  Future<List<FriendInfo>> getFriendRequests() async {
    final response = await _dio.get('/friends/requests');
    return (response.data as List)
        .map((e) => FriendInfo.fromJson(e))
        .toList();
  }

  Future<FriendProgress> getFriendProgress(int friendId) async {
    final response = await _dio.get('/friends/$friendId/progress');
    return FriendProgress.fromJson(response.data);
  }

  // ─── Achievements ───

  Future<List<Achievement>> getAchievements() async {
    final response = await _dio.get('/achievements/');
    return (response.data as List)
        .map((e) => Achievement.fromJson(e))
        .toList();
  }

  // ─── Detailed Analytics ───

  Future<DetailedAnalytics> getDetailedAnalytics({int days = 90}) async {
    final response = await _dio.get('/analytics/detailed',
        queryParameters: {'days': days});
    return DetailedAnalytics.fromJson(response.data);
  }

  String getExportUrl() {
    final baseUrl = kIsWeb ? AppConfig.baseUrlWeb : AppConfig.baseUrl;
    return '$baseUrl/analytics/export';
  }

  // ─── Mood ───

  Future<MoodLog> logMood(MoodLog mood) async {
    final response = await _dio.post('/mood/', data: mood.toJson());
    return MoodLog.fromJson(response.data);
  }

  Future<List<MoodLog>> getMoodLogs({int days = 30}) async {
    final response =
        await _dio.get('/mood/', queryParameters: {'days': days});
    return (response.data as List).map((e) => MoodLog.fromJson(e)).toList();
  }

  Future<MoodLog?> getTodayMood() async {
    final response = await _dio.get('/mood/today');
    if (response.data == null) return null;
    return MoodLog.fromJson(response.data);
  }

  Future<MoodAnalytics> getMoodAnalytics() async {
    final response = await _dio.get('/mood/analytics');
    return MoodAnalytics.fromJson(response.data);
  }

  // ─── Challenges ───

  Future<List<Challenge>> getChallenges({String? status}) async {
    final params = <String, dynamic>{};
    if (status != null) params['status_filter'] = status;
    final response =
        await _dio.get('/challenges/', queryParameters: params);
    return (response.data as List)
        .map((e) => Challenge.fromJson(e))
        .toList();
  }

  Future<List<Challenge>> generateChallenges() async {
    final response = await _dio.post('/challenges/generate');
    return (response.data as List)
        .map((e) => Challenge.fromJson(e))
        .toList();
  }

  Future<Challenge> updateChallengeProgress(int challengeId) async {
    final response = await _dio.post('/challenges/$challengeId/progress');
    return Challenge.fromJson(response.data);
  }

  // ─── Streak Recovery ───

  Future<List<StreakRecovery>> getStreakRecovery() async {
    final response = await _dio.get('/challenges/streak-recovery');
    return (response.data as List)
        .map((e) => StreakRecovery.fromJson(e))
        .toList();
  }

  // ─── Weekly Report ───

  Future<WeeklyReport?> getWeeklyReport() async {
    final response = await _dio.get('/challenges/weekly-report');
    if (response.data == null) return null;
    return WeeklyReport.fromJson(response.data);
  }

  Future<List<WeeklyReport>> getWeeklyReports({int limit = 8}) async {
    final response = await _dio.get('/challenges/weekly-reports',
        queryParameters: {'limit': limit});
    return (response.data as List)
        .map((e) => WeeklyReport.fromJson(e))
        .toList();
  }
}
