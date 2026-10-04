// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'agenda_form_cubit.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$AgendaFormState {

 VisitaAgenda get visita; List<OpcionMaestra> get campanas; List<OpcionMaestra> get tiposVisita;
/// Create a copy of AgendaFormState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AgendaFormStateCopyWith<AgendaFormState> get copyWith => _$AgendaFormStateCopyWithImpl<AgendaFormState>(this as AgendaFormState, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as AgendaFormState;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AgendaFormState&&(identical(other.visita, _this.visita) || other.visita == _this.visita)&&const DeepCollectionEquality().equals(other.campanas, _this.campanas)&&const DeepCollectionEquality().equals(other.tiposVisita, _this.tiposVisita));
}


@override
int get hashCode {
  final _this = this as AgendaFormState;
  return Object.hash(runtimeType,_this.visita,const DeepCollectionEquality().hash(_this.campanas),const DeepCollectionEquality().hash(_this.tiposVisita));
}

@override
String toString() {
  final _this = this as AgendaFormState;
  return 'AgendaFormState(visita: ${_this.visita}, campanas: ${_this.campanas}, tiposVisita: ${_this.tiposVisita})';
}


}

/// @nodoc
abstract mixin class $AgendaFormStateCopyWith<$Res>  {
  factory $AgendaFormStateCopyWith(AgendaFormState value, $Res Function(AgendaFormState) _then) = _$AgendaFormStateCopyWithImpl;
@useResult
$Res call({
 VisitaAgenda visita, List<OpcionMaestra> campanas, List<OpcionMaestra> tiposVisita
});


$VisitaAgendaCopyWith<$Res> get visita;

}
/// @nodoc
class _$AgendaFormStateCopyWithImpl<$Res>
    implements $AgendaFormStateCopyWith<$Res> {
  _$AgendaFormStateCopyWithImpl(this._self, this._then);

  final AgendaFormState _self;
  final $Res Function(AgendaFormState) _then;

/// Create a copy of AgendaFormState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? visita = null,Object? campanas = null,Object? tiposVisita = null,}) {
  return _then(AgendaFormState(
visita: null == visita ? _self.visita : visita // ignore: cast_nullable_to_non_nullable
as VisitaAgenda,campanas: null == campanas ? _self.campanas : campanas // ignore: cast_nullable_to_non_nullable
as List<OpcionMaestra>,tiposVisita: null == tiposVisita ? _self.tiposVisita : tiposVisita // ignore: cast_nullable_to_non_nullable
as List<OpcionMaestra>,
  ));
}
/// Create a copy of AgendaFormState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$VisitaAgendaCopyWith<$Res> get visita {
  
  return $VisitaAgendaCopyWith<$Res>(_self.visita, (value) {
    return _then(_self.copyWith(visita: value));
  });
}
}


/// Adds pattern-matching-related methods to [AgendaFormState].
extension AgendaFormStatePatterns on AgendaFormState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AgendaFormState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AgendaFormState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AgendaFormState value)  $default,){
final _that = this;
switch (_that) {
case _AgendaFormState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AgendaFormState value)?  $default,){
final _that = this;
switch (_that) {
case _AgendaFormState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( VisitaAgenda visita,  List<OpcionMaestra> campanas,  List<OpcionMaestra> tiposVisita)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AgendaFormState() when $default != null:
return $default(_that.visita,_that.campanas,_that.tiposVisita);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( VisitaAgenda visita,  List<OpcionMaestra> campanas,  List<OpcionMaestra> tiposVisita)  $default,) {final _that = this;
switch (_that) {
case _AgendaFormState():
return $default(_that.visita,_that.campanas,_that.tiposVisita);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( VisitaAgenda visita,  List<OpcionMaestra> campanas,  List<OpcionMaestra> tiposVisita)?  $default,) {final _that = this;
switch (_that) {
case _AgendaFormState() when $default != null:
return $default(_that.visita,_that.campanas,_that.tiposVisita);case _:
  return null;

}
}

}

/// @nodoc


class _AgendaFormState implements AgendaFormState {
  const _AgendaFormState({required this.visita,  List<OpcionMaestra> campanas = const <OpcionMaestra>[],  List<OpcionMaestra> tiposVisita = const <OpcionMaestra>[]}): _campanas = campanas,_tiposVisita = tiposVisita;
  

@override final  VisitaAgenda visita;
 final  List<OpcionMaestra> _campanas;
@override@JsonKey() List<OpcionMaestra> get campanas {
  if (_campanas is EqualUnmodifiableListView) return _campanas;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_campanas);
}

 final  List<OpcionMaestra> _tiposVisita;
@override@JsonKey() List<OpcionMaestra> get tiposVisita {
  if (_tiposVisita is EqualUnmodifiableListView) return _tiposVisita;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_tiposVisita);
}


/// Create a copy of AgendaFormState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AgendaFormStateCopyWith<_AgendaFormState> get copyWith => __$AgendaFormStateCopyWithImpl<_AgendaFormState>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _AgendaFormState&&(identical(other.visita, visita) || other.visita == visita)&&const DeepCollectionEquality().equals(other.campanas, _campanas)&&const DeepCollectionEquality().equals(other.tiposVisita, _tiposVisita));
}


@override
int get hashCode {
    return Object.hash(runtimeType,visita,const DeepCollectionEquality().hash(_campanas),const DeepCollectionEquality().hash(_tiposVisita));
}

@override
String toString() {
    return 'AgendaFormState(visita: $visita, campanas: $campanas, tiposVisita: $tiposVisita)';
}


}

/// @nodoc
abstract mixin class _$AgendaFormStateCopyWith<$Res> implements $AgendaFormStateCopyWith<$Res> {
  factory _$AgendaFormStateCopyWith(_AgendaFormState value, $Res Function(_AgendaFormState) _then) = __$AgendaFormStateCopyWithImpl;
@override @useResult
$Res call({
 VisitaAgenda visita, List<OpcionMaestra> campanas, List<OpcionMaestra> tiposVisita
});


@override $VisitaAgendaCopyWith<$Res> get visita;

}
/// @nodoc
class __$AgendaFormStateCopyWithImpl<$Res>
    implements _$AgendaFormStateCopyWith<$Res> {
  __$AgendaFormStateCopyWithImpl(this._self, this._then);

  final _AgendaFormState _self;
  final $Res Function(_AgendaFormState) _then;

/// Create a copy of AgendaFormState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? visita = null,Object? campanas = null,Object? tiposVisita = null,}) {
  return _then(_AgendaFormState(
visita: null == visita ? _self.visita : visita // ignore: cast_nullable_to_non_nullable
as VisitaAgenda,campanas: null == campanas ? _self._campanas : campanas // ignore: cast_nullable_to_non_nullable
as List<OpcionMaestra>,tiposVisita: null == tiposVisita ? _self._tiposVisita : tiposVisita // ignore: cast_nullable_to_non_nullable
as List<OpcionMaestra>,
  ));
}

/// Create a copy of AgendaFormState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$VisitaAgendaCopyWith<$Res> get visita {
  
  return $VisitaAgendaCopyWith<$Res>(_self.visita, (value) {
    return _then(_self.copyWith(visita: value));
  });
}
}

// dart format on
