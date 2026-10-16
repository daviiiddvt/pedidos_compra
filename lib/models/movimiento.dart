
class Movimiento {
  final String articuloId;
  final String articuloRef;
  final String articuloNombre;
  final String clienteId;
  final String fecha;
  final double entrada;
  final double salida;
  final double precio;
  final String numDoc;

  const Movimiento({
    required this.articuloId,
    required this.articuloRef,
    required this.articuloNombre,
    this.clienteId = '',
    required this.fecha,
    required this.entrada,
    required this.salida,
    required this.precio,
    required this.numDoc,
  });

  Movimiento copyWith({
    String? articuloId,
    String? articuloRef,
    String? articuloNombre,
    String? clienteId,
    String? fecha,
    double? entrada,
    double? salida,
    double? precio,
    String? numDoc,
  }) {
    return Movimiento(
      articuloId: articuloId ?? this.articuloId,
      articuloRef: articuloRef ?? this.articuloRef,
      articuloNombre: articuloNombre ?? this.articuloNombre,
      clienteId: clienteId ?? this.clienteId,
      fecha: fecha ?? this.fecha,
      entrada: entrada ?? this.entrada,
      salida: salida ?? this.salida,
      precio: precio ?? this.precio,
      numDoc: numDoc ?? this.numDoc,
    );
  }

  factory Movimiento.fromJson(Map<String, dynamic> json) {
    String s(List<String> keys) {
      for (final k in keys) {
        if (json.containsKey(k) && json[k] != null) return json[k].toString();
      }
      return '';
    }

    double d(List<String> keys) {
      for (final k in keys) {
        if (json.containsKey(k) && json[k] != null) {
          final val = json[k];
          if (val is num) return val.toDouble();
          return double.tryParse(val.toString().replaceAll(',', '.')) ?? 0.0;
        }
      }
      return 0.0;
    }

    return Movimiento(
      articuloId: s(['ART', 'art']),
      articuloRef: s(['ART.REF', 'art.ref', 'ref']),
      articuloNombre: s(['ART.NAME', 'art.name', 'name']),
      clienteId: s(['CLT_ENT', 'clt_ent', 'CLT', 'clt', 'cliente']),
      fecha: s(['FCH', 'fch', 'fecha']),
      entrada: d(['CAN_ENT', 'can_ent']),
      salida: d(['CAN_SAL', 'can_sal']),
      precio: d(['PRE', 'pre', 'precio']),
      numDoc: s(['NUM_DOC', 'num_doc']),
    );
  }

  Map<String, dynamic> toJson() => {
        'ART': articuloId,
        'ART.REF': articuloRef,
        'ART.NAME': articuloNombre,
        'CLT_ENT': clienteId,
        'FCH': fecha,
        'CAN_ENT': entrada,
        'CAN_SAL': salida,
        'PRE': precio,
        'NUM_DOC': numDoc,
      };
}
