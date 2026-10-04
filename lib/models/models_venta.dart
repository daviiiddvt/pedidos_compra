import 'models.dart';

String _text(dynamic value) {
  if (value is Map) return '${value['id'] ?? value['value'] ?? ''}';
  return value == null ? '' : '$value';
}

int _int(dynamic value) => int.tryParse(_text(value)) ?? 0;
double _double(dynamic value) =>
    double.tryParse(_text(value).replaceAll(',', '.')) ?? 0;

String _date(dynamic value) => _text(value);

class LineaPedidoVenta {
  final int? id;
  final int? codigo;
  final String articulo;
  final String articuloNombre;
  final String descripcion;
  final String nReferencia;
  final String referencia;
  final String referenciaProveedor;
  final double cantidad;
  final double cantidadServida;
  final double pendiente;
  final double precio;
  final double dto;
  final double importe;
  final double tipoIva;
  final String regIvaVta;
  final double retencionIrpf;
  final double retencionAlquiler;
  final String clienteVenta;
  final String estado;
  final bool cancelado;
  final String previstoPara;

  const LineaPedidoVenta({
    this.id,
    this.codigo,
    this.articulo = '',
    this.articuloNombre = '',
    this.descripcion = '',
    this.nReferencia = '',
    this.referencia = '',
    this.referenciaProveedor = '',
    this.cantidad = 1,
    this.cantidadServida = 0,
    this.pendiente = 1,
    this.precio = 0,
    this.dto = 0,
    this.importe = 0,
    this.tipoIva = 21,
    this.regIvaVta = 'G',
    this.retencionIrpf = 0,
    this.retencionAlquiler = 0,
    this.clienteVenta = '',
    this.estado = 'Pendiente',
    this.cancelado = false,
    this.previstoPara = '',
  });

  factory LineaPedidoVenta.fromJson(Map<String, dynamic> json) =>
      LineaPedidoVenta(
        id: json['id'] == null ? null : _int(json['id']),
        codigo: json['codigo'] == null ? null : _int(json['codigo']),
        articulo: _text(json['art'] ?? json['articulo']),
        articuloNombre: _text(json['art_nom'] ?? json['articuloNombre']),
        descripcion: _text(json['dsc'] ?? json['descripcion']),
        nReferencia: _text(json['ref_man'] ?? json['nReferencia']),
        referencia: _text(json['ref'] ?? json['referencia']),
        referenciaProveedor: _text(
          json['ref_prov'] ?? json['referenciaProveedor'],
        ),
        cantidad: _double(json['can_ped'] ?? json['cantidad']),
        cantidadServida: _double(json['can_srv'] ?? json['can_ser']),
        pendiente: _double(json['can_pte'] ?? json['can_pdt']),
        precio: _double(json['pre'] ?? json['precio']),
        dto: _double(json['por_dto'] ?? json['dto']),
        importe: _double(json['imp'] ?? json['importe']),
        tipoIva: _double(
          json['por_iva'] ?? json['tipo_iva'] ?? json['reg_iva_vta'],
        ),
        regIvaVta: _text(json['reg_iva_vta'] ?? json['regIvaVta'] ?? json['reg_iva']).isNotEmpty ? _text(json['reg_iva_vta'] ?? json['regIvaVta'] ?? json['reg_iva']).toUpperCase() : 'G',
        estado: _text(json['est'] ?? json['estado']),
        cancelado: json['cnc'] == true || json['cnc'] == 1,
        previstoPara: _date(json['fch_ent'] ?? json['previstoPara']),
      );

  LineaPedidoVenta copyWith({
    int? id,
    int? codigo,
    String? articulo,
    String? articuloNombre,
    String? descripcion,
    String? nReferencia,
    String? referencia,
    String? referenciaProveedor,
    double? cantidad,
    double? cantidadServida,
    double? pendiente,
    double? precio,
    double? dto,
    double? importe,
    double? tipoIva,
    String? regIvaVta,
    double? retencionIrpf,
    double? retencionAlquiler,
    String? clienteVenta,
    String? estado,
    bool? cancelado,
    String? previstoPara,
  }) => LineaPedidoVenta(
    id: id ?? this.id,
    codigo: codigo ?? this.codigo,
    articulo: articulo ?? this.articulo,
    articuloNombre: articuloNombre ?? this.articuloNombre,
    descripcion: descripcion ?? this.descripcion,
    nReferencia: nReferencia ?? this.nReferencia,
    referencia: referencia ?? this.referencia,
    referenciaProveedor: referenciaProveedor ?? this.referenciaProveedor,
    cantidad: cantidad ?? this.cantidad,
    cantidadServida: cantidadServida ?? this.cantidadServida,
    pendiente: pendiente ?? this.pendiente,
    precio: precio ?? this.precio,
    dto: dto ?? this.dto,
    importe: importe ?? this.importe,
    tipoIva: tipoIva ?? this.tipoIva,
    regIvaVta: regIvaVta ?? this.regIvaVta,
    retencionIrpf: retencionIrpf ?? this.retencionIrpf,
    retencionAlquiler: retencionAlquiler ?? this.retencionAlquiler,
    clienteVenta: clienteVenta ?? this.clienteVenta,
    estado: estado ?? this.estado,
    cancelado: cancelado ?? this.cancelado,
    previstoPara: previstoPara ?? this.previstoPara,
  );

  double get importeTotal => getLineTotal();

  double getLineTotal() =>
      importe != 0 ? importe : cantidad * precio * (1 - dto / 100);
}

class LineaPresupuestoVenta {
  final int? id;
  final String articulo;
  final String articuloNombre;
  final String descripcion;
  final double cantidad;
  final double precio;
  final double dto;
  final double importe;
  final double tipoIva;
  final String regIvaVta;
  final String estado;

  const LineaPresupuestoVenta({
    this.id,
    this.articulo = '',
    this.articuloNombre = '',
    this.descripcion = '',
    this.cantidad = 1,
    this.precio = 0,
    this.dto = 0,
    this.importe = 0,
    this.tipoIva = 21,
    this.regIvaVta = 'G',
    this.estado = 'Pendiente',
  });

  factory LineaPresupuestoVenta.fromJson(Map<String, dynamic> json) =>
      LineaPresupuestoVenta(
        id: json['id'] == null ? null : _int(json['id']),
        articulo: _text(json['art']),
        articuloNombre: _text(json['art_nom'] ?? json['articuloNombre'] ?? json['dsc_edt']),
        descripcion: _text(json['dsc'] ?? json['descripcion'] ?? json['dsc_edt']),
        cantidad: _double(json['can'] ?? json['cantidad']),
        precio: _double(json['pre'] ?? json['precio']),
        dto: _double(json['por_dto'] ?? json['dto']),
        importe: _double(json['imp'] ?? json['importe']),
        tipoIva: _double(
          json['por_iva'] ?? json['tipo_iva'] ?? json['reg_iva_vta'],
        ),
        regIvaVta: _text(json['reg_iva_vta'] ?? json['regIvaVta'] ?? json['reg_iva']).isNotEmpty ? _text(json['reg_iva_vta'] ?? json['regIvaVta'] ?? json['reg_iva']).toUpperCase() : 'G',
        estado: _text(json['est'] ?? json['estado']),
      );

  LineaPresupuestoVenta copyWith({
    int? id,
    String? articulo,
    String? articuloNombre,
    String? descripcion,
    double? cantidad,
    double? precio,
    double? dto,
    double? importe,
    double? tipoIva,
    String? regIvaVta,
    String? estado,
  }) => LineaPresupuestoVenta(
    id: id ?? this.id,
    articulo: articulo ?? this.articulo,
    articuloNombre: articuloNombre ?? this.articuloNombre,
    descripcion: descripcion ?? this.descripcion,
    cantidad: cantidad ?? this.cantidad,
    precio: precio ?? this.precio,
    dto: dto ?? this.dto,
    importe: importe ?? this.importe,
    tipoIva: tipoIva ?? this.tipoIva,
    regIvaVta: regIvaVta ?? this.regIvaVta,
    estado: estado ?? this.estado,
  );

  double get importeTotal => getLineTotal();

  double getLineTotal() =>
      importe != 0 ? importe : cantidad * precio * (1 - dto / 100);
}

class PedidoVenta {
  final int? id;
  final String numeroPedido;
  final int clienteId;
  final String estado;
  final double total;
  final List<LineaPedidoVenta> lineas;
  final String cliente;
  final String clienteNombre;
  final String serie;
  final String comercial;
  final String almacen;
  final String fecha;
  final String previstoPara;
  final String formaPago;
  final String direccionEnvio;
  final String email;
  final String observaciones;

  const PedidoVenta({
    this.id,
    this.numeroPedido = '',
    this.clienteId = 0,
    this.estado = 'P',
    this.total = 0,
    this.lineas = const [],
    this.cliente = '',
    this.clienteNombre = '',
    this.serie = '',
    this.comercial = '',
    this.almacen = '',
    this.fecha = '',
    this.previstoPara = '',
    this.formaPago = '',
    this.direccionEnvio = '',
    this.email = '',
    this.observaciones = '',
  });
}

class PresupuestoVenta {
  final int? id;
  final String numeroPresupuesto;
  final int clienteId;
  final String estado;
  final double total;
  final List<LineaPresupuestoVenta> lineas;
  final String cliente;
  final String clienteNombre;
  final String serie;
  final String serieNombre;
  final String comercial;
  final String comercialNombre;
  final String fecha;
  final String fechaValidez;
  final String formaPago;
  final String formaPagoNombre;
  final String direccionEnvio;
  final String almacen;
  final String almacenNombre;
  final String email;
  final String observaciones;
  final int vtaPedG;

  const PresupuestoVenta({
    this.id,
    this.numeroPresupuesto = '',
    this.clienteId = 0,
    this.estado = 'P',
    this.total = 0.0,
    this.lineas = const [],
    this.cliente = '',
    this.clienteNombre = '',
    this.serie = '',
    this.serieNombre = '',
    this.comercial = '',
    this.comercialNombre = '',
    this.fecha = '',
    this.fechaValidez = '',
    this.formaPago = '',
    this.formaPagoNombre = '',
    this.direccionEnvio = '',
    this.almacen = '',
    this.almacenNombre = '',
    this.email = '',
    this.observaciones = '',
    this.vtaPedG = 0,
  });

  PresupuestoVenta copyWith({
    int? id,
    String? numeroPresupuesto,
    int? clienteId,
    String? estado,
    double? total,
    List<LineaPresupuestoVenta>? lineas,
    String? cliente,
    String? clienteNombre,
    String? serie,
    String? serieNombre,
    String? comercial,
    String? comercialNombre,
    String? fecha,
    String? fechaValidez,
    String? formaPago,
    String? formaPagoNombre,
    String? direccionEnvio,
    String? almacen,
    String? almacenNombre,
    String? email,
    String? observaciones,
    int? vtaPedG,
  }) => PresupuestoVenta(
    id: id ?? this.id,
    numeroPresupuesto: numeroPresupuesto ?? this.numeroPresupuesto,
    clienteId: clienteId ?? this.clienteId,
    estado: estado ?? this.estado,
    total: total ?? this.total,
    lineas: lineas ?? this.lineas,
    cliente: cliente ?? this.cliente,
    clienteNombre: clienteNombre ?? this.clienteNombre,
    serie: serie ?? this.serie,
    serieNombre: serieNombre ?? this.serieNombre,
    comercial: comercial ?? this.comercial,
    comercialNombre: comercialNombre ?? this.comercialNombre,
    fecha: fecha ?? this.fecha,
    fechaValidez: fechaValidez ?? this.fechaValidez,
    formaPago: formaPago ?? this.formaPago,
    formaPagoNombre: formaPagoNombre ?? this.formaPagoNombre,
    direccionEnvio: direccionEnvio ?? this.direccionEnvio,
    almacen: almacen ?? this.almacen,
    almacenNombre: almacenNombre ?? this.almacenNombre,
    email: email ?? this.email,
    observaciones: observaciones ?? this.observaciones,
    vtaPedG: vtaPedG ?? this.vtaPedG,
  );

  factory PresupuestoVenta.fromJson(Map<String, dynamic> json) =>
      PresupuestoVenta(
        id: json['id'] == null ? null : _int(json['id']),
        numeroPresupuesto: _text(json['num_pre']),
        clienteId: _int(json['clt']),
        estado: _text(json['est']),
        total: _double(json['tot_pre'] ?? json['tot_ped']),
        cliente: _text(json['clt']),
        clienteNombre: _text(json['clt_nom'] ?? json['clienteNombre']),
        serie: _text(json['ser']),
        comercial: _text(json['cmr']),
        fecha: _date(json['fch']),
        fechaValidez: _date(json['fch_val']),
        formaPago: _text(json['fpg']),
        direccionEnvio: _text(json['dir_env']),
        email: _text(json['EMAIL_DE_ENVIO_CLT'] ?? json['email_de_envio_clt'] ?? json['email'] ?? json['eml']),
        observaciones: _text(json['obs']),
        vtaPedG: _int(json['VTA_PED_G'] ?? json['vta_ped_g'] ?? json['vtaPedG']),
      );

  double calcularTotal() =>
      lineas.fold(0, (sum, line) => sum + line.getLineTotal());

  Pedido toPedidoVisual() => Pedido(
    id: id,
    numeroPresupuesto: numeroPresupuesto,
    clienteId: clienteId,
    estado: estado,
    total: total,
    lineas: lineas
        .map(
          (linea) => LineaPedido(
            id: linea.id,
            articulo: linea.articulo,
            articuloNombre: linea.articuloNombre,
            descripcion: linea.descripcion,
            cantidad: linea.cantidad,
            precio: linea.precio,
            dto: linea.dto,
            importe: linea.importe,
            tipoIva: linea.tipoIva,
            regIvaVta: linea.regIvaVta,
            estado: linea.estado,
          ),
        )
        .toList(),
    cliente: cliente,
    clienteNombre: clienteNombre,
    serie: serie,
    serieNombre: serieNombre,
    comercial: comercial,
    comercialNombre: comercialNombre,
    fecha: fecha,
    fechaValidez: fechaValidez,
    formaPago: formaPago,
    formaPagoNombre: formaPagoNombre,
    direccionEnvio: direccionEnvio,
    almacen: almacen,
    almacenNombre: almacenNombre,
    email: email,
    observaciones: observaciones,
    vtaPedG: vtaPedG,
  );

  static PresupuestoVenta fromPedidoVisual(Pedido pedido) => PresupuestoVenta(
    id: pedido.id,
    numeroPresupuesto: pedido.numeroPresupuesto,
    clienteId: pedido.clienteId,
    estado: pedido.estado,
    total: pedido.total,
    lineas: pedido.lineas
        .map(
          (linea) => LineaPresupuestoVenta(
            id: linea.id,
            articulo: linea.articulo,
            articuloNombre: linea.articuloNombre,
            descripcion: linea.descripcion,
            cantidad: linea.cantidad,
            precio: linea.precio,
            dto: linea.dto,
            importe: linea.importe,
            tipoIva: linea.tipoIva,
            regIvaVta: linea.regIvaVta,
            estado: linea.estado,
          ),
        )
        .toList(),
    cliente: pedido.cliente,
    clienteNombre: pedido.clienteNombre,
    serie: pedido.serie,
    serieNombre: pedido.serieNombre,
    comercial: pedido.comercial,
    comercialNombre: pedido.comercialNombre,
    fecha: pedido.fecha,
    fechaValidez: pedido.fechaValidez,
    formaPago: pedido.formaPago,
    formaPagoNombre: pedido.formaPagoNombre,
    direccionEnvio: pedido.direccionEnvio,
    almacen: pedido.almacen,
    almacenNombre: pedido.almacenNombre,
    email: pedido.email,
    observaciones: pedido.observaciones,
    vtaPedG: pedido.vtaPedG,
  );
}

OpcionMaestra opcionDesdeCliente(Cliente cliente) =>
    OpcionMaestra(codigo: '${cliente.id}', nombre: cliente.nombreComercial);
