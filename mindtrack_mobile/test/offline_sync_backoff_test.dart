import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mindtrack_mobile/services/dio_service.dart';
import 'package:mindtrack_mobile/providers/mood_provider.dart';

class FakeDioService extends DioService {
  int logMoodCalls = 0;
  bool shouldThrowRateLimit = false;

  @override
  Future<Map<String, dynamic>> logMood(
    int score, {
    String note = 'Logged via mobile app',
    List<String> tags = const [],
    DateTime? timestamp,
  }) async {
    logMoodCalls++;
    if (shouldThrowRateLimit) {
      throw RateLimitException('Rate limit exceeded (Status code: 429)');
    }
    return {
      'id': 'remote_$logMoodCalls',
      'userId': 'user-123',
      'moodScore': score,
      'note': note,
      'tags': tags,
      'timestamp': (timestamp ?? DateTime.now()).toIso8601String(),
    };
  }

  @override
  Future<List<dynamic>> getMoodHistory({int days = 30}) async => [];

  @override
  Future<Map<String, dynamic>> getMoodAnomaly() async => {
        'riskLevel': 'LOW',
        'detectedPatterns': <String>[],
        'suggestedAction': '',
        'supportiveInsight': '',
        'confidence': 0.0,
        'insufficientData': true,
      };

  @override
  Future<Map<String, dynamic>> getUserStats() async => {
        'currentStreak': 0,
        'longestStreak': 0,
        'totalEntries': 0,
      };
}


void main() {
  late FakeDioService fakeDioService;

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'auth_jwt_token': 'fake_jwt_token',
    });
    fakeDioService = FakeDioService();
  });

  group('SyncNotifier Offline Backoff and Rate Limit Tests', () {
    test('Successful sync dequeues items and does not activate backoff', () async {
      final container = ProviderContainer(
        overrides: [
          dioServiceProvider.overrideWith((ref) => fakeDioService),
        ],
      );
      addTearDown(container.dispose);

      // Enqueue items
      final queueNotifier = container.read(offlineQueueProvider.notifier);
      await queueNotifier.enqueue(4, note: 'Had a great day', tags: ['happy']);
      await queueNotifier.enqueue(5, note: 'Amazing coding session', tags: ['productive']);

      var queue = container.read(offlineQueueProvider);
      expect(queue.length, equals(2));

      // Trigger sync
      final syncNotifier = container.read(syncProvider.notifier);
      await syncNotifier.syncPending();

      // Check if items are successfully synced and dequeued
      queue = container.read(offlineQueueProvider);
      expect(queue.isEmpty, isTrue);
      expect(fakeDioService.logMoodCalls, equals(2));
    });

    test('429 rate limit error stops sync loop and retains items as pending', () async {
      final container = ProviderContainer(
        overrides: [
          dioServiceProvider.overrideWith((ref) => fakeDioService),
        ],
      );
      addTearDown(container.dispose);

      // Enqueue items
      final queueNotifier = container.read(offlineQueueProvider.notifier);
      await queueNotifier.enqueue(3, note: 'Normal day note', tags: ['normal']);
      await queueNotifier.enqueue(2, note: 'Feeling a bit down', tags: ['tired']);

      var queue = container.read(offlineQueueProvider);
      expect(queue.length, equals(2));

      // Configure fake to throw 429 on the first sync call
      fakeDioService.shouldThrowRateLimit = true;

      // Trigger sync
      final syncNotifier = container.read(syncProvider.notifier);
      await syncNotifier.syncPending();

      // Items should still remain in the offline queue (marked as pending/queued)
      queue = container.read(offlineQueueProvider);
      expect(queue.length, equals(2));
      expect(queue.any((e) => e.isPending), isTrue);
      expect(fakeDioService.logMoodCalls, equals(1)); // Should stop immediately on the first failure
    });

    test('Active 10-minute backoff skips subsequent sync calls entirely', () async {
      final container = ProviderContainer(
        overrides: [
          dioServiceProvider.overrideWith((ref) => fakeDioService),
        ],
      );
      addTearDown(container.dispose);

      // Enqueue item
      final queueNotifier = container.read(offlineQueueProvider.notifier);
      await queueNotifier.enqueue(3, note: 'Some note', tags: []);

      // Trigger 429 rate limit
      fakeDioService.shouldThrowRateLimit = true;
      final syncNotifier = container.read(syncProvider.notifier);
      await syncNotifier.syncPending();

      expect(fakeDioService.logMoodCalls, equals(1));

      // Subsequent sync triggers within the 10-minute window should not hit the backend
      fakeDioService.shouldThrowRateLimit = false; // Even if it would succeed now, backoff prevents it
      await syncNotifier.syncPending();

      // logMoodCalls should still be 1 (no new requests made)
      expect(fakeDioService.logMoodCalls, equals(1));

      // Queue is untouched
      final queue = container.read(offlineQueueProvider);
      expect(queue.length, equals(1));
    });
  });
}
