import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../models/schedule.dart';

/// Android emulator: 10.0.2.2. For a physical phone pass your computer LAN IP.
const apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:8000');

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
    final request = http.MultipartRequest('POST', Uri.parse('$apiBaseUrl/api/import'));
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
