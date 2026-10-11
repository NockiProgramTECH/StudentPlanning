import 'package:flutter_test/flutter_test.dart';
import 'package:student_planning/services/planning_api.dart';

void main() {
  test('URL HTTPS du serveur déployé', () {
    expect(importEndpoint('https://api.example.org/'),
        Uri.parse('https://api.example.org/api/import'));
  });

  test('une adresse locale HTTP reste possible pour les essais debug', () {
    expect(importEndpoint('http://10.0.2.2:8000', release: false).host, '10.0.2.2');
    expect(() => importEndpoint('http://10.0.2.2:8000', release: true), throwsStateError);
  });

  test('aucun serveur caché ni URL contenant des identifiants', () {
    for (final url in ['', 'http://', 'https://name:password@example.org',
                       'https://api.example.org?secret=abc']) {
      expect(() => importEndpoint(url), throwsStateError);
    }
  });
}
