import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mindtrack_mobile/main.dart';
import 'package:mindtrack_mobile/navigation/bottom_nav_bar.dart';
import 'package:mindtrack_mobile/providers/mood_provider.dart';

class FakeTodayMoodNotifier extends TodayMoodNotifier {
  @override
  FutureOr<int?> build() => 4;
}

class FakeMoodHistoryNotifier extends MoodHistoryNotifier {
  @override
  FutureOr<List<MoodEntry>> build() => [
        MoodEntry(
          id: '1',
          userId: 'user1',
          moodScore: 4,
          note: 'Grateful and calm.',
          timestamp: DateTime.now(),
          tags: ['Mindfulness'],
        ),
      ];
}

void main() {
  testWidgets('Sanctuary App Bootstrapping and Custom Nav Rendering Smoke Test', (WidgetTester tester) async {
    // Build our app wrapped in ProviderScope with mocked notifier overrides
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          todayMoodProvider.overrideWith(FakeTodayMoodNotifier.new),
          moodHistoryProvider.overrideWith(FakeMoodHistoryNotifier.new),
        ],
        child: const MindTrackApp(),
      ),
    );

    // Let the go_router transitions and providers settle
    await tester.pumpAndSettle();

    // Verify that our custom BottomNavBar is rendered in the view hierarchy
    expect(find.byType(CustomBottomNavBar), findsOneWidget);

    // Verify that the greeting headline exists on the Home page
    expect(find.text('MindTracker'), findsOneWidget);
    expect(find.textContaining('streak'), findsWidgets);
  });
}
