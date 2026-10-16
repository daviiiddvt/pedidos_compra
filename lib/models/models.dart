import 'package:freezed_annotation/freezed_annotation.dart';

export 'models_venta.dart';

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
  for (final key in keys) {
    final lowerKey = key.toLowerCase();
    for (final entry in json.entries) {
      if (entry.key.toLowerCase() == lowerKey && entry.value != null) {
        return entry.value;
      }
    }
  }
  return null;
}

String _textValue(dynamic value) {
  if (value is Map) {
    return '${value['id'] ?? value['value'] ?? ''}';
  }
  return value == null ? '' : '$value';
}

String _normalizeOrderStatus(dynamic value) {
  final status = _textValue(value);
  return status.trim().toUpperCase() == 'X' ? 'Q' : status;
}

int _intValue(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse(_textValue(value)) ?? 0;
}

double _doubleValue(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(_textValue(value).replaceAll(',', '.')) ?? 0.0;
}

class RegimenIva {
  final String codigo;
  final String nombre;
  final double porcentaje;

  const RegimenIva({
    required this.codigo,
    required this.nombre,
    required this.porcentaje,
  });

  @override
  String toString() => nombre;
}

const List<RegimenIva> kRegimenesIva = [
  RegimenIva(codigo: 'G', nombre: 'GENERAL', porcentaje: 21.0),
  RegimenIva(codigo: 'R', nombre: 'REDUCIDO', porcentaje: 10.0),
  RegimenIva(codigo: 'S', nombre: 'SÚPER REDUCIDO', porcentaje: 2.0),
  RegimenIva(codigo: 'E', nombre: 'ESPECIAL', porcentaje: 0.0),
  RegimenIva(codigo: 'X', nombre: 'EXENTO', porcentaje: 0.0),
  RegimenIva(codigo: '1', nombre: 'IVA 0%', porcentaje: 0.0),
  RegimenIva(codigo: '2', nombre: 'IVA 5%', porcentaje: 5.0),
  RegimenIva(codigo: '3', nombre: 'OTROS 1', porcentaje: 0.0),
  RegimenIva(codigo: '4', nombre: 'OTROS 2', porcentaje: 0.0),
  RegimenIva(codigo: '5', nombre: 'OTROS 3', porcentaje: 0.0),
];

RegimenIva regimenIvaPorCodigo(String? codigo) {
  final clean = (codigo ?? '').trim().toUpperCase();
  for (final r in kRegimenesIva) {
    if (r.codigo == clean) return r;
  }
  return kRegimenesIva.first;
}

RegimenIva regimenIvaPorPorcentaje(double? porcentaje) {
  if (porcentaje == null) return kRegimenesIva.first;
  if (porcentaje >= 20) return kRegimenesIva[0];
  if (porcentaje >= 10) return kRegimenesIva[1];
  if (porcentaje == 5) return kRegimenesIva[6];
  if (porcentaje >= 2) return kRegimenesIva[2];
  return kRegimenesIva[4];
}

double _ivaValue(dynamic value) {
  final text = _textValue(value).trim().toUpperCase();
  switch (text) {
    case 'G':
      return 21.0;
    case 'R':
      return 10.0;
    case 'S':
        return 2.0;
    case '2':
      return 5.0;
    case 'E':
    case 'X':
    case '1':
    case '3':
    case '4':
    case '5':
    case '0':
      return 0.0;
    default:
      return _doubleValue(value);
  }
}

bool _boolValue(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  return [
    'true',
    '1',
    's',
    'si',
    'sÃ­',
  ].contains(_textValue(value).toLowerCase());
}

Map<String, dynamic> _normalizeLineaJson(
  Map<String, dynamic> json, {
  bool preferCan = false,
}) {
  final normalized = Map<String, dynamic>.from(json);
  final aliases = <String, List<String>>{
    'id': ['id', 'id_reg'],
    'codigo': ['codigo', 'cod'],
    'articulo': ['art', 'articulo'],
    'articuloNombre': [
      'art_nom',
      'art_name',
      'nombre_articulo',
      'articuloNombre', 'dsc_edt'],
    'descripcion': ['dsc', 'descripcion', 'dsc_edt'],
    'nReferencia': ['ref_man', 'nReferencia'],
    'referencia': ['ref', 'referencia'],
    'referenciaProveedor': ['ref_prov', 'referenciaProveedor'],
    'cantidad': preferCan
        ? ['can', 'can_ped', 'cantidad']
        : ['can_ped', 'can', 'cantidad'],
    'cantidadServida': ['can_srv', 'can_ser', 'cantidadServida', 'servida'],
    'pendiente': ['can_pte', 'can_pdt', 'pendiente', 'cantidadPendiente'],
    'precio': ['pre', 'precio'],
    'dto': ['por_dto', 'POR_DTO', 'dto'],
    'dto1': ['DTO1', 'dto1', 'dto_1', 'por_dto_1', 'por_dto1'],
    'dto2': ['DTO2', 'dto2', 'dto_2', 'por_dto_2', 'por_dto2'],
    'dto3': ['DTO3', 'dto3', 'dto_3', 'por_dto_3', 'por_dto3'],
    'importe': ['imp', 'importe'],
    'regIvaVta': ['reg_iva_vta', 'regIvaVta', 'reg_iva'],
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
    if ([
      'cantidad',
      'cantidadServida',
      'pendiente',
      'precio',
      'dto',
      'dto1',
      'dto2',
      'dto3',
      'importe',
      'retencionIrpf',
      'retencionAlquiler',
      'tipoIva',
    ].contains(entry.key)) {
      normalized[entry.key] = entry.key == 'tipoIva'
          ? _ivaValue(value)
          : _doubleValue(value);
    } else if (entry.key == 'id' || entry.key == 'codigo') {
      normalized[entry.key] = _intValue(value);
    } else if (entry.key == 'cancelado') {
      normalized[entry.key] = _boolValue(value);
    } else if (entry.key == 'estado') {
      normalized[entry.key] = _normalizeOrderStatus(value);
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
    'num_pre': ['num_pre', 'numeroPresupuesto'],
    'cliente': ['clt', 'cliente'],
    'clt': ['clt', 'clienteId'],
    'tot_ped': ['tot_ped', 'tot_pre', 'total'],
    'clienteNombre': [
      'clt_nom',
      'CLT_NOM',
      'clt_name',
      'CLT_NAME',
      'clt.name',
      'CLT.NAME',
      'clt.nom',
      'CLT.NOM',
      'name',
      'clienteNombre',
      'cliente_nombre',
      'CLIENTE_NOMBRE',
    ],
    'ser': ['ser', 'serie'],
    'ser_nom': ['ser_nom', 'serieNombre'],
    'vtaPedG': ['vta_ped_g', 'vta_ped', 'VTA_PED_G'],
    'fch': ['fch', 'fecha'],
    'fch_val': ['fch_val', 'fechaValidez'],
    'fch_ent': ['fch_ent', 'previstoPara'],
    'fpg': ['fpg', 'formaPago'],
    'fpg_nom': ['fpg_nom', 'formaPagoNombre'],
    'dir_env': ['dir_env', 'dir_env_man', 'direccionEnvio'],
    'email': ['email', 'mail', 'eml', 'EML', 'EMAIL_DE_ENVIO_CLT'],
    'obs': ['obs', 'OBS', 'observaciones'],
    'cmr_nom': ['cmr_nom', 'comercialNombre'],
    'alm': ['alm', 'almacen'],
    'alm_nom': ['alm_nom', 'almacenNombre'],
    'codigo': ['codigo', 'cod', 'id_reg'],
    'fot': ['fot', 'FOT', 'foto', 'fotoBase64'],
  };
  for (final entry in aliases.entries) {
    final value = _firstValue(json, entry.value);
    if (value != null) {
      if (['id', 'n_doc', 'clt', 'codigo', 'vtaPedG'].contains(entry.key)) {
        normalized[entry.key] = _intValue(value);
      } else if (entry.key == 'tot_ped') {
        normalized[entry.key] = _doubleValue(value);
      } else {
        normalized[entry.key] = _textValue(value);
      }
    }
  }
  final estado = _firstValue(json, ['est', 'estado']);
  if (estado != null && _textValue(estado).trim().toUpperCase() == 'X') {
    normalized['est'] = 'Q';
    normalized['estado'] = 'Q';
  }
  return normalized;
}

@freezed
abstract class OpcionMaestra with _$OpcionMaestra {
  const factory OpcionMaestra({
    required String codigo,
    required String nombre,
    @Default('') String referencia,
  }) = _OpcionMaestra;

  factory OpcionMaestra.fromJson(Map<String, dynamic> json) =>
      _$OpcionMaestraFromJson({
        'codigo': _textValue(_firstValue(json, ['codigo', 'id', 'code'])),
        'nombre': _textValue(
          _firstValue(json, ['nombre', 'name', 'name', 'descripcion']),
        ),
        'referencia': _textValue(
          _firstValue(json, ['referencia', 'ref', 'ref_man', 'REF']),
        ),
      });
}

/// Calcula el importe neto de una línea aplicando descuentos concatenados (en cascada):
/// 1. dto (% Dto. principal, POR_DTO)
/// 2. dto1 (% dto 1, DTO1)
/// 3. dto2 (% dto 2, DTO2)
/// 4. dto3 (% dto 3, DTO3)
double calcularImporteLinea({
  required double cantidad,
  required double precio,
  double dto = 0.0,
  double dto1 = 0.0,
  double dto2 = 0.0,
  double dto3 = 0.0,
}) {
  var subtotal = cantidad * precio;
  if (dto != 0.0) {
    subtotal -= subtotal * (dto / 100);
  }
  if (dto1 != 0.0) {
    subtotal -= subtotal * (dto1 / 100);
  }
  if (dto2 != 0.0) {
    subtotal -= subtotal * (dto2 / 100);
  }
  if (dto3 != 0.0) {
    subtotal -= subtotal * (dto3 / 100);
  }
  return subtotal;
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
    @JsonKey(includeToJson: false) @Default(1.0) double pendiente,
    @Default(0.0) double precio,
    @Default(0.0) double dto,
    @Default(0.0) double dto1,
    @Default(0.0) double dto2,
    @Default(0.0) double dto3,
    @Default(0.0) double importe,
    @Default(21.0) double tipoIva,
    @Default('G') String regIvaVta,
    @Default(0.0) double retencionIrpf,
    @Default(0.0) double retencionAlquiler,
    @Default('') String clienteVenta,
    @Default('Pendiente') String estado,
    @Default(false) bool cancelado,
    @Default('') String previstoPara,
  }) = _LineaPedido;

  factory LineaPedido.fromJson(Map<String, dynamic> json) =>
      _$LineaPedidoFromJson(_normalizeLineaJson(json));

  factory LineaPedido.fromPresupuestoJson(Map<String, dynamic> json) =>
      _$LineaPedidoFromJson(_normalizeLineaJson(json, preferCan: true));

  double get importeTotal => getLineTotal();

  double getLineTotal() {
    if (importe != 0.0) return importe;
    return calcularImporteLinea(
      cantidad: cantidad,
      precio: precio,
      dto: dto,
      dto1: dto1,
      dto2: dto2,
      dto3: dto3,
    );
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
    @Default('') String nombreFiscal,
    @Default('') String cif,
    @Default('') String email,
    @Default('') String telefono,
    @Default(0) int pob,
    @Default(0) int dirPriId,
  }) = _Cliente;

  factory Cliente.fromJson(Map<String, dynamic> json) => _$ClienteFromJson({
    'id': _intValue(_firstValue(json, ['id', 'codigo'])),
    'nombreComercial': _textValue(
      _firstValue(json, ['name', 'nombre', 'nom_fis', 'nombreComercial']),
    ),
    'nombreFiscal': _textValue(
      _firstValue(json, ['nom_fis', 'NOM_FIS', 'name', 'nombreFiscal']),
    ),
    'cif': _textValue(_firstValue(json, ['cif', 'nif'])),
    'email': _textValue(_firstValue(json, ['eml', 'EML', 'email'])),
    'telefono': _textValue(_firstValue(json, ['tlf', 'telefono', 'tel'])),
    'pob': _intValue(_firstValue(json, ['pob', 'POB'])),
    'dirPriId': _intValue(_firstValue(json, ['dir_pri_id', 'DIR_PRI_ID'])),
  });
}

@freezed
abstract class Pedido with _$Pedido {
  const Pedido._();

  const factory Pedido({
    int? id,
    @JsonKey(name: 'num_ped') @Default('') String numeroPedido,
    @JsonKey(name: 'num_pre') @Default('') String numeroPresupuesto,
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
    @Default(0) int vtaPedG,
    @JsonKey(
      name: 'cmr',
      fromJson: _referenceToString,
      toJson: _referenceToJson,
    )
    @Default('')
    String comercial,
    @JsonKey(name: 'cmr_nom') @Default('') String comercialNombre,
    @JsonKey(name: 'alm') @Default('') String almacen,
    @JsonKey(name: 'alm_nom') @Default('') String almacenNombre,
    @JsonKey(name: 'fch') @Default('') String fecha,
    @JsonKey(name: 'fch_val') @Default('') String fechaValidez,
    @JsonKey(name: 'fch_ent') @Default('') String previstoPara,
    @JsonKey(name: 'fpg') @Default('') String formaPago,
    @JsonKey(name: 'fpg_nom') @Default('') String formaPagoNombre,
    @JsonKey(name: 'dir_env') @Default('') String direccionEnvio,
    @JsonKey(name: 'email') @Default('') String email,
    @JsonKey(name: 'obs') @Default('') String observaciones,
    @JsonKey(name: 'fot') @Default('') String fotoBase64,
    @JsonKey(name: 'con_kyr', fromJson: _boolValue) @Default(false) bool conKyr,
  }) = _Pedido;

  factory Pedido.fromJson(Map<String, dynamic> json) =>
      _$PedidoFromJson(_normalizePedidoJson(json));

  String get nPedido => numeroPedido;
  String get nPresupuesto => numeroPresupuesto;
  String get proveedor => clienteNombre;
  String get proveedorNombre => clienteNombre;

  double calcularTotales() =>
      lineas.fold(0.0, (total, linea) => total + linea.getLineTotal());
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
