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

  Future<GoActionResponse> restartService(String id) async {
    final res = await http.post(_u('/services/restart', {'id': id}));
    if (res.statusCode >= 400) {
      throw Exception('Restart failed (${res.statusCode}): ${res.body}');
    }

    final json = jsonDecode(res.body);
    if (json is Map<String, dynamic>) {
      return GoActionResponse.fromJson(json);
    }

    throw Exception('Unexpected /services/restart response: ${res.body}');
  }

  Future<GoActionResponse> removeService(String id) async {
    final res = await http.delete(_u('/services/remove', {'id': id}));
    if (res.statusCode >= 400) {
      throw Exception('Remove failed (${res.statusCode}): ${res.body}');
    }

    final json = jsonDecode(res.body);
    if (json is Map<String, dynamic>) {
      return GoActionResponse.fromJson(json);
    }

    throw Exception('Unexpected /services/remove response: ${res.body}');
  }

  Future<GoLogsResponse> serviceLogs(String id, {String tail = '200', bool stdout = true, bool stderr = true}) async {
    final res = await http.get(
      _u('/services/logs', {
        'id': id,
        'tail': tail,
        'stdout': stdout ? '1' : '0',
        'stderr': stderr ? '1' : '0',
      }),
    );
    if (res.statusCode >= 400) {
      throw Exception('Logs failed (${res.statusCode}): ${res.body}');
    }

    final json = jsonDecode(res.body);
    if (json is Map<String, dynamic>) {
      return GoLogsResponse.fromJson(json);
    }

    throw Exception('Unexpected /services/logs response: ${res.body}');
  }

  Future<GoStatsResponse> serviceStats(String id) async {
    final res = await http.get(_u('/services/stats', {'id': id}));
    if (res.statusCode >= 400) {
      throw Exception('Stats failed (${res.statusCode}): ${res.body}');
    }

    final json = jsonDecode(res.body);
    if (json is Map<String, dynamic>) {
      return GoStatsResponse.fromJson(json);
    }

    throw Exception('Unexpected /services/stats response: ${res.body}');
  }

  Future<GoInspectResponse> serviceInspect(String id) async {
    final res = await http.get(_u('/services/inspect', {'id': id}));
    if (res.statusCode >= 400) {
      throw Exception('Inspect failed (${res.statusCode}): ${res.body}');
    }

    final json = jsonDecode(res.body);
    if (json is Map<String, dynamic>) {
      return GoInspectResponse.fromJson(json);
    }

    throw Exception('Unexpected /services/inspect response: ${res.body}');
  }

  /// POST /services/expose-lan?id=...
  /// Makes the service accessible on the local network (LAN).
  Future<void> exposeServiceLan(String id, {bool enabled = true}) async {
    final res = await http.post(_u('/services/expose-lan', {'id': id, 'enabled': enabled ? '1' : '0'}));

    if (res.statusCode >= 400) {
      throw Exception('Expose LAN failed (${res.statusCode}): ${res.body}');
    }
  }
}
