import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:mindtrack_mobile/services/dio_service.dart';

void main() {
  group('DioService Base URL and Error Handling Tests', () {
    test('baseUrl resolves correctly with fallback settings', () {
      final service = DioService();
      final baseUrl = service.baseUrl;
      expect(baseUrl.startsWith('http://'), isTrue);
      expect(baseUrl.endsWith(':8080'), isTrue);
      // Fallback is either localhost or emulator ip (10.0.2.2)
      expect(baseUrl == 'http://localhost:8080' || baseUrl == 'http://10.0.2.2:8080', isTrue);
    });

    test('handleDioError returns user-friendly connection error message', () {
      final service = DioService();
      final requestOptions = RequestOptions(path: '/test-endpoint', baseUrl: 'http://custom-url:8080');
      
      final connectionError = DioException(
        requestOptions: requestOptions,
        type: DioExceptionType.connectionError,
      );

      final message = service.handleDioError(connectionError);
      expect(message, contains('Connection error'));
      expect(message, contains('Unable to reach the server at http://custom-url:8080'));
      expect(message, contains('verify that the backend is active'));
    });

    test('handleDioError returns user-friendly timeout error messages', () {
      final service = DioService();
      final requestOptions = RequestOptions(path: '/test-endpoint', baseUrl: 'http://custom-url:8080');

      final connectTimeout = DioException(
        requestOptions: requestOptions,
        type: DioExceptionType.connectionTimeout,
      );

      final receiveTimeout = DioException(
        requestOptions: requestOptions,
        type: DioExceptionType.receiveTimeout,
      );

      expect(service.handleDioError(connectTimeout), contains('Connection timeout'));
      expect(service.handleDioError(receiveTimeout), contains('Receive timeout'));
    });

    test('handleDioError extracts message from bad response', () {
      final service = DioService();
      final requestOptions = RequestOptions(path: '/test-endpoint');

      final badResponse = DioException(
        requestOptions: requestOptions,
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: requestOptions,
          statusCode: 400,
          data: {'message': 'Invalid inputs specified'},
        ),
      );

      final message = service.handleDioError(badResponse);
      expect(message, equals('Invalid inputs specified (Status code: 400)'));
    });

    test('handleDioError formats socket exception under unknown type', () {
      final service = DioService();
      final requestOptions = RequestOptions(path: '/test-endpoint', baseUrl: 'http://custom-url:8080');

      final socketError = DioException(
        requestOptions: requestOptions,
        type: DioExceptionType.unknown,
        error: const SocketException('Connection refused'),
      );

      final message = service.handleDioError(socketError);
      expect(message, contains('Network unreachable'));
      expect(message, contains('http://custom-url:8080'));
    });
  });
}
