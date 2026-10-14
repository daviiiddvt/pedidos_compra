class TarifaArticulo {
  final String id;
  final String articuloId;
  final String articuloNombre;
  final String tarifaId;
  final String tarifaNombre;
  final double precio;
  final double descuento;

  const TarifaArticulo({
    this.id = '',
    this.articuloId = '',
    this.articuloNombre = '',
    this.tarifaId = '',
    this.tarifaNombre = '',
    this.precio = 0.0,
    this.descuento = 0.0,
  });

  TarifaArticulo copyWith({
    String? id,
    String? articuloId,
    String? articuloNombre,
    String? tarifaId,
    String? tarifaNombre,
    double? precio,
    double? descuento,
  }) {
    return TarifaArticulo(
      id: id ?? this.id,
      articuloId: articuloId ?? this.articuloId,
      articuloNombre: articuloNombre ?? this.articuloNombre,
      tarifaId: tarifaId ?? this.tarifaId,
      tarifaNombre: tarifaNombre ?? this.tarifaNombre,
      precio: precio ?? this.precio,
      descuento: descuento ?? this.descuento,
    );
  }

  factory TarifaArticulo.fromJson(Map<String, dynamic> json) {
    dynamic resolveField(List<String> keys) {
      for (final key in keys) {
        if (json.containsKey(key) && json[key] != null) return json[key];
        final lower = key.toLowerCase();
        if (json.containsKey(lower) && json[lower] != null) return json[lower];
        final upper = key.toUpperCase();
        if (json.containsKey(upper) && json[upper] != null) return json[upper];
      }
      return null;
    }

    String text(List<String> keys) {
      final val = resolveField(keys);
      if (val is Map) {
        return '${val['name'] ?? val['nom'] ?? val['id'] ?? val['value'] ?? ''}';
      }
      return val == null ? '' : '$val'.trim();
    }

    String refId(List<String> keys) {
      final val = resolveField(keys);
      if (val is Map) {
        return '${val['id'] ?? val['value'] ?? ''}';
      }
      return val == null ? '' : '$val'.trim();
    }

    String refName(List<String> keys) {
      final val = resolveField(keys);
      if (val is Map) {
        final name = '${val['name'] ?? val['nom'] ?? val['descripcion'] ?? ''}';
        if (name.isNotEmpty && name != 'null') return name;
      }
      return '';
    }

    double numVal(List<String> keys) {
      final val = resolveField(keys);
      if (val is num) return val.toDouble();
      if (val is String) {
        return double.tryParse(val.replaceAll(',', '.')) ?? 0.0;
      }
      return 0.0;
    }

    final id = text(['id', 'ID']);
    final articuloId = refId(['ART', 'art']);
    final articuloNombre = refName(['ART', 'art']);
    final tarifaId = refId(['VTA_TAR', 'vta_tar', 'tarifa']);
    final tarifaNombre = refName(['VTA_TAR', 'vta_tar', 'tarifa']);
    final precio = numVal(['PRE', 'pre', 'precio']);
    final descuento = numVal(['POR_DTO', 'por_dto', 'dto', 'descuento']);

    return TarifaArticulo(
      id: id,
      articuloId: articuloId,
      articuloNombre: articuloNombre,
      tarifaId: tarifaId,
      tarifaNombre: tarifaNombre,
      precio: precio,
      descuento: descuento,
    );
  }
}
