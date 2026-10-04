// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'agenda_list_cubit.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$AgendaListState {

 List<VisitaAgenda> get visitas; bool get cargando; String? get error;
/// Create a copy of AgendaListState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AgendaListStateCopyWith<AgendaListState> get copyWith => _$AgendaListStateCopyWithImpl<AgendaListState>(this as AgendaListState, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as AgendaListState;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AgendaListState&&const DeepCollectionEquality().equals(other.visitas, _this.visitas)&&(identical(other.cargando, _this.cargando) || other.cargando == _this.cargando)&&(identical(other.error, _this.error) || other.error == _this.error));
}


@override
int get hashCode {
  final _this = this as AgendaListState;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.visitas),_this.cargando,_this.error);
}

@override
String toString() {
  final _this = this as AgendaListState;
  return 'AgendaListState(visitas: ${_this.visitas}, cargando: ${_this.cargando}, error: ${_this.error})';
}


}

/// @nodoc
abstract mixin class $AgendaListStateCopyWith<$Res>  {
  factory $AgendaListStateCopyWith(AgendaListState value, $Res Function(AgendaListState) _then) = _$AgendaListStateCopyWithImpl;
@useResult
$Res call({
 List<VisitaAgenda> visitas, bool cargando, String? error
});




}
/// @nodoc
class _$AgendaListStateCopyWithImpl<$Res>
    implements $AgendaListStateCopyWith<$Res> {
  _$AgendaListStateCopyWithImpl(this._self, this._then);

  final AgendaListState _self;
  final $Res Function(AgendaListState) _then;

/// Create a copy of AgendaListState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? visitas = null,Object? cargando = null,Object? error = freezed,}) {
  return _then(AgendaListState(
visitas: null == visitas ? _self.visitas : visitas // ignore: cast_nullable_to_non_nullable
as List<VisitaAgenda>,cargando: null == cargando ? _self.cargando : cargando // ignore: cast_nullable_to_non_nullable
as bool,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [AgendaListState].
extension AgendaListStatePatterns on AgendaListState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AgendaListState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AgendaListState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AgendaListState value)  $default,){
final _that = this;
switch (_that) {
case _AgendaListState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AgendaListState value)?  $default,){
final _that = this;
switch (_that) {
case _AgendaListState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<VisitaAgenda> visitas,  bool cargando,  String? error)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AgendaListState() when $default != null:
return $default(_that.visitas,_that.cargando,_that.error);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<VisitaAgenda> visitas,  bool cargando,  String? error)  $default,) {final _that = this;
switch (_that) {
case _AgendaListState():
return $default(_that.visitas,_that.cargando,_that.error);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<VisitaAgenda> visitas,  bool cargando,  String? error)?  $default,) {final _that = this;
switch (_that) {
case _AgendaListState() when $default != null:
return $default(_that.visitas,_that.cargando,_that.error);case _:
  return null;

}
}

}

/// @nodoc


class _AgendaListState implements AgendaListState {
  const _AgendaListState({ List<VisitaAgenda> visitas = const <VisitaAgenda>[], this.cargando = false, this.error}): _visitas = visitas;
  

 final  List<VisitaAgenda> _visitas;
@override@JsonKey() List<VisitaAgenda> get visitas {
  if (_visitas is EqualUnmodifiableListView) return _visitas;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_visitas);
}

@override@JsonKey() final  bool cargando;
@override final  String? error;

/// Create a copy of AgendaListState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AgendaListStateCopyWith<_AgendaListState> get copyWith => __$AgendaListStateCopyWithImpl<_AgendaListState>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _AgendaListState&&const DeepCollectionEquality().equals(other.visitas, _visitas)&&(identical(other.cargando, cargando) || other.cargando == cargando)&&(identical(other.error, error) || other.error == error));
}


@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_visitas),cargando,error);
}

@override
String toString() {
    return 'AgendaListState(visitas: $visitas, cargando: $cargando, error: $error)';
}


}

/// @nodoc
abstract mixin class _$AgendaListStateCopyWith<$Res> implements $AgendaListStateCopyWith<$Res> {
  factory _$AgendaListStateCopyWith(_AgendaListState value, $Res Function(_AgendaListState) _then) = __$AgendaListStateCopyWithImpl;
@override @useResult
$Res call({
 List<VisitaAgenda> visitas, bool cargando, String? error
});




}
/// @nodoc
class __$AgendaListStateCopyWithImpl<$Res>
    implements _$AgendaListStateCopyWith<$Res> {
  __$AgendaListStateCopyWithImpl(this._self, this._then);

  final _AgendaListState _self;
  final $Res Function(_AgendaListState) _then;

/// Create a copy of AgendaListState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? visitas = null,Object? cargando = null,Object? error = freezed,}) {
  return _then(_AgendaListState(
visitas: null == visitas ? _self._visitas : visitas // ignore: cast_nullable_to_non_nullable
as List<VisitaAgenda>,cargando: null == cargando ? _self.cargando : cargando // ignore: cast_nullable_to_non_nullable
as bool,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
