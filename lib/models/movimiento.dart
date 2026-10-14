
class Movimiento {
  final String articuloId;
  final String articuloRef;
  final String articuloNombre;
  final String fecha;
  final double entrada;
  final double salida;
  final double precio;
  final String numDoc;

  const Movimiento({
    required this.articuloId,
    required this.articuloRef,
    required this.articuloNombre,
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
      fecha: s(['FCH', 'fch', 'fecha']),
      entrada: d(['CAN_ENT', 'can_ent']),
      salida: d(['CAN_SAL', 'can_sal']),
      precio: d(['PRE', 'pre', 'precio']),
      numDoc: s(['NUM_DOC', 'num_doc']),
    );
  }
}
