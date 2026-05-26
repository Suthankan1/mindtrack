import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mindtrack_mobile/screens/weekly_summary_screen.dart';
import 'package:mindtrack_mobile/providers/mood_provider.dart';
import 'package:mindtrack_mobile/services/dio_service.dart';

class FakeMoodHistoryNotifier extends MoodHistoryNotifier {
  @override
  FutureOr<List<MoodEntry>> build() {
    final now = DateTime.now();
    return [
      MoodEntry(
        id: '1',
        userId: 'user1',
        moodScore: 4,
        note: 'Feeling peaceful.',
        timestamp: now,
        tags: ['Mindfulness', 'Calm'],
      ),
      MoodEntry(
        id: '2',
        userId: 'user1',
        moodScore: 5,
        note: 'Excellent day!',
        timestamp: now.subtract(const Duration(days: 1)),
        tags: ['Joy', 'Mindfulness'],
      ),
      MoodEntry(
        id: '3',
        userId: 'user1',
        moodScore: 3,
        note: 'Just standard.',
        timestamp: now.subtract(const Duration(days: 2)),
        tags: ['Work'],
      ),
    ];
  }
}

class FakeWeeklyInsight {
  static WeeklyInsight get mock => WeeklyInsight(
        insight: 'Your overall mood this week is positive. Keep focusing on Mindfulness.',
        weeklyAverage: 4.0,
        peakDay: 'Friday',
        entryCount: 3,
        aiAvailable: true,
      );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'user_email': 'test@mindtrack.com',
      'auth_jwt_token': 'fake_token',
    });
  });

  group('WeeklySummaryScreen Widget Tests', () {
    testWidgets('WeeklySummaryScreen renders all summary cards, charts, and metrics', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            moodHistoryProvider.overrideWith(FakeMoodHistoryNotifier.new),
            weeklyInsightProvider.overrideWith((ref) => FakeWeeklyInsight.mock),
          ],
          child: const MaterialApp(
            home: WeeklySummaryScreen(),
          ),
        ),
      );

      // Settle initial rendering and loading states
      await tester.pumpAndSettle();

      // 1. Verify AppBar Title
      expect(find.text('Weekly Report'), findsOneWidget);

      // 2. Verify Consistency Score (3 logs out of 7 = 43%)
      expect(find.text('43%'), findsOneWidget);
      expect(find.text('Mood Consistency'), findsOneWidget);

      // 3. Verify Log Count Badge (3 logs)
      expect(find.text('3 logs'), findsOneWidget);

      // 4. Verify Emotional Trajectory sections
      expect(find.text('Emotional Trajectory'), findsOneWidget);
      expect(find.text('Weekly Sparkline'), findsOneWidget);

      // 5. Verify Gemini AI Weekly Summary Card
      expect(find.text('Weekly AI Summary'), findsOneWidget);
      expect(find.text('Your overall mood this week is positive. Keep focusing on Mindfulness.'), findsOneWidget);
      expect(find.text('Avg Mood: 4.0'), findsOneWidget);
      expect(find.text('Peak Stress: Friday'), findsOneWidget);

      // 6. Verify Top Used Tags (#Mindfulness, #Joy, #Calm)
      expect(find.text('Top Tags this Week'), findsOneWidget);
      expect(find.text('Mindfulness'), findsOneWidget);
      expect(find.text('Joy'), findsOneWidget);
      expect(find.text('Calm'), findsOneWidget);
    });
  });
}
