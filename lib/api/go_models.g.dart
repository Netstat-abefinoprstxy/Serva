// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'go_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_GoHealthResponse _$GoHealthResponseFromJson(Map<String, dynamic> json) =>
    _GoHealthResponse(ok: json['ok'] as bool);

Map<String, dynamic> _$GoHealthResponseToJson(_GoHealthResponse instance) =>
    <String, dynamic>{'ok': instance.ok};

_GoService _$GoServiceFromJson(Map<String, dynamic> json) => _GoService(
  id: json['id'] as String,
  name: json['name'] as String,
  image: json['image'] as String,
  state: json['state'] as String,
  status: json['status'] as String,
  port: (json['port'] as num).toInt(),
  localUrl: json['localUrl'] as String,
  lanUrl: json['lanUrl'] as String,
  lanEnabled: json['lanEnabled'] as bool? ?? false,
);

Map<String, dynamic> _$GoServiceToJson(_GoService instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'image': instance.image,
      'state': instance.state,
      'status': instance.status,
      'port': instance.port,
      'localUrl': instance.localUrl,
      'lanUrl': instance.lanUrl,
      'lanEnabled': instance.lanEnabled,
    };

_GoCreateServiceResponse _$GoCreateServiceResponseFromJson(
  Map<String, dynamic> json,
) => _GoCreateServiceResponse(
  id: json['id'] as String,
  name: json['name'] as String,
  port: (json['port'] as num).toInt(),
  localUrl: json['localUrl'] as String,
  lanUrl: json['lanUrl'] as String,
);

Map<String, dynamic> _$GoCreateServiceResponseToJson(
  _GoCreateServiceResponse instance,
) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'port': instance.port,
  'localUrl': instance.localUrl,
  'lanUrl': instance.lanUrl,
};

_GoErrorResponse _$GoErrorResponseFromJson(Map<String, dynamic> json) =>
    _GoErrorResponse(message: json['message'] as String);

Map<String, dynamic> _$GoErrorResponseToJson(_GoErrorResponse instance) =>
    <String, dynamic>{'message': instance.message};
