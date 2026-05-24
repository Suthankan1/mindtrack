import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/dio_service.dart';

/// Representation of a mood entry on the client side
class MoodEntry {
  final String id;
  final String userId;
  final int moodScore;
  final String note;
  final DateTime timestamp;
  final List<String> tags;

  MoodEntry({
    required this.id,
    required this.userId,
    required this.moodScore,
    required this.note,
    required this.timestamp,
    required this.tags,
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
    );
  }
}

/// Managed state notifier for today's mood score
class TodayMoodNotifier extends AsyncNotifier<int?> {
  @override
  FutureOr<int?> build() async {
    final dio = ref.watch(dioServiceProvider);
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

/// Managed state notifier for mood history logs
class MoodHistoryNotifier extends AsyncNotifier<List<MoodEntry>> {
  @override
  FutureOr<List<MoodEntry>> build() async {
    final dio = ref.watch(dioServiceProvider);
    try {
      final list = await dio.getMoodHistory(days: 30);
      return list
          .map((json) => MoodEntry.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('MoodHistoryNotifier: Error fetching mood history: $e');
      return [];
    }
  }

  /// Manually trigger a refresh of history from backend
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final dio = ref.watch(dioServiceProvider);
      final list = await dio.getMoodHistory(days: 30);
      return list
          .map((json) => MoodEntry.fromJson(json as Map<String, dynamic>))
          .toList();
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

/// Utility Provider to calculate the current mood streak from history (matching web dashboard logic)
final streakCountProvider = Provider<int>((ref) {
  final historyAsync = ref.watch(moodHistoryProvider);
  return historyAsync.maybeWhen(
    data: (entries) {
      if (entries.isEmpty) return 0;

      // Extract unique yyyy-MM-dd dates
      final uniqueDates = entries.map((e) {
        final t = e.timestamp.toLocal();
        return '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
      }).toSet();

      int streak = 0;
      final checkDate = DateTime.now();

      String getFormattedDate(DateTime date) {
        return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      }

      final todayStr = getFormattedDate(checkDate);
      final yesterdayStr = getFormattedDate(
        checkDate.subtract(const Duration(days: 1)),
      );

      // If user hasn't logged today AND hasn't logged yesterday, streak is broken (0)
      if (!uniqueDates.contains(todayStr) &&
          !uniqueDates.contains(yesterdayStr)) {
        return 0;
      }

      var iterDate = DateTime.now();
      while (true) {
        final dateStr = getFormattedDate(iterDate);
        if (uniqueDates.contains(dateStr)) {
          streak++;
          iterDate = iterDate.subtract(
            const Duration(days: 1),
          ); // subtract 1 day
        } else {
          break;
        }
      }
      return streak;
    },
    orElse: () => 0,
  );
});

/// Shared controller for actions, specifically logging the mood
class MoodActions {
  final Ref _ref;
  MoodActions(this._ref);

  Future<void> logMood(
    int score, {
    String note = 'Logged via mobile app',
    List<String> tags = const [],
  }) async {
    final dio = _ref.read(dioServiceProvider);

    // 1. Send POST request
    final jsonResult = await dio.logMood(score, note: note, tags: tags);
    final newEntry = MoodEntry.fromJson(jsonResult);

    // 2. Synchronize states reactively
    _ref.read(todayMoodProvider.notifier).updateState(score);
    _ref.read(moodHistoryProvider.notifier).addLocalEntry(newEntry);
  }
}

/// Provider for mood action triggers
final moodActionsProvider = Provider<MoodActions>((ref) {
  return MoodActions(ref);
});
