// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$OpcionMaestra {

 String get codigo; String get nombre;
/// Create a copy of OpcionMaestra
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OpcionMaestraCopyWith<OpcionMaestra> get copyWith => _$OpcionMaestraCopyWithImpl<OpcionMaestra>(this as OpcionMaestra, _$identity);

  /// Serializes this OpcionMaestra to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as OpcionMaestra;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OpcionMaestra&&(identical(other.codigo, _this.codigo) || other.codigo == _this.codigo)&&(identical(other.nombre, _this.nombre) || other.nombre == _this.nombre));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as OpcionMaestra;
  return Object.hash(runtimeType,_this.codigo,_this.nombre);
}

@override
String toString() {
  final _this = this as OpcionMaestra;
  return 'OpcionMaestra(codigo: ${_this.codigo}, nombre: ${_this.nombre})';
}


}

/// @nodoc
abstract mixin class $OpcionMaestraCopyWith<$Res>  {
  factory $OpcionMaestraCopyWith(OpcionMaestra value, $Res Function(OpcionMaestra) _then) = _$OpcionMaestraCopyWithImpl;
@useResult
$Res call({
 String codigo, String nombre
});




}
/// @nodoc
class _$OpcionMaestraCopyWithImpl<$Res>
    implements $OpcionMaestraCopyWith<$Res> {
  _$OpcionMaestraCopyWithImpl(this._self, this._then);

  final OpcionMaestra _self;
  final $Res Function(OpcionMaestra) _then;

/// Create a copy of OpcionMaestra
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? codigo = null,Object? nombre = null,}) {
  return _then(OpcionMaestra(
codigo: null == codigo ? _self.codigo : codigo // ignore: cast_nullable_to_non_nullable
as String,nombre: null == nombre ? _self.nombre : nombre // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [OpcionMaestra].
extension OpcionMaestraPatterns on OpcionMaestra {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _OpcionMaestra value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _OpcionMaestra() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _OpcionMaestra value)  $default,){
final _that = this;
switch (_that) {
case _OpcionMaestra():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _OpcionMaestra value)?  $default,){
final _that = this;
switch (_that) {
case _OpcionMaestra() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String codigo,  String nombre)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _OpcionMaestra() when $default != null:
return $default(_that.codigo,_that.nombre);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String codigo,  String nombre)  $default,) {final _that = this;
switch (_that) {
case _OpcionMaestra():
return $default(_that.codigo,_that.nombre);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String codigo,  String nombre)?  $default,) {final _that = this;
switch (_that) {
case _OpcionMaestra() when $default != null:
return $default(_that.codigo,_that.nombre);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _OpcionMaestra implements OpcionMaestra {
  const _OpcionMaestra({required this.codigo, required this.nombre});
  factory _OpcionMaestra.fromJson(Map<String, dynamic> json) => _$OpcionMaestraFromJson(json);

@override final  String codigo;
@override final  String nombre;

/// Create a copy of OpcionMaestra
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OpcionMaestraCopyWith<_OpcionMaestra> get copyWith => __$OpcionMaestraCopyWithImpl<_OpcionMaestra>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$OpcionMaestraToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _OpcionMaestra&&(identical(other.codigo, codigo) || other.codigo == codigo)&&(identical(other.nombre, nombre) || other.nombre == nombre));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,codigo,nombre);
}

@override
String toString() {
    return 'OpcionMaestra(codigo: $codigo, nombre: $nombre)';
}


}

/// @nodoc
abstract mixin class _$OpcionMaestraCopyWith<$Res> implements $OpcionMaestraCopyWith<$Res> {
  factory _$OpcionMaestraCopyWith(_OpcionMaestra value, $Res Function(_OpcionMaestra) _then) = __$OpcionMaestraCopyWithImpl;
@override @useResult
$Res call({
 String codigo, String nombre
});




}
/// @nodoc
class __$OpcionMaestraCopyWithImpl<$Res>
    implements _$OpcionMaestraCopyWith<$Res> {
  __$OpcionMaestraCopyWithImpl(this._self, this._then);

  final _OpcionMaestra _self;
  final $Res Function(_OpcionMaestra) _then;

/// Create a copy of OpcionMaestra
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? codigo = null,Object? nombre = null,}) {
  return _then(_OpcionMaestra(
codigo: null == codigo ? _self.codigo : codigo // ignore: cast_nullable_to_non_nullable
as String,nombre: null == nombre ? _self.nombre : nombre // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$LineaPedido {

 int? get id; int? get codigo; String get articulo; String get descripcion; String get nReferencia; double get cantidad; double get pendiente; double get precio; double get dto; double get importe; double get tipoIva; String get estado; bool get cancelado; String get previstoPara;
/// Create a copy of LineaPedido
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LineaPedidoCopyWith<LineaPedido> get copyWith => _$LineaPedidoCopyWithImpl<LineaPedido>(this as LineaPedido, _$identity);

  /// Serializes this LineaPedido to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as LineaPedido;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LineaPedido&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.codigo, _this.codigo) || other.codigo == _this.codigo)&&(identical(other.articulo, _this.articulo) || other.articulo == _this.articulo)&&(identical(other.descripcion, _this.descripcion) || other.descripcion == _this.descripcion)&&(identical(other.nReferencia, _this.nReferencia) || other.nReferencia == _this.nReferencia)&&(identical(other.cantidad, _this.cantidad) || other.cantidad == _this.cantidad)&&(identical(other.pendiente, _this.pendiente) || other.pendiente == _this.pendiente)&&(identical(other.precio, _this.precio) || other.precio == _this.precio)&&(identical(other.dto, _this.dto) || other.dto == _this.dto)&&(identical(other.importe, _this.importe) || other.importe == _this.importe)&&(identical(other.tipoIva, _this.tipoIva) || other.tipoIva == _this.tipoIva)&&(identical(other.estado, _this.estado) || other.estado == _this.estado)&&(identical(other.cancelado, _this.cancelado) || other.cancelado == _this.cancelado)&&(identical(other.previstoPara, _this.previstoPara) || other.previstoPara == _this.previstoPara));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as LineaPedido;
  return Object.hash(runtimeType,_this.id,_this.codigo,_this.articulo,_this.descripcion,_this.nReferencia,_this.cantidad,_this.pendiente,_this.precio,_this.dto,_this.importe,_this.tipoIva,_this.estado,_this.cancelado,_this.previstoPara);
}

@override
String toString() {
  final _this = this as LineaPedido;
  return 'LineaPedido(id: ${_this.id}, codigo: ${_this.codigo}, articulo: ${_this.articulo}, descripcion: ${_this.descripcion}, nReferencia: ${_this.nReferencia}, cantidad: ${_this.cantidad}, pendiente: ${_this.pendiente}, precio: ${_this.precio}, dto: ${_this.dto}, importe: ${_this.importe}, tipoIva: ${_this.tipoIva}, estado: ${_this.estado}, cancelado: ${_this.cancelado}, previstoPara: ${_this.previstoPara})';
}


}

/// @nodoc
abstract mixin class $LineaPedidoCopyWith<$Res>  {
  factory $LineaPedidoCopyWith(LineaPedido value, $Res Function(LineaPedido) _then) = _$LineaPedidoCopyWithImpl;
@useResult
$Res call({
 int? id, int? codigo, String articulo, String descripcion, String nReferencia, double cantidad, double pendiente, double precio, double dto, double importe, double tipoIva, String estado, bool cancelado, String previstoPara
});




}
/// @nodoc
class _$LineaPedidoCopyWithImpl<$Res>
    implements $LineaPedidoCopyWith<$Res> {
  _$LineaPedidoCopyWithImpl(this._self, this._then);

  final LineaPedido _self;
  final $Res Function(LineaPedido) _then;

/// Create a copy of LineaPedido
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = freezed,Object? codigo = freezed,Object? articulo = null,Object? descripcion = null,Object? nReferencia = null,Object? cantidad = null,Object? pendiente = null,Object? precio = null,Object? dto = null,Object? importe = null,Object? tipoIva = null,Object? estado = null,Object? cancelado = null,Object? previstoPara = null,}) {
  return _then(LineaPedido(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int?,codigo: freezed == codigo ? _self.codigo : codigo // ignore: cast_nullable_to_non_nullable
as int?,articulo: null == articulo ? _self.articulo : articulo // ignore: cast_nullable_to_non_nullable
as String,descripcion: null == descripcion ? _self.descripcion : descripcion // ignore: cast_nullable_to_non_nullable
as String,nReferencia: null == nReferencia ? _self.nReferencia : nReferencia // ignore: cast_nullable_to_non_nullable
as String,cantidad: null == cantidad ? _self.cantidad : cantidad // ignore: cast_nullable_to_non_nullable
as double,pendiente: null == pendiente ? _self.pendiente : pendiente // ignore: cast_nullable_to_non_nullable
as double,precio: null == precio ? _self.precio : precio // ignore: cast_nullable_to_non_nullable
as double,dto: null == dto ? _self.dto : dto // ignore: cast_nullable_to_non_nullable
as double,importe: null == importe ? _self.importe : importe // ignore: cast_nullable_to_non_nullable
as double,tipoIva: null == tipoIva ? _self.tipoIva : tipoIva // ignore: cast_nullable_to_non_nullable
as double,estado: null == estado ? _self.estado : estado // ignore: cast_nullable_to_non_nullable
as String,cancelado: null == cancelado ? _self.cancelado : cancelado // ignore: cast_nullable_to_non_nullable
as bool,previstoPara: null == previstoPara ? _self.previstoPara : previstoPara // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [LineaPedido].
extension LineaPedidoPatterns on LineaPedido {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LineaPedido value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LineaPedido() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LineaPedido value)  $default,){
final _that = this;
switch (_that) {
case _LineaPedido():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LineaPedido value)?  $default,){
final _that = this;
switch (_that) {
case _LineaPedido() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int? id,  int? codigo,  String articulo,  String descripcion,  String nReferencia,  double cantidad,  double pendiente,  double precio,  double dto,  double importe,  double tipoIva,  String estado,  bool cancelado,  String previstoPara)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LineaPedido() when $default != null:
return $default(_that.id,_that.codigo,_that.articulo,_that.descripcion,_that.nReferencia,_that.cantidad,_that.pendiente,_that.precio,_that.dto,_that.importe,_that.tipoIva,_that.estado,_that.cancelado,_that.previstoPara);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int? id,  int? codigo,  String articulo,  String descripcion,  String nReferencia,  double cantidad,  double pendiente,  double precio,  double dto,  double importe,  double tipoIva,  String estado,  bool cancelado,  String previstoPara)  $default,) {final _that = this;
switch (_that) {
case _LineaPedido():
return $default(_that.id,_that.codigo,_that.articulo,_that.descripcion,_that.nReferencia,_that.cantidad,_that.pendiente,_that.precio,_that.dto,_that.importe,_that.tipoIva,_that.estado,_that.cancelado,_that.previstoPara);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int? id,  int? codigo,  String articulo,  String descripcion,  String nReferencia,  double cantidad,  double pendiente,  double precio,  double dto,  double importe,  double tipoIva,  String estado,  bool cancelado,  String previstoPara)?  $default,) {final _that = this;
switch (_that) {
case _LineaPedido() when $default != null:
return $default(_that.id,_that.codigo,_that.articulo,_that.descripcion,_that.nReferencia,_that.cantidad,_that.pendiente,_that.precio,_that.dto,_that.importe,_that.tipoIva,_that.estado,_that.cancelado,_that.previstoPara);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LineaPedido implements LineaPedido {
  const _LineaPedido({this.id, this.codigo, this.articulo = '', this.descripcion = '', this.nReferencia = '', this.cantidad = 1.0, this.pendiente = 1.0, this.precio = 0.0, this.dto = 0.0, this.importe = 0.0, this.tipoIva = 21.0, this.estado = 'Pendiente', this.cancelado = false, this.previstoPara = ''});
  factory _LineaPedido.fromJson(Map<String, dynamic> json) => _$LineaPedidoFromJson(json);

@override final  int? id;
@override final  int? codigo;
@override@JsonKey() final  String articulo;
@override@JsonKey() final  String descripcion;
@override@JsonKey() final  String nReferencia;
@override@JsonKey() final  double cantidad;
@override@JsonKey() final  double pendiente;
@override@JsonKey() final  double precio;
@override@JsonKey() final  double dto;
@override@JsonKey() final  double importe;
@override@JsonKey() final  double tipoIva;
@override@JsonKey() final  String estado;
@override@JsonKey() final  bool cancelado;
@override@JsonKey() final  String previstoPara;

/// Create a copy of LineaPedido
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LineaPedidoCopyWith<_LineaPedido> get copyWith => __$LineaPedidoCopyWithImpl<_LineaPedido>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LineaPedidoToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _LineaPedido&&(identical(other.id, id) || other.id == id)&&(identical(other.codigo, codigo) || other.codigo == codigo)&&(identical(other.articulo, articulo) || other.articulo == articulo)&&(identical(other.descripcion, descripcion) || other.descripcion == descripcion)&&(identical(other.nReferencia, nReferencia) || other.nReferencia == nReferencia)&&(identical(other.cantidad, cantidad) || other.cantidad == cantidad)&&(identical(other.pendiente, pendiente) || other.pendiente == pendiente)&&(identical(other.precio, precio) || other.precio == precio)&&(identical(other.dto, dto) || other.dto == dto)&&(identical(other.importe, importe) || other.importe == importe)&&(identical(other.tipoIva, tipoIva) || other.tipoIva == tipoIva)&&(identical(other.estado, estado) || other.estado == estado)&&(identical(other.cancelado, cancelado) || other.cancelado == cancelado)&&(identical(other.previstoPara, previstoPara) || other.previstoPara == previstoPara));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,codigo,articulo,descripcion,nReferencia,cantidad,pendiente,precio,dto,importe,tipoIva,estado,cancelado,previstoPara);
}

@override
String toString() {
    return 'LineaPedido(id: $id, codigo: $codigo, articulo: $articulo, descripcion: $descripcion, nReferencia: $nReferencia, cantidad: $cantidad, pendiente: $pendiente, precio: $precio, dto: $dto, importe: $importe, tipoIva: $tipoIva, estado: $estado, cancelado: $cancelado, previstoPara: $previstoPara)';
}


}

/// @nodoc
abstract mixin class _$LineaPedidoCopyWith<$Res> implements $LineaPedidoCopyWith<$Res> {
  factory _$LineaPedidoCopyWith(_LineaPedido value, $Res Function(_LineaPedido) _then) = __$LineaPedidoCopyWithImpl;
@override @useResult
$Res call({
 int? id, int? codigo, String articulo, String descripcion, String nReferencia, double cantidad, double pendiente, double precio, double dto, double importe, double tipoIva, String estado, bool cancelado, String previstoPara
});




}
/// @nodoc
class __$LineaPedidoCopyWithImpl<$Res>
    implements _$LineaPedidoCopyWith<$Res> {
  __$LineaPedidoCopyWithImpl(this._self, this._then);

  final _LineaPedido _self;
  final $Res Function(_LineaPedido) _then;

/// Create a copy of LineaPedido
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = freezed,Object? codigo = freezed,Object? articulo = null,Object? descripcion = null,Object? nReferencia = null,Object? cantidad = null,Object? pendiente = null,Object? precio = null,Object? dto = null,Object? importe = null,Object? tipoIva = null,Object? estado = null,Object? cancelado = null,Object? previstoPara = null,}) {
  return _then(_LineaPedido(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int?,codigo: freezed == codigo ? _self.codigo : codigo // ignore: cast_nullable_to_non_nullable
as int?,articulo: null == articulo ? _self.articulo : articulo // ignore: cast_nullable_to_non_nullable
as String,descripcion: null == descripcion ? _self.descripcion : descripcion // ignore: cast_nullable_to_non_nullable
as String,nReferencia: null == nReferencia ? _self.nReferencia : nReferencia // ignore: cast_nullable_to_non_nullable
as String,cantidad: null == cantidad ? _self.cantidad : cantidad // ignore: cast_nullable_to_non_nullable
as double,pendiente: null == pendiente ? _self.pendiente : pendiente // ignore: cast_nullable_to_non_nullable
as double,precio: null == precio ? _self.precio : precio // ignore: cast_nullable_to_non_nullable
as double,dto: null == dto ? _self.dto : dto // ignore: cast_nullable_to_non_nullable
as double,importe: null == importe ? _self.importe : importe // ignore: cast_nullable_to_non_nullable
as double,tipoIva: null == tipoIva ? _self.tipoIva : tipoIva // ignore: cast_nullable_to_non_nullable
as double,estado: null == estado ? _self.estado : estado // ignore: cast_nullable_to_non_nullable
as String,cancelado: null == cancelado ? _self.cancelado : cancelado // ignore: cast_nullable_to_non_nullable
as bool,previstoPara: null == previstoPara ? _self.previstoPara : previstoPara // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$User {

 String get id; String get name; String get role; List<String> get assignedCustomerIds;
/// Create a copy of User
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UserCopyWith<User> get copyWith => _$UserCopyWithImpl<User>(this as User, _$identity);

  /// Serializes this User to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as User;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is User&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.role, _this.role) || other.role == _this.role)&&const DeepCollectionEquality().equals(other.assignedCustomerIds, _this.assignedCustomerIds));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as User;
  return Object.hash(runtimeType,_this.id,_this.name,_this.role,const DeepCollectionEquality().hash(_this.assignedCustomerIds));
}

@override
String toString() {
  final _this = this as User;
  return 'User(id: ${_this.id}, name: ${_this.name}, role: ${_this.role}, assignedCustomerIds: ${_this.assignedCustomerIds})';
}


}

/// @nodoc
abstract mixin class $UserCopyWith<$Res>  {
  factory $UserCopyWith(User value, $Res Function(User) _then) = _$UserCopyWithImpl;
@useResult
$Res call({
 String id, String name, String role, List<String> assignedCustomerIds
});




}
/// @nodoc
class _$UserCopyWithImpl<$Res>
    implements $UserCopyWith<$Res> {
  _$UserCopyWithImpl(this._self, this._then);

  final User _self;
  final $Res Function(User) _then;

/// Create a copy of User
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? role = null,Object? assignedCustomerIds = null,}) {
  return _then(User(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as String,assignedCustomerIds: null == assignedCustomerIds ? _self.assignedCustomerIds : assignedCustomerIds // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}

}


/// Adds pattern-matching-related methods to [User].
extension UserPatterns on User {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _User value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _User() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _User value)  $default,){
final _that = this;
switch (_that) {
case _User():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _User value)?  $default,){
final _that = this;
switch (_that) {
case _User() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String role,  List<String> assignedCustomerIds)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _User() when $default != null:
return $default(_that.id,_that.name,_that.role,_that.assignedCustomerIds);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String role,  List<String> assignedCustomerIds)  $default,) {final _that = this;
switch (_that) {
case _User():
return $default(_that.id,_that.name,_that.role,_that.assignedCustomerIds);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String role,  List<String> assignedCustomerIds)?  $default,) {final _that = this;
switch (_that) {
case _User() when $default != null:
return $default(_that.id,_that.name,_that.role,_that.assignedCustomerIds);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _User implements User {
  const _User({required this.id, required this.name, required this.role,  List<String> assignedCustomerIds = const []}): _assignedCustomerIds = assignedCustomerIds;
  factory _User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);

@override final  String id;
@override final  String name;
@override final  String role;
 final  List<String> _assignedCustomerIds;
@override@JsonKey() List<String> get assignedCustomerIds {
  if (_assignedCustomerIds is EqualUnmodifiableListView) return _assignedCustomerIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_assignedCustomerIds);
}


/// Create a copy of User
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UserCopyWith<_User> get copyWith => __$UserCopyWithImpl<_User>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$UserToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _User&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.role, role) || other.role == role)&&const DeepCollectionEquality().equals(other.assignedCustomerIds, _assignedCustomerIds));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,name,role,const DeepCollectionEquality().hash(_assignedCustomerIds));
}

@override
String toString() {
    return 'User(id: $id, name: $name, role: $role, assignedCustomerIds: $assignedCustomerIds)';
}


}

/// @nodoc
abstract mixin class _$UserCopyWith<$Res> implements $UserCopyWith<$Res> {
  factory _$UserCopyWith(_User value, $Res Function(_User) _then) = __$UserCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String role, List<String> assignedCustomerIds
});




}
/// @nodoc
class __$UserCopyWithImpl<$Res>
    implements _$UserCopyWith<$Res> {
  __$UserCopyWithImpl(this._self, this._then);

  final _User _self;
  final $Res Function(_User) _then;

/// Create a copy of User
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? role = null,Object? assignedCustomerIds = null,}) {
  return _then(_User(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as String,assignedCustomerIds: null == assignedCustomerIds ? _self._assignedCustomerIds : assignedCustomerIds // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}


}


/// @nodoc
mixin _$Cliente {

 int get id;@JsonKey(name: 'nom_com') String get nombreComercial;@JsonKey(name: 'cif') String get cif;@JsonKey(name: 'tlf') String get telefono;
/// Create a copy of Cliente
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ClienteCopyWith<Cliente> get copyWith => _$ClienteCopyWithImpl<Cliente>(this as Cliente, _$identity);

  /// Serializes this Cliente to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as Cliente;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Cliente&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.nombreComercial, _this.nombreComercial) || other.nombreComercial == _this.nombreComercial)&&(identical(other.cif, _this.cif) || other.cif == _this.cif)&&(identical(other.telefono, _this.telefono) || other.telefono == _this.telefono));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as Cliente;
  return Object.hash(runtimeType,_this.id,_this.nombreComercial,_this.cif,_this.telefono);
}

@override
String toString() {
  final _this = this as Cliente;
  return 'Cliente(id: ${_this.id}, nombreComercial: ${_this.nombreComercial}, cif: ${_this.cif}, telefono: ${_this.telefono})';
}


}

/// @nodoc
abstract mixin class $ClienteCopyWith<$Res>  {
  factory $ClienteCopyWith(Cliente value, $Res Function(Cliente) _then) = _$ClienteCopyWithImpl;
@useResult
$Res call({
 int id,@JsonKey(name: 'nom_com') String nombreComercial,@JsonKey(name: 'cif') String cif,@JsonKey(name: 'tlf') String telefono
});




}
/// @nodoc
class _$ClienteCopyWithImpl<$Res>
    implements $ClienteCopyWith<$Res> {
  _$ClienteCopyWithImpl(this._self, this._then);

  final Cliente _self;
  final $Res Function(Cliente) _then;

/// Create a copy of Cliente
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? nombreComercial = null,Object? cif = null,Object? telefono = null,}) {
  return _then(Cliente(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,nombreComercial: null == nombreComercial ? _self.nombreComercial : nombreComercial // ignore: cast_nullable_to_non_nullable
as String,cif: null == cif ? _self.cif : cif // ignore: cast_nullable_to_non_nullable
as String,telefono: null == telefono ? _self.telefono : telefono // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [Cliente].
extension ClientePatterns on Cliente {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Cliente value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Cliente() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Cliente value)  $default,){
final _that = this;
switch (_that) {
case _Cliente():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Cliente value)?  $default,){
final _that = this;
switch (_that) {
case _Cliente() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id, @JsonKey(name: 'nom_com')  String nombreComercial, @JsonKey(name: 'cif')  String cif, @JsonKey(name: 'tlf')  String telefono)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Cliente() when $default != null:
return $default(_that.id,_that.nombreComercial,_that.cif,_that.telefono);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id, @JsonKey(name: 'nom_com')  String nombreComercial, @JsonKey(name: 'cif')  String cif, @JsonKey(name: 'tlf')  String telefono)  $default,) {final _that = this;
switch (_that) {
case _Cliente():
return $default(_that.id,_that.nombreComercial,_that.cif,_that.telefono);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id, @JsonKey(name: 'nom_com')  String nombreComercial, @JsonKey(name: 'cif')  String cif, @JsonKey(name: 'tlf')  String telefono)?  $default,) {final _that = this;
switch (_that) {
case _Cliente() when $default != null:
return $default(_that.id,_that.nombreComercial,_that.cif,_that.telefono);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Cliente implements Cliente {
  const _Cliente({required this.id, @JsonKey(name: 'nom_com') this.nombreComercial = '', @JsonKey(name: 'cif') this.cif = '', @JsonKey(name: 'tlf') this.telefono = ''});
  factory _Cliente.fromJson(Map<String, dynamic> json) => _$ClienteFromJson(json);

@override final  int id;
@override@JsonKey(name: 'nom_com') final  String nombreComercial;
@override@JsonKey(name: 'cif') final  String cif;
@override@JsonKey(name: 'tlf') final  String telefono;

/// Create a copy of Cliente
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ClienteCopyWith<_Cliente> get copyWith => __$ClienteCopyWithImpl<_Cliente>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ClienteToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Cliente&&(identical(other.id, id) || other.id == id)&&(identical(other.nombreComercial, nombreComercial) || other.nombreComercial == nombreComercial)&&(identical(other.cif, cif) || other.cif == cif)&&(identical(other.telefono, telefono) || other.telefono == telefono));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,nombreComercial,cif,telefono);
}

@override
String toString() {
    return 'Cliente(id: $id, nombreComercial: $nombreComercial, cif: $cif, telefono: $telefono)';
}


}

/// @nodoc
abstract mixin class _$ClienteCopyWith<$Res> implements $ClienteCopyWith<$Res> {
  factory _$ClienteCopyWith(_Cliente value, $Res Function(_Cliente) _then) = __$ClienteCopyWithImpl;
@override @useResult
$Res call({
 int id,@JsonKey(name: 'nom_com') String nombreComercial,@JsonKey(name: 'cif') String cif,@JsonKey(name: 'tlf') String telefono
});




}
/// @nodoc
class __$ClienteCopyWithImpl<$Res>
    implements _$ClienteCopyWith<$Res> {
  __$ClienteCopyWithImpl(this._self, this._then);

  final _Cliente _self;
  final $Res Function(_Cliente) _then;

/// Create a copy of Cliente
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? nombreComercial = null,Object? cif = null,Object? telefono = null,}) {
  return _then(_Cliente(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,nombreComercial: null == nombreComercial ? _self.nombreComercial : nombreComercial // ignore: cast_nullable_to_non_nullable
as String,cif: null == cif ? _self.cif : cif // ignore: cast_nullable_to_non_nullable
as String,telefono: null == telefono ? _self.telefono : telefono // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$Pedido {

 int? get id;@JsonKey(name: 'num_ped') String get numeroPedido;@JsonKey(name: 'clt') int get clienteId;@JsonKey(name: 'est') String get estado;@JsonKey(name: 'tot_ped') double get total; List<LineaPedido> get lineas; String get clienteNombre; String get clienteTelefono; String get clienteCif; int get codigo; int get nDocumento; String get serie; String get serieNombre; String get comercial; String get comercialNombre; String get almacen; String get almacenNombre; String get fecha; String get previstoPara; String get formaPago; String get formaPagoNombre; String get direccionEnvio; String get email; String get observaciones;
/// Create a copy of Pedido
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PedidoCopyWith<Pedido> get copyWith => _$PedidoCopyWithImpl<Pedido>(this as Pedido, _$identity);

  /// Serializes this Pedido to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as Pedido;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Pedido&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.numeroPedido, _this.numeroPedido) || other.numeroPedido == _this.numeroPedido)&&(identical(other.clienteId, _this.clienteId) || other.clienteId == _this.clienteId)&&(identical(other.estado, _this.estado) || other.estado == _this.estado)&&(identical(other.total, _this.total) || other.total == _this.total)&&const DeepCollectionEquality().equals(other.lineas, _this.lineas)&&(identical(other.clienteNombre, _this.clienteNombre) || other.clienteNombre == _this.clienteNombre)&&(identical(other.clienteTelefono, _this.clienteTelefono) || other.clienteTelefono == _this.clienteTelefono)&&(identical(other.clienteCif, _this.clienteCif) || other.clienteCif == _this.clienteCif)&&(identical(other.codigo, _this.codigo) || other.codigo == _this.codigo)&&(identical(other.nDocumento, _this.nDocumento) || other.nDocumento == _this.nDocumento)&&(identical(other.serie, _this.serie) || other.serie == _this.serie)&&(identical(other.serieNombre, _this.serieNombre) || other.serieNombre == _this.serieNombre)&&(identical(other.comercial, _this.comercial) || other.comercial == _this.comercial)&&(identical(other.comercialNombre, _this.comercialNombre) || other.comercialNombre == _this.comercialNombre)&&(identical(other.almacen, _this.almacen) || other.almacen == _this.almacen)&&(identical(other.almacenNombre, _this.almacenNombre) || other.almacenNombre == _this.almacenNombre)&&(identical(other.fecha, _this.fecha) || other.fecha == _this.fecha)&&(identical(other.previstoPara, _this.previstoPara) || other.previstoPara == _this.previstoPara)&&(identical(other.formaPago, _this.formaPago) || other.formaPago == _this.formaPago)&&(identical(other.formaPagoNombre, _this.formaPagoNombre) || other.formaPagoNombre == _this.formaPagoNombre)&&(identical(other.direccionEnvio, _this.direccionEnvio) || other.direccionEnvio == _this.direccionEnvio)&&(identical(other.email, _this.email) || other.email == _this.email)&&(identical(other.observaciones, _this.observaciones) || other.observaciones == _this.observaciones));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as Pedido;
  return Object.hashAll([runtimeType,_this.id,_this.numeroPedido,_this.clienteId,_this.estado,_this.total,const DeepCollectionEquality().hash(_this.lineas),_this.clienteNombre,_this.clienteTelefono,_this.clienteCif,_this.codigo,_this.nDocumento,_this.serie,_this.serieNombre,_this.comercial,_this.comercialNombre,_this.almacen,_this.almacenNombre,_this.fecha,_this.previstoPara,_this.formaPago,_this.formaPagoNombre,_this.direccionEnvio,_this.email,_this.observaciones]);
}

@override
String toString() {
  final _this = this as Pedido;
  return 'Pedido(id: ${_this.id}, numeroPedido: ${_this.numeroPedido}, clienteId: ${_this.clienteId}, estado: ${_this.estado}, total: ${_this.total}, lineas: ${_this.lineas}, clienteNombre: ${_this.clienteNombre}, clienteTelefono: ${_this.clienteTelefono}, clienteCif: ${_this.clienteCif}, codigo: ${_this.codigo}, nDocumento: ${_this.nDocumento}, serie: ${_this.serie}, serieNombre: ${_this.serieNombre}, comercial: ${_this.comercial}, comercialNombre: ${_this.comercialNombre}, almacen: ${_this.almacen}, almacenNombre: ${_this.almacenNombre}, fecha: ${_this.fecha}, previstoPara: ${_this.previstoPara}, formaPago: ${_this.formaPago}, formaPagoNombre: ${_this.formaPagoNombre}, direccionEnvio: ${_this.direccionEnvio}, email: ${_this.email}, observaciones: ${_this.observaciones})';
}


}

/// @nodoc
abstract mixin class $PedidoCopyWith<$Res>  {
  factory $PedidoCopyWith(Pedido value, $Res Function(Pedido) _then) = _$PedidoCopyWithImpl;
@useResult
$Res call({
 int? id,@JsonKey(name: 'num_ped') String numeroPedido,@JsonKey(name: 'clt') int clienteId,@JsonKey(name: 'est') String estado,@JsonKey(name: 'tot_ped') double total, List<LineaPedido> lineas, String clienteNombre, String clienteTelefono, String clienteCif, int codigo, int nDocumento, String serie, String serieNombre, String comercial, String comercialNombre, String almacen, String almacenNombre, String fecha, String previstoPara, String formaPago, String formaPagoNombre, String direccionEnvio, String email, String observaciones
});




}
/// @nodoc
class _$PedidoCopyWithImpl<$Res>
    implements $PedidoCopyWith<$Res> {
  _$PedidoCopyWithImpl(this._self, this._then);

  final Pedido _self;
  final $Res Function(Pedido) _then;

/// Create a copy of Pedido
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = freezed,Object? numeroPedido = null,Object? clienteId = null,Object? estado = null,Object? total = null,Object? lineas = null,Object? clienteNombre = null,Object? clienteTelefono = null,Object? clienteCif = null,Object? codigo = null,Object? nDocumento = null,Object? serie = null,Object? serieNombre = null,Object? comercial = null,Object? comercialNombre = null,Object? almacen = null,Object? almacenNombre = null,Object? fecha = null,Object? previstoPara = null,Object? formaPago = null,Object? formaPagoNombre = null,Object? direccionEnvio = null,Object? email = null,Object? observaciones = null,}) {
  return _then(Pedido(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int?,numeroPedido: null == numeroPedido ? _self.numeroPedido : numeroPedido // ignore: cast_nullable_to_non_nullable
as String,clienteId: null == clienteId ? _self.clienteId : clienteId // ignore: cast_nullable_to_non_nullable
as int,estado: null == estado ? _self.estado : estado // ignore: cast_nullable_to_non_nullable
as String,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as double,lineas: null == lineas ? _self.lineas : lineas // ignore: cast_nullable_to_non_nullable
as List<LineaPedido>,clienteNombre: null == clienteNombre ? _self.clienteNombre : clienteNombre // ignore: cast_nullable_to_non_nullable
as String,clienteTelefono: null == clienteTelefono ? _self.clienteTelefono : clienteTelefono // ignore: cast_nullable_to_non_nullable
as String,clienteCif: null == clienteCif ? _self.clienteCif : clienteCif // ignore: cast_nullable_to_non_nullable
as String,codigo: null == codigo ? _self.codigo : codigo // ignore: cast_nullable_to_non_nullable
as int,nDocumento: null == nDocumento ? _self.nDocumento : nDocumento // ignore: cast_nullable_to_non_nullable
as int,serie: null == serie ? _self.serie : serie // ignore: cast_nullable_to_non_nullable
as String,serieNombre: null == serieNombre ? _self.serieNombre : serieNombre // ignore: cast_nullable_to_non_nullable
as String,comercial: null == comercial ? _self.comercial : comercial // ignore: cast_nullable_to_non_nullable
as String,comercialNombre: null == comercialNombre ? _self.comercialNombre : comercialNombre // ignore: cast_nullable_to_non_nullable
as String,almacen: null == almacen ? _self.almacen : almacen // ignore: cast_nullable_to_non_nullable
as String,almacenNombre: null == almacenNombre ? _self.almacenNombre : almacenNombre // ignore: cast_nullable_to_non_nullable
as String,fecha: null == fecha ? _self.fecha : fecha // ignore: cast_nullable_to_non_nullable
as String,previstoPara: null == previstoPara ? _self.previstoPara : previstoPara // ignore: cast_nullable_to_non_nullable
as String,formaPago: null == formaPago ? _self.formaPago : formaPago // ignore: cast_nullable_to_non_nullable
as String,formaPagoNombre: null == formaPagoNombre ? _self.formaPagoNombre : formaPagoNombre // ignore: cast_nullable_to_non_nullable
as String,direccionEnvio: null == direccionEnvio ? _self.direccionEnvio : direccionEnvio // ignore: cast_nullable_to_non_nullable
as String,email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,observaciones: null == observaciones ? _self.observaciones : observaciones // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [Pedido].
extension PedidoPatterns on Pedido {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Pedido value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Pedido() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Pedido value)  $default,){
final _that = this;
switch (_that) {
case _Pedido():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Pedido value)?  $default,){
final _that = this;
switch (_that) {
case _Pedido() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int? id, @JsonKey(name: 'num_ped')  String numeroPedido, @JsonKey(name: 'clt')  int clienteId, @JsonKey(name: 'est')  String estado, @JsonKey(name: 'tot_ped')  double total,  List<LineaPedido> lineas,  String clienteNombre,  String clienteTelefono,  String clienteCif,  int codigo,  int nDocumento,  String serie,  String serieNombre,  String comercial,  String comercialNombre,  String almacen,  String almacenNombre,  String fecha,  String previstoPara,  String formaPago,  String formaPagoNombre,  String direccionEnvio,  String email,  String observaciones)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Pedido() when $default != null:
return $default(_that.id,_that.numeroPedido,_that.clienteId,_that.estado,_that.total,_that.lineas,_that.clienteNombre,_that.clienteTelefono,_that.clienteCif,_that.codigo,_that.nDocumento,_that.serie,_that.serieNombre,_that.comercial,_that.comercialNombre,_that.almacen,_that.almacenNombre,_that.fecha,_that.previstoPara,_that.formaPago,_that.formaPagoNombre,_that.direccionEnvio,_that.email,_that.observaciones);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int? id, @JsonKey(name: 'num_ped')  String numeroPedido, @JsonKey(name: 'clt')  int clienteId, @JsonKey(name: 'est')  String estado, @JsonKey(name: 'tot_ped')  double total,  List<LineaPedido> lineas,  String clienteNombre,  String clienteTelefono,  String clienteCif,  int codigo,  int nDocumento,  String serie,  String serieNombre,  String comercial,  String comercialNombre,  String almacen,  String almacenNombre,  String fecha,  String previstoPara,  String formaPago,  String formaPagoNombre,  String direccionEnvio,  String email,  String observaciones)  $default,) {final _that = this;
switch (_that) {
case _Pedido():
return $default(_that.id,_that.numeroPedido,_that.clienteId,_that.estado,_that.total,_that.lineas,_that.clienteNombre,_that.clienteTelefono,_that.clienteCif,_that.codigo,_that.nDocumento,_that.serie,_that.serieNombre,_that.comercial,_that.comercialNombre,_that.almacen,_that.almacenNombre,_that.fecha,_that.previstoPara,_that.formaPago,_that.formaPagoNombre,_that.direccionEnvio,_that.email,_that.observaciones);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int? id, @JsonKey(name: 'num_ped')  String numeroPedido, @JsonKey(name: 'clt')  int clienteId, @JsonKey(name: 'est')  String estado, @JsonKey(name: 'tot_ped')  double total,  List<LineaPedido> lineas,  String clienteNombre,  String clienteTelefono,  String clienteCif,  int codigo,  int nDocumento,  String serie,  String serieNombre,  String comercial,  String comercialNombre,  String almacen,  String almacenNombre,  String fecha,  String previstoPara,  String formaPago,  String formaPagoNombre,  String direccionEnvio,  String email,  String observaciones)?  $default,) {final _that = this;
switch (_that) {
case _Pedido() when $default != null:
return $default(_that.id,_that.numeroPedido,_that.clienteId,_that.estado,_that.total,_that.lineas,_that.clienteNombre,_that.clienteTelefono,_that.clienteCif,_that.codigo,_that.nDocumento,_that.serie,_that.serieNombre,_that.comercial,_that.comercialNombre,_that.almacen,_that.almacenNombre,_that.fecha,_that.previstoPara,_that.formaPago,_that.formaPagoNombre,_that.direccionEnvio,_that.email,_that.observaciones);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Pedido implements Pedido {
  const _Pedido({this.id, @JsonKey(name: 'num_ped') this.numeroPedido = '', @JsonKey(name: 'clt') required this.clienteId, @JsonKey(name: 'est') this.estado = 'S', @JsonKey(name: 'tot_ped') this.total = 0.0,  List<LineaPedido> lineas = const [], this.clienteNombre = '', this.clienteTelefono = '', this.clienteCif = '', this.codigo = 0, this.nDocumento = 0, this.serie = '', this.serieNombre = '', this.comercial = '', this.comercialNombre = '', this.almacen = '', this.almacenNombre = '', this.fecha = '', this.previstoPara = '', this.formaPago = '', this.formaPagoNombre = '', this.direccionEnvio = '', this.email = '', this.observaciones = ''}): _lineas = lineas;
  factory _Pedido.fromJson(Map<String, dynamic> json) => _$PedidoFromJson(json);

@override final  int? id;
@override@JsonKey(name: 'num_ped') final  String numeroPedido;
@override@JsonKey(name: 'clt') final  int clienteId;
@override@JsonKey(name: 'est') final  String estado;
@override@JsonKey(name: 'tot_ped') final  double total;
 final  List<LineaPedido> _lineas;
@override@JsonKey() List<LineaPedido> get lineas {
  if (_lineas is EqualUnmodifiableListView) return _lineas;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_lineas);
}

@override@JsonKey() final  String clienteNombre;
@override@JsonKey() final  String clienteTelefono;
@override@JsonKey() final  String clienteCif;
@override@JsonKey() final  int codigo;
@override@JsonKey() final  int nDocumento;
@override@JsonKey() final  String serie;
@override@JsonKey() final  String serieNombre;
@override@JsonKey() final  String comercial;
@override@JsonKey() final  String comercialNombre;
@override@JsonKey() final  String almacen;
@override@JsonKey() final  String almacenNombre;
@override@JsonKey() final  String fecha;
@override@JsonKey() final  String previstoPara;
@override@JsonKey() final  String formaPago;
@override@JsonKey() final  String formaPagoNombre;
@override@JsonKey() final  String direccionEnvio;
@override@JsonKey() final  String email;
@override@JsonKey() final  String observaciones;

/// Create a copy of Pedido
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PedidoCopyWith<_Pedido> get copyWith => __$PedidoCopyWithImpl<_Pedido>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PedidoToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Pedido&&(identical(other.id, id) || other.id == id)&&(identical(other.numeroPedido, numeroPedido) || other.numeroPedido == numeroPedido)&&(identical(other.clienteId, clienteId) || other.clienteId == clienteId)&&(identical(other.estado, estado) || other.estado == estado)&&(identical(other.total, total) || other.total == total)&&const DeepCollectionEquality().equals(other.lineas, _lineas)&&(identical(other.clienteNombre, clienteNombre) || other.clienteNombre == clienteNombre)&&(identical(other.clienteTelefono, clienteTelefono) || other.clienteTelefono == clienteTelefono)&&(identical(other.clienteCif, clienteCif) || other.clienteCif == clienteCif)&&(identical(other.codigo, codigo) || other.codigo == codigo)&&(identical(other.nDocumento, nDocumento) || other.nDocumento == nDocumento)&&(identical(other.serie, serie) || other.serie == serie)&&(identical(other.serieNombre, serieNombre) || other.serieNombre == serieNombre)&&(identical(other.comercial, comercial) || other.comercial == comercial)&&(identical(other.comercialNombre, comercialNombre) || other.comercialNombre == comercialNombre)&&(identical(other.almacen, almacen) || other.almacen == almacen)&&(identical(other.almacenNombre, almacenNombre) || other.almacenNombre == almacenNombre)&&(identical(other.fecha, fecha) || other.fecha == fecha)&&(identical(other.previstoPara, previstoPara) || other.previstoPara == previstoPara)&&(identical(other.formaPago, formaPago) || other.formaPago == formaPago)&&(identical(other.formaPagoNombre, formaPagoNombre) || other.formaPagoNombre == formaPagoNombre)&&(identical(other.direccionEnvio, direccionEnvio) || other.direccionEnvio == direccionEnvio)&&(identical(other.email, email) || other.email == email)&&(identical(other.observaciones, observaciones) || other.observaciones == observaciones));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hashAll([runtimeType,id,numeroPedido,clienteId,estado,total,const DeepCollectionEquality().hash(_lineas),clienteNombre,clienteTelefono,clienteCif,codigo,nDocumento,serie,serieNombre,comercial,comercialNombre,almacen,almacenNombre,fecha,previstoPara,formaPago,formaPagoNombre,direccionEnvio,email,observaciones]);
}

@override
String toString() {
    return 'Pedido(id: $id, numeroPedido: $numeroPedido, clienteId: $clienteId, estado: $estado, total: $total, lineas: $lineas, clienteNombre: $clienteNombre, clienteTelefono: $clienteTelefono, clienteCif: $clienteCif, codigo: $codigo, nDocumento: $nDocumento, serie: $serie, serieNombre: $serieNombre, comercial: $comercial, comercialNombre: $comercialNombre, almacen: $almacen, almacenNombre: $almacenNombre, fecha: $fecha, previstoPara: $previstoPara, formaPago: $formaPago, formaPagoNombre: $formaPagoNombre, direccionEnvio: $direccionEnvio, email: $email, observaciones: $observaciones)';
}


}

/// @nodoc
abstract mixin class _$PedidoCopyWith<$Res> implements $PedidoCopyWith<$Res> {
  factory _$PedidoCopyWith(_Pedido value, $Res Function(_Pedido) _then) = __$PedidoCopyWithImpl;
@override @useResult
$Res call({
 int? id,@JsonKey(name: 'num_ped') String numeroPedido,@JsonKey(name: 'clt') int clienteId,@JsonKey(name: 'est') String estado,@JsonKey(name: 'tot_ped') double total, List<LineaPedido> lineas, String clienteNombre, String clienteTelefono, String clienteCif, int codigo, int nDocumento, String serie, String serieNombre, String comercial, String comercialNombre, String almacen, String almacenNombre, String fecha, String previstoPara, String formaPago, String formaPagoNombre, String direccionEnvio, String email, String observaciones
});




}
/// @nodoc
class __$PedidoCopyWithImpl<$Res>
    implements _$PedidoCopyWith<$Res> {
  __$PedidoCopyWithImpl(this._self, this._then);

  final _Pedido _self;
  final $Res Function(_Pedido) _then;

/// Create a copy of Pedido
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = freezed,Object? numeroPedido = null,Object? clienteId = null,Object? estado = null,Object? total = null,Object? lineas = null,Object? clienteNombre = null,Object? clienteTelefono = null,Object? clienteCif = null,Object? codigo = null,Object? nDocumento = null,Object? serie = null,Object? serieNombre = null,Object? comercial = null,Object? comercialNombre = null,Object? almacen = null,Object? almacenNombre = null,Object? fecha = null,Object? previstoPara = null,Object? formaPago = null,Object? formaPagoNombre = null,Object? direccionEnvio = null,Object? email = null,Object? observaciones = null,}) {
  return _then(_Pedido(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int?,numeroPedido: null == numeroPedido ? _self.numeroPedido : numeroPedido // ignore: cast_nullable_to_non_nullable
as String,clienteId: null == clienteId ? _self.clienteId : clienteId // ignore: cast_nullable_to_non_nullable
as int,estado: null == estado ? _self.estado : estado // ignore: cast_nullable_to_non_nullable
as String,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as double,lineas: null == lineas ? _self._lineas : lineas // ignore: cast_nullable_to_non_nullable
as List<LineaPedido>,clienteNombre: null == clienteNombre ? _self.clienteNombre : clienteNombre // ignore: cast_nullable_to_non_nullable
as String,clienteTelefono: null == clienteTelefono ? _self.clienteTelefono : clienteTelefono // ignore: cast_nullable_to_non_nullable
as String,clienteCif: null == clienteCif ? _self.clienteCif : clienteCif // ignore: cast_nullable_to_non_nullable
as String,codigo: null == codigo ? _self.codigo : codigo // ignore: cast_nullable_to_non_nullable
as int,nDocumento: null == nDocumento ? _self.nDocumento : nDocumento // ignore: cast_nullable_to_non_nullable
as int,serie: null == serie ? _self.serie : serie // ignore: cast_nullable_to_non_nullable
as String,serieNombre: null == serieNombre ? _self.serieNombre : serieNombre // ignore: cast_nullable_to_non_nullable
as String,comercial: null == comercial ? _self.comercial : comercial // ignore: cast_nullable_to_non_nullable
as String,comercialNombre: null == comercialNombre ? _self.comercialNombre : comercialNombre // ignore: cast_nullable_to_non_nullable
as String,almacen: null == almacen ? _self.almacen : almacen // ignore: cast_nullable_to_non_nullable
as String,almacenNombre: null == almacenNombre ? _self.almacenNombre : almacenNombre // ignore: cast_nullable_to_non_nullable
as String,fecha: null == fecha ? _self.fecha : fecha // ignore: cast_nullable_to_non_nullable
as String,previstoPara: null == previstoPara ? _self.previstoPara : previstoPara // ignore: cast_nullable_to_non_nullable
as String,formaPago: null == formaPago ? _self.formaPago : formaPago // ignore: cast_nullable_to_non_nullable
as String,formaPagoNombre: null == formaPagoNombre ? _self.formaPagoNombre : formaPagoNombre // ignore: cast_nullable_to_non_nullable
as String,direccionEnvio: null == direccionEnvio ? _self.direccionEnvio : direccionEnvio // ignore: cast_nullable_to_non_nullable
as String,email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,observaciones: null == observaciones ? _self.observaciones : observaciones // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
