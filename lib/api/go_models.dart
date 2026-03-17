import 'package:freezed_annotation/freezed_annotation.dart';

part 'go_models.freezed.dart';
part 'go_models.g.dart';

/// Models that mirror the JSON returned by the local `sovereignd` Go daemon.
///
/// Notes:
/// - Keep these aligned with Go responses (snake/camel handled via @JsonKey)
/// - v0 focuses on the endpoints we already have: /health, /services, /services/create(-test)

@freezed
abstract class GoHealthResponse with _$GoHealthResponse {
  const GoHealthResponse._();

  const factory GoHealthResponse({required bool ok}) = _GoHealthResponse;

  factory GoHealthResponse.fromJson(Map<String, dynamic> json) => _$GoHealthResponseFromJson(json);
}

@freezed
abstract class GoService with _$GoService {
  const GoService._();

  const factory GoService({
    required String id,
    required String name,
    required String image,

    /// Docker state (e.g. "running", "exited")
    required String state,

    /// Docker status string (e.g. "Up 2 seconds")
    required String status,

    /// Host port published by sovereignd. 0 if none.
    required int port,

    /// Convenience URL for the same machine.
    @JsonKey(name: 'localUrl') required String localUrl,

    /// Convenience URL for other devices on LAN (may be empty depending on host).
    @JsonKey(name: 'lanUrl') required String lanUrl,

    /// Whether the service is currently exposed to the LAN.
    @JsonKey(name: 'lanEnabled') @Default(false) bool lanEnabled,
  }) = _GoService;

  factory GoService.fromJson(Map<String, dynamic> json) => _$GoServiceFromJson(json);
}

/// Response body from:
/// - POST /services/create-test
/// - POST /services/create
///
/// Go returns: { id, name, port, localUrl, lanUrl }
@freezed
abstract class GoCreateServiceResponse with _$GoCreateServiceResponse {
  const GoCreateServiceResponse._();

  const factory GoCreateServiceResponse({
    required String id,
    required String name,
    required int port,
    @JsonKey(name: 'localUrl') required String localUrl,
    @JsonKey(name: 'lanUrl') required String lanUrl,
  }) = _GoCreateServiceResponse;

  factory GoCreateServiceResponse.fromJson(Map<String, dynamic> json) => _$GoCreateServiceResponseFromJson(json);
}

/// Lightweight error envelope you can optionally standardize on later.
/// Not currently returned by the Go service, but handy for future compatibility.
@freezed
abstract class GoErrorResponse with _$GoErrorResponse {
  const GoErrorResponse._();

  const factory GoErrorResponse({required String message}) = _GoErrorResponse;

  factory GoErrorResponse.fromJson(Map<String, dynamic> json) => _$GoErrorResponseFromJson(json);
}

class GoActionResponse {
  const GoActionResponse({required this.id, required this.success});

  final String id;
  final bool success;

  factory GoActionResponse.fromJson(Map<String, dynamic> json) {
    return GoActionResponse(
      id: json['id'] as String? ?? '',
      success: json['success'] as bool? ?? false,
    );
  }
}

class GoLogsResponse {
  const GoLogsResponse({
    required this.id,
    required this.name,
    required this.logs,
    required this.tail,
    required this.stdout,
    required this.stderr,
  });

  final String id;
  final String name;
  final String logs;
  final String tail;
  final bool stdout;
  final bool stderr;

  factory GoLogsResponse.fromJson(Map<String, dynamic> json) {
    return GoLogsResponse(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      logs: json['logs'] as String? ?? '',
      tail: json['tail'] as String? ?? '',
      stdout: json['stdout'] as bool? ?? false,
      stderr: json['stderr'] as bool? ?? false,
    );
  }
}

class GoStatsResponse {
  const GoStatsResponse({
    required this.id,
    required this.name,
    required this.readAt,
    required this.raw,
  });

  final String id;
  final String name;
  final String readAt;
  final Map<String, dynamic> raw;

  factory GoStatsResponse.fromJson(Map<String, dynamic> json) {
    return GoStatsResponse(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      readAt: json['readAt'] as String? ?? '',
      raw: (json['raw'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }
}

class GoInspectResponse {
  const GoInspectResponse({
    required this.id,
    required this.name,
    required this.image,
    required this.state,
    required this.status,
    required this.created,
    required this.path,
    required this.args,
    required this.env,
    required this.labels,
    required this.ports,
    required this.mounts,
    required this.restartPolicy,
    required this.localUrl,
    required this.lanUrl,
    required this.lanEnabled,
  });

  final String id;
  final String name;
  final String image;
  final String state;
  final String status;
  final String created;
  final String path;
  final List<String> args;
  final List<String> env;
  final Map<String, String> labels;
  final List<GoInspectPort> ports;
  final List<GoInspectMount> mounts;
  final String restartPolicy;
  final String localUrl;
  final String lanUrl;
  final bool lanEnabled;

  factory GoInspectResponse.fromJson(Map<String, dynamic> json) {
    return GoInspectResponse(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      image: json['image'] as String? ?? '',
      state: json['state'] as String? ?? '',
      status: json['status'] as String? ?? '',
      created: json['created'] as String? ?? '',
      path: json['path'] as String? ?? '',
      args: (json['args'] as List?)?.cast<String>() ?? const [],
      env: (json['env'] as List?)?.cast<String>() ?? const [],
      labels: (json['labels'] as Map?)?.map(
            (key, value) => MapEntry(key.toString(), value.toString()),
          ) ??
          const {},
      ports: ((json['ports'] as List?) ?? const [])
          .whereType<Map>()
          .map((entry) => GoInspectPort.fromJson(entry.cast<String, dynamic>()))
          .toList(),
      mounts: ((json['mounts'] as List?) ?? const [])
          .whereType<Map>()
          .map((entry) => GoInspectMount.fromJson(entry.cast<String, dynamic>()))
          .toList(),
      restartPolicy: json['restartPolicy'] as String? ?? '',
      localUrl: json['localUrl'] as String? ?? '',
      lanUrl: json['lanUrl'] as String? ?? '',
      lanEnabled: json['lanEnabled'] as bool? ?? false,
    );
  }
}

class GoInspectPort {
  const GoInspectPort({
    required this.ip,
    required this.privatePort,
    required this.publicPort,
    required this.type,
    required this.containerRef,
  });

  final String ip;
  final int privatePort;
  final int publicPort;
  final String type;
  final String containerRef;

  factory GoInspectPort.fromJson(Map<String, dynamic> json) {
    return GoInspectPort(
      ip: json['ip'] as String? ?? '',
      privatePort: json['privatePort'] as int? ?? 0,
      publicPort: json['publicPort'] as int? ?? 0,
      type: json['type'] as String? ?? '',
      containerRef: json['containerRef'] as String? ?? '',
    );
  }
}

class GoInspectMount {
  const GoInspectMount({
    required this.type,
    required this.source,
    required this.destination,
    required this.readOnly,
  });

  final String type;
  final String source;
  final String destination;
  final bool readOnly;

  factory GoInspectMount.fromJson(Map<String, dynamic> json) {
    return GoInspectMount(
      type: json['type'] as String? ?? '',
      source: json['source'] as String? ?? '',
      destination: json['destination'] as String? ?? '',
      readOnly: json['readOnly'] as bool? ?? false,
    );
  }
}
