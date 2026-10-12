import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/course_material.dart';
import 'planning_api.dart';

Uri courseEndpoint(String baseUrl, String subPath, {bool release = kReleaseMode}) =>
    apiUri(baseUrl, '/api/courses$subPath', release: release);

Uri licenseActivationEndpoint(String baseUrl, {bool release = kReleaseMode}) =>
    apiUri(baseUrl, '/api/licenses/activate', release: release);

class CourseStudyApi {
  final http.Client client;
  final String baseUrl;

  CourseStudyApi([http.Client? client, this.baseUrl = apiBaseUrl])
      : client = client ?? http.Client();

  Future<LicenseActivationModel> activateLicense({
    required String licenseKey,
    String? deviceIdentifier,
  }) async {
    final key = licenseKey.trim();
    if (key.isEmpty) {
      throw StateError('Clé de licence Chariow requise.');
    }
    final payload = <String, dynamic>{'license_key': key};
    if (deviceIdentifier != null && deviceIdentifier.trim().isNotEmpty) {
      payload['device_identifier'] = deviceIdentifier.trim();
    }
    final response = await client
        .post(
          licenseActivationEndpoint(baseUrl),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 30));
    final body = _decodeJson(response, 'Activation de la licence Chariow impossible');
    return LicenseActivationModel.fromJson(body);
  }

  Map<String, String> _authHeaders(String accessToken, {bool jsonBody = false}) {
    final token = accessToken.trim();
    if (token.isEmpty) {
      throw StateError('Jeton d’accès Studia requis pour importer ou interroger un support de cours.');
    }
    return {
      'Authorization': 'Bearer $token',
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
      final detail = body['detail'];
      throw Exception(detail is String ? detail : '$fallbackMessage (${response.statusCode}).');
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
