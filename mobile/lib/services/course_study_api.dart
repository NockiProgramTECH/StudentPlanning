import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/course_material.dart';
import 'planning_api.dart';

Uri courseEndpoint(String baseUrl, String subPath, {bool release = kReleaseMode}) =>
    apiUri(baseUrl, '/api/courses$subPath', release: release);

Uri accessActivationEndpoint(String baseUrl, {bool release = kReleaseMode}) =>
    apiUri(baseUrl, '/api/access/activate', release: release);

class StudentAccessConfig {
  final bool freeAccess;
  final String portalPath;
  const StudentAccessConfig({required this.freeAccess, required this.portalPath});
}

class CourseApiException implements Exception {
  final int statusCode;
  final String message;
  const CourseApiException(this.statusCode, this.message);
  @override
  String toString() => message;
}

class CourseStudyApi {
  final http.Client client;
  final String baseUrl;
  String? deviceIdentifier;

  CourseStudyApi([http.Client? client, this.baseUrl = apiBaseUrl])
      : client = client ?? http.Client();

  Future<StudentAccessConfig> accessConfig() async {
    final response = await client.get(apiUri(baseUrl, '/api/access/config'))
        .timeout(const Duration(seconds: 20));
    final body = _decodeJson(response, 'Configuration de l’espace étudiant indisponible');
    if (body['free_access'] is! bool || body['portal_url'] != '/api/access/portal') {
      throw const FormatException('Configuration de l’espace étudiant invalide.');
    }
    return StudentAccessConfig(
      freeAccess: body['free_access'] as bool,
      portalPath: body['portal_url'] as String,
    );
  }

  Future<void> checkAccess(String token) async {
    final response = await client.get(courseEndpoint(baseUrl, '/quota'),
        headers: _authHeaders(token)).timeout(const Duration(seconds: 20));
    _decodeJson(response, 'Accès étudiant indisponible');
  }

  Future<AccessActivationModel> activateAccess({
    required String accessCode,
    String? deviceIdentifier,
  }) async {
    final key = accessCode.trim();
    if (key.isEmpty) {
      throw StateError('Code d’accès ou e-mail étudiant requis.');
    }
    final payload = <String, dynamic>{'access_code': key};
    if (deviceIdentifier != null && deviceIdentifier.trim().isNotEmpty) {
      payload['device_identifier'] = deviceIdentifier.trim();
    }
    final response = await client
        .post(
          accessActivationEndpoint(baseUrl),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 30));
    final body = _decodeJson(response, 'Activation de l’accès impossible');
    return AccessActivationModel.fromJson(body);
  }

  Map<String, String> _authHeaders(String accessToken, {bool jsonBody = false}) {
    final token = accessToken.trim();
    if (token.isEmpty && (deviceIdentifier ?? '').isEmpty) {
      throw StateError('Jeton d’accès Studia requis pour importer ou interroger un support de cours.');
    }
    return {
      if (token.isNotEmpty) 'Authorization': 'Bearer $token',
      if (deviceIdentifier != null) 'X-Device-Identifier': deviceIdentifier!,
      if (jsonBody) 'Content-Type': 'application/json',
    };
  }

  Map<String, dynamic> _decodeJson(http.Response response, String fallbackMessage) {
    late final Map<String, dynamic> body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw Exception('Réponse serveur illisible (${response.statusCode}).');
    }
    if (response.statusCode != 200) {
      // Never render upstream service messages or identifiers in the interface.
      final message = switch (response.statusCode) {
        401 || 403 => 'Accès étudiant inactif ou non reconnu. Finalisez votre accès.',
        429 => 'Quota atteint. Réessayez après le renouvellement de votre quota.',
        _ => '$fallbackMessage (${response.statusCode}).',
      };
      throw CourseApiException(response.statusCode, message);
    }
    return body;
  }

  Future<CourseDocumentModel> importCoursePdf({
    required String accessToken,
    required Uint8List bytes,
    required String filename,
    required String subject,
    String? title,
  }) async {
    final request = http.MultipartRequest('POST', courseEndpoint(baseUrl, '/import'));
    request.headers.addAll(_authHeaders(accessToken));
    request.fields['subject'] = subject.trim();
    if (title != null && title.trim().isNotEmpty) {
      request.fields['title'] = title.trim();
    }
    request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));
    final streamed = await client.send(request).timeout(const Duration(seconds: 65));
    final response = await http.Response.fromStream(streamed);
    final body = _decodeJson(response, 'Import du support impossible');
    return CourseDocumentModel.fromJson(body);
  }

  Future<List<CourseQuestionModel>> generateSectionQuestions({
    required String accessToken,
    required String documentId,
    required int sectionIndex,
    int count = 3,
    bool regenerate = false,
  }) async {
    final response = await client
        .post(
          courseEndpoint(baseUrl, '/$documentId/sections/$sectionIndex/questions'),
          headers: _authHeaders(accessToken, jsonBody: true),
          body: jsonEncode({'count': count, 'regenerate': regenerate}),
        )
        .timeout(const Duration(seconds: 65));
    final body = _decodeJson(response, 'Génération des questions impossible');
    return (body['questions'] as List)
        .map((q) => CourseQuestionModel.fromJson(q as Map<String, dynamic>))
        .toList();
  }

  Future<Map<String, dynamic>> submitAnswer({
    required String accessToken,
    required String documentId,
    required int questionId,
    required int selectedIndex,
  }) async {
    final response = await client
        .post(
          courseEndpoint(baseUrl, '/$documentId/answers'),
          headers: _authHeaders(accessToken, jsonBody: true),
          body: jsonEncode({'question_id': questionId, 'selected_index': selectedIndex}),
        )
        .timeout(const Duration(seconds: 30));
    return _decodeJson(response, 'Notation de la réponse impossible');
  }
}
