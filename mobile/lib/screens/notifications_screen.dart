import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/app_colors.dart';
import '../core/theme_extensions.dart';
import '../providers/app_providers.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(notificationsProvider.notifier).load());
  }

  @override
  Widget build(BuildContext context) {
    final notifAsync = ref.watch(notificationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Уведомления'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) async {
              if (value == 'read_all') {
                await ref.read(notificationsProvider.notifier).markAllRead();
                ref.invalidate(unreadCountProvider);
              } else if (value == 'clear_all') {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Очистить уведомления?'),
                    content: const Text('Все уведомления будут удалены.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Отмена'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Очистить',
                            style: TextStyle(color: AppColors.error)),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await ref.read(notificationsProvider.notifier).clearAll();
                  ref.invalidate(unreadCountProvider);
                }
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'read_all',
                child: Row(
                  children: [
                    Icon(Icons.done_all, size: 20, color: AppColors.primary),
                    SizedBox(width: 8),
                    Text('Прочитать все'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'clear_all',
                child: Row(
                  children: [
                    Icon(Icons.delete_sweep, size: 20, color: AppColors.error),
                    SizedBox(width: 8),
                    Text('Очистить все'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: notifAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Ошибка: $e')),
        data: (notifications) {
          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.notifications_none,
                        size: 48, color: context.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  Text('Нет уведомлений',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: context.textSecondary)),
                  const SizedBox(height: 4),
                  Text('Здесь появятся ваши уведомления',
                      style: TextStyle(
                          fontSize: 13, color: context.textSecondary)),
                ],
              ),
            );
          }

          // Group by date
          final grouped = _groupByDate(notifications);

          return RefreshIndicator(
            onRefresh: () => ref.read(notificationsProvider.notifier).load(),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              itemCount: grouped.length,
              itemBuilder: (ctx, i) {
                final group = grouped[i];
                if (group is String) {
                  // Date header
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                    child: Text(group,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: context.textSecondary,
                        )),
                  );
                }
                final n = group as _NotifItem;
                return Dismissible(
                  key: Key('notif_${n.notification.id}'),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    margin:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.delete_outline,
                        color: AppColors.error),
                  ),
                  onDismissed: (_) async {
                    await ref
                        .read(notificationsProvider.notifier)
                        .deleteNotification(n.notification.id);
                    ref.invalidate(unreadCountProvider);
                  },
                  child: Card(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    elevation: n.notification.isRead ? 0.5 : 2,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () async {
                        if (!n.notification.isRead) {
                          await ref
                              .read(notificationsProvider.notifier)
                              .markRead(n.notification.id);
                          ref.invalidate(unreadCountProvider);
                        }
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: !n.notification.isRead
                              ? Border.all(
                                  color:
                                      AppColors.primary.withValues(alpha: 0.3),
                                  width: 1)
                              : null,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Icon
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: _getTypeColor(n.notification.type)
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  _getTypeIcon(n.notification.type),
                                  color: _getTypeColor(n.notification.type),
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Content
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            n.notification.title,
                                            style: TextStyle(
                                              fontWeight: n.notification.isRead
                                                  ? FontWeight.normal
                                                  : FontWeight.w600,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                        if (!n.notification.isRead)
                                          Container(
                                            width: 8,
                                            height: 8,
                                            decoration: const BoxDecoration(
                                              color: AppColors.primary,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                      ],
                                    ),
                                    if (n.notification.body.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        n.notification.body,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: n.notification.isRead
                                              ? context.textSecondary
                                              : context.textPrimary,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                    const SizedBox(height: 4),
                                    Text(
                                      _timeAgo(n.notification.createdAt),
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: context.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  List<dynamic> _groupByDate(List notifications) {
    final result = <dynamic>[];
    String? lastDateLabel;

    for (final n in notifications) {
      final label = _dateLabel(n.createdAt);
      if (label != lastDateLabel) {
        result.add(label);
        lastDateLabel = label;
      }
      result.add(_NotifItem(n));
    }
    return result;
  }

  String _dateLabel(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(dt.year, dt.month, dt.day);

    if (date == today) return 'Сегодня';
    if (date == today.subtract(const Duration(days: 1))) return 'Вчера';
    if (now.difference(dt).inDays < 7) return 'На этой неделе';
    return 'Ранее';
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'achievement':
        return Icons.emoji_events;
      case 'friend_request':
        return Icons.person_add;
      case 'friend_accepted':
        return Icons.people;
      case 'reminder':
        return Icons.alarm;
      case 'evening_reminder':
        return Icons.nightlight;
      default:
        return Icons.notifications;
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'achievement':
        return Colors.amber;
      case 'friend_request':
      case 'friend_accepted':
        return AppColors.primary;
      case 'reminder':
      case 'evening_reminder':
        return AppColors.warning;
      default:
        return context.textSecondary;
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'только что';
    if (diff.inMinutes < 60) return '${diff.inMinutes} мин. назад';
    if (diff.inHours < 24) return '${diff.inHours} ч. назад';
    if (diff.inDays < 7) return '${diff.inDays} дн. назад';
    return '${dt.day}.${dt.month.toString().padLeft(2, '0')}';
  }
}

class _NotifItem {
  final dynamic notification;
  _NotifItem(this.notification);
}
