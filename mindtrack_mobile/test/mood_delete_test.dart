import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mindtrack_mobile/services/dio_service.dart';
import 'package:mindtrack_mobile/providers/mood_provider.dart';
import 'package:mindtrack_mobile/screens/journal_screen.dart';

class CapturingDioServiceForDelete extends DioService {
  final List<String> deletedIds = [];
  bool shouldFail = false;

  CapturingDioServiceForDelete() : super(dio: null);

  @override
  Future<List<dynamic>> getMoodHistory({int days = 30}) async {
    return [
      {
        'id': 'entry-123',
        'userId': 'user-1',
        'moodScore': 4,
        'note': 'Feeling peaceful today',
        'timestamp': DateTime.now().toIso8601String(),
        'tags': ['Mindfulness'],
        'isPending': false,
      }
    ];
  }

  @override
  Future<void> deleteMoodEntry(String entryId) async {
    if (shouldFail) {
      throw Exception('Mock delete failed');
    }
    deletedIds.add(entryId);
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'onboarding_completed': true,
      'auth_jwt_token': 'fake_token',
    });
  });

  group('Mood Entry Deletion UI and Service Tests', () {
    test('DioService.deleteMoodEntry compiles and signature is correct', () {
      final service = DioService();
      expect(service.deleteMoodEntry, isNotNull);
    });

    testWidgets('JournalScreen renders Dismissible for each entry and handles delete success', (WidgetTester tester) async {
      final capturingService = CapturingDioServiceForDelete();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dioServiceProvider.overrideWith((_) => capturingService),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: JournalScreen(),
            ),
          ),
        ),
      );

      // Pump frames with duration to bypass repeating star twinkling animations
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Verify the list item with note is shown (both collapsed and expanded text views exist in AnimatedCrossFade)
      expect(find.text('Feeling peaceful today'), findsNWidgets(2));

      // Verify the Dismissible widget is present
      final dismissibleFinder = find.byType(Dismissible);
      expect(dismissibleFinder, findsOneWidget);

      // Swipe the Dismissible card from right to left (endToStart)
      await tester.drag(dismissibleFinder, const Offset(-500, 0));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Check if deleteMoodEntry was called with the correct ID
      expect(capturingService.deletedIds, contains('entry-123'));
    });
  });
}
