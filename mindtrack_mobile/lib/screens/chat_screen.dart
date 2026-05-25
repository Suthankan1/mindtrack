import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
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

  bool _hasCrisisActive = false;
  List<dynamic> _activeCrisisResources = [];

  @override
  void initState() {
    super.initState();
    // Initialize/load chat history after providers are initialized
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadChatHistory();
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadChatHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final email =
          prefs.getString('user_email') ?? 'practitioner@mindtrack.com';
      final historyStr = prefs.getString('chat_history_$email');

      if (historyStr != null) {
        final List<dynamic> decoded = json.decode(historyStr);
        final loadedMessages = decoded
            .map((m) => Map<String, dynamic>.from(m))
            .toList();

        bool hasCrisis = false;
        List<dynamic> activeCrisis = [];
        for (final msg in loadedMessages.reversed) {
          if (msg['showCrisisResources'] == true &&
              msg['crisisResources'] != null) {
            hasCrisis = true;
            activeCrisis = List<dynamic>.from(msg['crisisResources']);
            break;
          }
        }

        if (mounted) {
          setState(() {
            _messages = loadedMessages;
            _hasCrisisActive = hasCrisis;
            _activeCrisisResources = activeCrisis;
            if (_messages.isNotEmpty && _messages.last['role'] == 'model') {
              _suggestedFollowUps = List<String>.from(
                _messages.last['suggestedFollowUps'] ?? [],
              );
            }
          });
          _scrollToBottom();
        }
        return;
      }
    } catch (e) {
      debugPrint('Error loading chat history: $e');
    }

    _initializeChat();
  }

  Future<void> _saveChatHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final email =
          prefs.getString('user_email') ?? 'practitioner@mindtrack.com';

      if (_messages.isNotEmpty && _messages.last['role'] == 'model') {
        _messages.last['suggestedFollowUps'] = _suggestedFollowUps;
      }

      await prefs.setString('chat_history_$email', json.encode(_messages));
    } catch (e) {
      debugPrint('Error saving chat history: $e');
    }
  }

  void _initializeChat() {
    final todayMood = ref.read(todayMoodProvider).value;
    final history = ref.read(moodHistoryProvider).value ?? [];
    final int score =
        todayMood ?? (history.isNotEmpty ? history.first.moodScore : 3);

    setState(() {
      _messages = [
        {
          'role': 'model',
          'text':
              "Hi! I see you're feeling a $score/5 today. How are you really doing?",
          'suggestedFollowUps': <String>[],
        },
      ];
    });
    _saveChatHistory();
  }

  double _calculateWeeklyAverage() {
    final history = ref.read(moodHistoryProvider).value ?? [];
    if (history.isEmpty) return 3.0;
    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));
    final recentEntries = history
        .where((e) => e.timestamp.isAfter(sevenDaysAgo))
        .toList();
    if (recentEntries.isEmpty) {
      return history.first.moodScore.toDouble();
    }
    final sum = recentEntries.map((e) => e.moodScore).reduce((a, b) => a + b);
    return sum / recentEntries.length;
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    setState(() {
      _messages.add({'role': 'user', 'text': text, 'isFailed': false});
      _suggestedFollowUps = []; // clear previous suggestions
      _isLoading = true;
    });
    _messageController.clear();
    _scrollToBottom();
    await _saveChatHistory();

    try {
      final dio = ref.read(dioServiceProvider);

      // Calculate mood context
      final todayMood = ref.read(todayMoodProvider).value;
      final history = ref.read(moodHistoryProvider).value ?? [];
      final int score =
          todayMood ?? (history.isNotEmpty ? history.first.moodScore : 3);
      final double weeklyAverage = _calculateWeeklyAverage();

      final moodContext = {
        'currentScore': score,
        'weeklyAverage': weeklyAverage,
      };

      // Prepare conversation history for backend (excluding initial welcome message if preferred,
      // but standard is to include all alternating turns so Gemini has context)
      // Limit to last 8 messages.
      final rawHistory = _messages.sublist(0, _messages.length - 1);
      final startIndex = math.max(0, rawHistory.length - 8);
      final historyToSend = rawHistory.sublist(startIndex).map((m) {
        return {'role': m['role'], 'text': m['text']};
      }).toList();

      final response = await dio.sendChatMessage(
        message: text,
        conversationHistory: historyToSend,
        moodContext: moodContext,
      );

      final String reply =
          response['reply'] as String? ?? "I'm here to listen. Tell me more.";
      final List<String> followUps = List<String>.from(
        response['suggestedFollowUps'] ?? [],
      );
      final bool showCrisisResources = response['showCrisisResources'] == true;
      final List<dynamic> crisisResources = response['crisisResources'] ?? [];

      if (mounted) {
        setState(() {
          _messages.add({
            'role': 'model',
            'text': reply,
            'showCrisisResources': showCrisisResources,
            'crisisResources': crisisResources,
            'suggestedFollowUps': followUps,
          });
          _suggestedFollowUps = followUps;
          _isLoading = false;
          if (showCrisisResources && crisisResources.isNotEmpty) {
            _hasCrisisActive = true;
            _activeCrisisResources = List<dynamic>.from(crisisResources);
          }
        });
        _scrollToBottom();
        await _saveChatHistory();
      }
    } catch (e) {
      debugPrint('ChatScreen error: $e');
      if (mounted) {
        setState(() {
          if (_messages.isNotEmpty && _messages.last['role'] == 'user') {
            _messages.last['isFailed'] = true;
          }
          _isLoading = false;
        });
        _scrollToBottom();
        await _saveChatHistory();
      }
    }
  }

  Future<void> _retryMessage(int index) async {
    if (_isLoading) return;

    final failedMsg = _messages[index];
    final text = failedMsg['text'] as String;

    setState(() {
      _messages.removeRange(index, _messages.length);
      _isLoading = true;
    });

    _scrollToBottom();
    await _sendMessage(text);
  }

  Future<void> _launchUrl(String urlString) async {
    try {
      final Uri url = Uri.parse(urlString);
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw Exception('Could not launch $urlString');
      }
    } catch (e) {
      debugPrint('ChatScreen: Error launching URL: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open lifeline. Error: $e'),
            backgroundColor: AppColors.errorColor,
          ),
        );
      }
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 200), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Widget _buildPinnedCrisisBanner() {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3B1E1E), Color(0xFF2C1616)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.errorColor.withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: AppColors.errorColor,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Immediate Support Available',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white70, size: 18),
                onPressed: () {
                  setState(() {
                    _hasCrisisActive = false;
                  });
                },
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'If you are in danger or need immediate help, please reach out to local emergency services or use these resources:',
            style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.3),
          ),
          const SizedBox(height: 12),
          Column(
            children: _activeCrisisResources.map((res) {
              final name = res['lineName'] ?? 'Helpline';
              final phone = res['phoneNumber'] ?? '';
              final web = res['website'] ?? '';
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borderOverlay),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          if (web.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            GestureDetector(
                              onTap: () => _launchUrl(web),
                              child: Text(
                                web,
                                style: const TextStyle(
                                  color: AppColors.primaryColor,
                                  fontSize: 12,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (phone.isNotEmpty)
                      ElevatedButton.icon(
                        onPressed: () => _launchUrl('tel:$phone'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.errorColor.withValues(
                            alpha: 0.2,
                          ),
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: AppColors.errorColor),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.phone, size: 14),
                        label: Text(
                          phone,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderOverlay),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "How I can support you:",
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                _buildFeatureRow(
                  Icons.psychology_outlined,
                  "Reflect on your thoughts and emotional patterns",
                ),
                const SizedBox(height: 8),
                _buildFeatureRow(
                  Icons.air_rounded,
                  "Guide you through soothing breathing exercises",
                ),
                const SizedBox(height: 8),
                _buildFeatureRow(
                  Icons.analytics_outlined,
                  "Help identify stress triggers from your logs",
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            "Tap a suggestion to start:",
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildMoodContextChip("I feel anxious"),
              _buildMoodContextChip("Help me breathe"),
              _buildMoodContextChip("Reflect on today"),
              _buildMoodContextChip("What pattern do you see?"),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.02),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.borderOverlay.withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  color: AppColors.navBarUnselected,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Disclaimer: MindChat is a space for supportive reflection. It is not designed for emergency care, crisis intervention, or professional therapy.",
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.navBarUnselected,
                      fontSize: 11,
                      height: 1.4,
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

  Widget _buildFeatureRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primaryColor, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ),
      ],
    );
  }

  Widget _buildMoodContextChip(String text) {
    return ActionChip(
      label: Text(
        text,
        style: const TextStyle(
          color: AppColors.primaryColor,
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
        ),
      ),
      backgroundColor: AppColors.surfaceColor,
      side: const BorderSide(color: AppColors.borderOverlay),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      onPressed: () => _sendMessage(text),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4285F4), Color(0xFF8F00FF)],
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
            Text(
              '${_messages.length} messages',
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Clear Chat',
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: () {
              setState(() {
                _messages = [];
                _suggestedFollowUps = [];
              });
              _initializeChat();
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: AppColors.borderOverlay, height: 1.0),
        ),
      ),
      body: Column(
        children: [
          // Pinned Crisis Support Banner
          if (_hasCrisisActive && _activeCrisisResources.isNotEmpty)
            _buildPinnedCrisisBanner(),

          // Message List
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              itemCount:
                  _messages.length +
                  (_isLoading ? 1 : 0) +
                  (_messages.length <= 1 ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length && _isLoading) {
                  return const Align(
                    alignment: Alignment.centerLeft,
                    child: ChatBubble(
                      isUser: false,
                      isTyping: true,
                      child: PolishedTypingIndicator(),
                    ),
                  );
                }

                if (_messages.length <= 1 &&
                    index == _messages.length + (_isLoading ? 1 : 0)) {
                  return _buildEmptyState();
                }

                final msg = _messages[index];
                final bool isUser = msg['role'] == 'user';
                final isLast = index == _messages.length - 1;
                final bool showCrisis = msg['showCrisisResources'] == true;
                final List<dynamic> resources = msg['crisisResources'] ?? [];
                final bool isFailed = msg['isFailed'] == true;

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
                          fontWeight: isUser
                              ? FontWeight.w500
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                    if (isUser && isFailed) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            color: AppColors.errorColor,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            'Failed to send. ',
                            style: TextStyle(
                              color: AppColors.errorColor,
                              fontSize: 12,
                            ),
                          ),
                          GestureDetector(
                            onTap: () => _retryMessage(index),
                            child: const Text(
                              'Retry',
                              style: TextStyle(
                                color: AppColors.primaryColor,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                    // Show crisis resource card if requested and has resources
                    if (showCrisis && resources.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          width: MediaQuery.of(context).size.width * 0.8,
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.errorColor.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppColors.errorColor.withValues(
                                alpha: 0.3,
                              ),
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.support_agent_rounded,
                                    color: AppColors.errorColor,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Crisis Support Resources',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              ...resources.map((res) {
                                final name = res['lineName'] ?? 'Helpline';
                                final phone = res['phoneNumber'] ?? '';
                                final web = res['website'] ?? '';
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8.0),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceColor,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: AppColors.borderOverlay,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            if (phone.isNotEmpty) ...[
                                              Row(
                                                children: [
                                                  const Icon(
                                                    Icons.phone,
                                                    size: 12,
                                                    color:
                                                        AppColors.primaryColor,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    phone,
                                                    style: const TextStyle(
                                                      color: AppColors
                                                          .primaryColor,
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(width: 16),
                                            ],
                                            if (web.isNotEmpty)
                                              Expanded(
                                                child: GestureDetector(
                                                  onTap: () => _launchUrl(web),
                                                  child: Text(
                                                    web,
                                                    style: const TextStyle(
                                                      color: AppColors
                                                          .navBarUnselected,
                                                      fontSize: 12,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      decoration: TextDecoration
                                                          .underline,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      ),
                    ],
                    // Show suggested follow-up chips below the last AI message
                    if (!isUser &&
                        isLast &&
                        _suggestedFollowUps.isNotEmpty) ...[
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

          // Input bar with Disclaimer
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            decoration: const BoxDecoration(
              color: Colors.transparent,
              border: Border(
                top: BorderSide(color: AppColors.borderOverlay, width: 1.0),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        onSubmitted: (val) => _sendMessage(val),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                        ),
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
                const SizedBox(height: 8),
                Text(
                  "MindChat is a supportive reflection companion, not a replacement for therapy or emergency care.",
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.navBarUnselected,
                    fontSize: 10.5,
                  ),
                  textAlign: TextAlign.center,
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
                left: BorderSide(color: Color(0xFF4285F4), width: 3.0),
              )
            : null,
      ),
      child: child,
    );
  }
}

class PolishedTypingIndicator extends StatefulWidget {
  const PolishedTypingIndicator({super.key});

  @override
  State<PolishedTypingIndicator> createState() =>
      _PolishedTypingIndicatorState();
}

class _PolishedTypingIndicatorState extends State<PolishedTypingIndicator>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(3, (index) {
      return AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 600),
      );
    });

    _animations = _controllers.map((controller) {
      return Tween<double>(
        begin: 0.0,
        end: -8.0,
      ).animate(CurvedAnimation(parent: controller, curve: Curves.easeInOut));
    }).toList();

    _startAnimations();
  }

  void _startAnimations() async {
    for (int i = 0; i < 3; i++) {
      if (!mounted) return;
      _playAnimation(i);
      await Future.delayed(const Duration(milliseconds: 150));
    }
  }

  void _playAnimation(int index) async {
    if (!mounted) return;
    await _controllers[index].forward();
    if (!mounted) return;
    await _controllers[index].reverse();
    if (mounted) {
      _playAnimation(index);
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (index) {
          return AnimatedBuilder(
            animation: _animations[index],
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, _animations[index].value),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: Color(0xFF4285F4),
                    shape: BoxShape.circle,
                  ),
                ),
              );
            },
          );
        }),
      ),
    );
  }
}
