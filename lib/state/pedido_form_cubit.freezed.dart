// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'pedido_form_cubit.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$PedidoFormState {

 Pedido get pedido; List<OpcionMaestra> get direccionesCliente; bool get cargandoDetalle; bool get cargandoDatosCliente;
/// Create a copy of PedidoFormState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PedidoFormStateCopyWith<PedidoFormState> get copyWith => _$PedidoFormStateCopyWithImpl<PedidoFormState>(this as PedidoFormState, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as PedidoFormState;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PedidoFormState&&(identical(other.pedido, _this.pedido) || other.pedido == _this.pedido)&&const DeepCollectionEquality().equals(other.direccionesCliente, _this.direccionesCliente)&&(identical(other.cargandoDetalle, _this.cargandoDetalle) || other.cargandoDetalle == _this.cargandoDetalle)&&(identical(other.cargandoDatosCliente, _this.cargandoDatosCliente) || other.cargandoDatosCliente == _this.cargandoDatosCliente));
}


@override
int get hashCode {
  final _this = this as PedidoFormState;
  return Object.hash(runtimeType,_this.pedido,const DeepCollectionEquality().hash(_this.direccionesCliente),_this.cargandoDetalle,_this.cargandoDatosCliente);
}

@override
String toString() {
  final _this = this as PedidoFormState;
  return 'PedidoFormState(pedido: ${_this.pedido}, direccionesCliente: ${_this.direccionesCliente}, cargandoDetalle: ${_this.cargandoDetalle}, cargandoDatosCliente: ${_this.cargandoDatosCliente})';
}


}

/// @nodoc
abstract mixin class $PedidoFormStateCopyWith<$Res>  {
  factory $PedidoFormStateCopyWith(PedidoFormState value, $Res Function(PedidoFormState) _then) = _$PedidoFormStateCopyWithImpl;
@useResult
$Res call({
 Pedido pedido, List<OpcionMaestra> direccionesCliente, bool cargandoDetalle, bool cargandoDatosCliente
});


$PedidoCopyWith<$Res> get pedido;

}
/// @nodoc
class _$PedidoFormStateCopyWithImpl<$Res>
    implements $PedidoFormStateCopyWith<$Res> {
  _$PedidoFormStateCopyWithImpl(this._self, this._then);

  final PedidoFormState _self;
  final $Res Function(PedidoFormState) _then;

/// Create a copy of PedidoFormState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? pedido = null,Object? direccionesCliente = null,Object? cargandoDetalle = null,Object? cargandoDatosCliente = null,}) {
  return _then(PedidoFormState(
pedido: null == pedido ? _self.pedido : pedido // ignore: cast_nullable_to_non_nullable
as Pedido,direccionesCliente: null == direccionesCliente ? _self.direccionesCliente : direccionesCliente // ignore: cast_nullable_to_non_nullable
as List<OpcionMaestra>,cargandoDetalle: null == cargandoDetalle ? _self.cargandoDetalle : cargandoDetalle // ignore: cast_nullable_to_non_nullable
as bool,cargandoDatosCliente: null == cargandoDatosCliente ? _self.cargandoDatosCliente : cargandoDatosCliente // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}
/// Create a copy of PedidoFormState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PedidoCopyWith<$Res> get pedido {
  
  return $PedidoCopyWith<$Res>(_self.pedido, (value) {
    return _then(_self.copyWith(pedido: value));
  });
}
}


/// Adds pattern-matching-related methods to [PedidoFormState].
extension PedidoFormStatePatterns on PedidoFormState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PedidoFormState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PedidoFormState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PedidoFormState value)  $default,){
final _that = this;
switch (_that) {
case _PedidoFormState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PedidoFormState value)?  $default,){
final _that = this;
switch (_that) {
case _PedidoFormState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( Pedido pedido,  List<OpcionMaestra> direccionesCliente,  bool cargandoDetalle,  bool cargandoDatosCliente)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PedidoFormState() when $default != null:
return $default(_that.pedido,_that.direccionesCliente,_that.cargandoDetalle,_that.cargandoDatosCliente);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( Pedido pedido,  List<OpcionMaestra> direccionesCliente,  bool cargandoDetalle,  bool cargandoDatosCliente)  $default,) {final _that = this;
switch (_that) {
case _PedidoFormState():
return $default(_that.pedido,_that.direccionesCliente,_that.cargandoDetalle,_that.cargandoDatosCliente);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( Pedido pedido,  List<OpcionMaestra> direccionesCliente,  bool cargandoDetalle,  bool cargandoDatosCliente)?  $default,) {final _that = this;
switch (_that) {
case _PedidoFormState() when $default != null:
return $default(_that.pedido,_that.direccionesCliente,_that.cargandoDetalle,_that.cargandoDatosCliente);case _:
  return null;

}
}

}

/// @nodoc


class _PedidoFormState implements PedidoFormState {
  const _PedidoFormState({required this.pedido,  List<OpcionMaestra> direccionesCliente = const <OpcionMaestra>[], this.cargandoDetalle = false, this.cargandoDatosCliente = false}): _direccionesCliente = direccionesCliente;
  

@override final  Pedido pedido;
 final  List<OpcionMaestra> _direccionesCliente;
@override@JsonKey() List<OpcionMaestra> get direccionesCliente {
  if (_direccionesCliente is EqualUnmodifiableListView) return _direccionesCliente;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_direccionesCliente);
}

@override@JsonKey() final  bool cargandoDetalle;
@override@JsonKey() final  bool cargandoDatosCliente;

/// Create a copy of PedidoFormState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PedidoFormStateCopyWith<_PedidoFormState> get copyWith => __$PedidoFormStateCopyWithImpl<_PedidoFormState>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _PedidoFormState&&(identical(other.pedido, pedido) || other.pedido == pedido)&&const DeepCollectionEquality().equals(other.direccionesCliente, _direccionesCliente)&&(identical(other.cargandoDetalle, cargandoDetalle) || other.cargandoDetalle == cargandoDetalle)&&(identical(other.cargandoDatosCliente, cargandoDatosCliente) || other.cargandoDatosCliente == cargandoDatosCliente));
}


@override
int get hashCode {
    return Object.hash(runtimeType,pedido,const DeepCollectionEquality().hash(_direccionesCliente),cargandoDetalle,cargandoDatosCliente);
}

@override
String toString() {
    return 'PedidoFormState(pedido: $pedido, direccionesCliente: $direccionesCliente, cargandoDetalle: $cargandoDetalle, cargandoDatosCliente: $cargandoDatosCliente)';
}


}

/// @nodoc
abstract mixin class _$PedidoFormStateCopyWith<$Res> implements $PedidoFormStateCopyWith<$Res> {
  factory _$PedidoFormStateCopyWith(_PedidoFormState value, $Res Function(_PedidoFormState) _then) = __$PedidoFormStateCopyWithImpl;
@override @useResult
$Res call({
 Pedido pedido, List<OpcionMaestra> direccionesCliente, bool cargandoDetalle, bool cargandoDatosCliente
});


@override $PedidoCopyWith<$Res> get pedido;

}
/// @nodoc
class __$PedidoFormStateCopyWithImpl<$Res>
    implements _$PedidoFormStateCopyWith<$Res> {
  __$PedidoFormStateCopyWithImpl(this._self, this._then);

  final _PedidoFormState _self;
  final $Res Function(_PedidoFormState) _then;

/// Create a copy of PedidoFormState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? pedido = null,Object? direccionesCliente = null,Object? cargandoDetalle = null,Object? cargandoDatosCliente = null,}) {
  return _then(_PedidoFormState(
pedido: null == pedido ? _self.pedido : pedido // ignore: cast_nullable_to_non_nullable
as Pedido,direccionesCliente: null == direccionesCliente ? _self._direccionesCliente : direccionesCliente // ignore: cast_nullable_to_non_nullable
as List<OpcionMaestra>,cargandoDetalle: null == cargandoDetalle ? _self.cargandoDetalle : cargandoDetalle // ignore: cast_nullable_to_non_nullable
as bool,cargandoDatosCliente: null == cargandoDatosCliente ? _self.cargandoDatosCliente : cargandoDatosCliente // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

/// Create a copy of PedidoFormState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PedidoCopyWith<$Res> get pedido {
  
  return $PedidoCopyWith<$Res>(_self.pedido, (value) {
    return _then(_self.copyWith(pedido: value));
  });
}
}

// dart format on
