import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/mood_provider.dart';
import '../services/dio_service.dart';
import '../theme/app_theme.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  List<Map<String, dynamic>> _messages = [];
  List<String> _suggestedFollowUps = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Initialize welcome message after providers are initialized
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeChat();
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _initializeChat() {
    final todayMood = ref.read(todayMoodProvider).value;
    final history = ref.read(moodHistoryProvider).value ?? [];
    final int score = todayMood ?? (history.isNotEmpty ? history.first.moodScore : 3);

    setState(() {
      _messages = [
        {
          'role': 'model',
          'text': "Hi! I see you're feeling a $score/5 today. How are you really doing?",
        }
      ];
    });
  }

  double _calculateWeeklyAverage() {
    final history = ref.read(moodHistoryProvider).value ?? [];
    if (history.isEmpty) return 3.0;
    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));
    final recentEntries = history.where((e) => e.timestamp.isAfter(sevenDaysAgo)).toList();
    if (recentEntries.isEmpty) {
      return history.first.moodScore.toDouble();
    }
    final sum = recentEntries.map((e) => e.moodScore).reduce((a, b) => a + b);
    return sum / recentEntries.length;
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    // 1. Append user message locally
    setState(() {
      _messages.add({
        'role': 'user',
        'text': text,
      });
      _suggestedFollowUps = []; // clear previous suggestions
      _isLoading = true;
    });
    _messageController.clear();
    _scrollToBottom();

    try {
      final dio = ref.read(dioServiceProvider);
      
      // Calculate mood context
      final todayMood = ref.read(todayMoodProvider).value;
      final history = ref.read(moodHistoryProvider).value ?? [];
      final int score = todayMood ?? (history.isNotEmpty ? history.first.moodScore : 3);
      final double weeklyAverage = _calculateWeeklyAverage();

      final moodContext = {
        'currentScore': score,
        'weeklyAverage': weeklyAverage,
      };

      // Prepare conversation history for backend (excluding initial welcome message if preferred,
      // but standard is to include all alternating turns so Gemini has context)
      final historyToSend = _messages.sublist(0, _messages.length - 1).map((m) {
        return {
          'role': m['role'],
          'text': m['text'],
        };
      }).toList();

      final response = await dio.sendChatMessage(
        message: text,
        conversationHistory: historyToSend,
        moodContext: moodContext,
      );

      final String reply = response['reply'] as String? ?? "I'm here to listen. Tell me more.";
      final List<String> followUps = List<String>.from(response['suggestedFollowUps'] ?? []);

      if (mounted) {
        setState(() {
          _messages.add({
            'role': 'model',
            'text': reply,
          });
          _suggestedFollowUps = followUps;
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint('ChatScreen error: $e');
      if (mounted) {
        setState(() {
          _messages.add({
            'role': 'model',
            'text': "I'm having a little trouble connecting right now, but I'm still here for you. How are you feeling?",
          });
          _isLoading = false;
        });
        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            Text(
              'MindChat',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(width: 8),
            // Gemini-powered badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF4285F4),
                    Color(0xFF8F00FF),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.auto_awesome,
                    color: Colors.white,
                    size: 10,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Gemini',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: AppColors.borderOverlay,
            height: 1.0,
          ),
        ),
      ),
      body: Column(
        children: [
          // Message List
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length && _isLoading) {
                  return const Align(
                    alignment: Alignment.centerLeft,
                    child: ChatBubble(
                      isUser: false,
                      isTyping: true,
                      child: TypingIndicator(),
                    ),
                  );
                }

                final msg = _messages[index];
                final bool isUser = msg['role'] == 'user';
                final isLast = index == _messages.length - 1;

                return Column(
                  crossAxisAlignment: isUser
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    ChatBubble(
                      isUser: isUser,
                      child: Text(
                        msg['text'] as String,
                        style: TextStyle(
                          color: isUser ? Colors.black87 : Colors.white,
                          fontSize: 14.5,
                          height: 1.4,
                          fontWeight: isUser ? FontWeight.w500 : FontWeight.normal,
                        ),
                      ),
                    ),
                    // Show suggested follow-up chips below the last AI message
                    if (!isUser && isLast && _suggestedFollowUps.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _suggestedFollowUps.map((text) {
                          return ActionChip(
                            label: Text(
                              text,
                              style: const TextStyle(
                                color: AppColors.primaryColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            backgroundColor: AppColors.surfaceColor,
                            side: const BorderSide(
                              color: AppColors.borderOverlay,
                              width: 1,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            elevation: 0,
                            onPressed: () => _sendMessage(text),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                );
              },
            ),
          ),
          
          // Input bar
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            decoration: const BoxDecoration(
              color: Colors.transparent,
              border: Border(
                top: BorderSide(
                  color: AppColors.borderOverlay,
                  width: 1.0,
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    onSubmitted: (val) => _sendMessage(val),
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                    decoration: InputDecoration(
                      hintText: "Talk about your feelings...",
                      hintStyle: const TextStyle(
                        color: AppColors.navBarUnselected,
                        fontSize: 14.5,
                      ),
                      fillColor: AppColors.surfaceColor,
                      filled: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(
                          color: AppColors.borderOverlay,
                          width: 1,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(
                          color: AppColors.borderOverlay,
                          width: 1,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(
                          color: AppColors.primaryColor,
                          width: 1,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () => _sendMessage(_messageController.text),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: AppColors.primaryColor,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.send_rounded,
                      color: Colors.black,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ChatBubble extends StatelessWidget {
  final bool isUser;
  final bool isTyping;
  final Widget child;

  const ChatBubble({
    super.key,
    required this.isUser,
    required this.child,
    this.isTyping = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: isTyping ? 12 : 12,
      ),
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.76,
      ),
      decoration: BoxDecoration(
        color: isUser ? AppColors.primaryColor : AppColors.surfaceColor,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(isUser ? 16 : 0),
          bottomRight: Radius.circular(isUser ? 0 : 16),
        ),
        border: !isUser
            ? const Border(
                left: BorderSide(
                  color: Color(0xFF4285F4),
                  width: 3.0,
                ),
              )
            : null,
      ),
      child: child,
    );
  }
}

class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final double delay = index * 0.2;
            final double value = math.sin((_controller.value * 2 * math.pi) - delay);
            final double opacity = ((value + 1) / 2).clamp(0.2, 1.0);
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2.0),
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: const Color(0xFF4285F4).withValues(alpha: opacity),
                shape: BoxShape.circle,
              ),
            );
          },
        );
      }),
    );
  }
}
