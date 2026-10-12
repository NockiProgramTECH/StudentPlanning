import 'package:flutter_test/flutter_test.dart';
import 'package:student_planning/demo.dart';
import 'package:student_planning/models/course_material.dart';
import 'package:student_planning/services/course_study_api.dart';

void main() {
  test('le support de cours conserve les sections, questions et références de pages', () {
    final demo = demoCourseDocument();
    final roundtrip = CourseDocumentModel.fromJson(demo.toJson());
    expect(roundtrip.subject, 'Transmission des signaux analogiques');
    expect(roundtrip.sections.length, 2);
    expect(roundtrip.sections.first.pages, [1, 2, 3]);
    expect(roundtrip.questions.first.sourcePage, 2);
  });

  test('la notation met à jour la progression et le score par section', () {
    final demo = demoCourseDocument();
    final updatedQuestions = [
      demo.questions[0],
      demo.questions[1].copyWith(selectedIndex: 1, isCorrect: true),
    ];
    final updated = demo.withUpdatedQuestions(updatedQuestions);
    expect(updated.progress.completedSections, 1);
    expect(updated.progress.answeredQuestions, 2);
    expect(updated.progress.correctAnswers, 2);
    expect(updated.progress.scorePercent, 100);
    expect(updated.progress.nextSectionIndex, 1);
  });

  test('LicenseActivationModel décode la réponse Chariow du serveur', () {
    final model = LicenseActivationModel.fromJson({
      'valid': true,
      'student_id': 'chariow_123456',
      'access_token': 'studia_lic_secret',
      'masked_key': 'CHR-***-001',
      'status': 'active',
      'expires_at': '2027-06-30T23:59:59+00:00',
      'activation_count': 1,
      'max_activations': 2,
      'activations_remaining': 1,
      'product_name': 'Pass Semestre Studia L2 SIR',
      'quota': {
        'documents_today': 1,
        'max_documents_per_day': 5,
        'quiz_requests_today': 2,
        'max_quiz_requests_per_day': 20,
      },
    });
    expect(model.valid, isTrue);
    expect(model.maskedKey, 'CHR-***-001');
    expect(model.activationsRemaining, 1);
    expect(model.maxQuizRequestsPerDay, 20);
    expect(
      licenseActivationEndpoint('https://api.studia.example', release: true).toString(),
      'https://api.studia.example/api/licenses/activate',
    );
  });
}

