import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_animations.dart';
import '../core/app_colors.dart';
import '../core/app_spacing.dart';
import '../core/theme_extensions.dart';
import '../models/chat_message.dart';
import '../providers/app_providers.dart';
import '../widgets/add_habit_bottom_sheet.dart';
import '../widgets/shimmer_loader.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String? initialMessage;
  final Map<String, dynamic>? initialContextHints;

  const ChatScreen({
    super.key,
    this.initialMessage,
    this.initialContextHints,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  bool _sending = false;
  bool _historyLoading = true;
  int _lastMessageCount = 0;
  String? _lastChatId;
  bool _initialPromptSent = false;

  final Set<String> _addingSuggestionKeys = {};
  final Set<String> _addedSuggestionKeys = {};
  final Set<String> _addingBundleMessageKeys = {};
  final Set<String> _addedBundleMessageKeys = {};

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadChats);
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _resetAddedStateForNewChat() {
    _addingSuggestionKeys.clear();
    _addedSuggestionKeys.clear();
    _addingBundleMessageKeys.clear();
    _addedBundleMessageKeys.clear();
  }

  void _scrollToBottom({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final maxExtent = _scrollController.position.maxScrollExtent;
      if (animated) {
        _scrollController.animateTo(
          maxExtent,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
        );
      } else {
        _scrollController.jumpTo(maxExtent);
      }
    });
  }

  Future<void> _loadChats() async {
    if (mounted) {
      setState(() => _historyLoading = true);
    }

    await ref.read(chatProvider.notifier).loadChats();
    final chatState = ref.read(chatProvider);

    if (!mounted) return;
    setState(() {
      _historyLoading = false;
      _lastChatId = chatState.currentChatId;
      _lastMessageCount = chatState.messages.length;
    });
    _scrollToBottom(animated: false);
    await _sendInitialPromptIfNeeded();
  }

  Future<void> _sendInitialPromptIfNeeded() async {
    if (_initialPromptSent) return;
    final initialMessage = widget.initialMessage?.trim() ?? '';
    if (initialMessage.isEmpty) return;
    _initialPromptSent = true;
    _controller.text = initialMessage;
    await _send(contextHints: widget.initialContextHints);
  }

  Future<void> _createNewChat() async {
    setState(() {
      _historyLoading = true;
      _controller.clear();
      _resetAddedStateForNewChat();
    });

    await ref.read(chatProvider.notifier).createNewChat();
    final chatState = ref.read(chatProvider);

    if (!mounted) return;
    setState(() {
      _historyLoading = false;
      _lastChatId = chatState.currentChatId;
      _lastMessageCount = chatState.messages.length;
    });
    _scrollToBottom(animated: false);
  }

  Future<void> _openChat(String chatId) async {
    setState(() {
      _historyLoading = true;
      _resetAddedStateForNewChat();
    });

    await ref.read(chatProvider.notifier).openChat(chatId);
    final chatState = ref.read(chatProvider);

    if (!mounted) return;
    setState(() {
      _historyLoading = false;
      _lastChatId = chatState.currentChatId;
      _lastMessageCount = chatState.messages.length;
    });
    _scrollToBottom(animated: false);
  }

  Future<void> _showChatSessions(
      List<ChatSession> chats, String? currentId) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: context.surfaceColor,
      builder: (sheetContext) {
        return _ChatSessionsSheet(
          chats: chats,
          currentId: currentId,
          onOpen: (chatId) async {
            Navigator.pop(sheetContext);
            await _openChat(chatId);
          },
          onCreateNew: () async {
            Navigator.pop(sheetContext);
            await _createNewChat();
          },
          onDeleteSelected: (ids) async {
            await ref.read(chatProvider.notifier).deleteChats(ids);
          },
        );
      },
    );
  }

  Map<String, dynamic> _buildLiveContextHints({
    Map<String, dynamic>? baseHints,
  }) {
    final hints = <String, dynamic>{
      if (baseHints != null) ...baseHints,
    };

    final todayMood = ref.read(todayMoodProvider).valueOrNull;
    if (todayMood != null) {
      hints['mood_score'] = todayMood.score;
      if ((todayMood.stressLevel ?? 0) >= 4) {
        hints['trigger'] = 'high_stress_day';
      }
    }

    final moodAnalytics = ref.read(moodAnalyticsProvider).valueOrNull;
    if (moodAnalytics != null) {
      hints['mood_trend'] = moodAnalytics.moodTrend;
      if ((moodAnalytics.aiInsight ?? '').trim().isNotEmpty) {
        hints['mood_ai_insight'] = moodAnalytics.aiInsight;
      }
    }

    final habits = ref.read(habitsProvider).valueOrNull;
    if (habits != null) {
      hints['active_habit_count'] = habits.length;
      final lowStreakHabits = habits
          .where((h) => h.currentStreak <= 1)
          .take(3)
          .map((h) => h.name)
          .toList();
      if (lowStreakHabits.isNotEmpty) {
        hints['low_streak_habits'] = lowStreakHabits;
      }
    }

    final challenges = ref.read(challengesProvider).valueOrNull;
    if (challenges != null && challenges.isNotEmpty) {
      final activeChallenges = challenges
          .where((c) => c.status == 'active')
          .take(3)
          .map((c) => c.title)
          .toList();
      if (activeChallenges.isNotEmpty) {
        hints['active_challenges'] = activeChallenges;
      }
    }

    return hints;
  }

  Future<void> _send({Map<String, dynamic>? contextHints}) async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    final mergedContextHints = _buildLiveContextHints(baseHints: contextHints);

    _controller.clear();
    setState(() => _sending = true);
    _scrollToBottom();

    await ref.read(chatProvider.notifier).sendMessage(
          text,
          contextHints: mergedContextHints,
        );

    if (!mounted) return;
    final chatState = ref.read(chatProvider);
    setState(() {
      _sending = false;
      _lastChatId = chatState.currentChatId;
      _lastMessageCount = chatState.messages.length;
    });
    _scrollToBottom();
  }

  Future<void> _quickSend(
    String text, {
    Map<String, dynamic>? contextHints,
  }) async {
    _controller.text = text;
    await _send(contextHints: contextHints);
  }

  String _suggestionKey(ChatMessage message, ChatHabitSuggestion suggestion) {
    final messageKey = message.id?.toString() ??
        '${message.sessionId ?? 'local'}:${message.timestamp.millisecondsSinceEpoch}';
    return '$messageKey:${suggestion.title.toLowerCase()}';
  }

  String _buildSuggestionDescription(ChatHabitSuggestion suggestion) {
    final parts = <String>[];
    final description = suggestion.description?.trim() ?? '';
    final reason = suggestion.reason?.trim() ?? '';

    if (description.isNotEmpty) {
      parts.add(description);
    }
    if (reason.isNotEmpty && !parts.contains(reason)) {
      parts.add(reason);
    }

    return parts.join('\n\n');
  }

  HabitDraft _buildSuggestionDraft(ChatHabitSuggestion suggestion) {
    return HabitDraft(
      name: suggestion.title.trim(),
      description: _buildSuggestionDescription(suggestion),
      category: suggestion.category.trim().isEmpty
          ? 'other'
          : suggestion.category.trim().toLowerCase(),
      cooldownDays: suggestion.cooldownDays,
      dailyTarget: suggestion.dailyTarget,
      targetTime: suggestion.targetTime,
      reminderTime: suggestion.reminderTime,
    );
  }

  Future<void> _addSuggestedHabit(
    ChatMessage message,
    ChatHabitSuggestion suggestion,
  ) async {
    final key = _suggestionKey(message, suggestion);
    if (_addingSuggestionKeys.contains(key) ||
        _addedSuggestionKeys.contains(key)) {
      return;
    }

    setState(() => _addingSuggestionKeys.add(key));

    try {
      final saved = await showAddHabitBottomSheet(
        context: context,
        ref: ref,
        draft: _buildSuggestionDraft(suggestion),
        title: 'Добавить привычку',
      );

      if (!saved || !mounted) return;

      setState(() => _addedSuggestionKeys.add(key));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Привычка "${suggestion.title}" добавлена')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось добавить привычку')),
      );
    } finally {
      if (mounted) {
        setState(() => _addingSuggestionKeys.remove(key));
      }
    }
  }

  Future<void> _addSuggestionBundle(ChatMessage message) async {
    if (message.suggestedHabits.isEmpty) return;
    final bundleName = (message.suggestedBundleName ?? '').trim().isNotEmpty
        ? message.suggestedBundleName!.trim()
        : ((message.suggestedHabits.firstOrNull?.groupName ?? '')
                .trim()
                .isNotEmpty
            ? message.suggestedHabits.first.groupName!.trim()
            : 'Подборка от AI');
    final messageKey = message.id?.toString() ??
        '${message.sessionId ?? 'local'}:${message.timestamp.millisecondsSinceEpoch}';
    if (_addingBundleMessageKeys.contains(messageKey) ||
        _addedBundleMessageKeys.contains(messageKey)) {
      return;
    }

    setState(() => _addingBundleMessageKeys.add(messageKey));
    try {
      await ref.read(chatProvider.notifier).addBundleFromSuggestions(
            message.suggestedHabits,
            bundleName,
          );
      await ref.read(habitsProvider.notifier).loadHabits();
      if (!mounted) return;
      setState(() {
        _addedBundleMessageKeys.add(messageKey);
        for (final suggestion in message.suggestedHabits) {
          _addedSuggestionKeys.add(_suggestionKey(message, suggestion));
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Папка "$bundleName" создана',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось создать папку привычек')),
      );
    } finally {
      if (mounted) {
        setState(() => _addingBundleMessageKeys.remove(messageKey));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider);
    final messages = chatState.messages;
    final chats = chatState.chats;
    final currentChatId = chatState.currentChatId;

    final shouldJumpToBottom = currentChatId != _lastChatId;
    if (currentChatId != _lastChatId || messages.length != _lastMessageCount) {
      _lastChatId = currentChatId;
      _lastMessageCount = messages.length;
      _scrollToBottom(animated: !shouldJumpToBottom);
    }

    final currentChatTitle = chats
        .where((chat) => chat.chatId == currentChatId)
        .map((chat) => chat.title)
        .cast<String?>()
        .firstOrNull;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        toolbarHeight:
            (currentChatTitle ?? '').trim().isNotEmpty ? 72 : kToolbarHeight,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                const Text('AI Помощник'),
              ],
            ),
            if ((currentChatTitle ?? '').trim().isNotEmpty)
              Text(
                currentChatTitle!,
                style: TextStyle(
                  fontSize: 12,
                  color: context.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: 'Список чатов',
            onPressed: chats.isEmpty
                ? null
                : () => _showChatSessions(chats, currentChatId),
          ),
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Новый чат',
            onPressed: _createNewChat,
          ),
        ],
      ),
      body: AnimatedPadding(
        duration: AppAnimations.fast,
        curve: AppAnimations.enterCurve,
        padding:
            EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          children: [
            Expanded(
              child: AnimatedSwitcher(
                duration: AppAnimations.normal,
                switchInCurve: AppAnimations.enterCurve,
                switchOutCurve: AppAnimations.exitCurve,
                child: _historyLoading
                    ? const Padding(
                        key: ValueKey('chat-loading'),
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: ShimmerLoader(
                            shape: ShimmerShape.listTile, count: 6),
                      )
                    : messages.isEmpty
                        ? _buildEmptyState(
                            key: ValueKey(currentChatId ?? 'chat-empty'),
                          )
                        : ListView.builder(
                            key: ValueKey(currentChatId ?? 'chat-messages'),
                            controller: _scrollController,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            itemCount: messages.length,
                            itemBuilder: (ctx, i) => _MessageBubble(
                              message: messages[i],
                              onAddSuggestedHabit: _addSuggestedHabit,
                              onAddBundle: _addSuggestionBundle,
                              addingSuggestionKeys: _addingSuggestionKeys,
                              addedSuggestionKeys: _addedSuggestionKeys,
                              addingBundleMessageKeys: _addingBundleMessageKeys,
                              addedBundleMessageKeys: _addedBundleMessageKeys,
                            ),
                          ),
              ),
            ),
            if (_sending)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: context.primaryColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'AI думает...',
                      style:
                          TextStyle(color: context.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              )
                  .animate()
                  .fadeIn(
                    duration: AppAnimations.fast.inMilliseconds.ms,
                    curve: AppAnimations.enterCurve,
                  )
                  .slideY(begin: 0.2, curve: AppAnimations.enterCurve),
            Container(
              padding: EdgeInsets.fromLTRB(
                16,
                8,
                8,
                MediaQuery.viewInsetsOf(context).bottom > 0 ? 8 : 16,
              ),
              decoration: BoxDecoration(
                color: context.isDark ? AppColors.darkSurface : Colors.white,
                border: Border(
                  top: BorderSide(color: context.dividerColor, width: 0.5),
                ),
              ),
              child: SafeArea(
                top: false,
                bottom: MediaQuery.viewInsetsOf(context).bottom <= 0,
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        decoration: InputDecoration(
                          hintText: 'Спроси что-нибудь...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: context.surfaceColor,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                        maxLines: 3,
                        minLines: 1,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: const BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        onPressed: _sending ? null : _send,
                        icon: const Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState({Key? key}) {
    return LayoutBuilder(
      key: key,
      builder: (context, constraints) => SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: IntrinsicHeight(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 16,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.auto_awesome,
                      color: Colors.white, size: 36),
                ).animate().scale(
                      begin: const Offset(0.5, 0.5),
                      curve: Curves.easeOutBack,
                    ),
                const SizedBox(height: 20),
                const Text(
                  'Новый пустой чат',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  'Напиши сообщение или выбери быстрый сценарий. История старых чатов доступна через кнопку сверху.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.textSecondary),
                ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    _QuickAction(
                      label: '👋 Привет',
                      onTap: () => _quickSend(
                        'Привет!',
                        contextHints: {
                          'source_screen': 'chat_empty_state',
                          'intent': 'greeting',
                        },
                      ),
                    ),
                    _QuickAction(
                      label: '📊 Статистика',
                      onTap: () => _quickSend(
                        'Покажи мою статистику',
                        contextHints: {
                          'source_screen': 'chat_empty_state',
                          'intent': 'stats_review',
                        },
                      ),
                    ),
                    _QuickAction(
                      label: '💡 Совет',
                      onTap: () => _quickSend(
                        'Дай совет по привычкам',
                        contextHints: {
                          'source_screen': 'chat_empty_state',
                          'intent': 'coaching_advice',
                        },
                      ),
                    ),
                    _QuickAction(
                      label: '😴 Сон',
                      onTap: () => _quickSend(
                        'Предложи привычки для улучшения сна',
                        contextHints: {
                          'source_screen': 'chat_empty_state',
                          'intent': 'sleep_improvement',
                          'focus_areas': ['sleep', 'recovery'],
                        },
                      ),
                    ),
                    _QuickAction(
                      label: '🧠 Настроение',
                      onTap: () => _quickSend(
                        'У меня не лучший день, помоги с мягким планом',
                        contextHints: {
                          'source_screen': 'chat_empty_state',
                          'intent': 'mood_support',
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final Future<void> Function(ChatMessage, ChatHabitSuggestion)?
      onAddSuggestedHabit;
  final Future<void> Function(ChatMessage)? onAddBundle;
  final Set<String> addingSuggestionKeys;
  final Set<String> addedSuggestionKeys;
  final Set<String> addingBundleMessageKeys;
  final Set<String> addedBundleMessageKeys;

  const _MessageBubble({
    required this.message,
    this.onAddSuggestedHabit,
    this.onAddBundle,
    this.addingSuggestionKeys = const {},
    this.addedSuggestionKeys = const {},
    this.addingBundleMessageKeys = const {},
    this.addedBundleMessageKeys = const {},
  });

  String _suggestionKey(ChatHabitSuggestion suggestion) {
    final messageKey = message.id?.toString() ??
        '${message.sessionId ?? 'local'}:${message.timestamp.millisecondsSinceEpoch}';
    return '$messageKey:${suggestion.title.toLowerCase()}';
  }

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final hasSuggestions = message.suggestedHabits.isNotEmpty;
    final effectiveBundleName =
        (message.suggestedBundleName ?? '').trim().isNotEmpty
            ? message.suggestedBundleName!.trim()
            : ((message.suggestedHabits.firstOrNull?.groupName ?? '')
                    .trim()
                    .isNotEmpty
                ? message.suggestedHabits.first.groupName!.trim()
                : 'Подборка от AI');
    final bundleKey = message.id?.toString() ??
        '${message.sessionId ?? 'local'}:${message.timestamp.millisecondsSinceEpoch}';

    final canShowBundleButton = message.suggestedHabits.length > 1;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width *
              (isUser ? 0.78 : (hasSuggestions ? 0.94 : 0.82)),
        ),
        decoration: BoxDecoration(
          gradient: isUser ? AppColors.primaryGradient : null,
          color: isUser
              ? null
              : context.isDark
                  ? AppColors.darkSurfaceVariant
                  : AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isUser ? 18 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 18),
          ),
          boxShadow: isUser
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: isUser
            ? Text(
                message.content,
                softWrap: true,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14.5,
                  height: 1.4,
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MarkdownBody(
                    data: message.content,
                    selectable: true,
                    styleSheet: MarkdownStyleSheet(
                      p: TextStyle(
                        color: context.textPrimary,
                        fontSize: 14.5,
                        height: 1.4,
                      ),
                      strong: const TextStyle(fontWeight: FontWeight.bold),
                      em: const TextStyle(fontStyle: FontStyle.italic),
                      h1: TextStyle(
                        color: context.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      h2: TextStyle(
                        color: context.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      h3: TextStyle(
                        color: context.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      listBullet: TextStyle(color: context.textPrimary),
                    ),
                  ),
                  if (message.suggestedHabits.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      'Предлагаю добавить:',
                      style: TextStyle(
                        color: context.textSecondary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...message.suggestedHabits.asMap().entries.map((entry) {
                      final index = entry.key;
                      final suggestion = entry.value;
                      final key = _suggestionKey(suggestion);
                      final isAdding = addingSuggestionKeys.contains(key);
                      final isAdded = addedSuggestionKeys.contains(key);
                      final description = [
                        suggestion.description?.trim() ?? '',
                        if ((suggestion.reason ?? '').trim().isNotEmpty &&
                            (suggestion.reason?.trim() ?? '') !=
                                (suggestion.description?.trim() ?? ''))
                          suggestion.reason!.trim(),
                      ].where((item) => item.isNotEmpty).join(' • ');

                      final recommendationPills = <Widget>[
                        _ParamPill(
                          icon: Icons.sell_outlined,
                          label: _categoryLabel(suggestion.category),
                        ),
                        _ParamPill(
                          icon: Icons.repeat_rounded,
                          label: suggestion.frequency,
                        ),
                        if ((suggestion.targetTime ?? '').trim().isNotEmpty)
                          _ParamPill(
                            icon: Icons.schedule_rounded,
                            label: 'Время: ${suggestion.targetTime}',
                          )
                        else if ((suggestion.timeOfDay ?? '').trim().isNotEmpty)
                          _ParamPill(
                            icon: Icons.wb_twilight_outlined,
                            label: _timeOfDayLabel(suggestion.timeOfDay),
                          ),
                      ];

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: context.glassColor,
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusLg + 2),
                          border: Border.all(
                            color: isAdded
                                ? AppColors.success.withValues(alpha: 0.28)
                                : context.glassBorder,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(
                                alpha: context.isDark ? 0.16 : 0.06,
                              ),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.cardPadding),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      suggestion.title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                        color: context.textPrimary,
                                      ),
                                    ),
                                    if (description.isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Text(
                                        description,
                                        maxLines: 4,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 13,
                                          height: 1.35,
                                          color: context.textSecondary,
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 10),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: recommendationPills,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              AnimatedContainer(
                                duration: AppAnimations.fast,
                                curve: AppAnimations.enterCurve,
                                child: isAdded
                                    ? Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.success
                                              .withValues(alpha: 0.14),
                                          borderRadius:
                                              BorderRadius.circular(14),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.check_rounded,
                                              color: AppColors.success,
                                              size: 18,
                                            ),
                                            SizedBox(width: 6),
                                            Text(
                                              'Добавлено',
                                              style: TextStyle(
                                                color: AppColors.success,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 12.5,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    : Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          onTap: (isAdding ||
                                                  onAddSuggestedHabit == null)
                                              ? null
                                              : () => onAddSuggestedHabit!(
                                                    message,
                                                    suggestion,
                                                  ),
                                          child: Ink(
                                            width: 44,
                                            height: 44,
                                            decoration: BoxDecoration(
                                              gradient:
                                                  AppColors.primaryGradient,
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: AppColors.primary
                                                      .withValues(alpha: 0.28),
                                                  blurRadius: 10,
                                                  offset: const Offset(0, 4),
                                                ),
                                              ],
                                            ),
                                            child: isAdding
                                                ? const Center(
                                                    child: SizedBox(
                                                      width: 18,
                                                      height: 18,
                                                      child:
                                                          CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                  )
                                                : const Icon(
                                                    Icons.add_rounded,
                                                    color: Colors.white,
                                                    size: 22,
                                                  ),
                                          ),
                                        ),
                                      ),
                              ),
                            ],
                          ),
                        ),
                      )
                          .animate()
                          .fadeIn(
                            delay: (120 + index * 70).ms,
                            duration: AppAnimations.normal.inMilliseconds.ms,
                            curve: AppAnimations.enterCurve,
                          )
                          .slideY(
                            begin: 0.12,
                            end: 0,
                            curve: AppAnimations.enterCurve,
                          )
                          .scale(
                            begin: const Offset(0.98, 0.98),
                            curve: AppAnimations.enterCurve,
                          );
                    }),
                    if (canShowBundleButton)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          onPressed: (onAddBundle == null ||
                                  addingBundleMessageKeys.contains(bundleKey) ||
                                  addedBundleMessageKeys.contains(bundleKey))
                              ? null
                              : () => onAddBundle!(message),
                          icon: addingBundleMessageKeys.contains(bundleKey)
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Icon(
                                  addedBundleMessageKeys.contains(bundleKey)
                                      ? Icons.check_circle_outline_rounded
                                      : Icons.create_new_folder_outlined,
                                  size: 18,
                                  color:
                                      addedBundleMessageKeys.contains(bundleKey)
                                          ? AppColors.success
                                          : AppColors.primary,
                                ),
                          label: Text(
                            addedBundleMessageKeys.contains(bundleKey)
                                ? 'Папка создана'
                                : 'Создать папку: $effectiveBundleName',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            softWrap: true,
                            style: TextStyle(
                              color: addedBundleMessageKeys.contains(bundleKey)
                                  ? AppColors.success
                                  : AppColors.primary,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            side: BorderSide(
                              color: (addedBundleMessageKeys.contains(bundleKey)
                                      ? AppColors.success
                                      : AppColors.primary)
                                  .withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                      ),
                  ],
                ],
              ),
      ),
    )
        .animate()
        .fadeIn(
          duration: AppAnimations.normal.inMilliseconds.ms,
          curve: AppAnimations.enterCurve,
        )
        .slideY(begin: 0.1, curve: AppAnimations.enterCurve);
  }
}

class _ChatSessionsSheet extends StatefulWidget {
  final List<ChatSession> chats;
  final String? currentId;
  final void Function(String chatId) onOpen;
  final VoidCallback onCreateNew;
  final Future<void> Function(List<String> ids) onDeleteSelected;

  const _ChatSessionsSheet({
    required this.chats,
    required this.currentId,
    required this.onOpen,
    required this.onCreateNew,
    required this.onDeleteSelected,
  });

  @override
  State<_ChatSessionsSheet> createState() => _ChatSessionsSheetState();
}

class _ChatSessionsSheetState extends State<_ChatSessionsSheet> {
  final Set<String> _selected = {};
  bool _deleting = false;
  late List<ChatSession> _localChats;

  @override
  void initState() {
    super.initState();
    _localChats = List<ChatSession>.from(widget.chats);
  }

  @override
  void didUpdateWidget(covariant _ChatSessionsSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.chats != widget.chats) {
      _localChats = List<ChatSession>.from(widget.chats);
      _selected
          .removeWhere((id) => !_localChats.any((chat) => chat.chatId == id));
    }
  }

  bool get _selectionMode => _selected.isNotEmpty;

  void _toggleSelect(String id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else {
        _selected.add(id);
      }
    });
  }

  Future<void> _deleteSelected() async {
    final ids = List<String>.from(_selected);
    final previousChats = List<ChatSession>.from(_localChats);
    setState(() {
      _deleting = true;
      _localChats.removeWhere((chat) => ids.contains(chat.chatId));
      _selected.clear();
    });

    if (_localChats.isEmpty && mounted) {
      Navigator.pop(context);
    }
    try {
      await widget.onDeleteSelected(ids);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Удалено чатов: ${ids.length}')),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _localChats = previousChats;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось удалить выбранные чаты.')),
      );
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  Future<void> _deleteSingle(ChatSession chat, int index) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _localChats.removeAt(index);
      _selected.remove(chat.chatId);
    });

    try {
      await widget.onDeleteSelected([chat.chatId]);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Чат "${chat.title}" удалён')),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        final safeIndex = index.clamp(0, _localChats.length);
        _localChats.insert(safeIndex, chat);
      });
      messenger.showSnackBar(
        const SnackBar(
            content: Text('Не удалось удалить чат. Попробуйте снова.')),
      );
    }
  }

  Future<bool> _confirmDeleteSingle(ChatSession chat) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить чат?'),
        content: Text(
            'Чат "${chat.title}" будет удалён без возможности восстановления.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child:
                const Text('Удалить', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final chats = _localChats;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _selectionMode
                        ? 'Выбрано: ${_selected.length}'
                        : 'Мои чаты',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: context.textPrimary,
                    ),
                  ),
                ),
                if (_selectionMode) ...[
                  if (_deleting)
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded),
                      color: Colors.red,
                      tooltip: 'Удалить выбранные',
                      onPressed: _deleteSelected,
                    ),
                  TextButton(
                    onPressed: () => setState(() => _selected.clear()),
                    child: const Text('Отмена'),
                  ),
                ] else
                  FilledButton.icon(
                    onPressed: widget.onCreateNew,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Новый'),
                  ),
              ],
            ),
            if (!_selectionMode)
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 4),
                child: Text(
                  'Зажмите чат, чтобы выбрать несколько',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.textSecondary,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: chats.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (ctx, index) {
                  final chat = chats[index];
                  final isActive = chat.chatId == widget.currentId;
                  final isSelected = _selected.contains(chat.chatId);
                  Widget tile = _ChatSessionTile(
                    chat: chat,
                    isActive: isActive,
                    isSelected: isSelected,
                    isSelectionMode: _selectionMode,
                    onTap: _selectionMode
                        ? () => _toggleSelect(chat.chatId)
                        : () => widget.onOpen(chat.chatId),
                    onLongPress: () => _toggleSelect(chat.chatId),
                  );

                  if (!_selectionMode) {
                    tile = Dismissible(
                      key: ValueKey('chat_${chat.chatId}'),
                      direction: DismissDirection.endToStart,
                      confirmDismiss: (_) => _confirmDeleteSingle(chat),
                      onDismissed: (_) async {
                        await _deleteSingle(chat, index);
                      },
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          gradient: AppColors.accentGradient,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.delete_outline_rounded,
                          color: Colors.white,
                        ),
                      ),
                      child: tile,
                    );
                  }

                  return tile;
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatSessionTile extends StatelessWidget {
  final ChatSession chat;
  final bool isActive;
  final bool isSelected;
  final bool isSelectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _ChatSessionTile({
    required this.chat,
    required this.isActive,
    required this.onTap,
    required this.onLongPress,
    this.isSelected = false,
    this.isSelectionMode = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary
                    .withValues(alpha: context.isDark ? 0.25 : 0.15)
                : isActive
                    ? AppColors.primary
                        .withValues(alpha: context.isDark ? 0.16 : 0.1)
                    : context.glassColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? AppColors.primary.withValues(alpha: 0.6)
                  : isActive
                      ? AppColors.primary.withValues(alpha: 0.35)
                      : context.glassBorder,
            ),
          ),
          child: Row(
            children: [
              if (isSelectionMode) ...[
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: Icon(
                    isSelected
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    key: ValueKey(isSelected),
                    color:
                        isSelected ? AppColors.primary : context.textSecondary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child:
                    const Icon(Icons.chat_bubble_rounded, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      chat.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      softWrap: true,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: context.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      chat.preview?.trim().isNotEmpty == true
                          ? chat.preview!
                          : 'Пустой чат',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      softWrap: true,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: context.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (isActive)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'Открыт',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  const SizedBox(height: 6),
                  Text(
                    '${chat.messageCount}',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _QuickAction({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 13)),
      onPressed: onTap,
      backgroundColor: AppColors.primary.withValues(alpha: 0.08),
      side: BorderSide(color: AppColors.primary.withValues(alpha: 0.2)),
    );
  }
}

class _ParamPill extends StatelessWidget {
  final String label;
  final IconData? icon;

  const _ParamPill({required this.label, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: context.isDark ? 0.16 : 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: AppColors.primary),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

String _categoryLabel(String value) {
  switch (value.toLowerCase()) {
    case 'sleep':
      return 'Сон';
    case 'health':
      return 'Здоровье';
    case 'fitness':
      return 'Фитнес';
    case 'nutrition':
      return 'Питание';
    case 'mindfulness':
      return 'Осознанность';
    case 'productivity':
      return 'Продуктивность';
    case 'learning':
      return 'Обучение';
    case 'social':
      return 'Социальное';
    case 'finance':
      return 'Финансы';
    default:
      return 'Другое';
  }
}

String _timeOfDayLabel(String? value) {
  switch ((value ?? '').toLowerCase()) {
    case 'morning':
      return 'Утро';
    case 'day':
      return 'День';
    case 'evening':
      return 'Вечер';
    default:
      return 'Любое время';
  }
}
