import 'dart:convert';

import 'package:http/http.dart' as http;
import 'go_models.dart';

/// Thin client for the local `sovereignd` (Go) daemon.
///
/// v0 goals:
/// - Keep it boring and UI-agnostic
/// - Centralize endpoint URLs + JSON handling
/// - Throw readable errors
class SovereignApi {
  SovereignApi({String baseUrl = 'http://127.0.0.1:8080'}) : _base = Uri.parse(baseUrl);

  final Uri _base;

  Uri _u(String path, [Map<String, String>? query]) {
    final uri = _base.resolve(path);
    return (query == null || query.isEmpty) ? uri : uri.replace(queryParameters: query);
  }

  /// GET /health -> {"ok": true}
  Future<GoHealthResponse> health() async {
    final res = await http.get(_u('/health'));
    if (res.statusCode != 200) {
      throw Exception('Health check failed (${res.statusCode}): ${res.body}');
    }

    final json = jsonDecode(res.body);
    if (json is Map<String, dynamic>) {
      return GoHealthResponse.fromJson(json);
    }

    throw Exception('Unexpected /health response: ${res.body}');
  }

  /// GET /services -> List<ServiceJson>
  Future<List<GoService>> listServices() async {
    final res = await http.get(_u('/services'));
    if (res.statusCode != 200) {
      throw Exception('List services failed (${res.statusCode}): ${res.body}');
    }

    final json = jsonDecode(res.body);
    if (json is List) {
      return json.whereType<Map<String, dynamic>>().map(GoService.fromJson).toList();
    }

    throw Exception('Unexpected /services response: ${res.body}');
  }

  /// POST /services/create-test
  Future<GoCreateServiceResponse?> createTestService() async {
    final res = await http.post(_u('/services/create-test'));
    if (res.statusCode >= 400) {
      throw Exception('Create test failed (${res.statusCode}): ${res.body}');
    }

    if (res.body.trim().isEmpty) return null;
    final json = jsonDecode(res.body);
    if (json is Map<String, dynamic>) {
      return GoCreateServiceResponse.fromJson(json);
    }
    return null;
  }

  /// POST /services/create?name=...&image=...&containerPort=...
  Future<GoCreateServiceResponse?> createService({
    required String name,
    required String image,
    int containerPort = 80,
  }) async {
    final res = await http.post(
      _u('/services/create', {'name': name, 'image': image, 'containerPort': containerPort.toString()}),
    );

    if (res.statusCode >= 400) {
      throw Exception('Create service failed (${res.statusCode}): ${res.body}');
    }

    if (res.body.trim().isEmpty) return null;
    final json = jsonDecode(res.body);
    if (json is Map<String, dynamic>) {
      return GoCreateServiceResponse.fromJson(json);
    }
    return null;
  }

  /// POST /services/start?id=...
  Future<void> startService(String id) async {
    final res = await http.post(_u('/services/start', {'id': id}));
    if (res.statusCode >= 400) {
      throw Exception('Start failed (${res.statusCode}): ${res.body}');
    }
  }

  /// POST /services/stop?id=...
  Future<void> stopService(String id) async {
    final res = await http.post(_u('/services/stop', {'id': id}));
    if (res.statusCode >= 400) {
      throw Exception('Stop failed (${res.statusCode}): ${res.body}');
    }
  }
}
