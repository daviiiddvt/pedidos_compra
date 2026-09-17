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

@freezed
abstract class OpcionMaestra with _$OpcionMaestra {
  const factory OpcionMaestra({
    required String codigo,
    required String nombre,
  }) = _OpcionMaestra;

  factory OpcionMaestra.fromJson(Map<String, dynamic> json) =>
      _$OpcionMaestraFromJson(json);
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
      _$LineaPedidoFromJson(json);

  double getLineTotal() => importe;
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
      _$ClienteFromJson(json);
}

@freezed
abstract class Pedido with _$Pedido {
  const Pedido._();

  const factory Pedido({
    int? id,
    @JsonKey(name: 'num_ped') @Default('') String numeroPedido,
    @JsonKey(name: 'clt') @Default(0) int clienteId,
    @JsonKey(name: 'est') @Default('S') String estado,
    @JsonKey(name: 'tot_ped') @Default(0.0) double total,
    @Default(<LineaPedido>[]) List<LineaPedido> lineas,
    @Default('') String clienteNombre,
    @Default('') String clienteTelefono,
    @Default('') String clienteCif,
    @Default('') String cliente,
    @Default(0) int codigo,
    @Default(0) int nDocumento,
    @Default('') String serie,
    @Default('') String serieNombre,
    @JsonKey(
      name: 'cmr',
      fromJson: _referenceToString,
      toJson: _referenceToJson,
    )
    @Default('') String comercial,
    @Default('') String comercialNombre,
    @Default('') String almacen,
    @Default('') String almacenNombre,
    @Default('') String fecha,
    @Default('') String previstoPara,
    @Default('') String formaPago,
    @Default('') String formaPagoNombre,
    @Default('') String direccionEnvio,
    @Default('') String email,
    @Default('') String observaciones,
  }) = _Pedido;

  factory Pedido.fromJson(Map<String, dynamic> json) => _$PedidoFromJson(json);

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
  final base = lineas.fold<double>(0.0, (sum, linea) => sum + linea.importe);
  final iva = lineas.fold<double>(
    0.0,
    (sum, linea) => sum + linea.importe * linea.tipoIva / 100,
  );
  return TotalesCalculados(base: base, iva: iva, total: base + iva);
}
