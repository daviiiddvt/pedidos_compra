class Articulo {
  final String id;
  final String codigo;
  final String referencia;
  final String nombre;
  final String familiaId;
  final String familiaNombre;
  final String proveedorId;
  final String proveedorNombre;
  final String codigoBarras;
  final double precio;
  final String imagen;
  final bool desactivado;

  const Articulo({
    this.id = '',
    this.codigo = '',
    this.referencia = '',
    this.nombre = '',
    this.familiaId = '',
    this.familiaNombre = '',
    this.proveedorId = '',
    this.proveedorNombre = '',
    this.codigoBarras = '',
    this.precio = 0.0,
    this.imagen = '',
    this.desactivado = false,
  });

  /// Devuelve true si el artículo tiene una familia asignada (FAM_M tiene valor y no es '0').
  bool get tieneFamilia {
    final fam = familiaId.trim();
    if (fam.isNotEmpty && fam != '0' && fam.toLowerCase() != 'null') return true;
    final nom = familiaNombre.trim();
    return nom.isNotEmpty && nom != '0' && nom.toLowerCase() != 'null';
  }

  Articulo copyWith({
    String? id,
    String? codigo,
    String? referencia,
    String? nombre,
    String? familiaId,
    String? familiaNombre,
    String? proveedorId,
    String? proveedorNombre,
    String? codigoBarras,
    double? precio,
    String? imagen,
    bool? desactivado,
  }) {
    return Articulo(
      id: id ?? this.id,
      codigo: codigo ?? this.codigo,
      referencia: referencia ?? this.referencia,
      nombre: nombre ?? this.nombre,
      familiaId: familiaId ?? this.familiaId,
      familiaNombre: familiaNombre ?? this.familiaNombre,
      proveedorId: proveedorId ?? this.proveedorId,
      proveedorNombre: proveedorNombre ?? this.proveedorNombre,
      codigoBarras: codigoBarras ?? this.codigoBarras,
      precio: precio ?? this.precio,
      imagen: imagen ?? this.imagen,
      desactivado: desactivado ?? this.desactivado,
    );
  }

  factory Articulo.fromJson(Map<String, dynamic> json) {
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
        return '${val['name'] ?? val['nom'] ?? val['name'] ?? val['id'] ?? val['value'] ?? ''}';
      }
      return val == null ? '' : '$val'.trim();
    }

    String refId(List<String> keys) {
      final val = resolveField(keys);
      if (val == null || val is bool) return '';
      if (val is Map) {
        return '${val['id'] ?? val['value'] ?? ''}'.trim();
      }
      return '$val'.trim();
    }

    String refName(List<String> keys) {
      final val = resolveField(keys);
      if (val is Map) {
        final name = '${val['name'] ?? val['nom'] ?? val['name'] ?? val['descripcion'] ?? ''}';
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

    bool boolVal(List<String> keys) {
      final val = resolveField(keys);
      if (val is bool) return val;
      if (val is num) return val != 0;
      if (val is String) {
        final lower = val.trim().toLowerCase();
        return lower == '1' || lower == 'true' || lower == 's' || lower == 'si' || lower == 'sí';
      }
      return false;
    }

    final id = text(['id', 'ID', 'art', 'ART', 'codigo', 'CODIGO']);
    final codigo = text(['art', 'ART', 'codigo', 'CODIGO', 'id', 'ID']);
    final referencia = text([
      'REF',
      'ref',
      'nReferencia',
      'referencia',
      'n_ref',
      'N_REF',
      'ref_art',
      'ART_REF',
      'art_ref',
    ]);
    final nombre = text([
      'NAME',
      'name',
      'nombre',
      'nom',
      'NOM',
      'nom_art',
      'art_nom',
      'ART_NOM',
      'descripcion',
      'dsc',
      'DSC',
      'des',
    ]);
    final familiaId = refId(['FAM_M', 'fam_m', 'FAM', 'fam', 'id_fam', 'familia']);
    final familiaNombre = refName(['FAM_M', 'fam_m', 'FAM', 'fam', 'familia']);
    final proveedorId = refId(['PRV', 'prv', 'id_prv', 'proveedor', 'ent']);
    final proveedorNombre = refName(['PRV', 'prv', 'proveedor']);
    final codigoBarras = text([
      'COD_BAR',
      'cod_bar',
      'codigo_barras',
      'codbar',
      'ean',
      'EAN',
      'cod_ean',
    ]);
    final precio = numVal(['PVP', 'pvp', 'pre', 'precio', 'tarifa', 'imp']);
    final imagen = text(['IMG', 'img', 'foto', 'fotoBase64', 'imagen', 'img_art']);
    final desactivado = boolVal([
      'OFF',
      'off',
      'desactivado',
      'DESACTIVADO',
      'art_off',
      'ART_OFF',
    ]);

    return Articulo(
      id: id,
      codigo: codigo,
      referencia: referencia,
      nombre: nombre,
      familiaId: familiaId,
      familiaNombre: familiaNombre,
      proveedorId: proveedorId,
      proveedorNombre: proveedorNombre,
      codigoBarras: codigoBarras,
      precio: precio,
      imagen: imagen,
      desactivado: desactivado,
    );
  }
}
