import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:mindtrack_mobile/services/dio_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Per-Email Onboarding Tests', () {
    test('DioService.login saves email to user_email in preferences', () async {
      final dio = Dio();
      dio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.path == '/api/auth/login') {
            handler.resolve(Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'accessToken': 'dummy_token',
                'email': 'user@example.com',
              },
            ));
          } else {
            handler.next(options);
          }
        },
      ));

      final service = DioService(dio: dio);
      await service.login('user@example.com', 'password123');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('auth_jwt_token'), 'dummy_token');
      expect(prefs.getString('user_email'), 'user@example.com');
    });

    test('DioService.logout does not clear onboarding completed flag', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_jwt_token', 'dummy_token');
      await prefs.setBool('onboarding_complete_user@example.com', true);

      final service = DioService();
      await service.logout();

      expect(prefs.getString('auth_jwt_token'), isNull);
      expect(prefs.getBool('onboarding_complete_user@example.com'), isTrue);
    });
  });
}
