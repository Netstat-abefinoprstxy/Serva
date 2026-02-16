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
