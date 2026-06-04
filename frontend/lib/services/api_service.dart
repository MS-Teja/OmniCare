import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../models/observation.dart';
import '../models/intervention.dart';

/// Handles all communication with the OmniCare backend.
///
/// Every method returns a result or throws an [ApiException]
/// with a user-friendly message — never raw HTTP jargon.
class ApiService {
  final http.Client _client;

  ApiService({http.Client? client}) : _client = client ?? http.Client();

  // ── Health Check ──────────────────────────────────────────────────

  Future<bool> healthCheck() async {
    try {
      final response = await _client
          .get(Uri.parse('${Config.baseUrl}/'))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ── Log an Observation ────────────────────────────────────────────

  Future<IngestResponse> logObservation({
    required String text,
    String? audioBase64,
    String patientId = 'unknown',
  }) async {
    if (text.trim().isEmpty && (audioBase64 == null || audioBase64.isEmpty)) {
      throw const ApiException(
        'Please write something or record a voice note first.',
      );
    }

    try {
      final body = <String, dynamic>{
        'text': text.trim(),
        'patient_id': patientId,
      };
      if (audioBase64 != null && audioBase64.isNotEmpty) {
        body['audio_data'] = audioBase64;
      }

      final response = await _client
          .post(
            Uri.parse('${Config.baseUrl}/ingest'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(Config.requestTimeout);

      if (response.statusCode != 200) {
        throw ApiException(_parseError(response));
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return IngestResponse.fromJson(json);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(_friendlyError(e));
    }
  }

  // ── Ask for Help ──────────────────────────────────────────────────

  Future<InterventionResponse> askForHelp(
    String question, {
    String patientId = 'unknown',
  }) async {
    if (question.trim().isEmpty) {
      throw const ApiException(
        'Please describe what\'s happening so we can help.',
      );
    }

    try {
      final response = await _client
          .post(
            Uri.parse('${Config.baseUrl}/query'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'question': question.trim(),
              'patient_id': patientId,
            }),
          )
          .timeout(Config.requestTimeout);

      if (response.statusCode != 200) {
        throw ApiException(_parseError(response));
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return InterventionResponse.fromJson(json);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(_friendlyError(e));
    }
  }

  // ── History ────────────────────────────────────────────────────────

  Future<List<Observation>> getHistory({
    String patientId = 'unknown',
    int limit = 50,
  }) async {
    try {
      final response = await _client
          .get(Uri.parse(
              '${Config.baseUrl}/history?patient_id=${Uri.encodeComponent(patientId)}&limit=$limit'))
          .timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        throw ApiException(_parseError(response));
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final list = json['observations'] as List<dynamic>? ?? [];
      return list
          .map((e) => Observation.fromJson(e as Map<String, dynamic>))
          .toList();
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(_friendlyError(e));
    }
  }

  // ── Patients ──────────────────────────────────────────────────────

  Future<List<String>> getPatients() async {
    try {
      final response = await _client
          .get(Uri.parse('${Config.baseUrl}/patients'))
          .timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        throw ApiException(_parseError(response));
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final list = json['patients'] as List<dynamic>? ?? [];
      return list.map((e) => e.toString()).toList();
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(_friendlyError(e));
    }
  }

  // ── Error Helpers ──────────────────────────────────────────────────

  String _parseError(http.Response response) {
    try {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final detail = json['detail'];
      if (detail is String && detail.isNotEmpty) {
        // Don't leak stack traces to users
        if (detail.length > 200) {
          return 'Something went wrong on our end. Please try again in a moment.';
        }
        return detail;
      }
    } catch (_) {}
    return 'Something went wrong (${response.statusCode}). Please try again.';
  }

  String _friendlyError(Object error) {
    final message = error.toString().toLowerCase();
    if (message.contains('timeout') || message.contains('timed out')) {
      return 'This is taking longer than usual — the AI might be busy. '
          'Please try again in a moment.';
    }
    if (message.contains('connection refused') ||
        message.contains('socketexception') ||
        message.contains('no route to host') ||
        message.contains('network is unreachable')) {
      return 'Can\'t reach OmniCare right now. '
          'Check that the backend is running and your device is on the same network.';
    }
    if (message.contains('handshake') || message.contains('certificate')) {
      return 'There\'s a connection security issue. '
          'Make sure you\'re on a trusted network.';
    }
    return 'Something went wrong. Please try again.';
  }

  void dispose() {
    _client.close();
  }
}

/// A user-facing API error.
class ApiException implements Exception {
  final String message;

  const ApiException(this.message);

  @override
  String toString() => message;
}
