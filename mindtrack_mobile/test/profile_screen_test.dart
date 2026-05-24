import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mindtrack_mobile/screens/profile_screen.dart';
import 'package:mindtrack_mobile/providers/mood_provider.dart';

class FakeTodayMoodNotifier extends TodayMoodNotifier {
  @override
  FutureOr<int?> build() => 4;
}

class FakeMoodHistoryNotifier extends MoodHistoryNotifier {
  @override
  FutureOr<List<MoodEntry>> build() {
    final now = DateTime.now();
    return [
      MoodEntry(
        id: '1',
        userId: 'user1',
        moodScore: 4,
        note: 'Grateful and calm.',
        timestamp: now,
        tags: ['Mindfulness'],
      ),
      MoodEntry(
        id: '2',
        userId: 'user1',
        moodScore: 3,
        note: 'Steady focus.',
        timestamp: now.subtract(const Duration(days: 1)),
        tags: ['Focus'],
      ),
      MoodEntry(
        id: '3',
        userId: 'user1',
        moodScore: 5,
        note: 'High energy!',
        timestamp: now.subtract(const Duration(days: 2)),
        tags: ['Joy'],
      ),
      // Day 3 is skipped (broken streak)
      MoodEntry(
        id: '4',
        userId: 'user1',
        moodScore: 4,
        note: 'Relaxed evening.',
        timestamp: now.subtract(const Duration(days: 4)),
        tags: ['Relax'],
      ),
      MoodEntry(
        id: '5',
        userId: 'user1',
        moodScore: 3,
        note: 'Reflective morning.',
        timestamp: now.subtract(const Duration(days: 5)),
        tags: ['Reflection'],
      ),
    ];
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'user_display_name': 'Test User',
      'user_email': 'test@mindtrack.com',
      'user_join_date': DateTime(2026, 5, 1).toIso8601String(),
      'notifications_enabled': true,
      'theme_light_mode': false,
    });
  });

  group('ProfileScreen Widget & Logic Tests', () {
    testWidgets('ProfileScreen renders with correct user data and stats', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            todayMoodProvider.overrideWith(FakeTodayMoodNotifier.new),
            moodHistoryProvider.overrideWith(FakeMoodHistoryNotifier.new),
          ],
          child: const MaterialApp(
            home: ProfileScreen(),
          ),
        ),
      );

      // Settle SharedPreferences loading async phase
      await tester.pumpAndSettle();

      // Verify that user personal info renders correctly
      expect(find.text('Test User'), findsOneWidget);
      expect(find.text('test@mindtrack.com'), findsOneWidget);
      expect(find.text('Joined May 2026'), findsOneWidget);

      // Verify initials avatar CP is constructed correctly (TU for Test User)
      expect(find.text('TU'), findsOneWidget);

      // Verify total entries (Fake history has 5 entries)
      expect(find.text('5'), findsOneWidget);

      // Verify settings options exist
      expect(find.text('Breathing Reminders'), findsOneWidget);
      expect(find.text('Light Mode Active'), findsOneWidget);

      // Verify UN SDG 3 card is visible
      expect(find.text('UN Sustainable Goal 3'), findsOneWidget);
      expect(find.text('SDG'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);

      // Verify persistent Crisis Support section is rendered
      expect(find.text('Crisis Support Resources'), findsOneWidget);
      expect(find.text('Talk to Someone'), findsOneWidget);
      expect(find.text('Find Therapist'), findsOneWidget);
      expect(find.text('Emergency'), findsOneWidget);
    });
  });
}
