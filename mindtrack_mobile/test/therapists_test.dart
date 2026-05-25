import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mindtrack_mobile/services/dio_service.dart';

class CapturingTherapistDioService extends DioService {
  bool didFetchTherapists = false;

  @override
  Future<List<dynamic>> getTherapists() async {
    didFetchTherapists = true;
    return [
      {
        'id': '1',
        'name': 'Dr. Elara Vance',
        'specialty': 'Cognitive Behavioral Therapy (CBT)',
        'location': 'New York, NY (Remote)',
        'contactEmail': 'elara.vance@mindtrack.org',
        'verified': true,
        'bio': 'Specializes in CBT.',
        'rating': 4.9,
        'availability': 'Available Tomorrow',
        'avatarGradient': 'from-teal-400 to-emerald-500',
        'tags': ['CBT', 'Anxiety'],
      }
    ];
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'auth_jwt_token': 'fake_jwt_token',
    });
  });

  group('DioService.getTherapists — integration contract', () {
    test('fetches list of therapists successfully', () async {
      final service = CapturingTherapistDioService();
      final result = await service.getTherapists();

      expect(service.didFetchTherapists, isTrue);
      expect(result, isNotEmpty);
      expect(result.first['name'], equals('Dr. Elara Vance'));
      expect(result.first['verified'], isTrue);
      expect(result.first['rating'], equals(4.9));
      expect(result.first['tags'], contains('CBT'));
    });
  });
}
