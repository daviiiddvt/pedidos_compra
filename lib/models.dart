import 'package:freezed_annotation/freezed_annotation.dart';

part 'models.freezed.dart';
part 'models.g.dart';

String _referenceToString(dynamic value) {
  if (value is Map) {
    return '${value['id'] ?? value['value'] ?? ''}';
  }
  return value == null ? '' : '$value';
}

dynamic _referenceToJson(String value) => value;

dynamic _firstValue(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    if (json.containsKey(key) && json[key] != null) return json[key];
  }
  return null;
}

String _textValue(dynamic value) {
  if (value is Map) {
    return '${value['id'] ?? value['value'] ?? ''}';
  }
  return value == null ? '' : '$value';
}

int _intValue(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse(_textValue(value)) ?? 0;
}

double _doubleValue(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(_textValue(value).replaceAll(',', '.')) ?? 0.0;
}

double _ivaValue(dynamic value) {
  final text = _textValue(value).toUpperCase();
  switch (text) {
    case 'G':
      return 21.0;
    case 'R':
      return 10.0;
    case 'S':
      return 4.0;
    case 'E':
      return 0.0;
    default:
      return _doubleValue(value);
  }
}

bool _boolValue(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  return ['true', '1', 's', 'si', 'sí'].contains(_textValue(value).toLowerCase());
}

Map<String, dynamic> _normalizeLineaJson(Map<String, dynamic> json) {
  final normalized = Map<String, dynamic>.from(json);
  final aliases = <String, List<String>>{
    'id': ['id', 'id_reg'],
    'codigo': ['codigo', 'cod'],
    'articulo': ['art', 'articulo'],
    'articuloNombre': ['art_nom', 'art_name', 'nombre_articulo', 'articuloNombre'],
    'descripcion': ['dsc', 'descripcion'],
    'nReferencia': ['ref_man', 'nReferencia'],
    'referencia': ['ref', 'referencia'],
    'referenciaProveedor': ['ref_prov', 'referenciaProveedor'],
    'cantidad': ['can_ped', 'cantidad'],
    'cantidadServida': ['can_srv', 'can_ser', 'cantidadServida', 'servida'],
    'pendiente': ['can_pte', 'can_pdt', 'pendiente', 'cantidadPendiente'],
    'precio': ['pre', 'precio'],
    'dto': ['por_dto', 'dto'],
    'importe': ['imp', 'importe'],
    'tipoIva': ['por_iva', 'tipo_iva', 'reg_iva_vta', 'tipoIva'],
    'retencionIrpf': ['por_irpf', 'retencionIrpf'],
    'retencionAlquiler': ['por_alq', 'retencionAlquiler'],
    'clienteVenta': ['clt_vta', 'clienteVenta'],
    'estado': ['est', 'estado'],
    'cancelado': ['cnc', 'cancelado'],
    'previstoPara': ['fch_ent', 'previstoPara'],
  };
  for (final entry in aliases.entries) {
    final value = _firstValue(json, entry.value);
    if (value == null) continue;
    if (['cantidad', 'cantidadServida', 'pendiente', 'precio', 'dto', 'importe',
        'retencionIrpf', 'retencionAlquiler', 'tipoIva']
        .contains(entry.key)) {
      normalized[entry.key] = entry.key == 'tipoIva'
        ? _ivaValue(value)
        : _doubleValue(value);
    } else if (entry.key == 'id' || entry.key == 'codigo') {
      normalized[entry.key] = _intValue(value);
    } else if (entry.key == 'cancelado') {
      normalized[entry.key] = _boolValue(value);
    } else {
      normalized[entry.key] = _textValue(value);
    }
  }
  return normalized;
}

Map<String, dynamic> _normalizePedidoJson(Map<String, dynamic> json) {
  final normalized = Map<String, dynamic>.from(json);
  final aliases = <String, List<String>>{
    'id': ['id', 'id_reg', 'codigo'],
    'n_doc': ['n_doc', 'num_doc', 'nDocumento'],
    'cliente': ['clt', 'cliente'],
    'clt': ['clt', 'clienteId'],
    'tot_ped': ['tot_ped', 'total'],
    'clienteNombre': ['clt_nom', 'clt_name', 'nom_com', 'clienteNombre'],
    'ser': ['ser', 'serie'],
    'ser_nom': ['ser_nom', 'serieNombre'],
    'fch': ['fch', 'fecha'],
    'fch_ent': ['fch_ent', 'previstoPara'],
    'fpg': ['fpg', 'formaPago'],
    'fpg_nom': ['fpg_nom', 'formaPagoNombre'],
    'dir_env': ['dir_env', 'dir_env_man', 'direccionEnvio'],
    'email': ['email', 'mail'],
    'obs': ['obs', 'observaciones'],
    'cmr_nom': ['cmr_nom', 'comercialNombre'],
    'alm': ['alm', 'almacen'],
    'alm_nom': ['alm_nom', 'almacenNombre'],
    'codigo': ['codigo', 'cod'],
  };
  for (final entry in aliases.entries) {
    final value = _firstValue(json, entry.value);
    if (value != null) {
      if (['id', 'n_doc', 'clt', 'codigo'].contains(entry.key)) {
        normalized[entry.key] = _intValue(value);
      } else if (entry.key == 'tot_ped') {
        normalized[entry.key] = _doubleValue(value);
      } else {
        normalized[entry.key] = _textValue(value);
      }
    }
  }
  return normalized;
}

@freezed
abstract class OpcionMaestra with _$OpcionMaestra {
  const factory OpcionMaestra({
    required String codigo,
    required String nombre,
  }) = _OpcionMaestra;

  factory OpcionMaestra.fromJson(Map<String, dynamic> json) =>
      _$OpcionMaestraFromJson({
        'codigo': _textValue(_firstValue(json, ['codigo', 'id', 'code'])),
        'nombre': _textValue(
          _firstValue(json, ['nombre', 'name', 'nom_com', 'descripcion']),
        ),
      });
}

@freezed
abstract class LineaPedido with _$LineaPedido {
  const LineaPedido._();

  const factory LineaPedido({
    int? id,
    int? codigo,
    @Default('') String articulo,
    @Default('') String articuloNombre,
    @Default('') String descripcion,
    @Default('') String nReferencia,
    @Default('') String referencia,
    @Default('') String referenciaProveedor,
    @Default(1.0) double cantidad,
    @Default(0.0) double cantidadServida,
    @Default(1.0) double pendiente,
    @Default(0.0) double precio,
    @Default(0.0) double dto,
    @Default(0.0) double importe,
    @Default(21.0) double tipoIva,
    @Default(0.0) double retencionIrpf,
    @Default(0.0) double retencionAlquiler,
    @Default('') String clienteVenta,
    @Default('Pendiente') String estado,
    @Default(false) bool cancelado,
    @Default('') String previstoPara,
  }) = _LineaPedido;

    factory LineaPedido.fromJson(Map<String, dynamic> json) =>
      _$LineaPedidoFromJson(_normalizeLineaJson(json));

  double getLineTotal() {
    if (importe != 0.0) return importe;
    final base = cantidad * precio;
    return base - base * (dto / 100);
  }

  double get pendienteCalculada => cantidad - cantidadServida;
}

@freezed
abstract class User with _$User {
  const factory User({
    required String id,
    required String name,
    required String role,
    @Default('') String contactId,
  }) = _User;

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
}

@freezed
abstract class Cliente with _$Cliente {
  const factory Cliente({
    required int id,
    @Default('') String nombreComercial,
    @Default('') String cif,
    @Default('') String telefono,
  }) = _Cliente;

  factory Cliente.fromJson(Map<String, dynamic> json) =>
      _$ClienteFromJson({
        'id': _intValue(_firstValue(json, ['id', 'codigo'])),
        'nombreComercial': _textValue(
          _firstValue(json, ['nom_com', 'name', 'nombreComercial']),
        ),
        'cif': _textValue(_firstValue(json, ['cif', 'nif'])),
        'telefono': _textValue(_firstValue(json, ['tlf', 'telefono', 'tel'])),
      });
}

@freezed
abstract class Pedido with _$Pedido {
  const Pedido._();

  const factory Pedido({
    int? id,
    @JsonKey(name: 'num_ped') @Default('') String numeroPedido,
    @JsonKey(name: 'clt') @Default(0) int clienteId,
    @JsonKey(name: 'est') @Default('P') String estado,
    @JsonKey(name: 'tot_ped') @Default(0.0) double total,
    @Default(<LineaPedido>[]) List<LineaPedido> lineas,
    @Default('') String clienteNombre,
    @Default('') String clienteTelefono,
    @Default('') String clienteCif,
    @Default('') String cliente,
    @Default(0) int codigo,
    @JsonKey(name: 'n_doc') @Default(0) int nDocumento,
    @JsonKey(name: 'ser') @Default('') String serie,
    @JsonKey(name: 'ser_nom') @Default('') String serieNombre,
    @JsonKey(
      name: 'cmr',
      fromJson: _referenceToString,
      toJson: _referenceToJson,
    )
    @Default('') String comercial,
    @JsonKey(name: 'cmr_nom') @Default('') String comercialNombre,
    @JsonKey(name: 'alm') @Default('') String almacen,
    @JsonKey(name: 'alm_nom') @Default('') String almacenNombre,
    @JsonKey(name: 'fch') @Default('') String fecha,
    @JsonKey(name: 'fch_ent') @Default('') String previstoPara,
    @JsonKey(name: 'fpg') @Default('') String formaPago,
    @JsonKey(name: 'fpg_nom') @Default('') String formaPagoNombre,
    @JsonKey(name: 'dir_env') @Default('') String direccionEnvio,
    @JsonKey(name: 'email') @Default('') String email,
    @JsonKey(name: 'obs') @Default('') String observaciones,
  }) = _Pedido;

  factory Pedido.fromJson(Map<String, dynamic> json) =>
      _$PedidoFromJson(_normalizePedidoJson(json));

  String get nPedido => numeroPedido;
  String get proveedor => clienteNombre;
  String get proveedorNombre => clienteNombre;

  double calcularTotales() => lineas.fold(
        0.0,
        (total, linea) => total + linea.getLineTotal(),
      );
}

class TotalesCalculados {
  final double base;
  final double iva;
  final double total;

  const TotalesCalculados({
    required this.base,
    required this.iva,
    required this.total,
  });
}

TotalesCalculados calcularTotales(List<LineaPedido> lineas) {
  final base = lineas.fold<double>(
    0.0,
    (sum, linea) => sum + linea.getLineTotal(),
  );
  final iva = lineas.fold<double>(
    0.0,
    (sum, linea) => sum + linea.getLineTotal() * linea.tipoIva / 100,
  );
  return TotalesCalculados(base: base, iva: iva, total: base + iva);
}
