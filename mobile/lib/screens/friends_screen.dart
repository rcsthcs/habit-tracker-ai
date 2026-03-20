import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../core/app_colors.dart';
import '../core/theme_extensions.dart';
import '../models/friendship.dart';
import '../providers/app_providers.dart';
import '../widgets/user_avatar.dart';
import 'friend_profile_screen.dart';

class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({super.key});

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  List<UserSearchResult> _searchResults = [];
  bool _searching = false;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    Future.microtask(() {
      ref.read(friendsProvider.notifier).loadFriends();
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    if (query.length < 2) {
      setState(() {
        _searchResults = [];
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      _search(query);
    });
  }

  Future<void> _search(String query) async {
    try {
      final api = ref.read(apiServiceProvider);
      final results = await api.searchUsers(query);
      if (mounted) setState(() => _searchResults = results);
    } catch (_) {}
    if (mounted) setState(() => _searching = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Друзья'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: context.textSecondary,
          indicatorColor: AppColors.primary,
          labelStyle: const TextStyle(fontSize: 12),
          tabs: const [
            Tab(text: 'Друзья'),
            Tab(text: 'Входящие'),
            Tab(text: 'Исходящие'),
            Tab(text: 'Поиск'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFriendsList(),
          _buildIncomingRequests(),
          _buildSentRequests(),
          _buildSearch(),
        ],
      ),
    );
  }

  Widget _buildFriendsList() {
    final friendsAsync = ref.watch(friendsProvider);

    return RefreshIndicator(
      onRefresh: () => ref.read(friendsProvider.notifier).loadFriends(),
      child: friendsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Ошибка: $e')),
        data: (friends) {
          if (friends.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline,
                      size: 64,
                      color: context.textSecondary.withValues(alpha: 0.5)),
                  const SizedBox(height: 16),
                  Text('Пока нет друзей',
                      style: TextStyle(
                          fontSize: 16, color: context.textSecondary)),
                  const SizedBox(height: 8),
                  Text('Найди друзей во вкладке «Поиск»',
                      style: TextStyle(
                          color: context.textSecondary, fontSize: 13)),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: friends.length,
            itemBuilder: (ctx, i) => _FriendCard(
              friend: friends[i],
              onRemove: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Удалить из друзей?'),
                    content: Text('Удалить ${friends[i].username}?'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Отмена')),
                      TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Удалить',
                              style: TextStyle(color: AppColors.error))),
                    ],
                  ),
                );
                if (confirm == true) {
                  await ref
                      .read(friendsProvider.notifier)
                      .removeFriend(friends[i].userId);
                }
              },
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FriendProfileScreen(friend: friends[i]),
                  ),
                );
              },
            ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.2, end: 0),
          );
        },
      ),
    );
  }

  Widget _buildIncomingRequests() {
    final requestsAsync = ref.watch(friendRequestsProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(friendRequestsProvider),
      child: requestsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Ошибка: $e')),
        data: (requests) {
          if (requests.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox_outlined,
                      size: 64,
                      color: context.textSecondary.withValues(alpha: 0.5)),
                  const SizedBox(height: 16),
                  Text('Нет входящих запросов',
                      style: TextStyle(
                          fontSize: 16, color: context.textSecondary)),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: requests.length,
            itemBuilder: (ctx, i) {
              final req = requests[i];
              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: context.dividerColor),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      UserAvatar(
                        avatarUrl: req.avatarUrl,
                        name: req.username,
                        radius: 24,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(req.username,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text('Хочет добавить тебя в друзья',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: context.textSecondary)),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.check_circle,
                                color: AppColors.success),
                            onPressed: () async {
                              await ref
                                  .read(friendsProvider.notifier)
                                  .acceptRequest(req.friendshipId);
                              ref.invalidate(friendRequestsProvider);
                            },
                            tooltip: 'Принять',
                          ),
                          IconButton(
                            icon: const Icon(Icons.cancel,
                                color: AppColors.error),
                            onPressed: () async {
                              await ref
                                  .read(friendsProvider.notifier)
                                  .rejectRequest(req.friendshipId);
                              ref.invalidate(friendRequestsProvider);
                            },
                            tooltip: 'Отклонить',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.2, end: 0);
            },
          );
        },
      ),
    );
  }

  Widget _buildSentRequests() {
    final sentAsync = ref.watch(sentRequestsProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(sentRequestsProvider),
      child: sentAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Ошибка: $e')),
        data: (requests) {
          if (requests.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.outbox_outlined,
                      size: 64,
                      color: context.textSecondary.withValues(alpha: 0.5)),
                  const SizedBox(height: 16),
                  Text('Нет исходящих запросов',
                      style: TextStyle(
                          fontSize: 16, color: context.textSecondary)),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: requests.length,
            itemBuilder: (ctx, i) {
              final req = requests[i];
              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: context.dividerColor),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      UserAvatar(
                        avatarUrl: req.avatarUrl,
                        name: req.username,
                        radius: 24,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(req.username,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text(
                              'Ожидает подтверждения',
                              style: TextStyle(
                                fontSize: 13,
                                color: context.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () async {
                          try {
                            await ref
                                .read(friendsProvider.notifier)
                                .cancelRequest(req.friendshipId);
                            ref.invalidate(sentRequestsProvider);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Запрос отозван')),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Ошибка: $e')),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.close,
                            size: 18, color: AppColors.error),
                        label: const Text('Отозвать',
                            style: TextStyle(
                                fontSize: 13, color: AppColors.error)),
                      ),
                    ],
                  ),
                ),
              ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.2, end: 0);
            },
          );
        },
      ),
    );
  }

  Widget _buildSearch() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              labelText: 'Поиск по имени',
              hintText: 'Введите имя пользователя...',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: _onSearchChanged,
          ),
        ),
        if (_searching)
          const Padding(
            padding: EdgeInsets.all(16),
            child: CircularProgressIndicator(),
          ),
        Expanded(
          child: _searchResults.isEmpty
              ? Center(
                  child: Text(
                    _searchController.text.length < 2
                        ? 'Введите минимум 2 символа'
                        : 'Никого не найдено',
                    style: TextStyle(color: context.textSecondary),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: _searchResults.length,
                  itemBuilder: (ctx, i) {
                    final user = _searchResults[i];
                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: context.dividerColor),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            UserAvatar(
                              avatarUrl: user.avatarUrl,
                              name: user.username,
                              radius: 24,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                user.username,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                            _buildFriendshipAction(user),
                          ],
                        ),
                      ),
                    )
                        .animate()
                        .fadeIn(duration: 300.ms)
                        .slideY(begin: 0.2, end: 0);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildFriendshipAction(UserSearchResult user) {
    if (user.friendshipStatus == 'accepted') {
      return const Chip(
        label: Text('Друзья', style: TextStyle(fontSize: 12)),
        backgroundColor: Color(0xFFE8F5E9),
      );
    }
    if (user.friendshipStatus == 'pending') {
      return TextButton.icon(
        onPressed: user.friendshipId != null
            ? () async {
                try {
                  await ref
                      .read(friendsProvider.notifier)
                      .cancelRequest(user.friendshipId!);
                  _search(_searchController.text);
                  ref.invalidate(sentRequestsProvider);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Запрос отозван')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Ошибка: $e')),
                    );
                  }
                }
              }
            : null,
        icon: const Icon(Icons.close, size: 14, color: AppColors.warning),
        label: const Text('Отозвать',
            style: TextStyle(fontSize: 12, color: AppColors.warning)),
      );
    }
    return ElevatedButton(
      onPressed: () async {
        try {
          await ref.read(friendsProvider.notifier).sendRequest(user.id);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Запрос отправлен ${user.username}')),
          );
          _search(_searchController.text); // refresh
          ref.invalidate(sentRequestsProvider);
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка: $e')),
          );
        }
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16),
      ),
      child: const Text('Добавить', style: TextStyle(fontSize: 13)),
    );
  }
}

class _FriendCard extends StatelessWidget {
  final FriendInfo friend;
  final VoidCallback onRemove;
  final VoidCallback onTap;

  const _FriendCard({
    required this.friend,
    required this.onRemove,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: context.dividerColor),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              UserAvatar(
                avatarUrl: friend.avatarUrl,
                name: friend.username,
                radius: 28,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      friend.username,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Нажми для просмотра профиля',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.person_remove_outlined,
                  color: context.textSecondary,
                  size: 22,
                ),
                onPressed: onRemove,
                tooltip: 'Удалить из друзей',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FriendProgressDialog extends ConsumerStatefulWidget {
  final int friendId;
  const _FriendProgressDialog({required this.friendId});

  @override
  ConsumerState<_FriendProgressDialog> createState() =>
      _FriendProgressDialogState();
}

class _FriendProgressDialogState extends ConsumerState<_FriendProgressDialog> {
  FriendProgress? _progress;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final api = ref.read(apiServiceProvider);
      final p = await api.getFriendProgress(widget.friendId);
      setState(() {
        _progress = p;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_progress?.username ?? 'Прогресс друга'),
      content: _loading
          ? const SizedBox(
              height: 100, child: Center(child: CircularProgressIndicator()))
          : _progress == null
              ? const Text('Не удалось загрузить')
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ProgressRow(
                        icon: Icons.checklist,
                        label: 'Привычки',
                        value: '${_progress!.activeHabits} активных'),
                    _ProgressRow(
                        icon: Icons.local_fire_department,
                        label: 'Лучшая серия',
                        value: '${_progress!.bestStreak} дн.'),
                    _ProgressRow(
                        icon: Icons.pie_chart,
                        label: 'Выполнение',
                        value:
                            '${_progress!.overallCompletionRate.toStringAsFixed(0)}%'),
                    _ProgressRow(
                        icon: Icons.today,
                        label: 'Сегодня',
                        value:
                            '${_progress!.todayCompleted}/${_progress!.todayTotal}'),
                  ],
                ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Закрыть'),
        ),
      ],
    );
  }
}

class _ProgressRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ProgressRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
              child:
                  Text(label, style: TextStyle(color: context.textSecondary))),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
