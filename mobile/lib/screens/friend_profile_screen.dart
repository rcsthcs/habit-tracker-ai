import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/app_colors.dart';
import '../core/theme_extensions.dart';
import '../models/friendship.dart';
import '../providers/app_providers.dart';
import '../widgets/user_avatar.dart';

class FriendProfileScreen extends ConsumerStatefulWidget {
  final FriendInfo friend;

  const FriendProfileScreen({super.key, required this.friend});

  @override
  ConsumerState<FriendProfileScreen> createState() =>
      _FriendProfileScreenState();
}

class _FriendProfileScreenState extends ConsumerState<FriendProfileScreen> {
  FriendProgress? _progress;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    try {
      final api = ref.read(apiServiceProvider);
      final p = await api.getFriendProgress(widget.friend.userId);
      setState(() {
        _progress = p;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.friend.username),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 48, color: AppColors.error),
                      const SizedBox(height: 16),
                      Text('Ошибка: $_error'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _loading = true;
                            _error = null;
                          });
                          _loadProgress();
                        },
                        child: const Text('Повторить'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadProgress,
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      // Avatar & name
                      Center(
                        child: Column(
                          children: [
                            UserAvatar(
                              avatarUrl: _progress?.avatarUrl,
                              name: widget.friend.username,
                              radius: 50,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _progress?.username ?? widget.friend.username,
                              style: const TextStyle(
                                  fontSize: 22, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            if (widget.friend.createdAt != null)
                              Text(
                                'Друзья с ${_formatDate(widget.friend.createdAt!)}',
                                style: TextStyle(
                                    fontSize: 13, color: context.textSecondary),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Stats grid
                      Row(
                        children: [
                          _StatTile(
                            icon: Icons.checklist,
                            label: 'Активных\nпривычек',
                            value: '${_progress?.activeHabits ?? 0}',
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 12),
                          _StatTile(
                            icon: Icons.local_fire_department,
                            label: 'Лучшая\nсерия',
                            value: '${_progress?.bestStreak ?? 0} дн.',
                            color: AppColors.warning,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _StatTile(
                            icon: Icons.pie_chart,
                            label: 'Общее\nвыполнение',
                            value:
                                '${_progress?.overallCompletionRate.toStringAsFixed(0) ?? 0}%',
                            color: AppColors.success,
                          ),
                          const SizedBox(width: 12),
                          _StatTile(
                            icon: Icons.today,
                            label: 'Сегодня\nвыполнено',
                            value:
                                '${_progress?.todayCompleted ?? 0}/${_progress?.todayTotal ?? 0}',
                            color: AppColors.secondary,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Total habits
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color:
                                      AppColors.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.list_alt,
                                    color: AppColors.primary),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Всего привычек',
                                        style: TextStyle(
                                            color: context.textSecondary,
                                            fontSize: 13)),
                                    Text(
                                      '${_progress?.totalHabits ?? 0}',
                                      style: const TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Today's progress bar
                      if (_progress != null && _progress!.todayTotal > 0) ...[
                        const Text('Прогресс сегодня',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: _progress!.todayTotal > 0
                                ? _progress!.todayCompleted /
                                    _progress!.todayTotal
                                : 0,
                            minHeight: 12,
                            backgroundColor:
                                AppColors.primary.withValues(alpha: 0.1),
                            color: _progress!.todayCompleted ==
                                    _progress!.todayTotal
                                ? AppColors.success
                                : AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_progress!.todayCompleted} из ${_progress!.todayTotal} выполнено',
                          style: TextStyle(
                              fontSize: 12, color: context.textSecondary),
                        ),
                      ],
                    ],
                  ),
                ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      return '${dt.day}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
    } catch (_) {
      return dateStr;
    }
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(value,
                  style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold, color: color)),
              const SizedBox(height: 4),
              Text(label,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: context.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }
}
