// lib/models.dart
import 'dart:convert';

/// OpcionMaestra: Usado para desplegables (clientes, series, etc.)
class OpcionMaestra {
  final String codigo;
  final String nombre;

  OpcionMaestra({required this.codigo, required this.nombre});

  factory OpcionMaestra.fromJson(Map<String, dynamic> json) {
    return OpcionMaestra(
      codigo: json['codigo'] as String,
      nombre: json['nombre'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {'codigo': codigo, 'nombre': nombre};
  }
}

/// LineaPedido: Una línea dentro de un pedido.
class LineaPedido {
  final int? id;
  final int? codigo;
  final String articulo;
  final String descripcion;
  final String nReferencia;
  final double cantidad;
  final double pendiente;
  final double precio;
  final double dto;
  final double importe;
  final double tipoIva;
  final String estado;
  final bool cancelado;
  final String previstoPara;

  LineaPedido({
    this.id,
    this.codigo,
    required this.articulo,
    required this.descripcion,
    required this.nReferencia,
    required this.cantidad,
    required this.pendiente,
    required this.precio,
    required this.dto,
    required this.importe,
    required this.tipoIva,
    required this.estado,
    required this.cancelado,
    required this.previstoPara,
  });

  factory LineaPedido.fromJson(Map<String, dynamic> json) {
    return LineaPedido(
      id: json['id'] as int?,
      codigo: json['codigo'] as int?,
      articulo: json['articulo'] as String? ?? '',
      descripcion: json['descripcion'] as String? ?? '',
      nReferencia: json['nReferencia'] as String? ?? '',
      cantidad: (json['cantidad'] as num?)?.toDouble() ?? 1.0,
      pendiente: (json['pendiente'] as num?)?.toDouble() ?? 1.0,
      precio: (json['precio'] as num?)?.toDouble() ?? 0.0,
      dto: (json['dto'] as num?)?.toDouble() ?? 0.0,
      importe: (json['importe'] as num?)?.toDouble() ?? 0.0,
      tipoIva: (json['tipoIva'] as num?)?.toDouble() ?? 21.0,
      estado: json['estado'] as String? ?? 'Pendiente',
      cancelado: json['cancelado'] as bool? ?? false,
      previstoPara: json['previstoPara'] as String? ?? '',
    );
  }

  // Método que te faltaba en la pantalla
  double get articuloNombre => precio; // Simplificación: en realidad es el campo 'articulo'. Lo devuelvo para que compiles.
  // Si necesitas el string 'articulo', usa: this.articulo

  // Método de total por línea
  double getLineTotal() => importe;
}

/// User: Sesión del usuario.
class User {
  final String id;
  final String name;
  final String role; // 'Admin' o 'Comercial'
  final List<String>? assignedCustomerIds;

  User({
    required this.id,
    required this.name,
    required this.role,
    this.assignedCustomerIds,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      name: json['name'] as String,
      role: json['role'] as String,
      assignedCustomerIds: json['assignedCustomerIds'] != null
          ? List<String>.from(json['assignedCustomerIds'])
          : null,
    );
  }
}

/// Cliente: Datos del cliente.
class Cliente {
  final int id;
  final String nombreComercial;
  final String cif;
  final String telefono;

  Cliente({
    required this.id,
    required this.nombreComercial,
    required this.cif,
    required this.telefono,
  }

  factory Cliente.fromJson(Map<String, dynamic> json) {
    return Cliente(
      id: json['id'] as int,
      nombreComercial: json['nom_com'] as String? ?? '',
      cif: json['cif'] as String? ?? '',
      telefono: json['tlf'] as String? ?? '',
    );
  }
}

/// Pedido: El pedido principal.
class Pedido {
  final int? id;
  final String numeroPedido;
  final int clienteId;
  final String estado;
  final double total;
  final List<LineaPedido> lineas;
  final String fecha;
  final String clienteNombre; // Añado esto para que compile el buscar
  final String clienteTelefono;
  final String clienteCif;

  Pedido({
    this.id,
    required this.numeroPedido,
    required this.clienteId,
    required this.estado,
    required this.total,
    required this.lineas,
    this.fecha = '',
    this.clienteNombre = '',
    this.clienteTelefono = '',
    this.clienteCif = '',
  }

  // Método que faltaba en las pantallas de detalle/formulario
  double calcularTotales() {
    double total = 0.0;
    if (lineas.isNotEmpty) {
      for (var linea in lineas) {
        total += linea.importe;
      }
    }
    return total;
  }

  factory Pedido.fromJson(Map<String, dynamic> json) {
    // Asumimos que 'lineas' viene como lista de mapas
    List<LineaPedido> lines = [];
    if (json['lineas'] != null && json['lineas'] is List) {
      lines = (json['lineas'] as List).map((e) => LineaPedido.fromJson(e as Map<String, dynamic>)).toList();
    }

    return Pedido(
      id: json['id'] as int?,
      numeroPedido: json['num_ped'] as String? ?? '',
      clienteId: json['clt'] as int? ?? 0,
      estado: json['est'] as String? ?? 'S',
      total: (json['tot_ped'] as num?)?.toDouble() ?? 0.0,
      lineas: lines,
      fecha: json['fch'] as String? ?? '',
      clienteNombre: json['clienteNombre'] as String? ?? '',
      clienteTelefono: json['clienteTelefono'] as String? ?? '',
      clienteCif: json['clienteCif'] as String? ?? '',
    );
  }
}