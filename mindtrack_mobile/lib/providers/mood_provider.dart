import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/dio_service.dart';

/// Representation of a mood entry on the client side
class MoodEntry {
  final String id;
  final String userId;
  final int moodScore;
  final String note;
  final DateTime timestamp;
  final List<String> tags;
  final bool isPending;

  MoodEntry({
    required this.id,
    required this.userId,
    required this.moodScore,
    required this.note,
    required this.timestamp,
    required this.tags,
    this.isPending = false,
  });

  factory MoodEntry.fromJson(Map<String, dynamic> json) {
    return MoodEntry(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      moodScore: json['moodScore'] as int? ?? 3,
      note: json['note'] as String? ?? '',
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
      tags: json['tags'] != null
          ? List<String>.from(json['tags'] as List<dynamic>)
          : const [],
      isPending: json['isPending'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'moodScore': moodScore,
      'note': note,
      'timestamp': timestamp.toIso8601String(),
      'tags': tags,
      'isPending': isPending,
    };
  }
}

/// Managed state notifier for today's mood score
class TodayMoodNotifier extends AsyncNotifier<int?> {
  @override
  FutureOr<int?> build() async {
    final dio = ref.watch(dioServiceProvider);

    // Watch offline queue so we automatically rebuild when local items are added/removed/synced
    final pending = ref.watch(offlineQueueProvider);
    if (pending.isNotEmpty) {
      final now = DateTime.now();
      final todayPending = pending.where((e) {
        final localTime = e.timestamp.toLocal();
        return localTime.year == now.year &&
            localTime.month == now.month &&
            localTime.day == now.day;
      }).toList();

      if (todayPending.isNotEmpty) {
        // Since pending list is prepended with newest first, the first element is the most recent today
        return todayPending.first.moodScore;
      }
    }

    try {
      final list = await dio.getTodayMoods();
      if (list.isNotEmpty) {
        // Since the backend sorts descending by timestamp, the first is today's most recent
        final entry = MoodEntry.fromJson(list.first as Map<String, dynamic>);
        return entry.moodScore;
      }
      return null;
    } catch (e) {
      debugPrint('TodayMoodNotifier: Error fetching today\'s mood score: $e');
      return null;
    }
  }

  /// Manually update today's mood score in the state
  void updateState(int? score) {
    state = AsyncData(score);
  }
}

/// Riverpod provider for today's mood score
final todayMoodProvider = AsyncNotifierProvider<TodayMoodNotifier, int?>(
  TodayMoodNotifier.new,
);

/// Shared pending journal prompt used to hand off AI-generated reflection text
/// from the breathing flow into the journal composer.
class PendingJournalPromptNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setPrompt(String? prompt) {
    state = prompt;
  }

  void clear() {
    state = null;
  }
}

final pendingJournalPromptProvider =
    NotifierProvider<PendingJournalPromptNotifier, String?>(
      PendingJournalPromptNotifier.new,
    );

/// Managed state notifier for mood history logs
class MoodHistoryNotifier extends AsyncNotifier<List<MoodEntry>> {
  @override
  FutureOr<List<MoodEntry>> build() async {
    final dio = ref.watch(dioServiceProvider);
    final pending = ref.watch(offlineQueueProvider);

    List<MoodEntry> remoteList = [];
    try {
      final list = await dio.getMoodHistory(days: 30);
      remoteList = list
          .map((json) => MoodEntry.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('MoodHistoryNotifier: Error fetching mood history: $e');
    }

    final pendingIds = pending.map((e) => e.id).toSet();
    final uniqueRemote = remoteList
        .where((e) => !pendingIds.contains(e.id))
        .toList();
    return [...pending, ...uniqueRemote];
  }

  /// Manually trigger a refresh of history from backend
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final dio = ref.read(dioServiceProvider);
      final pending = ref.read(offlineQueueProvider);

      List<MoodEntry> remoteList = [];
      try {
        final list = await dio.getMoodHistory(days: 30);
        remoteList = list
            .map((json) => MoodEntry.fromJson(json as Map<String, dynamic>))
            .toList();
      } catch (e) {
        debugPrint('MoodHistoryNotifier: Error refreshing history: $e');
        rethrow;
      }

      final pendingIds = pending.map((e) => e.id).toSet();
      final uniqueRemote = remoteList
          .where((e) => !pendingIds.contains(e.id))
          .toList();
      return [...pending, ...uniqueRemote];
    });
  }

  /// Add a newly logged entry to local history state for immediate fluid updates
  void addLocalEntry(MoodEntry entry) {
    state.whenData((currentList) {
      // Prepend to history (since list is sorted descending)
      final updatedList = [entry, ...currentList];
      state = AsyncData(updatedList);
    });
  }
}

/// Riverpod provider for mood history logs
final moodHistoryProvider =
    AsyncNotifierProvider<MoodHistoryNotifier, List<MoodEntry>>(
      MoodHistoryNotifier.new,
    );

/// Backend-backed current streak, aligned with the profile stats calculation.
final streakProvider = FutureProvider<int>((ref) async {
  final dio = ref.read(dioServiceProvider);
  try {
    final stats = await dio.getUserStats();
    return stats['currentStreak'] as int? ?? 0;
  } catch (e) {
    final history = ref.read(moodHistoryProvider).value ?? [];
    if (history.isEmpty) return 0;

    final today = DateTime.now();
    final hasToday = history.any((entry) {
      final date = entry.timestamp.toLocal();
      return date.year == today.year &&
          date.month == today.month &&
          date.day == today.day;
    });
    return hasToday ? 1 : 0;
  }
});

/// Backend-backed longest streak, aligned with the profile stats calculation.
final longestStreakProvider = FutureProvider<int>((ref) async {
  final dio = ref.read(dioServiceProvider);
  try {
    final stats = await dio.getUserStats();
    return stats['longestStreak'] as int? ?? 0;
  } catch (e) {
    debugPrint('MoodProvider: Error fetching longest streak: $e');
    return 0;
  }
});

/// Shared controller for actions, specifically logging the mood
class MoodActions {
  final Ref _ref;
  MoodActions(this._ref);

  Future<Map<String, dynamic>> logMood(
    int score, {
    String note = 'Logged via mobile app',
    List<String> tags = const [],
  }) async {
    final dio = _ref.read(dioServiceProvider);

    try {
      // 1. Send POST request
      final jsonResult = await dio.logMood(score, note: note, tags: tags);
      final newEntry = MoodEntry.fromJson(jsonResult);

      // 2. Synchronize states reactively
      _ref.read(todayMoodProvider.notifier).updateState(score);
      _ref.read(moodHistoryProvider.notifier).addLocalEntry(newEntry);
      _ref.invalidate(streakProvider);
      _ref.invalidate(longestStreakProvider);

      final historyCount = _ref.read(moodHistoryProvider).value?.length ?? 0;
      if (historyCount % 5 == 0) {
        _ref.invalidate(moodAnomalyProvider);
      }

      return jsonResult;
    } catch (e) {
      if (_isNetworkError(e)) {
        debugPrint(
          'MoodActions: Network error detected. Saving to offline queue.',
        );
        final pendingEntry = await _ref
            .read(offlineQueueProvider.notifier)
            .enqueue(score, note: note, tags: tags);

        // Optimistically update states
        _ref.read(todayMoodProvider.notifier).updateState(score);

        return {
          'id': pendingEntry.id,
          'userId': pendingEntry.userId,
          'moodScore': pendingEntry.moodScore,
          'note': pendingEntry.note,
          'timestamp': pendingEntry.timestamp.toIso8601String(),
          'tags': pendingEntry.tags,
          'isPending': true,
        };
      } else {
        rethrow;
      }
    }
  }

  bool _isNetworkError(dynamic error) {
    final errStr = error.toString().toLowerCase();
    return errStr.contains('connection timeout') ||
        errStr.contains('connection error') ||
        errStr.contains('send timeout') ||
        errStr.contains('receive timeout') ||
        errStr.contains('network unreachable') ||
        errStr.contains('socketexception');
  }
}

/// Provider for mood action triggers
final moodActionsProvider = Provider<MoodActions>((ref) {
  return MoodActions(ref);
});

/// Client-side model representing mood anomaly and burnout diagnostics
class MoodAnomaly {
  final String riskLevel;
  final List<String> detectedPatterns;
  final String suggestedAction;
  final String supportiveInsight;
  final double confidence;
  final bool insufficientData;

  MoodAnomaly({
    required this.riskLevel,
    required this.detectedPatterns,
    required this.suggestedAction,
    required this.supportiveInsight,
    required this.confidence,
    required this.insufficientData,
  });

  factory MoodAnomaly.fromJson(Map<String, dynamic> json) {
    return MoodAnomaly(
      riskLevel: json['riskLevel'] as String? ?? 'LOW',
      detectedPatterns: json['detectedPatterns'] != null
          ? List<String>.from(json['detectedPatterns'] as List<dynamic>)
          : const [],
      suggestedAction: json['suggestedAction'] as String? ?? '',
      supportiveInsight: json['supportiveInsight'] as String? ?? '',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      insufficientData: json['insufficientData'] as bool? ?? false,
    );
  }
}

/// Managed state notifier for weekly mood anomaly and burnout diagnostics
class MoodAnomalyNotifier extends AsyncNotifier<MoodAnomaly?> {
  @override
  FutureOr<MoodAnomaly?> build() async {
    final dio = ref.watch(dioServiceProvider);
    ref.keepAlive();
    try {
      final data = await dio.getMoodAnomaly();
      return MoodAnomaly.fromJson(data);
    } catch (e) {
      debugPrint('MoodAnomalyNotifier: Error fetching anomaly: $e');
      return null;
    }
  }

  /// Manually trigger a refresh of anomaly data from backend
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final dio = ref.watch(dioServiceProvider);
      final data = await dio.getMoodAnomaly();
      return MoodAnomaly.fromJson(data);
    });
  }
}

/// Riverpod provider for weekly mood anomaly and burnout diagnostics
final moodAnomalyProvider =
    AsyncNotifierProvider.autoDispose<MoodAnomalyNotifier, MoodAnomaly?>(
      MoodAnomalyNotifier.new,
    );

// --- OFFLINE MOOD LOGGING QUEUE ---

class OfflineQueueNotifier extends Notifier<List<MoodEntry>> {
  static const _kQueueKey = 'pending_mood_entries';

  @override
  List<MoodEntry> build() {
    _loadQueue();
    return const [];
  }

  Future<void> _loadQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_kQueueKey);
      if (jsonStr != null) {
        final List<dynamic> decoded = json.decode(jsonStr);
        final list = decoded
            .map((item) => MoodEntry.fromJson(item as Map<String, dynamic>))
            .toList();
        list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        state = list;
      }
    } catch (e) {
      debugPrint('OfflineQueueNotifier: Error loading queue: $e');
    }
  }

  Future<void> _saveQueue(List<MoodEntry> queue) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = queue.map((e) => e.toJson()).toList();
      await prefs.setString(_kQueueKey, json.encode(encoded));
    } catch (e) {
      debugPrint('OfflineQueueNotifier: Error saving queue: $e');
    }
  }

  Future<MoodEntry> enqueue(
    int score, {
    required String note,
    required List<String> tags,
  }) async {
    final newEntry = MoodEntry(
      id: 'local_${DateTime.now().millisecondsSinceEpoch}_$score',
      userId: 'local_user',
      moodScore: score,
      note: note,
      timestamp: DateTime.now(),
      tags: tags,
      isPending: true,
    );

    final updated = [newEntry, ...state];
    state = updated;
    await _saveQueue(updated);
    return newEntry;
  }

  Future<void> dequeue(String id) async {
    final updated = state.where((e) => e.id != id).toList();
    state = updated;
    await _saveQueue(updated);
  }

  Future<void> clear() async {
    state = const [];
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kQueueKey);
  }
}

final offlineQueueProvider =
    NotifierProvider<OfflineQueueNotifier, List<MoodEntry>>(
      OfflineQueueNotifier.new,
    );

class SyncNotifier extends Notifier<bool> {
  Timer? _timer;
  DateTime? _rateLimitBackoffUntil;

  @override
  bool build() {
    _timer = Timer.periodic(const Duration(seconds: 20), (timer) {
      syncPending();
    });

    ref.onDispose(() {
      _timer?.cancel();
    });

    return false;
  }

  Future<void> syncPending() async {
    if (state) return;
    if (_rateLimitBackoffUntil != null &&
        DateTime.now().isBefore(_rateLimitBackoffUntil!)) {
      debugPrint('SyncNotifier: Skipping sync due to active rate-limit backoff (active until $_rateLimitBackoffUntil).');
      return;
    }
    final offlineQueue = ref.read(offlineQueueProvider);
    if (offlineQueue.isEmpty) return;

    final token = await _getAuthToken();
    if (token == null) {
      debugPrint('SyncNotifier: User not authenticated. Skipping sync.');
      return;
    }

    state = true;

    try {
      final dio = ref.read(dioServiceProvider);
      final pendingCopy = List<MoodEntry>.from(offlineQueue);

      // Sync oldest first
      for (final entry in pendingCopy.reversed) {
        try {
          await dio.logMood(
            entry.moodScore,
            note: entry.note,
            tags: entry.tags,
            timestamp: entry.timestamp,
          );
          await ref.read(offlineQueueProvider.notifier).dequeue(entry.id);
          debugPrint('SyncNotifier: Synced entry ${entry.id} successfully.');
        } on RateLimitException {
          _rateLimitBackoffUntil = DateTime.now().add(const Duration(minutes: 10));
          debugPrint('SyncNotifier: Rate limit (429) encountered when syncing entry ${entry.id}. '
              'Backing off sync for 10 minutes (until $_rateLimitBackoffUntil).');
          break;
        } catch (e) {
          debugPrint('SyncNotifier: Failed to sync entry ${entry.id}: $e');
          if (_isNetworkError(e)) {
            break;
          }
        }
      }

      await ref.read(moodHistoryProvider.notifier).refresh();
      ref.invalidate(todayMoodProvider);
      ref.invalidate(streakProvider);
      ref.invalidate(longestStreakProvider);
      await ref.read(moodAnomalyProvider.notifier).refresh();
    } finally {
      state = false;
    }
  }

  Future<String?> _getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_jwt_token');
  }

  bool _isNetworkError(dynamic error) {
    final errStr = error.toString().toLowerCase();
    return errStr.contains('connection timeout') ||
        errStr.contains('connection error') ||
        errStr.contains('send timeout') ||
        errStr.contains('receive timeout') ||
        errStr.contains('network unreachable') ||
        errStr.contains('socketexception');
  }
}

final syncProvider = NotifierProvider<SyncNotifier, bool>(SyncNotifier.new);
