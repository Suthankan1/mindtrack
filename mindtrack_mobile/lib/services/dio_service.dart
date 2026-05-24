import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _kTokenKey = 'auth_jwt_token';

class DioService {
  final Dio _dio;
  String? _token;

  DioService()
    : _dio = Dio(
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

  static String _determineBaseUrl() {
    // Android Emulator routes localhost through 10.0.2.2.
    // iOS and macOS use localhost directly.
    if (!kIsWeb && Platform.isAndroid) {
      return 'http://10.0.2.2:8080';
    }
    return 'http://localhost:8080';
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
      final msg = e.response?.data != null && e.response?.data is Map
          ? (e.response?.data['message'] ?? 'Invalid email or password')
          : 'Failed to connect to authentication server.';
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
      final msg = e.response?.data != null && e.response?.data is Map
          ? (e.response?.data['message'] ?? 'Registration failed')
          : 'Failed to connect to authentication server.';
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
    try {
      final response = await _dio.get('/api/mood/today');
      if (response.statusCode == 200 && response.data != null) {
        return response.data as List<dynamic>;
      }
      return [];
    } catch (e) {
      debugPrint('DioService: Error fetching today\'s mood logs: $e');
      rethrow;
    }
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
    try {
      final response = await _dio.get(
        '/api/mood/history',
        queryParameters: {'days': days},
      );
      if (response.statusCode == 200 && response.data != null) {
        return response.data as List<dynamic>;
      }
      return [];
    } catch (e) {
      debugPrint('DioService: Error fetching mood history: $e');
      rethrow;
    }
  }

  /// Logs a new mood entry.
  Future<Map<String, dynamic>> logMood(
    int score, {
    String note = 'Logged via mobile app',
    List<String> tags = const [],
  }) async {
    if (_token == null) {
      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString(_kTokenKey);
    }
    if (_token == null) {
      throw Exception('Not authenticated. Please log in.');
    }
    try {
      final response = await _dio.post(
        '/api/mood/log',
        data: {'moodScore': score, 'note': note, 'tags': tags},
      );

      if (response.statusCode == 201 && response.data != null) {
        debugPrint('DioService: Mood logged successfully. Score: $score');
        return response.data as Map<String, dynamic>;
      }
      throw Exception(
        'DioService: Failed to log mood. Status: ${response.statusCode}',
      );
    } catch (e) {
      debugPrint('DioService: Error logging mood: $e');
      rethrow;
    }
  }

  /// Logs a completed coping session.
  Future<Map<String, dynamic>> logCopingSession({
    required String type,
    required int duration,
  }) async {
    if (_token == null) {
      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString(_kTokenKey);
    }
    if (_token == null) {
      throw Exception('Not authenticated. Please log in.');
    }
    try {
      final response = await _dio.post(
        '/api/coping/session',
        data: {'type': type, 'duration': duration},
      );

      if ((response.statusCode == 200 || response.statusCode == 201) && response.data != null) {
        debugPrint('DioService: Coping session logged successfully. Type: $type, Duration: $duration');
        return response.data as Map<String, dynamic>;
      }
      throw Exception(
        'DioService: Failed to log coping session. Status: ${response.statusCode}',
      );
    } catch (e) {
      debugPrint('DioService: Error logging coping session: $e');
      rethrow;
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
    try {
      final response = await _dio.get('/api/user/stats');
      if (response.statusCode == 200 && response.data != null) {
        return response.data as Map<String, dynamic>;
      }
      throw Exception('Failed to load user stats: status ${response.statusCode}');
    } catch (e) {
      debugPrint('DioService: Error fetching user stats: $e');
      rethrow;
    }
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
    try {
      final response = await _dio.get('/api/ai/sentiment/$entryId');
      if (response.statusCode == 200 && response.data != null) {
        return response.data as Map<String, dynamic>;
      }
      throw Exception('Failed to load sentiment analysis');
    } catch (e) {
      debugPrint('DioService: Error fetching sentiment analysis: $e');
      rethrow;
    }
  }
}

/// Riverpod provider for DioService singleton
final dioServiceProvider = Provider<DioService>((ref) {
  return DioService();
});
