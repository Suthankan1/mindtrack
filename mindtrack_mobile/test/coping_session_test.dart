import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mindtrack_mobile/services/dio_service.dart';

// ---------------------------------------------------------------------------
// Fake DioService implementations
// ---------------------------------------------------------------------------

/// Captures every call to [logCopingSession] and returns a successful 201-like map.
class CapturingDioService extends DioService {
  final List<Map<String, dynamic>> capturedPayloads = [];

  @override
  Future<Map<String, dynamic>> logCopingSession({
    required String type,
    required int durationSeconds,
  }) async {
    capturedPayloads.add({'type': type, 'durationSeconds': durationSeconds});
    return {
      'id': 'session-123',
      'type': type,
      'durationSeconds': durationSeconds,
    };
  }
}

/// Always returns an empty map — simulates a non-fatal network failure.
class FailingDioService extends DioService {
  @override
  Future<Map<String, dynamic>> logCopingSession({
    required String type,
    required int durationSeconds,
  }) async {
    return {};
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'auth_jwt_token': 'fake_jwt_token',
    });
  });

  group('DioService.logCopingSession — payload contract', () {
    test(
      'sends durationSeconds (not duration) in the request payload',
      () async {
        final service = CapturingDioService();
        final result =
            await service.logCopingSession(type: 'breathing', durationSeconds: 120);

        // The returned map must include durationSeconds at the top level.
        expect(result['durationSeconds'], equals(120));
        expect(result['type'], equals('breathing'));

        // The captured payload sent to the "server" must use durationSeconds.
        expect(service.capturedPayloads, hasLength(1));
        final sent = service.capturedPayloads.first;
        expect(sent.containsKey('durationSeconds'), isTrue,
            reason: 'Payload must contain durationSeconds, not duration');
        expect(sent.containsKey('duration'), isFalse,
            reason: 'Legacy "duration" key must not be present');
        expect(sent['durationSeconds'], equals(120));
        expect(sent['type'], equals('breathing'));
      },
    );

    test(
      'returns a non-empty map on success',
      () async {
        final service = CapturingDioService();
        final result =
            await service.logCopingSession(type: 'breathing', durationSeconds: 60);

        expect(result.isNotEmpty, isTrue);
      },
    );

    test(
      'returns empty map on failure and does not throw',
      () async {
        final service = FailingDioService();
        Map<String, dynamic>? result;
        Object? thrown;

        try {
          result = await service.logCopingSession(
              type: 'breathing', durationSeconds: 60);
        } catch (e) {
          thrown = e;
        }

        expect(thrown, isNull,
            reason: 'logCopingSession must not throw on failure');
        expect(result, isNotNull);
        expect(result!.isEmpty, isTrue,
            reason: 'An empty map signals non-fatal failure to callers');
      },
    );

    test(
      'durationSeconds value is forwarded exactly as provided',
      () async {
        const expectedDuration = 247;
        final service = CapturingDioService();
        await service.logCopingSession(
            type: 'breathing', durationSeconds: expectedDuration);

        expect(
            service.capturedPayloads.first['durationSeconds'], expectedDuration);
      },
    );
  });

  group('dioServiceProvider — Riverpod integration', () {
    test(
      'provider can be overridden with a capturing fake for integration tests',
      () async {
        final capturingService = CapturingDioService();

        final container = ProviderContainer(
          overrides: [
            dioServiceProvider.overrideWith((_) => capturingService),
          ],
        );
        addTearDown(container.dispose);

        final service = container.read(dioServiceProvider);
        await service.logCopingSession(
            type: 'breathing', durationSeconds: 90);

        expect(capturingService.capturedPayloads.first['durationSeconds'],
            equals(90));
      },
    );
  });
}
