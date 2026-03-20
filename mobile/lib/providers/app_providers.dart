import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import '../services/api_service.dart';
import '../models/user.dart';
import '../models/habit.dart';
import '../models/chat_message.dart';
import '../models/achievement.dart';
import '../models/friendship.dart';
import '../models/notification_item.dart';
import '../models/detailed_analytics.dart';
import '../models/mood.dart';
import '../models/challenge.dart';

// ─── API Service singleton ───
final apiServiceProvider = Provider<ApiService>((ref) => ApiService());

// ─── Theme ───
class ThemeNotifier extends StateNotifier<ThemeMode> {
  ThemeNotifier() : super(ThemeMode.system) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString('theme_mode') ?? 'system';
    state = _fromString(value);
  }

  Future<void> setTheme(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', _toString(mode));
  }

  Future<void> toggle() async {
    final next = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    await setTheme(next);
  }

  static ThemeMode _fromString(String s) => switch (s) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

  static String _toString(ThemeMode m) => switch (m) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        _ => 'system',
      };
}

final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeMode>(
  (ref) => ThemeNotifier(),
);

// ─── Auth state ───
enum AuthStatus { initial, authenticated, unauthenticated }

class AuthState {
  final AuthStatus status;
  final User? user;
  final String? error;

  AuthState({this.status = AuthStatus.initial, this.user, this.error});

  AuthState copyWith({AuthStatus? status, User? user, String? error}) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      error: error,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final ApiService _api;
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);

  AuthNotifier(this._api) : super(AuthState());

  Future<void> checkAuth() async {
    await _api.loadToken();
    if (_api.isLoggedIn) {
      try {
        final user = await _api.getMe();
        state = AuthState(status: AuthStatus.authenticated, user: user);
      } catch (_) {
        await _api.clearToken();
        state = AuthState(status: AuthStatus.unauthenticated);
      }
    } else {
      state = AuthState(status: AuthStatus.unauthenticated);
    }
  }

  Future<void> login(String username, String password) async {
    try {
      await _api.login(username, password);
      final user = await _api.getMe();
      state = AuthState(status: AuthStatus.authenticated, user: user);
    } catch (e) {
      state = AuthState(
          status: AuthStatus.unauthenticated,
          error: 'Неверный логин или пароль');
    }
  }

  Future<void> loginWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return; // user cancelled

      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      if (idToken == null) {
        state = AuthState(
            status: AuthStatus.unauthenticated,
            error: 'Не удалось получить Google токен');
        return;
      }

      await _api.loginWithGoogle(idToken);
      final user = await _api.getMe();
      state = AuthState(status: AuthStatus.authenticated, user: user);
    } catch (e) {
      state = AuthState(
          status: AuthStatus.unauthenticated,
          error: 'Ошибка входа через Google');
    }
  }

  Future<void> register(String username, String email, String password) async {
    try {
      await _api.register(username, email, password);
      await login(username, password);
    } catch (e) {
      state = AuthState(
          status: AuthStatus.unauthenticated,
          error: 'Ошибка регистрации. Попробуйте другое имя.');
    }
  }

  Future<void> logout() async {
    await _api.clearToken();
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    state = AuthState(status: AuthStatus.unauthenticated);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final api = ref.watch(apiServiceProvider);
  return AuthNotifier(api);
});

// ─── Habit folder helpers ───

/// Extracts the folder name from a habit description string (reads "Папка: ..." marker).
String? extractFolderFromDescription(String description) {
  final lower = description.toLowerCase();
  const marker = 'папка:';
  final idx = lower.indexOf(marker);
  if (idx < 0) return null;
  final raw = description.substring(idx + marker.length).trim();
  final name = raw.split('\n').first.trim();
  return name.isEmpty ? null : name;
}

/// Returns description with the "Папка: <name>" marker added, replaced, or removed.
String setFolderInDescription(String description, String? folderName) {
  final lines = description.split('\n');
  final filtered = lines
      .where((l) => !l.toLowerCase().trimLeft().startsWith('папка:'))
      .join('\n')
      .trim();
  if (folderName == null || folderName.trim().isEmpty) return filtered;
  return filtered.isEmpty
      ? 'Папка: $folderName'
      : '$filtered\nПапка: $folderName';
}

// ─── Habits ───
class HabitsNotifier extends StateNotifier<AsyncValue<List<Habit>>> {
  final ApiService _api;
  List<Habit> _lastHabits = const [];

  HabitsNotifier(this._api) : super(const AsyncValue.loading());

  Future<void> loadHabits({bool showLoading = false}) async {
    if (showLoading || _lastHabits.isEmpty) {
      state = const AsyncValue.loading();
    }
    try {
      final habits = await _api.getHabits();
      _lastHabits = habits;
      state = AsyncValue.data(habits);
    } catch (e, st) {
      if (_lastHabits.isNotEmpty) {
        state = AsyncValue.data(_lastHabits);
      } else {
        state = AsyncValue.error(e, st);
      }
    }
  }

  Future<void> createHabit(Map<String, dynamic> data) async {
    await _api.createHabit(data);
    await loadHabits();
  }

  Future<void> toggleHabit(int habitId, bool completed) async {
    // Optimistic local update to avoid full reload flash
    state.whenData((habits) {
      state = AsyncValue.data(
        habits.map((h) {
          if (h.id == habitId) {
            final newCompletions = completed
                ? (h.todayCompletions + 1).clamp(0, h.dailyTarget)
                : (h.todayCompletions - 1).clamp(0, h.dailyTarget);
            return Habit(
              id: h.id,
              userId: h.userId,
              name: h.name,
              description: h.description,
              category: h.category,
              frequency: h.frequency,
              cooldownDays: h.cooldownDays,
              dailyTarget: h.dailyTarget,
              targetTime: h.targetTime,
              reminderTime: h.reminderTime,
              color: h.color,
              icon: h.icon,
              isActive: h.isActive,
              createdAt: h.createdAt,
              currentStreak: completed
                  ? h.currentStreak + 1
                  : (h.currentStreak > 0 ? h.currentStreak - 1 : 0),
              bestStreak: h.bestStreak,
              completedToday: newCompletions >= h.dailyTarget,
              todayCompletions: newCompletions,
              completionRate: h.completionRate,
            );
          }
          return h;
        }).toList(),
      );
    });
    try {
      await _api.logHabit(habitId, DateTime.now(), completed);
      // Silently refresh from server in background
      final habits = await _api.getHabits();
      state = AsyncValue.data(habits);
    } catch (e) {
      // Revert on error
      await loadHabits();
    }
  }

  Future<void> deleteHabit(int id) async {
    await _api.deleteHabit(id);
    await loadHabits();
  }

  Future<void> updateHabit(int id, Map<String, dynamic> data) async {
    await _api.updateHabit(id, data);
    await loadHabits();
  }

  /// Move a list of habits into a folder (or remove from folder if folderName is null).
  /// Updates description by adding/replacing the "Папка: <name>" marker.
  Future<void> moveHabitsToFolder(
      List<int> habitIds, String? folderName) async {
    final habits = _lastHabits;
    for (final id in habitIds) {
      final habit =
          habits.firstWhere((h) => h.id == id, orElse: () => habits.first);
      if (habit.id != id) continue;
      final newDesc = setFolderInDescription(habit.description, folderName);
      await _api.updateHabit(id, {
        'name': habit.name,
        'description': newDesc,
        'category': habit.category,
        'frequency': habit.frequency,
        'cooldown_days': habit.cooldownDays,
        'daily_target': habit.dailyTarget,
        'target_time': habit.targetTime,
        'reminder_time': habit.reminderTime,
        'color': habit.color,
        'icon': habit.icon,
        'is_active': habit.isActive,
      });
    }
    await loadHabits();
  }
}

final habitsProvider =
    StateNotifierProvider<HabitsNotifier, AsyncValue<List<Habit>>>((ref) {
  final api = ref.watch(apiServiceProvider);
  return HabitsNotifier(api);
});

// ─── Analytics ───
final analyticsProvider = FutureProvider<Analytics>((ref) async {
  final api = ref.watch(apiServiceProvider);
  return await api.getAnalytics();
});

// ─── Recommendations ───
final recommendationsProvider = FutureProvider<Recommendations>((ref) async {
  final api = ref.watch(apiServiceProvider);
  return await api.getRecommendations();
});

// ─── Chat ───
class ChatState {
  final List<ChatSession> chats;
  final String? currentChatId;
  final List<ChatMessage> messages;

  const ChatState({
    this.chats = const [],
    this.currentChatId,
    this.messages = const [],
  });

  ChatState copyWith({
    List<ChatSession>? chats,
    String? currentChatId,
    List<ChatMessage>? messages,
    bool clearCurrentChatId = false,
  }) {
    return ChatState(
      chats: chats ?? this.chats,
      currentChatId:
          clearCurrentChatId ? null : (currentChatId ?? this.currentChatId),
      messages: messages ?? this.messages,
    );
  }
}

class ChatNotifier extends StateNotifier<ChatState> {
  final ApiService _api;

  ChatNotifier(this._api) : super(const ChatState());

  bool _isNetworkError(Object error) {
    if (error is! DioException) return false;
    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return true;
    }
    final message = (error.message ?? '').toLowerCase();
    return message.contains('socketexception') ||
        message.contains('network') ||
        message.contains('timed out');
  }

  ChatMessage _buildAssistantFallback({
    required String? currentChatId,
    required bool isNetworkError,
  }) {
    return ChatMessage(
      sessionId: currentChatId,
      role: 'assistant',
      content: isNetworkError
          ? 'Похоже, сейчас проблема с сетью. Проверь подключение и попробуй ещё раз.'
          : 'Я получил запрос, но не смог подготовить структурированный ответ. Попробуй переформулировать — я отвечу текстом и предложу шаги.',
      timestamp: DateTime.now(),
      suggestedHabits: const [],
      suggestedBundleName: null,
    );
  }

  Future<void> loadChats() async {
    try {
      final chats = await _api.getChatSessions();
      if (chats.isEmpty) {
        final created = await _api.createChatSession();
        state = ChatState(
          chats: [created],
          currentChatId: created.chatId,
          messages: const [],
        );
        return;
      }

      final currentChatId = state.currentChatId ?? chats.first.chatId;
      state = state.copyWith(chats: chats, currentChatId: currentChatId);
      await openChat(currentChatId);
    } catch (_) {}
  }

  Future<void> openChat(String chatId) async {
    try {
      final messages = await _api.getChatHistory(chatId: chatId);
      state = state.copyWith(currentChatId: chatId, messages: messages);
    } catch (_) {}
  }

  Future<void> createNewChat() async {
    try {
      final created = await _api.createChatSession();
      state = state.copyWith(
        chats: [created, ...state.chats],
        currentChatId: created.chatId,
        messages: const [],
      );
    } catch (_) {}
  }

  Future<void> clearHistory() async {
    final currentChatId = state.currentChatId;
    if (currentChatId == null) {
      await createNewChat();
      return;
    }

    try {
      await _api.clearChatHistory(chatId: currentChatId);
      final refreshedChats = await _api.getChatSessions();
      state = state.copyWith(chats: refreshedChats, messages: const []);
    } catch (_) {}
  }

  Future<void> reloadCurrentChat() async {
    final currentChatId = state.currentChatId;
    if (currentChatId == null) return;
    await openChat(currentChatId);
  }

  Future<void> sendMessage(
    String content, {
    Map<String, dynamic>? contextHints,
  }) async {
    var currentChatId = state.currentChatId;
    if (currentChatId == null) {
      try {
        final created = await _api.createChatSession();
        currentChatId = created.chatId;
        state = state.copyWith(
          chats: [created, ...state.chats],
          currentChatId: currentChatId,
          messages: const [],
        );
      } catch (error) {
        state = state.copyWith(
          messages: [
            ...state.messages,
            _buildAssistantFallback(
              currentChatId: currentChatId,
              isNetworkError: _isNetworkError(error),
            ),
          ],
        );
        return;
      }
    }

    final optimisticMessage = ChatMessage(
      sessionId: currentChatId,
      role: 'user',
      content: content,
      timestamp: DateTime.now(),
    );
    state = state.copyWith(messages: [...state.messages, optimisticMessage]);

    try {
      final response = await _api.sendChatMessage(
        chatId: currentChatId,
        content: content,
        contextHints: contextHints,
      );
      final refreshedChats = await _api.getChatSessions();
      state = state.copyWith(
        chats: refreshedChats,
        currentChatId: currentChatId,
        messages: [...state.messages, response],
      );
    } catch (error) {
      state = state.copyWith(
        messages: [
          ...state.messages,
          _buildAssistantFallback(
            currentChatId: currentChatId,
            isNetworkError: _isNetworkError(error),
          ),
        ],
      );
    }
  }

  Future<void> addHabitFromSuggestion(ChatHabitSuggestion suggestion) async {
    final category = suggestion.category.toLowerCase();
    const allowedCategories = {
      'health',
      'fitness',
      'nutrition',
      'mindfulness',
      'productivity',
      'learning',
      'social',
      'sleep',
      'finance',
      'other',
    };

    await _api.createHabit({
      'name': suggestion.title.trim(),
      'description': suggestion.reason ?? suggestion.description ?? '',
      'category': allowedCategories.contains(category) ? category : 'other',
      'frequency': 'daily',
      'cooldown_days': suggestion.cooldownDays,
      'daily_target': suggestion.dailyTarget,
      'target_time': suggestion.targetTime,
      'reminder_time': suggestion.reminderTime,
      'icon': 'check_circle',
      'color': '#4CAF50',
    });
  }

  Future<void> addHabitFromSuggestionDraft({
    required ChatHabitSuggestion suggestion,
    required String name,
    required String category,
    required String description,
    required int cooldownDays,
    required int dailyTarget,
    String? targetTime,
    String? reminderTime,
  }) async {
    const allowedCategories = {
      'health',
      'fitness',
      'nutrition',
      'mindfulness',
      'productivity',
      'learning',
      'social',
      'sleep',
      'finance',
      'other',
    };

    final normalizedCategory = category.toLowerCase();
    await _api.createHabit({
      'name': name.trim(),
      'description': description.trim(),
      'category': allowedCategories.contains(normalizedCategory)
          ? normalizedCategory
          : 'other',
      'frequency': 'daily',
      'cooldown_days': cooldownDays,
      'daily_target': dailyTarget,
      'target_time': targetTime,
      'reminder_time': reminderTime,
      'icon': 'check_circle',
      'color': '#4CAF50',
    });
  }

  Future<void> deleteChats(List<String> chatIds) async {
    final deletedIds = <String>{};
    for (final id in chatIds) {
      try {
        await _api.deleteChatSession(chatId: id);
        deletedIds.add(id);
      } catch (_) {}
    }

    List<ChatSession> refreshedChats;
    try {
      refreshedChats = await _api.getChatSessions();
    } catch (_) {
      refreshedChats =
          state.chats.where((c) => !deletedIds.contains(c.chatId)).toList();
    }

    if (refreshedChats.isEmpty) {
      await createNewChat();
      return;
    }

    final currentWasDeleted = deletedIds.contains(state.currentChatId);
    final newCurrentId = currentWasDeleted
        ? refreshedChats.first.chatId
        : (state.currentChatId ?? refreshedChats.first.chatId);

    state = state.copyWith(
      chats: refreshedChats,
      currentChatId: newCurrentId,
      messages: currentWasDeleted ? const [] : state.messages,
    );
    if (currentWasDeleted) {
      await openChat(newCurrentId);
    }
  }

  Future<void> addBundleFromSuggestions(
    List<ChatHabitSuggestion> suggestions,
    String bundleName,
  ) async {
    for (final suggestion in suggestions) {
      await addHabitFromSuggestionDraft(
        suggestion: suggestion,
        name: suggestion.title,
        category: suggestion.category,
        description: [
          if ((suggestion.groupName ?? '').trim().isNotEmpty)
            'Группа: ${suggestion.groupName}',
          if ((suggestion.reason ?? '').trim().isNotEmpty) suggestion.reason!,
          if ((suggestion.description ?? '').trim().isNotEmpty)
            suggestion.description!,
          'Папка: $bundleName',
        ].join('\n'),
        cooldownDays: suggestion.cooldownDays,
        dailyTarget: suggestion.dailyTarget,
        targetTime: suggestion.targetTime,
        reminderTime: suggestion.reminderTime,
      );
    }
  }
}

final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  final api = ref.watch(apiServiceProvider);
  return ChatNotifier(api);
});

// ─── Friends ───
class FriendsNotifier extends StateNotifier<AsyncValue<List<FriendInfo>>> {
  final ApiService _api;

  FriendsNotifier(this._api) : super(const AsyncValue.loading());

  Future<void> loadFriends() async {
    state = const AsyncValue.loading();
    try {
      final friends = await _api.getFriends();
      state = AsyncValue.data(friends);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> sendRequest(int friendId) async {
    await _api.sendFriendRequest(friendId);
  }

  Future<void> acceptRequest(int friendshipId) async {
    await _api.acceptFriendRequest(friendshipId);
    await loadFriends();
  }

  Future<void> rejectRequest(int friendshipId) async {
    await _api.rejectFriendRequest(friendshipId);
  }

  Future<void> removeFriend(int friendId) async {
    await _api.removeFriend(friendId);
    await loadFriends();
  }

  Future<void> cancelRequest(int friendshipId) async {
    await _api.cancelFriendRequest(friendshipId);
  }
}

final friendsProvider =
    StateNotifierProvider<FriendsNotifier, AsyncValue<List<FriendInfo>>>((ref) {
  final api = ref.watch(apiServiceProvider);
  return FriendsNotifier(api);
});

final friendRequestsProvider = FutureProvider<List<FriendInfo>>((ref) async {
  final api = ref.watch(apiServiceProvider);
  return await api.getFriendRequests();
});

final sentRequestsProvider = FutureProvider<List<FriendInfo>>((ref) async {
  final api = ref.watch(apiServiceProvider);
  return await api.getSentRequests();
});

// ─── Achievements ───
final achievementsProvider = FutureProvider<List<Achievement>>((ref) async {
  final api = ref.watch(apiServiceProvider);
  return await api.getAchievements();
});

// ─── Notifications ───
class NotificationsNotifier
    extends StateNotifier<AsyncValue<List<NotificationItem>>> {
  final ApiService _api;

  NotificationsNotifier(this._api) : super(const AsyncValue.loading());

  Future<void> load() async {
    try {
      final items = await _api.getNotifications();
      state = AsyncValue.data(items);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> markRead(int id) async {
    await _api.markNotificationRead(id);
    await load();
  }

  Future<void> markAllRead() async {
    await _api.markAllNotificationsRead();
    await load();
  }

  Future<void> deleteNotification(int id) async {
    await _api.deleteNotification(id);
    // Update local state immediately
    state.whenData((items) {
      state = AsyncValue.data(items.where((n) => n.id != id).toList());
    });
  }

  Future<void> clearAll() async {
    await _api.clearAllNotifications();
    state = const AsyncValue.data([]);
  }
}

final notificationsProvider = StateNotifierProvider<NotificationsNotifier,
    AsyncValue<List<NotificationItem>>>((ref) {
  final api = ref.watch(apiServiceProvider);
  return NotificationsNotifier(api);
});

final unreadCountProvider = FutureProvider<int>((ref) async {
  final api = ref.watch(apiServiceProvider);
  return await api.getUnreadNotificationCount();
});

// ─── Detailed Analytics ───
final detailedAnalyticsProvider =
    FutureProvider<DetailedAnalytics>((ref) async {
  final api = ref.watch(apiServiceProvider);
  return await api.getDetailedAnalytics();
});

// ─── Mood ───
class MoodNotifier extends StateNotifier<AsyncValue<List<MoodLog>>> {
  final ApiService _api;

  MoodNotifier(this._api) : super(const AsyncValue.loading());

  Future<void> loadMoods({int days = 30}) async {
    state = const AsyncValue.loading();
    try {
      final moods = await _api.getMoodLogs(days: days);
      state = AsyncValue.data(moods);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> logMood(MoodLog mood) async {
    await _api.logMood(mood);
    await loadMoods();
  }
}

final moodProvider =
    StateNotifierProvider<MoodNotifier, AsyncValue<List<MoodLog>>>((ref) {
  final api = ref.watch(apiServiceProvider);
  return MoodNotifier(api);
});

final todayMoodProvider = FutureProvider<MoodLog?>((ref) async {
  final api = ref.watch(apiServiceProvider);
  return await api.getTodayMood();
});

final moodAnalyticsProvider = FutureProvider<MoodAnalytics>((ref) async {
  final api = ref.watch(apiServiceProvider);
  return await api.getMoodAnalytics();
});

// ─── Challenges ───
class ChallengesNotifier extends StateNotifier<AsyncValue<List<Challenge>>> {
  final ApiService _api;

  ChallengesNotifier(this._api) : super(const AsyncValue.loading());

  Future<void> loadChallenges({String? status}) async {
    state = const AsyncValue.loading();
    try {
      final challenges = await _api.getChallenges(status: status);
      state = AsyncValue.data(challenges);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> generateChallenges() async {
    try {
      await _api.generateChallenges();
      await loadChallenges();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final challengesProvider =
    StateNotifierProvider<ChallengesNotifier, AsyncValue<List<Challenge>>>(
        (ref) {
  final api = ref.watch(apiServiceProvider);
  return ChallengesNotifier(api);
});

// ─── Streak Recovery ───
final streakRecoveryProvider =
    FutureProvider<List<StreakRecovery>>((ref) async {
  final api = ref.watch(apiServiceProvider);
  return await api.getStreakRecovery();
});

// ─── Weekly Report ───
final weeklyReportProvider = FutureProvider<WeeklyReport?>((ref) async {
  final api = ref.watch(apiServiceProvider);
  return await api.getWeeklyReport();
});

final weeklyReportsHistoryProvider =
    FutureProvider<List<WeeklyReport>>((ref) async {
  final api = ref.watch(apiServiceProvider);
  return await api.getWeeklyReports();
});
