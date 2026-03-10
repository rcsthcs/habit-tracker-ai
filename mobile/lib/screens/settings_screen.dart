import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';
import '../providers/app_providers.dart';
import 'notifications_screen.dart';
import 'achievements_screen.dart';
import 'profile_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final unreadAsync = ref.watch(unreadCountProvider);
    final unreadCount = unreadAsync.valueOrNull ?? 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Profile card
          Card(
            child: InkWell(
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ProfileScreen())),
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: AppTheme.primaryColor,
                      child: Text(
                        user?.username.substring(0, 1).toUpperCase() ?? '?',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user?.username ?? 'Пользователь',
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text(user?.email ?? '',
                              style: const TextStyle(
                                  color: AppTheme.textSecondary, fontSize: 14)),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right,
                        color: AppTheme.textSecondary),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Quick actions
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Badge(
                    isLabelVisible: unreadCount > 0,
                    label: Text('$unreadCount'),
                    child: const Icon(Icons.notifications_outlined,
                        color: AppTheme.primaryColor),
                  ),
                  title: const Text('Уведомления'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const NotificationsScreen())),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.emoji_events_outlined,
                      color: AppTheme.primaryColor),
                  title: const Text('Достижения'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const AchievementsScreen())),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Info section
          const Text('О приложении',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary)),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.info_outline,
                      color: AppTheme.primaryColor),
                  title: const Text('Версия'),
                  subtitle: const Text('1.0.0'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.auto_awesome,
                      color: AppTheme.primaryColor),
                  title: const Text('AI Модель'),
                  subtitle: const Text('LLM (Ollama / OpenAI)'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading:
                      const Icon(Icons.storage, color: AppTheme.primaryColor),
                  title: const Text('База данных'),
                  subtitle: const Text('PostgreSQL'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Migration info
          Card(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: AppTheme.primaryColor.withOpacity(0.05),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('🏗️ Архитектура',
                      style:
                          TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  SizedBox(height: 8),
                  Text(
                    '• БД: PostgreSQL 16\n'
                    '• Бэкенд: FastAPI + Uvicorn\n'
                    '• AI: Ollama / OpenAI LLM\n'
                    '• Уведомления: APScheduler + Push\n'
                    '• Деплой: Docker Compose',
                    style: TextStyle(
                        fontSize: 13,
                        height: 1.6,
                        color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Logout
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => ref.read(authProvider.notifier).logout(),
              icon: const Icon(Icons.logout, color: AppTheme.errorColor),
              label: const Text('Выйти из аккаунта',
                  style: TextStyle(color: AppTheme.errorColor)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppTheme.errorColor),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

