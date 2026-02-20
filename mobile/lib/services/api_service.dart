import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/config.dart';
import '../models/user.dart';
import '../models/habit.dart';
import '../models/habit_log.dart';
import '../models/chat_message.dart';

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

  Future<User> getMe() async {
    final response = await _dio.get('/auth/me');
    return User.fromJson(response.data);
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

  Future<List<Map<String, dynamic>>> getNotifications() async {
    final response = await _dio.get('/notifications/');
    return (response.data['notifications'] as List)
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }
}

