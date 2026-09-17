// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_OpcionMaestra _$OpcionMaestraFromJson(Map<String, dynamic> json) =>
    _OpcionMaestra(
      codigo: json['codigo'] as String,
      nombre: json['nombre'] as String,
    );

Map<String, dynamic> _$OpcionMaestraToJson(_OpcionMaestra instance) =>
    <String, dynamic>{'codigo': instance.codigo, 'nombre': instance.nombre};

_LineaPedido _$LineaPedidoFromJson(Map<String, dynamic> json) => _LineaPedido(
  id: (json['id'] as num?)?.toInt(),
  codigo: (json['codigo'] as num?)?.toInt(),
  articulo: json['articulo'] as String? ?? '',
  articuloNombre: json['articuloNombre'] as String? ?? '',
  descripcion: json['descripcion'] as String? ?? '',
  nReferencia: json['nReferencia'] as String? ?? '',
  referencia: json['referencia'] as String? ?? '',
  referenciaProveedor: json['referenciaProveedor'] as String? ?? '',
  cantidad: (json['cantidad'] as num?)?.toDouble() ?? 1.0,
  pendiente: (json['pendiente'] as num?)?.toDouble() ?? 1.0,
  precio: (json['precio'] as num?)?.toDouble() ?? 0.0,
  dto: (json['dto'] as num?)?.toDouble() ?? 0.0,
  importe: (json['importe'] as num?)?.toDouble() ?? 0.0,
  tipoIva: (json['tipoIva'] as num?)?.toDouble() ?? 21.0,
  retencionIrpf: (json['retencionIrpf'] as num?)?.toDouble() ?? 0.0,
  retencionAlquiler: (json['retencionAlquiler'] as num?)?.toDouble() ?? 0.0,
  clienteVenta: json['clienteVenta'] as String? ?? '',
  estado: json['estado'] as String? ?? 'Pendiente',
  cancelado: json['cancelado'] as bool? ?? false,
  previstoPara: json['previstoPara'] as String? ?? '',
);

Map<String, dynamic> _$LineaPedidoToJson(_LineaPedido instance) =>
    <String, dynamic>{
      'id': instance.id,
      'codigo': instance.codigo,
      'articulo': instance.articulo,
      'articuloNombre': instance.articuloNombre,
      'descripcion': instance.descripcion,
      'nReferencia': instance.nReferencia,
      'referencia': instance.referencia,
      'referenciaProveedor': instance.referenciaProveedor,
      'cantidad': instance.cantidad,
      'pendiente': instance.pendiente,
      'precio': instance.precio,
      'dto': instance.dto,
      'importe': instance.importe,
      'tipoIva': instance.tipoIva,
      'retencionIrpf': instance.retencionIrpf,
      'retencionAlquiler': instance.retencionAlquiler,
      'clienteVenta': instance.clienteVenta,
      'estado': instance.estado,
      'cancelado': instance.cancelado,
      'previstoPara': instance.previstoPara,
    };

_User _$UserFromJson(Map<String, dynamic> json) => _User(
  id: json['id'] as String,
  name: json['name'] as String,
  role: json['role'] as String,
  contactId: json['contactId'] as String? ?? '',
);

Map<String, dynamic> _$UserToJson(_User instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'role': instance.role,
  'contactId': instance.contactId,
};

_Cliente _$ClienteFromJson(Map<String, dynamic> json) => _Cliente(
  id: (json['id'] as num).toInt(),
  nombreComercial: json['nombreComercial'] as String? ?? '',
  cif: json['cif'] as String? ?? '',
  telefono: json['telefono'] as String? ?? '',
);

Map<String, dynamic> _$ClienteToJson(_Cliente instance) => <String, dynamic>{
  'id': instance.id,
  'nombreComercial': instance.nombreComercial,
  'cif': instance.cif,
  'telefono': instance.telefono,
};

_Pedido _$PedidoFromJson(Map<String, dynamic> json) => _Pedido(
  id: (json['id'] as num?)?.toInt(),
  numeroPedido: json['num_ped'] as String? ?? '',
  clienteId: (json['clt'] as num?)?.toInt() ?? 0,
  estado: json['est'] as String? ?? 'S',
  total: (json['tot_ped'] as num?)?.toDouble() ?? 0.0,
  lineas:
      (json['lineas'] as List<dynamic>?)
          ?.map((e) => LineaPedido.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <LineaPedido>[],
  clienteNombre: json['clienteNombre'] as String? ?? '',
  clienteTelefono: json['clienteTelefono'] as String? ?? '',
  clienteCif: json['clienteCif'] as String? ?? '',
  cliente: json['cliente'] as String? ?? '',
  codigo: (json['codigo'] as num?)?.toInt() ?? 0,
  nDocumento: (json['nDocumento'] as num?)?.toInt() ?? 0,
  serie: json['serie'] as String? ?? '',
  serieNombre: json['serieNombre'] as String? ?? '',
  comercial: json['cmr'] == null ? '' : _referenceToString(json['cmr']),
  comercialNombre: json['comercialNombre'] as String? ?? '',
  almacen: json['almacen'] as String? ?? '',
  almacenNombre: json['almacenNombre'] as String? ?? '',
  fecha: json['fecha'] as String? ?? '',
  previstoPara: json['previstoPara'] as String? ?? '',
  formaPago: json['formaPago'] as String? ?? '',
  formaPagoNombre: json['formaPagoNombre'] as String? ?? '',
  direccionEnvio: json['direccionEnvio'] as String? ?? '',
  email: json['email'] as String? ?? '',
  observaciones: json['observaciones'] as String? ?? '',
);

Map<String, dynamic> _$PedidoToJson(_Pedido instance) => <String, dynamic>{
  'id': instance.id,
  'num_ped': instance.numeroPedido,
  'clt': instance.clienteId,
  'est': instance.estado,
  'tot_ped': instance.total,
  'lineas': instance.lineas,
  'clienteNombre': instance.clienteNombre,
  'clienteTelefono': instance.clienteTelefono,
  'clienteCif': instance.clienteCif,
  'cliente': instance.cliente,
  'codigo': instance.codigo,
  'nDocumento': instance.nDocumento,
  'serie': instance.serie,
  'serieNombre': instance.serieNombre,
  'cmr': _referenceToJson(instance.comercial),
  'comercialNombre': instance.comercialNombre,
  'almacen': instance.almacen,
  'almacenNombre': instance.almacenNombre,
  'fecha': instance.fecha,
  'previstoPara': instance.previstoPara,
  'formaPago': instance.formaPago,
  'formaPagoNombre': instance.formaPagoNombre,
  'direccionEnvio': instance.direccionEnvio,
  'email': instance.email,
  'observaciones': instance.observaciones,
};
