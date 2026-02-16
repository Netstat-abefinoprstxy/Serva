// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'go_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$GoHealthResponse {

 bool get ok;
/// Create a copy of GoHealthResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GoHealthResponseCopyWith<GoHealthResponse> get copyWith => _$GoHealthResponseCopyWithImpl<GoHealthResponse>(this as GoHealthResponse, _$identity);

  /// Serializes this GoHealthResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GoHealthResponse&&(identical(other.ok, ok) || other.ok == ok));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,ok);

@override
String toString() {
  return 'GoHealthResponse(ok: $ok)';
}


}

/// @nodoc
abstract mixin class $GoHealthResponseCopyWith<$Res>  {
  factory $GoHealthResponseCopyWith(GoHealthResponse value, $Res Function(GoHealthResponse) _then) = _$GoHealthResponseCopyWithImpl;
@useResult
$Res call({
 bool ok
});




}
/// @nodoc
class _$GoHealthResponseCopyWithImpl<$Res>
    implements $GoHealthResponseCopyWith<$Res> {
  _$GoHealthResponseCopyWithImpl(this._self, this._then);

  final GoHealthResponse _self;
  final $Res Function(GoHealthResponse) _then;

/// Create a copy of GoHealthResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? ok = null,}) {
  return _then(_self.copyWith(
ok: null == ok ? _self.ok : ok // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [GoHealthResponse].
extension GoHealthResponsePatterns on GoHealthResponse {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _GoHealthResponse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _GoHealthResponse() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _GoHealthResponse value)  $default,){
final _that = this;
switch (_that) {
case _GoHealthResponse():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _GoHealthResponse value)?  $default,){
final _that = this;
switch (_that) {
case _GoHealthResponse() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool ok)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _GoHealthResponse() when $default != null:
return $default(_that.ok);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool ok)  $default,) {final _that = this;
switch (_that) {
case _GoHealthResponse():
return $default(_that.ok);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool ok)?  $default,) {final _that = this;
switch (_that) {
case _GoHealthResponse() when $default != null:
return $default(_that.ok);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _GoHealthResponse extends GoHealthResponse {
  const _GoHealthResponse({required this.ok}): super._();
  factory _GoHealthResponse.fromJson(Map<String, dynamic> json) => _$GoHealthResponseFromJson(json);

@override final  bool ok;

/// Create a copy of GoHealthResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GoHealthResponseCopyWith<_GoHealthResponse> get copyWith => __$GoHealthResponseCopyWithImpl<_GoHealthResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$GoHealthResponseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _GoHealthResponse&&(identical(other.ok, ok) || other.ok == ok));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,ok);

@override
String toString() {
  return 'GoHealthResponse(ok: $ok)';
}


}

/// @nodoc
abstract mixin class _$GoHealthResponseCopyWith<$Res> implements $GoHealthResponseCopyWith<$Res> {
  factory _$GoHealthResponseCopyWith(_GoHealthResponse value, $Res Function(_GoHealthResponse) _then) = __$GoHealthResponseCopyWithImpl;
@override @useResult
$Res call({
 bool ok
});




}
/// @nodoc
class __$GoHealthResponseCopyWithImpl<$Res>
    implements _$GoHealthResponseCopyWith<$Res> {
  __$GoHealthResponseCopyWithImpl(this._self, this._then);

  final _GoHealthResponse _self;
  final $Res Function(_GoHealthResponse) _then;

/// Create a copy of GoHealthResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? ok = null,}) {
  return _then(_GoHealthResponse(
ok: null == ok ? _self.ok : ok // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$GoService {

 String get id; String get name; String get image;/// Docker state (e.g. "running", "exited")
 String get state;/// Docker status string (e.g. "Up 2 seconds")
 String get status;/// Host port published by sovereignd. 0 if none.
 int get port;/// Convenience URL for the same machine.
@JsonKey(name: 'localUrl') String get localUrl;/// Convenience URL for other devices on LAN (may be empty depending on host).
@JsonKey(name: 'lanUrl') String get lanUrl;/// Whether the service is currently exposed to the LAN.
@JsonKey(name: 'lanEnabled') bool get lanEnabled;
/// Create a copy of GoService
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GoServiceCopyWith<GoService> get copyWith => _$GoServiceCopyWithImpl<GoService>(this as GoService, _$identity);

  /// Serializes this GoService to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GoService&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.image, image) || other.image == image)&&(identical(other.state, state) || other.state == state)&&(identical(other.status, status) || other.status == status)&&(identical(other.port, port) || other.port == port)&&(identical(other.localUrl, localUrl) || other.localUrl == localUrl)&&(identical(other.lanUrl, lanUrl) || other.lanUrl == lanUrl)&&(identical(other.lanEnabled, lanEnabled) || other.lanEnabled == lanEnabled));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,image,state,status,port,localUrl,lanUrl,lanEnabled);

@override
String toString() {
  return 'GoService(id: $id, name: $name, image: $image, state: $state, status: $status, port: $port, localUrl: $localUrl, lanUrl: $lanUrl, lanEnabled: $lanEnabled)';
}


}

/// @nodoc
abstract mixin class $GoServiceCopyWith<$Res>  {
  factory $GoServiceCopyWith(GoService value, $Res Function(GoService) _then) = _$GoServiceCopyWithImpl;
@useResult
$Res call({
 String id, String name, String image, String state, String status, int port,@JsonKey(name: 'localUrl') String localUrl,@JsonKey(name: 'lanUrl') String lanUrl,@JsonKey(name: 'lanEnabled') bool lanEnabled
});




}
/// @nodoc
class _$GoServiceCopyWithImpl<$Res>
    implements $GoServiceCopyWith<$Res> {
  _$GoServiceCopyWithImpl(this._self, this._then);

  final GoService _self;
  final $Res Function(GoService) _then;

/// Create a copy of GoService
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? image = null,Object? state = null,Object? status = null,Object? port = null,Object? localUrl = null,Object? lanUrl = null,Object? lanEnabled = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,image: null == image ? _self.image : image // ignore: cast_nullable_to_non_nullable
as String,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,port: null == port ? _self.port : port // ignore: cast_nullable_to_non_nullable
as int,localUrl: null == localUrl ? _self.localUrl : localUrl // ignore: cast_nullable_to_non_nullable
as String,lanUrl: null == lanUrl ? _self.lanUrl : lanUrl // ignore: cast_nullable_to_non_nullable
as String,lanEnabled: null == lanEnabled ? _self.lanEnabled : lanEnabled // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [GoService].
extension GoServicePatterns on GoService {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _GoService value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _GoService() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _GoService value)  $default,){
final _that = this;
switch (_that) {
case _GoService():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _GoService value)?  $default,){
final _that = this;
switch (_that) {
case _GoService() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String image,  String state,  String status,  int port, @JsonKey(name: 'localUrl')  String localUrl, @JsonKey(name: 'lanUrl')  String lanUrl, @JsonKey(name: 'lanEnabled')  bool lanEnabled)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _GoService() when $default != null:
return $default(_that.id,_that.name,_that.image,_that.state,_that.status,_that.port,_that.localUrl,_that.lanUrl,_that.lanEnabled);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String image,  String state,  String status,  int port, @JsonKey(name: 'localUrl')  String localUrl, @JsonKey(name: 'lanUrl')  String lanUrl, @JsonKey(name: 'lanEnabled')  bool lanEnabled)  $default,) {final _that = this;
switch (_that) {
case _GoService():
return $default(_that.id,_that.name,_that.image,_that.state,_that.status,_that.port,_that.localUrl,_that.lanUrl,_that.lanEnabled);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String image,  String state,  String status,  int port, @JsonKey(name: 'localUrl')  String localUrl, @JsonKey(name: 'lanUrl')  String lanUrl, @JsonKey(name: 'lanEnabled')  bool lanEnabled)?  $default,) {final _that = this;
switch (_that) {
case _GoService() when $default != null:
return $default(_that.id,_that.name,_that.image,_that.state,_that.status,_that.port,_that.localUrl,_that.lanUrl,_that.lanEnabled);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _GoService extends GoService {
  const _GoService({required this.id, required this.name, required this.image, required this.state, required this.status, required this.port, @JsonKey(name: 'localUrl') required this.localUrl, @JsonKey(name: 'lanUrl') required this.lanUrl, @JsonKey(name: 'lanEnabled') this.lanEnabled = false}): super._();
  factory _GoService.fromJson(Map<String, dynamic> json) => _$GoServiceFromJson(json);

@override final  String id;
@override final  String name;
@override final  String image;
/// Docker state (e.g. "running", "exited")
@override final  String state;
/// Docker status string (e.g. "Up 2 seconds")
@override final  String status;
/// Host port published by sovereignd. 0 if none.
@override final  int port;
/// Convenience URL for the same machine.
@override@JsonKey(name: 'localUrl') final  String localUrl;
/// Convenience URL for other devices on LAN (may be empty depending on host).
@override@JsonKey(name: 'lanUrl') final  String lanUrl;
/// Whether the service is currently exposed to the LAN.
@override@JsonKey(name: 'lanEnabled') final  bool lanEnabled;

/// Create a copy of GoService
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GoServiceCopyWith<_GoService> get copyWith => __$GoServiceCopyWithImpl<_GoService>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$GoServiceToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _GoService&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.image, image) || other.image == image)&&(identical(other.state, state) || other.state == state)&&(identical(other.status, status) || other.status == status)&&(identical(other.port, port) || other.port == port)&&(identical(other.localUrl, localUrl) || other.localUrl == localUrl)&&(identical(other.lanUrl, lanUrl) || other.lanUrl == lanUrl)&&(identical(other.lanEnabled, lanEnabled) || other.lanEnabled == lanEnabled));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,image,state,status,port,localUrl,lanUrl,lanEnabled);

@override
String toString() {
  return 'GoService(id: $id, name: $name, image: $image, state: $state, status: $status, port: $port, localUrl: $localUrl, lanUrl: $lanUrl, lanEnabled: $lanEnabled)';
}


}

/// @nodoc
abstract mixin class _$GoServiceCopyWith<$Res> implements $GoServiceCopyWith<$Res> {
  factory _$GoServiceCopyWith(_GoService value, $Res Function(_GoService) _then) = __$GoServiceCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String image, String state, String status, int port,@JsonKey(name: 'localUrl') String localUrl,@JsonKey(name: 'lanUrl') String lanUrl,@JsonKey(name: 'lanEnabled') bool lanEnabled
});




}
/// @nodoc
class __$GoServiceCopyWithImpl<$Res>
    implements _$GoServiceCopyWith<$Res> {
  __$GoServiceCopyWithImpl(this._self, this._then);

  final _GoService _self;
  final $Res Function(_GoService) _then;

/// Create a copy of GoService
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? image = null,Object? state = null,Object? status = null,Object? port = null,Object? localUrl = null,Object? lanUrl = null,Object? lanEnabled = null,}) {
  return _then(_GoService(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,image: null == image ? _self.image : image // ignore: cast_nullable_to_non_nullable
as String,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,port: null == port ? _self.port : port // ignore: cast_nullable_to_non_nullable
as int,localUrl: null == localUrl ? _self.localUrl : localUrl // ignore: cast_nullable_to_non_nullable
as String,lanUrl: null == lanUrl ? _self.lanUrl : lanUrl // ignore: cast_nullable_to_non_nullable
as String,lanEnabled: null == lanEnabled ? _self.lanEnabled : lanEnabled // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$GoCreateServiceResponse {

 String get id; String get name; int get port;@JsonKey(name: 'localUrl') String get localUrl;@JsonKey(name: 'lanUrl') String get lanUrl;
/// Create a copy of GoCreateServiceResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GoCreateServiceResponseCopyWith<GoCreateServiceResponse> get copyWith => _$GoCreateServiceResponseCopyWithImpl<GoCreateServiceResponse>(this as GoCreateServiceResponse, _$identity);

  /// Serializes this GoCreateServiceResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GoCreateServiceResponse&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.port, port) || other.port == port)&&(identical(other.localUrl, localUrl) || other.localUrl == localUrl)&&(identical(other.lanUrl, lanUrl) || other.lanUrl == lanUrl));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,port,localUrl,lanUrl);

@override
String toString() {
  return 'GoCreateServiceResponse(id: $id, name: $name, port: $port, localUrl: $localUrl, lanUrl: $lanUrl)';
}


}

/// @nodoc
abstract mixin class $GoCreateServiceResponseCopyWith<$Res>  {
  factory $GoCreateServiceResponseCopyWith(GoCreateServiceResponse value, $Res Function(GoCreateServiceResponse) _then) = _$GoCreateServiceResponseCopyWithImpl;
@useResult
$Res call({
 String id, String name, int port,@JsonKey(name: 'localUrl') String localUrl,@JsonKey(name: 'lanUrl') String lanUrl
});




}
/// @nodoc
class _$GoCreateServiceResponseCopyWithImpl<$Res>
    implements $GoCreateServiceResponseCopyWith<$Res> {
  _$GoCreateServiceResponseCopyWithImpl(this._self, this._then);

  final GoCreateServiceResponse _self;
  final $Res Function(GoCreateServiceResponse) _then;

/// Create a copy of GoCreateServiceResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? port = null,Object? localUrl = null,Object? lanUrl = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,port: null == port ? _self.port : port // ignore: cast_nullable_to_non_nullable
as int,localUrl: null == localUrl ? _self.localUrl : localUrl // ignore: cast_nullable_to_non_nullable
as String,lanUrl: null == lanUrl ? _self.lanUrl : lanUrl // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [GoCreateServiceResponse].
extension GoCreateServiceResponsePatterns on GoCreateServiceResponse {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _GoCreateServiceResponse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _GoCreateServiceResponse() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _GoCreateServiceResponse value)  $default,){
final _that = this;
switch (_that) {
case _GoCreateServiceResponse():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _GoCreateServiceResponse value)?  $default,){
final _that = this;
switch (_that) {
case _GoCreateServiceResponse() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  int port, @JsonKey(name: 'localUrl')  String localUrl, @JsonKey(name: 'lanUrl')  String lanUrl)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _GoCreateServiceResponse() when $default != null:
return $default(_that.id,_that.name,_that.port,_that.localUrl,_that.lanUrl);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  int port, @JsonKey(name: 'localUrl')  String localUrl, @JsonKey(name: 'lanUrl')  String lanUrl)  $default,) {final _that = this;
switch (_that) {
case _GoCreateServiceResponse():
return $default(_that.id,_that.name,_that.port,_that.localUrl,_that.lanUrl);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  int port, @JsonKey(name: 'localUrl')  String localUrl, @JsonKey(name: 'lanUrl')  String lanUrl)?  $default,) {final _that = this;
switch (_that) {
case _GoCreateServiceResponse() when $default != null:
return $default(_that.id,_that.name,_that.port,_that.localUrl,_that.lanUrl);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _GoCreateServiceResponse extends GoCreateServiceResponse {
  const _GoCreateServiceResponse({required this.id, required this.name, required this.port, @JsonKey(name: 'localUrl') required this.localUrl, @JsonKey(name: 'lanUrl') required this.lanUrl}): super._();
  factory _GoCreateServiceResponse.fromJson(Map<String, dynamic> json) => _$GoCreateServiceResponseFromJson(json);

@override final  String id;
@override final  String name;
@override final  int port;
@override@JsonKey(name: 'localUrl') final  String localUrl;
@override@JsonKey(name: 'lanUrl') final  String lanUrl;

/// Create a copy of GoCreateServiceResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GoCreateServiceResponseCopyWith<_GoCreateServiceResponse> get copyWith => __$GoCreateServiceResponseCopyWithImpl<_GoCreateServiceResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$GoCreateServiceResponseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _GoCreateServiceResponse&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.port, port) || other.port == port)&&(identical(other.localUrl, localUrl) || other.localUrl == localUrl)&&(identical(other.lanUrl, lanUrl) || other.lanUrl == lanUrl));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,port,localUrl,lanUrl);

@override
String toString() {
  return 'GoCreateServiceResponse(id: $id, name: $name, port: $port, localUrl: $localUrl, lanUrl: $lanUrl)';
}


}

/// @nodoc
abstract mixin class _$GoCreateServiceResponseCopyWith<$Res> implements $GoCreateServiceResponseCopyWith<$Res> {
  factory _$GoCreateServiceResponseCopyWith(_GoCreateServiceResponse value, $Res Function(_GoCreateServiceResponse) _then) = __$GoCreateServiceResponseCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, int port,@JsonKey(name: 'localUrl') String localUrl,@JsonKey(name: 'lanUrl') String lanUrl
});




}
/// @nodoc
class __$GoCreateServiceResponseCopyWithImpl<$Res>
    implements _$GoCreateServiceResponseCopyWith<$Res> {
  __$GoCreateServiceResponseCopyWithImpl(this._self, this._then);

  final _GoCreateServiceResponse _self;
  final $Res Function(_GoCreateServiceResponse) _then;

/// Create a copy of GoCreateServiceResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? port = null,Object? localUrl = null,Object? lanUrl = null,}) {
  return _then(_GoCreateServiceResponse(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,port: null == port ? _self.port : port // ignore: cast_nullable_to_non_nullable
as int,localUrl: null == localUrl ? _self.localUrl : localUrl // ignore: cast_nullable_to_non_nullable
as String,lanUrl: null == lanUrl ? _self.lanUrl : lanUrl // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$GoErrorResponse {

 String get message;
/// Create a copy of GoErrorResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GoErrorResponseCopyWith<GoErrorResponse> get copyWith => _$GoErrorResponseCopyWithImpl<GoErrorResponse>(this as GoErrorResponse, _$identity);

  /// Serializes this GoErrorResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GoErrorResponse&&(identical(other.message, message) || other.message == message));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,message);

@override
String toString() {
  return 'GoErrorResponse(message: $message)';
}


}

/// @nodoc
abstract mixin class $GoErrorResponseCopyWith<$Res>  {
  factory $GoErrorResponseCopyWith(GoErrorResponse value, $Res Function(GoErrorResponse) _then) = _$GoErrorResponseCopyWithImpl;
@useResult
$Res call({
 String message
});




}
/// @nodoc
class _$GoErrorResponseCopyWithImpl<$Res>
    implements $GoErrorResponseCopyWith<$Res> {
  _$GoErrorResponseCopyWithImpl(this._self, this._then);

  final GoErrorResponse _self;
  final $Res Function(GoErrorResponse) _then;

/// Create a copy of GoErrorResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? message = null,}) {
  return _then(_self.copyWith(
message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [GoErrorResponse].
extension GoErrorResponsePatterns on GoErrorResponse {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _GoErrorResponse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _GoErrorResponse() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _GoErrorResponse value)  $default,){
final _that = this;
switch (_that) {
case _GoErrorResponse():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _GoErrorResponse value)?  $default,){
final _that = this;
switch (_that) {
case _GoErrorResponse() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String message)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _GoErrorResponse() when $default != null:
return $default(_that.message);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String message)  $default,) {final _that = this;
switch (_that) {
case _GoErrorResponse():
return $default(_that.message);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String message)?  $default,) {final _that = this;
switch (_that) {
case _GoErrorResponse() when $default != null:
return $default(_that.message);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _GoErrorResponse extends GoErrorResponse {
  const _GoErrorResponse({required this.message}): super._();
  factory _GoErrorResponse.fromJson(Map<String, dynamic> json) => _$GoErrorResponseFromJson(json);

@override final  String message;

/// Create a copy of GoErrorResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GoErrorResponseCopyWith<_GoErrorResponse> get copyWith => __$GoErrorResponseCopyWithImpl<_GoErrorResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$GoErrorResponseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _GoErrorResponse&&(identical(other.message, message) || other.message == message));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,message);

@override
String toString() {
  return 'GoErrorResponse(message: $message)';
}


}

/// @nodoc
abstract mixin class _$GoErrorResponseCopyWith<$Res> implements $GoErrorResponseCopyWith<$Res> {
  factory _$GoErrorResponseCopyWith(_GoErrorResponse value, $Res Function(_GoErrorResponse) _then) = __$GoErrorResponseCopyWithImpl;
@override @useResult
$Res call({
 String message
});




}
/// @nodoc
class __$GoErrorResponseCopyWithImpl<$Res>
    implements _$GoErrorResponseCopyWith<$Res> {
  __$GoErrorResponseCopyWithImpl(this._self, this._then);

  final _GoErrorResponse _self;
  final $Res Function(_GoErrorResponse) _then;

/// Create a copy of GoErrorResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? message = null,}) {
  return _then(_GoErrorResponse(
message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
