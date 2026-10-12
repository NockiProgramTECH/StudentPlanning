import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:student_planning/models/course_material.dart';
import 'package:student_planning/screens/course_study_screen.dart';
import 'package:student_planning/services/course_study_api.dart';
import 'package:student_planning/services/schedule_store.dart';

const server = 'https://api.studia.example';
const device = 'persistent-test-device-12345';

class MemoryAccessStore extends ScheduleStore {
  String? token;
  int writes = 0;
  @override
  Future<String> deviceIdentifier() async => device;
  @override
  Future<List<CourseDocumentModel>> courseDocuments() async => [];
  @override
  Future<String?> studentAccessToken(String server) async => token;
  @override
  Future<void> saveStudentAccessToken(String server, String? value) async {
    token = value;
    writes++;
  }
}

http.Response config(bool free) => http.Response(jsonEncode({
  'free_access': free, 'portal_url': '/api/access/portal',
}), 200);

void main() {
  test('free requests use the persistent device without an authorization header', () async {
    final api = CourseStudyApi(MockClient((request) async {
      expect(request.url.path, '/api/courses/quota');
      expect(request.headers['X-Device-Identifier'], device);
      expect(request.headers.containsKey('Authorization'), isFalse);
      return http.Response('{}', 200);
    }), server)..deviceIdentifier = device;
    await api.checkAccess('');
  });

  test('access activation uses neutral route and server token', () async {
    final api = CourseStudyApi(MockClient((request) async {
      expect(request.url.path, '/api/access/activate');
      expect(jsonDecode(request.body), {
        'access_code': 'student@example.edu', 'device_identifier': device,
      });
      return http.Response(jsonEncode({
        'valid': true, 'access_token': 'test-token', 'status': 'active',
      }), 200);
    }), server);
    final response = await api.activateAccess(
        accessCode: ' student@example.edu ', deviceIdentifier: device);
    expect(response.accessToken, 'test-token');
  });

  test('upstream text is never rendered to students', () async {
    final api = CourseStudyApi(MockClient((_) async => http.Response(
      jsonEncode({'detail': 'Chariow licence sk_live_server_secret'}), 403,
    )), server)..deviceIdentifier = device;
    await expectLater(api.checkAccess(''), throwsA(isA<CourseApiException>()
        .having((e) => e.message, 'neutral message',
            'Accès étudiant inactif ou non reconnu. Finalisez votre accès.')));
  });

  test('malformed config and external portal injection fail closed', () async {
    for (final body in [
      {'free_access': 'true', 'portal_url': '/api/access/portal'},
      {'free_access': true, 'portal_url': 'https://untrusted.example'},
    ]) {
      final api = CourseStudyApi(MockClient((_) async => http.Response(jsonEncode(body), 200)), server);
      await expectLater(api.accessConfig(), throwsFormatException);
    }
  });

  testWidgets('free mode hides all access controls and offers direct PDF import', (tester) async {
    final api = CourseStudyApi(MockClient((_) async => config(true)), server);
    await tester.pumpWidget(MaterialApp(home: CourseStudyScreen(store: MemoryAccessStore(), api: api)));
    await tester.pumpAndSettle();
    expect(find.text('Ouvrir le portail étudiant'), findsNothing);
    expect(find.text('Finaliser mon accès'), findsNothing);
    expect(find.text("Code d'accès ou e-mail étudiant"), findsNothing);
    expect(find.text('Choisir un PDF de cours'), findsOneWidget);
    expect(api.deviceIdentifier, device);
  });

  testWidgets('portal return, one-click activation and saved access on reopen', (tester) async {
    final store = MemoryAccessStore();
    var configs = 0;
    var activations = 0;
    String? openedUrl;
    const channel = MethodChannel('studia/student_portal');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'open');
      openedUrl = call.arguments as String;
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null));
    final api = CourseStudyApi(MockClient((request) async {
      if (request.url.path == '/api/access/config') {
        configs++;
        return config(false);
      }
      if (request.url.path == '/api/access/activate') {
        activations++;
        expect(jsonDecode(request.body)['device_identifier'], device);
        return http.Response('{"valid":true,"status":"active","access_token":"saved-test-token"}', 200);
      }
      expect(request.url.path, '/api/courses/quota');
      expect(request.headers['Authorization'], 'Bearer saved-test-token');
      return http.Response('{}', 200);
    }), server);
    await tester.pumpWidget(MaterialApp(home: CourseStudyScreen(store: store, api: api)));
    await tester.pumpAndSettle();
    expect(find.text('Choisir un PDF de cours'), findsNothing);
    await tester.tap(find.text('Ouvrir le portail étudiant'));
    await tester.pumpAndSettle();
    expect(openedUrl, '$server/api/access/portal');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(configs, 2);
    await tester.enterText(find.byType(TextField), 'student@example.edu');
    await tester.ensureVisible(find.text('Finaliser mon accès'));
    await tester.tap(find.text('Finaliser mon accès'));
    await tester.pumpAndSettle();
    expect(activations, 1);
    expect(store.token, 'saved-test-token');
    expect(store.writes, 1);
    expect(find.text('Finaliser mon accès'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(MaterialApp(home: CourseStudyScreen(store: store, api: api)));
    await tester.pumpAndSettle();
    expect(find.text('Ouvrir le portail étudiant'), findsNothing);
    expect(find.text('Choisir un PDF de cours'), findsOneWidget);
    expect(activations, 1);
  });

  testWidgets('revoked saved access is removed and can be renewed', (tester) async {
    final store = MemoryAccessStore()..token = 'expired-test-token';
    final api = CourseStudyApi(MockClient((request) async =>
      request.url.path == '/api/access/config' ? config(false) : http.Response('{}', 403)), server);
    await tester.pumpWidget(MaterialApp(home: CourseStudyScreen(store: store, api: api)));
    await tester.pumpAndSettle();
    expect(store.token, isNull);
    expect(find.text('Ouvrir le portail étudiant'), findsOneWidget);
    expect(find.text('Choisir un PDF de cours'), findsNothing);
  });

  testWidgets('configuration failure never silently unlocks import', (tester) async {
    final api = CourseStudyApi(MockClient((_) async => http.Response('{}', 503)), server);
    await tester.pumpWidget(MaterialApp(home: CourseStudyScreen(store: MemoryAccessStore(), api: api)));
    await tester.pumpAndSettle();
    expect(find.text('Choisir un PDF de cours'), findsNothing);
    expect(find.text('Réessayer'), findsOneWidget);
  });
}
