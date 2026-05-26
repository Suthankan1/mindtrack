import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _kTokenKey = 'auth_jwt_token';

class DioService {
  final Dio _dio;
  String? _token;

  DioService({Dio? dio})
    : _dio = dio ?? Dio(
        BaseOptions(
          baseUrl: _determineBaseUrl(),
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      ) {
    _init();
  }

  String get baseUrl => _dio.options.baseUrl;

  static String _determineBaseUrl() {
    const String dartDefineUrl = String.fromEnvironment('API_BASE_URL');
    if (dartDefineUrl.isNotEmpty) {
      return dartDefineUrl;
    }
    // Android Emulator routes localhost through 10.0.2.2.
    // iOS and macOS use localhost directly.
    if (!kIsWeb && Platform.isAndroid) {
      return 'http://10.0.2.2:8080';
    }
    return 'http://localhost:8080';
  }

  String handleDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
        return 'Connection timeout: The server at ${e.requestOptions.baseUrl} took too long to respond. Please check your network and ensure the backend is running.';
      case DioExceptionType.sendTimeout:
        return 'Send timeout: Failed to transmit data to the server.';
      case DioExceptionType.receiveTimeout:
        return 'Receive timeout: The server took too long to return a response.';
      case DioExceptionType.connectionError:
        return 'Connection error: Unable to reach the server at ${e.requestOptions.baseUrl}. Please verify that the backend is active, your IP is correct, and your device is on the same network.';
      case DioExceptionType.badResponse:
        final code = e.response?.statusCode;
        final data = e.response?.data;
        if (data is Map && data.containsKey('message')) {
          return '${data['message']} (Status code: $code)';
        }
        return 'Server error (Status code: $code)';
      case DioExceptionType.badCertificate:
        return 'Secure connection failed due to an invalid certificate.';
      case DioExceptionType.cancel:
        return 'The request was cancelled.';
      case DioExceptionType.unknown:
        if (e.error is SocketException) {
          return 'Network unreachable: Please check if your device is connected to the same network as the server at ${e.requestOptions.baseUrl}. Details: ${e.error}';
        }
        return 'Unexpected network issue: ${e.message ?? e.error?.toString()}';
    }
  }

  Future<T> _request<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      if (e.response?.statusCode == 429) {
        throw RateLimitException(handleDioError(e));
      }
      throw Exception(handleDioError(e));
    }
  }

  void _init() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          if (_token != null) {
            options.headers['Authorization'] = 'Bearer $_token';
          }
          return handler.next(options);
        },
        onError: (DioException e, handler) async {
          if ((e.response?.statusCode == 401 || e.response?.statusCode == 403) &&
              !e.requestOptions.path.contains('/api/auth') &&
              _token != null) {
            await logout();
            throw Exception('Session expired. Please log in again.');
          }
          return handler.next(e);
        },
      ),
    );
  }

  /// Public sign in method
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await _dio.post(
        '/api/auth/login',
        data: {'email': email, 'password': password},
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        _token = data['accessToken'] as String?;
        if (_token != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_kTokenKey, _token!);
        }
        return data;
      }
      throw Exception('Login failed: Invalid server response.');
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.connectionError ||
          (e.type == DioExceptionType.unknown && e.error is SocketException)) {
        throw Exception(handleDioError(e));
      }
      final msg = e.response?.data != null && e.response?.data is Map
          ? (e.response?.data['message'] ?? 'Invalid email or password')
          : handleDioError(e);
      throw Exception(msg);
    }
  }

  /// Public registration method
  Future<Map<String, dynamic>> register(String email, String password, {bool anonymousMode = false}) async {
    try {
      final response = await _dio.post(
        '/api/auth/register',
        data: {
          'email': email,
          'password': password,
          'anonymousMode': anonymousMode,
        },
      );

      if ((response.statusCode == 200 || response.statusCode == 201) && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        _token = data['accessToken'] as String?;
        if (_token != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_kTokenKey, _token!);
        }
        return data;
      }
      throw Exception('Registration failed: Invalid server response.');
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.connectionError ||
          (e.type == DioExceptionType.unknown && e.error is SocketException)) {
        throw Exception(handleDioError(e));
      }
      final msg = e.response?.data != null && e.response?.data is Map
          ? (e.response?.data['message'] ?? 'Registration failed')
          : handleDioError(e);
      throw Exception(msg);
    }
  }

  /// Clear token (Logout)
  Future<void> logout() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kTokenKey);
  }

  /// Fetches today's mood logs.
  Future<List<dynamic>> getTodayMoods() async {
    if (_token == null) {
      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString(_kTokenKey);
    }
    if (_token == null) {
      throw Exception('Not authenticated. Please log in.');
    }
    return _request(() async {
      final response = await _dio.get('/api/mood/today');
      if (response.statusCode == 200 && response.data != null) {
        return response.data as List<dynamic>;
      }
      return [];
    });
  }

  /// Fetches the last 30 days of mood logs.
  Future<List<dynamic>> getMoodHistory({int days = 30}) async {
    if (_token == null) {
      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString(_kTokenKey);
    }
    if (_token == null) {
      throw Exception('Not authenticated. Please log in.');
    }
    return _request(() async {
      final response = await _dio.get(
        '/api/mood/history',
        queryParameters: {'days': days},
      );
      if (response.statusCode == 200 && response.data != null) {
        return response.data as List<dynamic>;
      }
      return [];
    });
  }

  /// Logs a new mood entry.
  Future<Map<String, dynamic>> logMood(
    int score, {
    String note = 'Logged via mobile app',
    List<String> tags = const [],
    DateTime? timestamp,
  }) async {
    if (_token == null) {
      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString(_kTokenKey);
    }
    if (_token == null) {
      throw Exception('Not authenticated. Please log in.');
    }
    return _request(() async {
      final response = await _dio.post(
        '/api/mood/log',
        data: {
          'moodScore': score,
          'note': note,
          'tags': tags,
          if (timestamp != null) 'timestamp': timestamp.toIso8601String(),
        },
      );

      if (response.statusCode == 201 && response.data != null) {
        debugPrint('DioService: Mood logged successfully. Score: $score');
        return response.data as Map<String, dynamic>;
      }
      throw Exception(
        'DioService: Failed to log mood. Status: ${response.statusCode}',
      );
    });
  }

  /// Logs a completed coping session.
  ///
  /// Sends `{ "type": ..., "durationSeconds": ... }` to POST /api/coping/session.
  /// Returns the created session map on success, or an empty map on failure so
  /// callers (e.g. the breathing UI) are never crashed by a network error.
  Future<Map<String, dynamic>> logCopingSession({
    required String type,
    required int durationSeconds,
  }) async {
    if (_token == null) {
      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString(_kTokenKey);
    }
    if (_token == null) {
      debugPrint('DioService: logCopingSession skipped — user not authenticated.');
      return {};
    }
    try {
      final response = await _dio.post(
        '/api/coping/session',
        data: {
          'type': type,
          'durationSeconds': durationSeconds,
        },
      );

      if ((response.statusCode == 200 || response.statusCode == 201) &&
          response.data != null) {
        debugPrint(
          'DioService: Coping session logged. Type: $type, durationSeconds: $durationSeconds',
        );
        return response.data as Map<String, dynamic>;
      }
      debugPrint(
        'DioService: Unexpected status logging coping session: ${response.statusCode}',
      );
      return {};
    } catch (e) {
      debugPrint('DioService: Failed to log coping session (non-fatal): $e');
      return {};
    }
  }

  /// Fetches user statistics from the API.
  Future<Map<String, dynamic>> getUserStats() async {
    if (_token == null) {
      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString(_kTokenKey);
    }
    if (_token == null) {
      throw Exception('Not authenticated. Please log in.');
    }
    return _request(() async {
      final response = await _dio.get('/api/user/stats');
      if (response.statusCode == 200 && response.data != null) {
        return response.data as Map<String, dynamic>;
      }
      throw Exception('Failed to load user stats: status ${response.statusCode}');
    });
  }

  /// Fetches sentiment analysis for a specific mood entry.
  Future<Map<String, dynamic>> getSentimentAnalysis(String entryId) async {
    if (_token == null) {
      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString(_kTokenKey);
    }
    if (_token == null) {
      throw Exception('Not authenticated. Please log in.');
    }
    return _request(() async {
      final response = await _dio.get('/api/ai/sentiment/$entryId');
      if (response.statusCode == 200 && response.data != null) {
        return response.data as Map<String, dynamic>;
      }
      throw Exception('Failed to load sentiment analysis');
    });
  }

  /// Fetches an AI-powered coping suggestion from the API.
  Future<Map<String, dynamic>> getAiCopingSuggestion({
    required int moodScore,
    required String timeOfDay,
    double recentAverage = 3.0,
    List<String> lastTags = const [],
  }) async {
    if (_token == null) {
      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString(_kTokenKey);
    }
    if (_token == null) {
      throw Exception('Not authenticated. Please log in.');
    }
    return _request(() async {
      final response = await _dio.post(
        '/api/ai/coping/suggest',
        data: {
          'moodScore': moodScore,
          'timeOfDay': timeOfDay,
          'recentAverage': recentAverage,
          'lastTags': lastTags,
        },
      );
      if (response.statusCode == 200 && response.data != null) {
        return response.data as Map<String, dynamic>;
      }
      throw Exception('Failed to fetch coping suggestion: status ${response.statusCode}');
    });
  }

  /// Generates an instant AI mood reflection based on score, tags, note, and optional recent average.
  Future<Map<String, dynamic>> getMoodReflection({
    required int moodScore,
    required List<String> tags,
    String? note,
    double? recentAverage,
  }) async {
    if (_token == null) {
      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString(_kTokenKey);
    }
    if (_token == null) {
      throw Exception('Not authenticated. Please log in.');
    }
    return _request(() async {
      final response = await _dio.post(
        '/api/ai/mood/reflection',
        data: {
          'moodScore': moodScore,
          'tags': tags,
          if (note != null) 'note': note,
          if (recentAverage != null) 'recentAverage': recentAverage,
        },
      );
      if (response.statusCode == 200 && response.data != null) {
        return response.data as Map<String, dynamic>;
      }
      throw Exception('Failed to get mood reflection: status ${response.statusCode}');
    });
  }

  /// Generates a personalized AI journal reflection prompt based on mood score and tags.
  Future<Map<String, dynamic>> getJournalPrompt({
    required int moodScore,
    List<String> tags = const [],
    List<String> recentNoteSummaries = const [],
  }) async {
    if (_token == null) {
      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString(_kTokenKey);
    }
    if (_token == null) {
      throw Exception('Not authenticated. Please log in.');
    }
    return _request(() async {
      final response = await _dio.post(
        '/api/ai/journal/prompt',
        data: {
          'moodScore': moodScore,
          'tags': tags,
          'recentNoteSummaries': recentNoteSummaries,
        },
      );
      if (response.statusCode == 200 && response.data != null) {
        return response.data as Map<String, dynamic>;
      }
      throw Exception(
        'Failed to generate journal prompt: status ${response.statusCode}',
      );
    });
  }

  /// Generates a personalized AI journal reflection prompt based on mood score and tags.
  Future<Map<String, dynamic>> generateJournalPrompt({
    required int moodScore,
    required List<String> tags,
    List<String> recentNoteSummaries = const [],
  }) async {
    return getJournalPrompt(
      moodScore: moodScore,
      tags: tags,
      recentNoteSummaries: recentNoteSummaries,
    );
  }


  /// Sends a chat message to the MindChat AI companion.
  Future<Map<String, dynamic>> sendChatMessage({
    required String message,
    required List<dynamic> conversationHistory,
    required Map<String, dynamic> moodContext,
  }) async {
    if (_token == null) {
      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString(_kTokenKey);
    }
    if (_token == null) {
      throw Exception('Not authenticated. Please log in.');
    }
    return _request(() async {
      final response = await _dio.post(
        '/api/ai/chat',
        data: {
          'message': message,
          'conversationHistory': conversationHistory,
          'moodContext': moodContext,
        },
      );
      if (response.statusCode == 200 && response.data != null) {
        return response.data as Map<String, dynamic>;
      }
      throw Exception('Failed to send chat message: status ${response.statusCode}');
    });
  }

  /// Fetches weekly mood anomalies & burnout trends
  Future<Map<String, dynamic>> getMoodAnomaly() async {
    if (_token == null) {
      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString(_kTokenKey);
    }
    if (_token == null) {
      throw Exception('Not authenticated. Please log in.');
    }
    return _request(() async {
      final response = await _dio.get('/api/ai/anomaly/weekly');
      if (response.statusCode == 200 && response.data != null) {
        return response.data as Map<String, dynamic>;
      }
      throw Exception('Failed to load anomaly detection: status ${response.statusCode}');
    });
  }

  /// Fetches the therapist directory profiles from the Spring Boot backend.
  Future<List<dynamic>> getTherapists() async {
    if (_token == null) {
      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString(_kTokenKey);
    }
    if (_token == null) {
      throw Exception('Not authenticated. Please log in.');
    }
    return _request(() async {
      final response = await _dio.get('/api/therapists');
      if (response.statusCode == 200 && response.data != null) {
        return (response.data as List<dynamic>).map((therapist) {
          if (therapist is Map<String, dynamic>) {
            return {
              ...therapist,
              'contactEmail': therapist['contactEmail'] ?? therapist['email'] ?? '',
            };
          }
          return therapist;
        }).toList();
      }
      return [];
    });
  }

  /// Fetches the user preferences from the Spring Boot backend.
  Future<Map<String, dynamic>> getUserPreferences() async {
    if (_token == null) {
      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString(_kTokenKey);
    }
    if (_token == null) {
      throw Exception('Not authenticated. Please log in.');
    }
    return _request(() async {
      final response = await _dio.get('/api/user/preferences');
      if (response.statusCode == 200 && response.data != null) {
        return response.data as Map<String, dynamic>;
      }
      throw Exception('Failed to load user preferences: status ${response.statusCode}');
    });
  }

  /// Updates the user preferences in the Spring Boot backend.
  Future<Map<String, dynamic>> updateUserPreferences(Map<String, dynamic> preferences) async {
    if (_token == null) {
      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString(_kTokenKey);
    }
    if (_token == null) {
      throw Exception('Not authenticated. Please log in.');
    }
    return _request(() async {
      final response = await _dio.put(
        '/api/user/preferences',
        data: preferences,
      );
      if (response.statusCode == 200 && response.data != null) {
        return response.data as Map<String, dynamic>;
      }
      throw Exception('Failed to update user preferences: status ${response.statusCode}');
    });
  }
}

/// Riverpod provider for DioService singleton
final dioServiceProvider = Provider<DioService>((ref) {
  return DioService();
});

class RateLimitException implements Exception {
  final String message;
  RateLimitException(this.message);

  @override
  String toString() => message;
}
