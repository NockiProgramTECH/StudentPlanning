import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../models/schedule.dart';

/// Set at build time: 10.0.2.2 for emulator, LAN IP for local phone,
/// HTTPS public domain for deployed builds. Never bake a personal LAN IP in.
const apiBaseUrl = String.fromEnvironment('API_BASE_URL');

Uri importEndpoint(String baseUrl, {bool release = kReleaseMode}) {
  final trimmed = baseUrl.trim().replaceFirst(RegExp(r'/+$'), '');
  final base = Uri.tryParse(trimmed);
  if (base == null || !base.hasAuthority ||
      (base.scheme != 'https' && base.scheme != 'http') ||
      base.userInfo.isNotEmpty || base.query.isNotEmpty || base.fragment.isNotEmpty) {
    throw StateError('Adresse du serveur API absente ou invalide. Fournissez --dart-define=API_BASE_URL=https://votre-domaine.');
  }
  if (release && base.scheme != 'https') {
    throw StateError('En version distribuée, le serveur API doit utiliser HTTPS.');
  }
  return Uri.parse('$trimmed/api/import');
}

class ImportResponse {
  final Schedule schedule;
  final List<Change> changes;
  const ImportResponse(this.schedule, this.changes);
}

class PlanningApi {
  final http.Client client;
  PlanningApi([http.Client? client]) : client = client ?? http.Client();

  Future<ImportResponse> importPdf({required Uint8List bytes, required String filename,
    required String className, required DateTime weekStart, Schedule? previous}) async {
    final request = http.MultipartRequest('POST', importEndpoint(apiBaseUrl));
    request.fields['class_name'] = className;
    request.fields['week_start'] = Schedule(className: className, weekStart: weekStart, courses: const []).toJson()['week_start'] as String;
    if (previous != null) request.fields['previous'] = jsonEncode(previous.toJson());
    request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));
    final response = await http.Response.fromStream(await client.send(request).timeout(const Duration(seconds: 65)));
    late final Map<String, dynamic> body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw Exception('Réponse serveur illisible (${response.statusCode}).');
    }
    if (response.statusCode != 200) {
      final detail = body['detail'];
      throw Exception(detail is String ? detail : 'Import impossible (${response.statusCode}).');
    }
    return ImportResponse(Schedule.fromJson(body['schedule'] as Map<String, dynamic>),
      (body['changes_from_previous_week'] as List).map((c) => Change.fromJson(c as Map<String, dynamic>)).toList());
  }
}
