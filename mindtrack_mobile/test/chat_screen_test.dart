import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mindtrack_mobile/screens/chat_screen.dart';
import 'package:mindtrack_mobile/services/dio_service.dart';
import 'package:mindtrack_mobile/providers/mood_provider.dart';

// Fakes for testing
class FakeChatDioService extends DioService {
  Map<String, dynamic> responseToReturn;
  bool shouldThrow;
  List<dynamic> capturedHistory = [];
  String? capturedMessage;

  FakeChatDioService({
    required this.responseToReturn,
    this.shouldThrow = false,
  });

  @override
  Future<Map<String, dynamic>> sendChatMessage({
    required String message,
    required List<dynamic> conversationHistory,
    required Map<String, dynamic> moodContext,
  }) async {
    if (shouldThrow) {
      throw Exception("Network failure simulation");
    }
    capturedMessage = message;
    capturedHistory = conversationHistory;
    return responseToReturn;
  }
}

class FakeTodayMoodNotifier extends TodayMoodNotifier {
  @override
  FutureOr<int?> build() => 4;
}

class FakeMoodHistoryNotifier extends MoodHistoryNotifier {
  @override
  FutureOr<List<MoodEntry>> build() => [];
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'user_email': 'testuser@example.com',
      'auth_jwt_token': 'fake_token',
    });
  });

  testWidgets('MindChat Empty State, Disclaimer, and Chips render on start', (WidgetTester tester) async {
    final fakeDio = FakeChatDioService(responseToReturn: {
      'reply': 'I hear you.',
      'suggestedFollowUps': <String>[],
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dioServiceProvider.overrideWith((ref) => fakeDio),
          todayMoodProvider.overrideWith(FakeTodayMoodNotifier.new),
          moodHistoryProvider.overrideWith(FakeMoodHistoryNotifier.new),
        ],
        child: const MaterialApp(
          home: ChatScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Title and Gemini badge
    expect(find.text('MindChat'), findsOneWidget);
    expect(find.text('Gemini'), findsOneWidget);

    // Verify Welcome message
    expect(find.textContaining("feeling a 4/5 today"), findsOneWidget);

    // Verify empty state features
    expect(find.text('How I can support you:'), findsOneWidget);
    expect(find.textContaining('Reflect on your thoughts'), findsOneWidget);

    // Verify mood chips
    expect(find.text('I feel anxious'), findsOneWidget);
    expect(find.text('Help me breathe'), findsOneWidget);
    expect(find.text('Reflect on today'), findsOneWidget);
    expect(find.text('What pattern do you see?'), findsOneWidget);

    // Verify Disclaimer
    expect(find.textContaining('Disclaimer: MindChat is a space for supportive reflection'), findsWidgets);
  });

  testWidgets('Tapping suggestion chip sends message and displays reply', (WidgetTester tester) async {
    final fakeDio = FakeChatDioService(responseToReturn: {
      'reply': 'Let us take a slow breath together.',
      'suggestedFollowUps': ['Can we do box breathing?'],
      'showCrisisResources': false,
      'crisisResources': [],
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dioServiceProvider.overrideWith((ref) => fakeDio),
          todayMoodProvider.overrideWith(FakeTodayMoodNotifier.new),
          moodHistoryProvider.overrideWith(FakeMoodHistoryNotifier.new),
        ],
        child: const MaterialApp(
          home: ChatScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Tap the 'Help me breathe' chip
    await tester.tap(find.text('Help me breathe'));
    await tester.pump(); // Start request

    // Wait for the async operation to complete
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();

    // Verify user message bubble was rendered
    expect(find.text('Help me breathe'), findsWidgets);

    // Verify model reply was rendered
    expect(find.text('Let us take a slow breath together.'), findsOneWidget);

    // Verify transient suggested followups rendered as chips
    expect(find.text('Can we do box breathing?'), findsOneWidget);

    // Verify empty state is now hidden since messages count > 1
    expect(find.text('How I can support you:'), findsNothing);
  });

  testWidgets('Failed message displays retry button and retry works', (WidgetTester tester) async {
    // 1. First request fails
    final fakeDio = FakeChatDioService(
      responseToReturn: {
        'reply': 'Anxiety can be tough. I am here.',
        'suggestedFollowUps': <String>[],
      },
      shouldThrow: true,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dioServiceProvider.overrideWith((ref) => fakeDio),
          todayMoodProvider.overrideWith(FakeTodayMoodNotifier.new),
          moodHistoryProvider.overrideWith(FakeMoodHistoryNotifier.new),
        ],
        child: const MaterialApp(
          home: ChatScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Tap suggestion to send message
    await tester.tap(find.text('I feel anxious'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();

    // Verify user message shows error indicator and "Retry" text
    expect(find.text('Failed to send. '), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);

    // 2. Disable throwing on the SAME service instance so it succeeds on retry
    fakeDio.shouldThrow = false;

    // Tap "Retry"
    await tester.tap(find.text('Retry'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();

    // Verify failed indicator is gone
    expect(find.text('Failed to send. '), findsNothing);

    // Verify model reply succeeded
    expect(find.text('Anxiety can be tough. I am here.'), findsOneWidget);
  });

  testWidgets('High-risk message pins crisis resources banner, and close button dismisses it', (WidgetTester tester) async {
    final fakeDio = FakeChatDioService(responseToReturn: {
      'reply': 'Please know you are not alone.',
      'suggestedFollowUps': <String>[],
      'showCrisisResources': true,
      'crisisResources': [
        {
          'lineName': '988 Suicide & Crisis Lifeline',
          'phoneNumber': '988',
          'website': 'https://988lifeline.org',
        }
      ],
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dioServiceProvider.overrideWith((ref) => fakeDio),
          todayMoodProvider.overrideWith(FakeTodayMoodNotifier.new),
          moodHistoryProvider.overrideWith(FakeMoodHistoryNotifier.new),
        ],
        child: const MaterialApp(
          home: ChatScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Tap Suggestion Chip
    await tester.tap(find.text('I feel anxious'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();

    // Verify pinned crisis support banner exists
    expect(find.text('Immediate Support Available'), findsOneWidget);
    expect(find.textContaining('988 Suicide & Crisis Lifeline'), findsWidgets);

    // Tap Close Button on the pinned banner
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    // Verify pinned banner is dismissed
    expect(find.text('Immediate Support Available'), findsNothing);
  });

  testWidgets('Chat survives app restart and is saved per-user', (WidgetTester tester) async {
    // Mock user email and initial chat history in SharedPreferences
    final messagesToSave = [
      {'role': 'model', 'text': "Initial message", 'suggestedFollowUps': <String>[]},
      {'role': 'user', 'text': "My custom message", 'isFailed': false},
      {'role': 'model', 'text': "My custom response", 'suggestedFollowUps': <String>[]},
    ];

    SharedPreferences.setMockInitialValues({
      'user_email': 'customuser@example.com',
      'chat_history_customuser@example.com': json.encode(messagesToSave),
      'auth_jwt_token': 'fake_token',
    });

    final fakeDio = FakeChatDioService(responseToReturn: {});

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dioServiceProvider.overrideWith((ref) => fakeDio),
          todayMoodProvider.overrideWith(FakeTodayMoodNotifier.new),
          moodHistoryProvider.overrideWith(FakeMoodHistoryNotifier.new),
        ],
        child: const MaterialApp(
          home: ChatScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify saved history is successfully restored on start
    expect(find.text('My custom message'), findsOneWidget);
    expect(find.text('My custom response'), findsOneWidget);
  });

  testWidgets('Limits history payload sent to backend to the last 8 messages', (WidgetTester tester) async {
    // Generate a long list of messages (12 messages total)
    final messagesToSave = List.generate(12, (index) {
      final isUser = index % 2 == 1;
      return {
        'role': isUser ? 'user' : 'model',
        'text': 'Msg $index',
        'isFailed': false,
        'suggestedFollowUps': <String>[],
      };
    });

    SharedPreferences.setMockInitialValues({
      'user_email': 'testuser@example.com',
      'chat_history_testuser@example.com': json.encode(messagesToSave),
      'auth_jwt_token': 'fake_token',
    });

    final fakeDio = FakeChatDioService(responseToReturn: {
      'reply': 'Reply to newest message',
      'suggestedFollowUps': <String>[],
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dioServiceProvider.overrideWith((ref) => fakeDio),
          todayMoodProvider.overrideWith(FakeTodayMoodNotifier.new),
          moodHistoryProvider.overrideWith(FakeMoodHistoryNotifier.new),
        ],
        child: const MaterialApp(
          home: ChatScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Send a new message to trigger sendChatMessage
    await tester.enterText(find.byType(TextField), 'New message');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();

    // Verify history payload sent to the backend is limited to last 8 messages
    expect(fakeDio.capturedHistory.length, lessThanOrEqualTo(8));
    // Verify it sent the latest ones starting at Msg 4 (since 12 total messages, rawHistory length = 12, 12 - 8 = 4)
    final firstSentMsg = fakeDio.capturedHistory.first['text'];
    expect(firstSentMsg, equals('Msg 4'));
  });
}
