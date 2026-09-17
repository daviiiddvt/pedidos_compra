import 'package:freezed_annotation/freezed_annotation.dart';

part 'models.freezed.dart';
part 'models.g.dart';

// Utility functions
String regIvaCodigo(double tipoIva) {
  if (tipoIva >= 9 && tipoIva <= 11) return 'R'; 
  if (tipoIva >= 3 && tipoIva <= 5) return 'S'; 
  if (tipoIva <= 0.5) return 'E'; 
  return 'G'; 
}

double regIvaPct(String codigo) {
  switch (codigo.toUpperCase()) {
    case 'R': return 10;
    case 'S': return 4;
    case 'E': return 0;
    case 'G':
    default: return 21;
  }
}

// Alias para compatibilidad con código existente
typedef Order = Pedido;
typedef OrderLine = LineaPedido;

@freezed
class OpcionMaestra with _$OpcionMaestra {
  const factory OpcionMaestra({
    required String codigo,
    required String nombre,
  }) = _OpcionMaestra;

  factory OpcionMaestra.fromJson(Map<String, dynamic> json) => _$OpcionMaestraFromJson(json);
}

@freezed
class LineaPedido with _$LineaPedido {
  const factory LineaPedido({
    int? id,
    int? codigo,
    @Default('') String articulo,
    @Default('') String descripcion,
    @Default('') String nReferencia,
    @Default(1.0) double cantidad,
    @Default(1.0) double pendiente,
    @Default(0.0) double precio,
    @Default(0.0) double dto,
    @Default(0.0) double importe,
    @Default(21.0) double tipoIva,
    @Default('Pendiente') String estado,
    @Default(false) bool cancelado,
    @Default('') String previstoPara,
  }) = _LineaPedido;

  factory LineaPedido.fromJson(Map<String, dynamic> json) => _$LineaPedidoFromJson(json);
}

@freezed
class User with _$User {
  const factory User({
    required String id,
    required String name,
    required String role, // 'Admin' o 'Comercial'
    @Default([]) List<String> assignedCustomerIds,
  }) = _User;

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
}

@freezed
class Cliente with _$Cliente {
  const factory Cliente({
    required int id,
    @JsonKey(name: 'nom_com') @Default('') String nombreComercial,
    @JsonKey(name: 'cif') @Default('') String cif,
    @JsonKey(name: 'tlf') @Default('') String telefono,
  }) = _Cliente;

  factory Cliente.fromJson(Map<String, dynamic> json) => _$ClienteFromJson(json);
}

@freezed
class Pedido with _$Pedido {
  const factory Pedido({
    int? id,
    @JsonKey(name: 'num_ped') @Default('') String numeroPedido,
    @JsonKey(name: 'clt') required int clienteId,
    @JsonKey(name: 'est') @Default('S') String estado,
    @JsonKey(name: 'tot_ped') @Default(0.0) double total,
    @Default([]) List<LineaPedido> lineas,
    
    // Campos enriquecidos
    @Default('') String clienteNombre,
    @Default('') String clienteTelefono,
    @Default('') String clienteCif,
    
    // Campos de compatibilidad (mapeados de Velneo o defaults)
    @Default(0) int codigo,
    @Default(0) int nDocumento,
    @Default('') String serie,
    @Default('') String serieNombre,
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
}

// Extensión para compatibilidad de campos y métodos antiguos
extension PedidoCompat on Pedido {
  String get nPedido => numeroPedido;
  String get cliente => clienteNombre;
  int get codigo => id ?? 0;
  String get fecha => '';
  
  double calcularTotales() {
    return lineas.fold(0.0, (sum, item) => sum + item.importe);
  }
}

extension LineaPedidoCompat on LineaPedido {
  String get articuloNombre => articulo;
  double get retencionIrpf => 0.0;
  double get retencionAlquiler => 0.0;
}
