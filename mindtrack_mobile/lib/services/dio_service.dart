import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Predefined credentials for automatic authentication
const String _kAuthEmail = 'practitioner@mindtrack.com';
const String _kAuthPassword = 'password123';
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
          // If token isn't loaded in memory yet, load it from SharedPreferences
          if (_token == null) {
            final prefs = await SharedPreferences.getInstance();
            _token = prefs.getString(_kTokenKey);
          }

          if (_token != null) {
            options.headers['Authorization'] = 'Bearer $_token';
          }
          return handler.next(options);
        },
        onError: (DioException e, handler) async {
          // If we get an Unauthorized 401 or 403, our token might have expired.
          // Let's clear the token and try to re-authenticate if we are not already trying to authenticate.
          final isAuthPath = e.requestOptions.path.contains('/api/auth/');
          if ((e.response?.statusCode == 401 ||
                  e.response?.statusCode == 403) &&
              !isAuthPath) {
            try {
              final authenticated = await _authenticate();
              if (authenticated) {
                // Retry the original request with the new token
                final options = e.requestOptions;
                options.headers['Authorization'] = 'Bearer $_token';
                final cloneReq = await _dio.fetch(options);
                return handler.resolve(cloneReq);
              }
            } catch (err) {
              debugPrint('Re-auth failed: $err');
            }
          }
          return handler.next(e);
        },
      ),
    );
  }

  /// Attempts to log in. If user doesn't exist, registers them, then logs in.
  Future<bool> _authenticate() async {
    final prefs = await SharedPreferences.getInstance();

    // 1. Try to Login
    try {
      final response = await _dio.post(
        '/api/auth/login',
        data: {'email': _kAuthEmail, 'password': _kAuthPassword},
      );

      if (response.statusCode == 200 && response.data != null) {
        _token = response.data['accessToken'] as String?;
        if (_token != null) {
          await prefs.setString(_kTokenKey, _token!);
          debugPrint('DioService: Auto-login succeeded.');
          return true;
        }
      }
    } on DioException catch (e) {
      debugPrint(
        'DioService: Login failed, attempting auto-registration. Status: ${e.response?.statusCode}',
      );
    }

    // 2. Try to Register (Fallback)
    try {
      final response = await _dio.post(
        '/api/auth/register',
        data: {
          'email': _kAuthEmail,
          'password': _kAuthPassword,
          'anonymousMode': false,
        },
      );

      if (response.statusCode == 201 && response.data != null) {
        _token = response.data['accessToken'] as String?;
        if (_token != null) {
          await prefs.setString(_kTokenKey, _token!);
          debugPrint('DioService: Auto-registration & login succeeded.');
          return true;
        }
      }
    } on DioException catch (e) {
      debugPrint(
        'DioService: Registration failed. Status: ${e.response?.statusCode}, Error: ${e.response?.data}',
      );
    }

    return false;
  }

  /// Ensures a valid authentication token exists before making secure calls.
  Future<void> ensureAuthenticated() async {
    if (_token != null) return;

    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_kTokenKey);
    if (_token != null) return;

    final authenticated = await _authenticate();
    if (!authenticated) {
      throw Exception(
        'DioService: Failed to establish automatic secure handshake.',
      );
    }
  }

  /// Fetches today's mood logs.
  Future<List<dynamic>> getTodayMoods() async {
    await ensureAuthenticated();
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
    await ensureAuthenticated();
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
    await ensureAuthenticated();
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
}

/// Riverpod provider for DioService singleton
final dioServiceProvider = Provider<DioService>((ref) {
  return DioService();
});
