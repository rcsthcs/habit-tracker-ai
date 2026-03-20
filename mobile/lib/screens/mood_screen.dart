import 'dart:ui';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../core/app_colors.dart';
import '../core/theme_extensions.dart';
import '../models/mood.dart';
import '../providers/app_providers.dart';
import '../screens/chat_screen.dart';
import '../widgets/glass_card.dart';

class MoodScreen extends ConsumerStatefulWidget {
  const MoodScreen({super.key});

  @override
  ConsumerState<MoodScreen> createState() => _MoodScreenState();
}

class _MoodScreenState extends ConsumerState<MoodScreen>
    with SingleTickerProviderStateMixin {
  double _selectedMood = 3.0;
  double _energyLevel = 3.0;
  double _stressLevel = 3.0;
  final _noteController = TextEditingController();
  bool _saving = false;
  late TabController _tabController;

  static const _moods = [
    {'emoji': '😞', 'label': 'Плохо', 'color': Color(0xFFE57373)},
    {'emoji': '😕', 'label': 'Так себе', 'color': Color(0xFFFFB74D)},
    {'emoji': '😐', 'label': 'Нормально', 'color': Color(0xFFFFD54F)},
    {'emoji': '😊', 'label': 'Хорошо', 'color': Color(0xFF81C784)},
    {'emoji': '🤩', 'label': 'Отлично', 'color': Color(0xFF4FC3F7)},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadTodayMood();
    Future.microtask(() => ref.read(moodProvider.notifier).loadMoods());
  }

  Future<void> _loadTodayMood() async {
    try {
      final api = ref.read(apiServiceProvider);
      final today = await api.getTodayMood();
      if (today != null && mounted) {
        setState(() {
          _selectedMood = today.score;
          _energyLevel = today.energyLevel ?? 3.0;
          _stressLevel = today.stressLevel ?? 3.0;
          _noteController.text = today.note ?? '';
        });
      }
    } catch (_) {}
  }

  Future<void> _saveMood() async {
    setState(() => _saving = true);
    try {
      final mood = MoodLog(
        date: DateTime.now(),
        score: _selectedMood,
        note: _noteController.text.isNotEmpty ? _noteController.text : null,
        energyLevel: _energyLevel,
        stressLevel: _stressLevel,
      );
      await ref.read(moodProvider.notifier).logMood(mood);
      if (mounted) {
        HapticFeedback.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Настроение сохранено ✨'),
            backgroundColor: context.successColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: $e'),
            backgroundColor: context.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openCoachChat({MoodAnalytics? analytics}) async {
    final trend = analytics?.moodTrend ?? 'stable';
    final insight = analytics?.aiInsight?.trim();

    final initialMessage = trend == 'declining'
        ? 'Помоги составить щадящий план на сегодня: короткие шаги, чтобы вернуть фокус и не сорваться с привычек.'
        : 'Дай персональный план на сегодня по моим привычкам и настроению в формате 3 коротких шагов.';

    final hints = <String, dynamic>{
      'source': 'mood_screen',
      'mood_score': _selectedMood,
      'energy_level': _energyLevel,
      'stress_level': _stressLevel,
      'mood_trend': trend,
      if (insight != null && insight.isNotEmpty) 'mood_ai_insight': insight,
      if (_noteController.text.trim().isNotEmpty)
        'today_note': _noteController.text.trim(),
      'trigger': trend == 'declining' ? 'mood_decline' : 'mood_checkin',
    };

    try {
      final api = ref.read(apiServiceProvider);
      await api.getChatSessions();
    } on DioException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'AI-коуч временно недоступен. Проверь подключение к сети и попробуй ещё раз.',
          ),
        ),
      );
      return;
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Не удалось подключить AI-коуча. Повтори попытку позже.'),
        ),
      );
      return;
    }

    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          initialMessage: initialMessage,
          initialContextHints: hints,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _noteController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bg = context.backgroundColor;

    return Scaffold(
      extendBodyBehindAppBar: false,
      appBar: AppBar(
        title: const Text('Настроение'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: context.textSecondary,
          indicatorColor: AppColors.primary,
          dividerColor: Colors.transparent,
          tabs: const [
            Tab(text: 'Сегодня'),
            Tab(text: 'История'),
          ],
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              bg,
              AppColors.primary.withValues(alpha: 0.05),
              bg,
            ],
          ),
        ),
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildTodayTab(),
            _buildHistoryTab(),
          ],
        ),
      ),
    );
  }

  // ─── TODAY TAB ───
  Widget _buildTodayTab() {
    final moodAnalytics = ref.watch(moodAnalyticsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMoodPicker()
              .animate()
              .fadeIn(duration: 400.ms)
              .slideY(begin: 0.1),
          const SizedBox(height: 16),
          _buildEnergyStress()
              .animate()
              .fadeIn(duration: 400.ms, delay: 100.ms)
              .slideY(begin: 0.1),
          const SizedBox(height: 16),
          _buildNoteSection()
              .animate()
              .fadeIn(duration: 400.ms, delay: 200.ms)
              .slideY(begin: 0.1),
          const SizedBox(height: 24),
          _buildSaveButton()
              .animate()
              .fadeIn(duration: 400.ms, delay: 300.ms)
              .slideY(begin: 0.1),
          const SizedBox(height: 32),
          moodAnalytics.when(
            data: (data) => _buildAnalytics(data),
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  // ─── HISTORY TAB ───
  Widget _buildHistoryTab() {
    final moodsAsync = ref.watch(moodProvider);

    return SafeArea(
      top: false,
      bottom: true,
      child: moodsAsync.when(
        loading: () => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            16,
            24,
            16,
            MediaQuery.of(context).padding.bottom + 88,
          ),
          children: const [
            SizedBox(height: 120),
            Center(child: CircularProgressIndicator()),
          ],
        ),
        error: (e, _) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            16,
            24,
            16,
            MediaQuery.of(context).padding.bottom + 88,
          ),
          children: [
            const SizedBox(height: 120),
            Text(
              'Ошибка: $e',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.textSecondary),
            ),
          ],
        ),
        data: (moods) {
          if (moods.isEmpty) {
            return LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  16,
                  24,
                  16,
                  MediaQuery.of(context).padding.bottom + 24,
                ),
                child: ConstrainedBox(
                  constraints:
                      BoxConstraints(minHeight: constraints.maxHeight - 24),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('😶', style: TextStyle(fontSize: 64)),
                        const SizedBox(height: 16),
                        Text(
                          'Пока нет записей',
                          style: TextStyle(
                            fontSize: 18,
                            color: context.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Сохрани настроение во вкладке «Сегодня»',
                          style: TextStyle(
                            color: context.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }

          // Sort by date descending
          final sorted = List<MoodLog>.from(moods)
            ..sort((a, b) => b.date.compareTo(a.date));

          // Weekly chart data (last 7 entries)
          final last7 = sorted.take(7).toList().reversed.toList();

          return RefreshIndicator(
            onRefresh: () => ref.read(moodProvider.notifier).loadMoods(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                MediaQuery.of(context).padding.bottom + 88,
              ),
              children: [
                // Weekly mini chart
                if (last7.length >= 2) ...[
                  Text(
                    'Последние дни',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 12),
                  _buildWeeklyChart(last7).animate().fadeIn(duration: 400.ms),
                  const SizedBox(height: 24),
                ],

                Text(
                  'Все записи',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 12),

                ...sorted.map((mood) => _buildMoodHistoryItem(mood)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildWeeklyChart(List<MoodLog> entries) {
    return GlassCard(
      child: SizedBox(
        height: 140,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: entries.map((entry) {
            final idx = (entry.score - 1).round().clamp(0, 4);
            final color = _moods[idx]['color'] as Color;
            final emoji = _moods[idx]['emoji'] as String;
            final barHeight = (entry.score / 5.0) * 74;
            final day =
                '${entry.date.day}.${entry.date.month.toString().padLeft(2, '0')}';

            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(emoji, style: const TextStyle(fontSize: 16)),
                    const SizedBox(height: 4),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeOutCubic,
                      height: barHeight,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [color, color.withValues(alpha: 0.4)],
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      day,
                      style: TextStyle(
                        fontSize: 10,
                        color: context.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildMoodHistoryItem(MoodLog mood) {
    final idx = (mood.score - 1).round().clamp(0, 4);
    final moodInfo = _moods[idx];
    final color = moodInfo['color'] as Color;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Mood indicator
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: color.withValues(alpha: 0.3)),
              ),
              child: Center(
                child: Text(
                  moodInfo['emoji'] as String,
                  style: const TextStyle(fontSize: 24),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        moodInfo['label'] as String,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _formatDate(mood.date),
                        style: TextStyle(
                          fontSize: 12,
                          color: context.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (mood.energyLevel != null) ...[
                        _miniTag(
                            '⚡ ${mood.energyLevel!.round()}', Colors.amber),
                        const SizedBox(width: 6),
                      ],
                      if (mood.stressLevel != null)
                        _miniTag('😰 ${mood.stressLevel!.round()}',
                            Colors.red.shade300),
                    ],
                  ),
                  if (mood.note != null && mood.note!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      mood.note!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: context.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 300.ms).slideX(begin: 0.03);
  }

  Widget _miniTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style:
            TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);
    if (d == today) return 'Сегодня';
    if (d == today.subtract(const Duration(days: 1))) return 'Вчера';
    return '${date.day}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  // ─── MOOD PICKER ───
  Widget _buildMoodPicker() {
    final idx = (_selectedMood - 1).round().clamp(0, 4);
    final current = _moods[idx];

    return GlassCard(
      child: Column(
        children: [
          Text(
            'Как ты сегодня?',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 20),
          Text(
            current['emoji'] as String,
            style: const TextStyle(fontSize: 64),
          ).animate(key: ValueKey(idx)).scale(
                begin: const Offset(0.5, 0.5),
                end: const Offset(1, 1),
                duration: 300.ms,
                curve: Curves.elasticOut,
              ),
          const SizedBox(height: 8),
          Text(
            current['label'] as String,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: current['color'] as Color,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(5, (i) {
              final isSelected = (i + 1) == _selectedMood.round();
              return GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() => _selectedMood = (i + 1).toDouble());
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: isSelected ? 56 : 44,
                  height: isSelected ? 56 : 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected
                        ? (_moods[i]['color'] as Color).withValues(alpha: 0.2)
                        : Colors.grey.withValues(alpha: 0.1),
                    border: Border.all(
                      color: isSelected
                          ? _moods[i]['color'] as Color
                          : Colors.grey.withValues(alpha: 0.3),
                      width: isSelected ? 2.5 : 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: (_moods[i]['color'] as Color)
                                  .withValues(alpha: 0.3),
                              blurRadius: 8,
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      _moods[i]['emoji'] as String,
                      style: TextStyle(fontSize: isSelected ? 28 : 22),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // ─── ENERGY & STRESS ───
  Widget _buildEnergyStress() {
    return GlassCard(
      child: Column(
        children: [
          _buildSliderRow(
            emoji: '⚡',
            label: 'Энергия',
            value: _energyLevel,
            activeColor: Colors.amber.shade700,
            onChanged: (v) => setState(() => _energyLevel = v),
          ),
          const SizedBox(height: 12),
          _buildSliderRow(
            emoji: '😰',
            label: 'Стресс',
            value: _stressLevel,
            activeColor: Colors.red.shade400,
            onChanged: (v) => setState(() => _stressLevel = v),
          ),
        ],
      ),
    );
  }

  Widget _buildSliderRow({
    required String emoji,
    required String label,
    required double value,
    required Color activeColor,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: activeColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                value.round().toString(),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: activeColor,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: activeColor,
            inactiveTrackColor: activeColor.withValues(alpha: 0.15),
            thumbColor: activeColor,
            overlayColor: activeColor.withValues(alpha: 0.1),
            trackHeight: 6,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
          ),
          child: Slider(
            value: value,
            min: 1,
            max: 5,
            divisions: 4,
            onChanged: (v) {
              HapticFeedback.selectionClick();
              onChanged(v);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildNoteSection() {
    return GlassCard(
      child: TextField(
        controller: _noteController,
        maxLines: 3,
        decoration: InputDecoration(
          hintText: 'Как прошёл твой день? (необязательно)',
          hintStyle:
              TextStyle(color: context.textSecondary.withValues(alpha: 0.6)),
          border: InputBorder.none,
          icon: const Icon(Icons.edit_note, color: AppColors.primary),
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: _saving ? null : _saveMood,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: _saving
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2),
                )
              : const Text(
                  'Сохранить настроение',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
      ),
    );
  }

  // ─── ANALYTICS ───
  Widget _buildAnalytics(MoodAnalytics data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Аналитика',
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.bold),
        ).animate().fadeIn(duration: 400.ms, delay: 400.ms),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                '7 дн.',
                data.avgMood7d?.toStringAsFixed(1) ?? '—',
                Icons.calendar_today,
                Colors.blue,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildStatCard(
                '30 дн.',
                data.avgMood30d?.toStringAsFixed(1) ?? '—',
                Icons.date_range,
                Colors.purple,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildStatCard(
                'Тренд',
                _trendEmoji(data.moodTrend),
                Icons.trending_up,
                Colors.teal,
              ),
            ),
          ],
        ).animate().fadeIn(duration: 400.ms, delay: 500.ms),
        if ((data.aiInsight ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: 16),
          GlassCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.auto_awesome_rounded,
                      size: 18,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        data.aiInsight!.trim(),
                        style: TextStyle(
                          color: context.textPrimary,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _openCoachChat(analytics: data),
                    icon: const Icon(Icons.chat_bubble_outline_rounded),
                    label: const Text('Обсудить с AI-коучем'),
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 400.ms, delay: 580.ms),
        ],
        const SizedBox(height: 20),
        if (data.correlations.isNotEmpty) ...[
          Text(
            'Влияние привычек на настроение',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          ...data.correlations.take(5).map(
                (c) => _buildCorrelationItem(c),
              ),
        ],
      ],
    );
  }

  Widget _buildStatCard(
      String label, String value, IconData icon, Color color) {
    return GlassCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: context.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCorrelationItem(MoodHabitCorrelation c) {
    final color = c.interpretation == 'positive'
        ? Colors.green
        : c.interpretation == 'negative'
            ? Colors.red
            : Colors.grey;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassCard(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 40,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c.habitName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    c.description,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${c.correlation > 0 ? '+' : ''}${(c.correlation * 100).toInt()}%',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 300.ms).slideX(begin: 0.05);
  }

  String _trendEmoji(String trend) {
    switch (trend) {
      case 'improving':
        return '📈';
      case 'declining':
        return '📉';
      default:
        return '➡️';
    }
  }
}
