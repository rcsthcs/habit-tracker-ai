import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../core/app_colors.dart';
import '../core/theme_extensions.dart';
import '../providers/app_providers.dart';
import '../widgets/user_avatar.dart';
import '../widgets/glass_card.dart';
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
    final themeState = ref.watch(themeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          // Profile card
          GlassCard(
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ProfileScreen())),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  UserAvatar(
                    avatarUrl: user?.avatarUrl,
                    name: user?.username ?? '?',
                    radius: 30,
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
                            style: TextStyle(
                                color: context.textSecondary, fontSize: 14)),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: context.textSecondary),
                ],
              ),
            ),
          ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.05),
          const SizedBox(height: 20),

          // ─── Theme Toggle ───
          _SectionTitle(title: 'Оформление'),
          const SizedBox(height: 8),
          GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.palette_outlined,
                            color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Text('Тема оформления',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _ThemeChip(
                        icon: Icons.brightness_auto,
                        label: 'Система',
                        isSelected: themeState == ThemeMode.system,
                        onTap: () => ref
                            .read(themeProvider.notifier)
                            .setTheme(ThemeMode.system),
                      ),
                      const SizedBox(width: 8),
                      _ThemeChip(
                        icon: Icons.light_mode,
                        label: 'Светлая',
                        isSelected: themeState == ThemeMode.light,
                        onTap: () => ref
                            .read(themeProvider.notifier)
                            .setTheme(ThemeMode.light),
                      ),
                      const SizedBox(width: 8),
                      _ThemeChip(
                        icon: Icons.dark_mode,
                        label: 'Тёмная',
                        isSelected: themeState == ThemeMode.dark,
                        onTap: () => ref
                            .read(themeProvider.notifier)
                            .setTheme(ThemeMode.dark),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ).animate().fadeIn(delay: 100.ms),
          const SizedBox(height: 20),

          // Quick actions
          _SectionTitle(title: 'Быстрые действия'),
          const SizedBox(height: 8),
          GlassCard(
            child: Column(
              children: [
                _SettingsTile(
                  icon: Icons.notifications_outlined,
                  iconGradient: AppColors.accentGradient,
                  title: 'Уведомления',
                  badge: unreadCount,
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(
                          builder: (_) => const NotificationsScreen())),
                ),
                Divider(height: 1, color: context.dividerColor),
                _SettingsTile(
                  icon: Icons.emoji_events_outlined,
                  iconGradient: AppColors.successGradient,
                  title: 'Достижения',
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(
                          builder: (_) => const AchievementsScreen())),
                ),
              ],
            ),
          ).animate().fadeIn(delay: 200.ms),
          const SizedBox(height: 20),

          // Info section
          _SectionTitle(title: 'О приложении'),
          const SizedBox(height: 8),
          GlassCard(
            child: Column(
              children: [
                _InfoTile(
                    icon: Icons.info_outline,
                    title: 'Версия',
                    subtitle: '1.0.0'),
                Divider(height: 1, color: context.dividerColor),
                _InfoTile(
                    icon: Icons.auto_awesome,
                    title: 'AI Модель',
                    subtitle: 'LLM (Ollama / OpenAI)'),
                Divider(height: 1, color: context.dividerColor),
                _InfoTile(
                    icon: Icons.storage,
                    title: 'База данных',
                    subtitle: 'PostgreSQL'),
              ],
            ),
          ).animate().fadeIn(delay: 300.ms),
          const SizedBox(height: 20),

          // Architecture card
          GlassCard(
            gradient: LinearGradient(
              colors: [
                context.primaryColor.withValues(alpha: 0.08),
                context.secondaryColor.withValues(alpha: 0.04),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('🏗️ Архитектура',
                      style:
                          TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  const SizedBox(height: 8),
                  Text(
                    '• БД: PostgreSQL 16\n'
                    '• Бэкенд: FastAPI + Uvicorn\n'
                    '• AI: Ollama / OpenAI LLM\n'
                    '• Уведомления: APScheduler + Push\n'
                    '• Деплой: Docker Compose',
                    style: TextStyle(
                        fontSize: 13,
                        height: 1.6,
                        color: context.textSecondary),
                  ),
                ],
              ),
            ),
          ).animate().fadeIn(delay: 400.ms),
          const SizedBox(height: 24),

          // Logout
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => ref.read(authProvider.notifier).logout(),
              icon: Icon(Icons.logout, color: context.errorColor),
              label: Text('Выйти из аккаунта',
                  style: TextStyle(color: context.errorColor)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: context.errorColor.withValues(alpha: 0.5)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ).animate().fadeIn(delay: 500.ms),
          const SizedBox(height: 40), // Bottom padding for nav bar
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(title,
        style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: context.textSecondary,
            letterSpacing: 0.5));
  }
}

class _ThemeChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeChip({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? context.primaryColor.withValues(alpha: 0.12)
                : context.surfaceColor.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? context.primaryColor.withValues(alpha: 0.4)
                  : context.dividerColor,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon,
                  size: 22,
                  color: isSelected
                      ? context.primaryColor
                      : context.textSecondary),
              const SizedBox(height: 4),
              Text(label,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: isSelected
                          ? context.primaryColor
                          : context.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final LinearGradient iconGradient;
  final String title;
  final int badge;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.iconGradient,
    required this.title,
    this.badge = 0,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          gradient: iconGradient,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Badge(
          isLabelVisible: badge > 0,
          label: Text('$badge',
              style:
                  const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      trailing: Icon(Icons.chevron_right, color: context.textSecondary),
      onTap: onTap,
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _InfoTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: context.primaryColor),
      title: Text(title),
      subtitle: Text(subtitle, style: TextStyle(color: context.textSecondary)),
    );
  }
}

