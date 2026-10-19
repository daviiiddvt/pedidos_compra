import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../models/articulo.dart';
import '../../models/models.dart';
import '../../models/movimiento.dart';
import '../api_service.dart';

/// Gestor de base de datos SQLite para soporte sin conexión (Offline-first).
///
/// Soporta Android, iOS, Windows, macOS y Linux mediante sqflite y sqflite_common_ffi.
class OfflineDatabase {
  static final OfflineDatabase instance = OfflineDatabase._();
  OfflineDatabase._();

  Database? _db;
  bool _initialized = false;

  /// Ruta personalizada para pruebas unitarias.
  String? dbPathOverride;
  DatabaseFactory? factoryOverride;
  void Function()? onOutboxChanged;

  Database get db {
    final d = _db;
    if (d == null || !_initialized) {
      throw StateError('OfflineDatabase no inicializado. Llama a init() antes.');
    }
    return d;
  }

  Future<void> init() async {
    if (_initialized && _db != null && _db!.isOpen) return;

    final factory = factoryOverride ?? _defaultFactory();
    final path = dbPathOverride ?? await _defaultPath(factory);

    _db = await factory.openDatabase(
      path,
      options: sqflite.OpenDatabaseOptions(
        version: 1,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      ),
    );
    await _db!.execute('''
      CREATE TABLE IF NOT EXISTS movimientos_lineas_offline (
        id TEXT PRIMARY KEY,
        articulo_id TEXT NOT NULL,
        cliente_id TEXT NOT NULL DEFAULT '',
        fecha TEXT NOT NULL DEFAULT '',
        num_doc TEXT NOT NULL DEFAULT '',
        json_data TEXT NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    try {
      await _db!.execute('ALTER TABLE movimientos_lineas_offline ADD COLUMN cliente_id TEXT NOT NULL DEFAULT ""');
    } catch (_) {}
    await _db!.execute('CREATE INDEX IF NOT EXISTS idx_mov_lin_art ON movimientos_lineas_offline(articulo_id)');
    await _db!.execute('CREATE INDEX IF NOT EXISTS idx_mov_lin_art_clt ON movimientos_lineas_offline(articulo_id, cliente_id)');

    // Tabla de licencia según especificación Velneo
    await _db!.execute('''
      CREATE TABLE IF NOT EXISTS licencia (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        tecnico TEXT DEFAULT '',
        id_licencia TEXT DEFAULT '',
        identificador TEXT DEFAULT '',
        licencia_codigo TEXT DEFAULT '',
        uuid TEXT DEFAULT '',
        server_host TEXT DEFAULT 'https://tecerp.nunsys.com:4331',
        server_api TEXT DEFAULT '',
        version TEXT DEFAULT '',
        validada INTEGER DEFAULT 0,
        ent_m TEXT DEFAULT '',
        contraclave TEXT DEFAULT '',
        offline_intentos INTEGER DEFAULT 0,
        api_key TEXT DEFAULT ''
      )
    ''');
    await _db!.execute('INSERT OR IGNORE INTO licencia (id) VALUES (1)');
    try {
      await _db!.execute('ALTER TABLE licencia ADD COLUMN tecnico TEXT DEFAULT ""');
    } catch (_) {}
    try {
      await _db!.execute('ALTER TABLE licencia ADD COLUMN api_key TEXT DEFAULT ""');
    } catch (_) {}
    try {
      await _db!.execute('ALTER TABLE licencia ADD COLUMN server_host TEXT DEFAULT ""');
    } catch (_) {}

    _initialized = true;
    debugPrint('[OFFLINE_DB] Base de datos SQLite inicializada en: $path');
  }

  DatabaseFactory _defaultFactory() {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      return databaseFactoryFfi;
    }
    return sqflite.databaseFactory;
  }

  Future<String> _defaultPath(DatabaseFactory factory) async {
    final dir = await factory.getDatabasesPath();
    return p.join(dir, 'pedidos_offline_storage.db');
  }

  Future<void> _onCreate(Database db, int version) async {
    // 1. Maestros genéricos (18 tablas)
    await db.execute('''
      CREATE TABLE maestros_data (
        tabla TEXT NOT NULL,
        id TEXT NOT NULL,
        codigo TEXT NOT NULL DEFAULT '',
        nombre TEXT NOT NULL DEFAULT '',
        tiene_familia INTEGER NOT NULL DEFAULT 1,
        es_cmr INTEGER NOT NULL DEFAULT 0,
        extra_json TEXT NOT NULL DEFAULT '{}',
        updated_at INTEGER NOT NULL,
        PRIMARY KEY (tabla, id)
      )
    ''');
    await db.execute('CREATE INDEX idx_mae_tabla ON maestros_data(tabla)');
    await db.execute('CREATE INDEX idx_mae_tabla_nom ON maestros_data(tabla, nombre)');
    await db.execute('CREATE INDEX idx_mae_tabla_cod ON maestros_data(tabla, codigo)');
    await db.execute('CREATE INDEX idx_mae_tabla_fam ON maestros_data(tabla, tiene_familia)');
    await db.execute('CREATE INDEX idx_mae_tabla_cmr ON maestros_data(tabla, es_cmr)');

    // 2. Pedidos y sus líneas
    await db.execute('''
      CREATE TABLE pedidos_offline (
        id TEXT PRIMARY KEY,
        numero TEXT NOT NULL DEFAULT '',
        fecha TEXT NOT NULL DEFAULT '',
        cliente_id INTEGER NOT NULL DEFAULT 0,
        cliente_nombre TEXT NOT NULL DEFAULT '',
        comercial_id TEXT NOT NULL DEFAULT '',
        estado TEXT NOT NULL DEFAULT 'PENDIENTE',
        total REAL NOT NULL DEFAULT 0.0,
        json_data TEXT NOT NULL,
        is_outbox INTEGER NOT NULL DEFAULT 0,
        updated_at INTEGER NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_ped_fch ON pedidos_offline(fecha)');
    await db.execute('CREATE INDEX idx_ped_clt ON pedidos_offline(cliente_id)');
    await db.execute('CREATE INDEX idx_ped_cmr ON pedidos_offline(comercial_id)');
    await db.execute('CREATE INDEX idx_ped_outbox ON pedidos_offline(is_outbox)');

    await db.execute('''
      CREATE TABLE pedidos_lineas_offline (
        id TEXT PRIMARY KEY,
        pedido_id TEXT NOT NULL,
        articulo_id TEXT NOT NULL DEFAULT '',
        articulo_nombre TEXT NOT NULL DEFAULT '',
        cantidad REAL NOT NULL DEFAULT 1.0,
        precio REAL NOT NULL DEFAULT 0.0,
        total REAL NOT NULL DEFAULT 0.0,
        json_data TEXT NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_ped_lin_ped ON pedidos_lineas_offline(pedido_id)');

    // 3. Presupuestos y sus líneas
    await db.execute('''
      CREATE TABLE presupuestos_offline (
        id TEXT PRIMARY KEY,
        numero TEXT NOT NULL DEFAULT '',
        fecha TEXT NOT NULL DEFAULT '',
        cliente_id INTEGER NOT NULL DEFAULT 0,
        cliente_nombre TEXT NOT NULL DEFAULT '',
        comercial_id TEXT NOT NULL DEFAULT '',
        estado TEXT NOT NULL DEFAULT 'PENDIENTE',
        total REAL NOT NULL DEFAULT 0.0,
        json_data TEXT NOT NULL,
        is_outbox INTEGER NOT NULL DEFAULT 0,
        updated_at INTEGER NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_pre_fch ON presupuestos_offline(fecha)');
    await db.execute('CREATE INDEX idx_pre_clt ON presupuestos_offline(cliente_id)');
    await db.execute('CREATE INDEX idx_pre_cmr ON presupuestos_offline(comercial_id)');
    await db.execute('CREATE INDEX idx_pre_outbox ON presupuestos_offline(is_outbox)');

    await db.execute('''
      CREATE TABLE presupuestos_lineas_offline (
        id TEXT PRIMARY KEY,
        presupuesto_id TEXT NOT NULL,
        articulo_id TEXT NOT NULL DEFAULT '',
        articulo_nombre TEXT NOT NULL DEFAULT '',
        cantidad REAL NOT NULL DEFAULT 1.0,
        precio REAL NOT NULL DEFAULT 0.0,
        total REAL NOT NULL DEFAULT 0.0,
        json_data TEXT NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_pre_lin_pre ON presupuestos_lineas_offline(presupuesto_id)');

    // 4. Cola de subida (Outbox Queue)
    await db.execute('''
      CREATE TABLE outbox_cola (
        id TEXT PRIMARY KEY,
        tipo TEXT NOT NULL,
        accion TEXT NOT NULL,
        documento_id TEXT NOT NULL,
        payload_json TEXT NOT NULL,
        estado TEXT NOT NULL DEFAULT 'pendiente',
        error_msg TEXT,
        created_at INTEGER NOT NULL,
        intentos INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('CREATE INDEX idx_outbox_est ON outbox_cola(estado)');

    // 5. Metadatos de sincronización
    await db.execute('''
      CREATE TABLE sync_metadata (
        clave TEXT PRIMARY KEY,
        valor TEXT NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    // 6. Base de conocimiento de líneas (movimientos por artículo)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS movimientos_lineas_offline (
        id TEXT PRIMARY KEY,
        articulo_id TEXT NOT NULL,
        cliente_id TEXT NOT NULL DEFAULT '',
        fecha TEXT NOT NULL DEFAULT '',
        num_doc TEXT NOT NULL DEFAULT '',
        json_data TEXT NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_mov_lin_art ON movimientos_lineas_offline(articulo_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_mov_lin_art_clt ON movimientos_lineas_offline(articulo_id, cliente_id)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Migraciones futuras de base de datos
  }

  // ===========================================================================
  // METADATOS (Última sincronización, días configurados, etc.)
  // ===========================================================================

  Future<String?> getMetadata(String clave) async {
    final rows = await db.query(
      'sync_metadata',
      columns: ['valor'],
      where: 'clave = ?',
      whereArgs: [clave],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['valor'] as String?;
  }

  Future<void> setMetadata(String clave, String valor) async {
    await db.insert(
      'sync_metadata',
      {
        'clave': clave,
        'valor': valor,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: sqflite.ConflictAlgorithm.replace,
    );
  }

  // ===========================================================================
  // OPERACIONES DE MAESTROS
  // ===========================================================================

  /// Inserta o actualiza un lote masivo de registros para una tabla maestra.
  /// Se ejecuta dentro de una transacción en bloque (batch) para máxima velocidad.
  Future<void> saveMaestrosBatch({
    required String tabla,
    required List<Map<String, dynamic>> items,
    bool clearBefore = false,
  }) async {
    if (clearBefore) {
      await db.delete('maestros_data', where: 'tabla = ?', whereArgs: [tabla]);
    }
    if (items.isEmpty) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    final batch = db.batch();

    for (final item in items) {
      final id = _extractId(item);
      if (id.isEmpty) continue;

      final codigo = _extractCodigo(item);
      final nombre = _extractNombre(item);

      // Evaluar si tiene familia (en ART_M)
      var tieneFamilia = 1;
      if (tabla == 'ART_M') {
        final fam = (item['FAM_M'] ?? item['fam_m'] ?? item['fam'] ?? '').toString().trim();
        tieneFamilia = fam.isNotEmpty ? 1 : 0;
      }

      // Evaluar si es comercial (en ENT_M)
      var esCmr = 0;
      if (tabla == 'ENT_M') {
        final esCmrVal = item['es_cmr'] ?? item['cmr'] ?? item['ES_CMR'] ?? 0;
        if (esCmrVal == 1 || esCmrVal == true || esCmrVal == '1' || esCmrVal == 'true') {
          esCmr = 1;
        }
      }

      batch.insert(
        'maestros_data',
        {
          'tabla': tabla,
          'id': id,
          'codigo': codigo,
          'nombre': nombre,
          'tiene_familia': tieneFamilia,
          'es_cmr': esCmr,
          'extra_json': jsonEncode(item),
          'updated_at': now,
        },
        conflictAlgorithm: sqflite.ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  String _extractId(Map<String, dynamic> item) {
    final raw = item['id'] ?? item['id_reg'] ?? item['codigo'] ?? item['cod'] ?? '';
    if (raw is Map) return '${raw['id'] ?? raw['value'] ?? ''}';
    return raw.toString().trim();
  }

  String _extractCodigo(Map<String, dynamic> item) {
    final raw = item['codigo'] ?? item['cod'] ?? item['id'] ?? '';
    if (raw is Map) return '${raw['id'] ?? raw['value'] ?? ''}';
    return raw.toString().trim();
  }

  String _extractNombre(Map<String, dynamic> item) {
    for (final k in [
      'name', 'nom', 'nombre', 'raz_soc', 'nombreComercial',
      'dir_com', 'DIR_COM', 'dir', 'DIR', 'dom', 'DOM',
      'nom_alm', 'alm_nom', 'dsc', 'dsc_edt', 'des'
    ]) {
      final val = item[k];
      if (val != null && val.toString().trim().isNotEmpty) {
        return val.toString().trim();
      }
    }
    return '';
  }

  /// Recupera la lista de comerciales desde SQLite (tabla ENT_M con es_cmr = 1).
  Future<List<OpcionMaestra>> getComercialesOffline() async {
    final rows = await db.query(
      'maestros_data',
      columns: ['id', 'codigo', 'nombre', 'extra_json'],
      where: 'tabla = ? AND es_cmr = 1',
      whereArgs: ['ENT_M'],
      orderBy: 'nombre ASC',
    );
    if (rows.isNotEmpty) {
      return rows.map((r) {
        final id = (r['id'] ?? '').toString().trim();
        final cod = (r['codigo'] ?? '').toString().trim();
        final nom = (r['nombre'] ?? '').toString().trim();
        return OpcionMaestra(
          codigo: id.isNotEmpty ? id : cod,
          nombre: nom.isNotEmpty ? nom : (cod.isNotEmpty ? cod : id),
        );
      }).toList();
    }

    // Fallback si no tenían la marca es_cmr = 1 en la columna
    final allEnt = await db.query(
      'maestros_data',
      columns: ['id', 'codigo', 'nombre', 'extra_json'],
      where: 'tabla = ?',
      whereArgs: ['ENT_M'],
      orderBy: 'nombre ASC',
    );
    final resultado = <OpcionMaestra>[];
    for (final r in allEnt) {
      try {
        final extraStr = r['extra_json'] as String?;
        if (extraStr != null && extraStr.isNotEmpty) {
          final m = jsonDecode(extraStr) as Map<String, dynamic>;
          final esCmr = m['es_cmr'] ?? m['cmr'] ?? m['ES_CMR'] ?? 0;
          if (esCmr == 1 || esCmr == true || esCmr == '1' || esCmr == 'true') {
            final id = (r['id'] ?? '').toString().trim();
            final cod = (r['codigo'] ?? '').toString().trim();
            final nom = (r['nombre'] ?? '').toString().trim();
            resultado.add(OpcionMaestra(
              codigo: id.isNotEmpty ? id : cod,
              nombre: nom.isNotEmpty ? nom : (cod.isNotEmpty ? cod : id),
            ));
          }
        }
      } catch (_) {}
    }
    return resultado;
  }

  /// Recupera el nombre de un comercial desde SQLite (ENT_M) por su ID o código.
  Future<String> getNombreComercialOffline(String idOrCod) async {
    final clean = idOrCod.trim();
    if (clean.isEmpty) return '';
    try {
      final rows = await db.query(
        'maestros_data',
        columns: ['nombre'],
        where: 'tabla = ? AND (id = ? OR codigo = ?)',
        whereArgs: ['ENT_M', clean, clean],
        limit: 1,
      );
      if (rows.isNotEmpty) {
        final nom = (rows.first['nombre'] ?? '').toString().trim();
        if (nom.isNotEmpty) return nom;
      }
    } catch (_) {}
    return '';
  }

  /// Recupera el nombre de una opción maestra en SQLite por su tabla e ID o código.
  Future<String> getNombreMaestroOffline(String tabla, String idOrCod) async {
    final clean = idOrCod.trim();
    if (clean.isEmpty) return '';
    try {
      final rows = await db.query(
        'maestros_data',
        columns: ['nombre', 'extra_json'],
        where: 'tabla = ? AND (id = ? OR codigo = ?)',
        whereArgs: [tabla, clean, clean],
        limit: 1,
      );
      if (rows.isNotEmpty) {
        final nom = (rows.first['nombre'] ?? '').toString().trim();
        if (nom.isNotEmpty) return nom;
        final extra = rows.first['extra_json'] as String?;
        if (extra != null && extra.isNotEmpty) {
          final m = jsonDecode(extra) as Map<String, dynamic>;
          for (final k in ['DIR_COM', 'dir_com', 'DIR', 'dir', 'name', 'nom', 'nombre']) {
            final val = m[k];
            if (val != null && val.toString().trim().isNotEmpty) {
              return val.toString().trim();
            }
          }
        }
      }
    } catch (_) {}
    return '';
  }

  /// Recupera opciones maestras para un desplegable o selector.
  Future<List<OpcionMaestra>> getMaestrosOpciones(String tabla) async {
    final rows = await db.query(
      'maestros_data',
      columns: ['id', 'codigo', 'nombre'],
      where: 'tabla = ?',
      whereArgs: [tabla],
      orderBy: 'nombre ASC, codigo ASC',
    );

    return rows.map((r) {
      final id = (r['id'] ?? '').toString();
      final cod = (r['codigo'] ?? '').toString();
      final nom = (r['nombre'] ?? '').toString();
      return OpcionMaestra(
        codigo: cod.isNotEmpty ? cod : id,
        nombre: nom.isNotEmpty ? nom : (cod.isNotEmpty ? cod : id),
      );
    }).toList();
  }

  /// Recupera registros completos de una tabla maestra.
  Future<List<Map<String, dynamic>>> getMaestrosData(String tabla, {String? query, int limit = 200}) async {
    String? where = 'tabla = ?';
    List<dynamic> whereArgs = [tabla];

    if (query != null && query.trim().isNotEmpty) {
      final q = '%${query.trim()}%';
      where += ' AND (nombre LIKE ? OR codigo LIKE ?)';
      whereArgs.addAll([q, q]);
    }

    final rows = await db.query(
      'maestros_data',
      columns: ['extra_json'],
      where: where,
      whereArgs: whereArgs,
      limit: limit,
      orderBy: 'nombre ASC',
    );

    return rows.map((r) {
      try {
        return jsonDecode(r['extra_json'] as String) as Map<String, dynamic>;
      } catch (_) {
        return <String, dynamic>{};
      }
    }).where((m) => m.isNotEmpty).toList();
  }

  /// Consulta de artículos sin conexión (excluye siempre artículos sin familia).
  Future<ResultadoLista<Articulo>> getArticulosOffline({
    String? query,
    int page = 1,
    int pageSize = 50,
  }) async {
    String where = 'tabla = ? AND tiene_familia = 1';
    List<dynamic> whereArgs = ['ART_M'];

    if (query != null && query.trim().isNotEmpty) {
      final q = '%${query.trim()}%';
      where += ' AND (nombre LIKE ? OR codigo LIKE ?)';
      whereArgs.addAll([q, q]);
    }

    final countResult = await db.rawQuery(
      'SELECT COUNT(*) as total FROM maestros_data WHERE $where',
      whereArgs,
    );
    final total = sqflite.Sqflite.firstIntValue(countResult) ?? 0;

    final offset = (page - 1) * pageSize;
    final rows = await db.query(
      'maestros_data',
      columns: ['extra_json'],
      where: where,
      whereArgs: whereArgs,
      orderBy: 'nombre ASC',
      limit: pageSize,
      offset: offset,
    );

    final items = <Articulo>[];
    for (final r in rows) {
      try {
        final map = jsonDecode(r['extra_json'] as String) as Map<String, dynamic>;
        final art = Articulo.fromJson(map);
        if (art.tieneFamilia) {
          items.add(art);
        }
      } catch (_) {}
    }

    return ResultadoLista<Articulo>(
      items: items,
      total: total,
      page: page,
    );
  }

  /// Consulta de clientes sin conexión.
  Future<ResultadoLista<Cliente>> getClientesOffline({
    String? query,
    String? comercialId,
    int page = 1,
    int pageSize = 50,
  }) async {
    String where = 'tabla = ?';
    List<dynamic> whereArgs = ['ENT_M'];

    if (query != null && query.trim().isNotEmpty) {
      final q = '%${query.trim()}%';
      where += ' AND (nombre LIKE ? OR codigo LIKE ?)';
      whereArgs.addAll([q, q]);
    }

    final rows = await db.query(
      'maestros_data',
      columns: ['extra_json'],
      where: where,
      whereArgs: whereArgs,
      orderBy: 'nombre ASC',
    );

    final cleanComercialId = comercialId?.trim() ?? '';
    final comercialNum = int.tryParse(cleanComercialId);

    final items = <Cliente>[];
    for (final r in rows) {
      try {
        final map = jsonDecode(r['extra_json'] as String) as Map<String, dynamic>;
        final esClt = map['es_clt'] ?? map['ES_CLT'] ?? map['clt'] ?? map['CLT'];
        if (esClt != null) {
          if (esClt == 0 || esClt == false || esClt == '0' || esClt == 'false') {
            continue;
          }
        }

        if (cleanComercialId.isNotEmpty) {
          final rawCmr = map['cmr'] ??
              map['CMR'] ??
              map['cmr_m'] ??
              map['CMR_M'] ??
              map['ent_cmr'] ??
              map['ENT_CMR'] ??
              map['comercial'] ??
              map['COMERCIAL'] ??
              map['id_cmr'] ??
              map['ID_CMR'];

          String cmrStr = '';
          if (rawCmr is Map) {
            cmrStr = '${rawCmr['id'] ?? rawCmr['codigo'] ?? rawCmr['value'] ?? ''}'.trim();
          } else if (rawCmr != null) {
            cmrStr = rawCmr.toString().trim();
          }

          final cmrNum = int.tryParse(cmrStr);
          final matches = (cmrStr.isNotEmpty && cmrStr == cleanComercialId) ||
              (comercialNum != null && cmrNum != null && comercialNum == cmrNum);

          if (!matches) {
            continue;
          }
        }

        items.add(Cliente.fromJson(map));
      } catch (_) {}
    }

    final total = items.length;
    final offset = (page - 1) * pageSize;
    final pagedItems = items.skip(offset).take(pageSize).toList();

    return ResultadoLista<Cliente>(
      items: pagedItems,
      total: total,
      page: page,
    );
  }

  /// Recupera clientes rápidamente desde SQLite por sus IDs numéricos o códigos.
  Future<Map<int, Cliente>> getClientesByIdsOffline(List<int> ids) async {
    if (ids.isEmpty) return {};
    final cleanIds = ids.where((id) => id > 0).toSet().toList();
    if (cleanIds.isEmpty) return {};

    final placeholders = List.filled(cleanIds.length, '?').join(',');
    final idStrings = cleanIds.map((id) => id.toString()).toList();

    try {
      final rows = await db.query(
        'maestros_data',
        columns: ['id', 'codigo', 'nombre', 'extra_json'],
        where: 'tabla = ? AND (id IN ($placeholders) OR codigo IN ($placeholders) OR CAST(id AS INTEGER) IN ($placeholders) OR CAST(codigo AS INTEGER) IN ($placeholders))',
        whereArgs: ['ENT_M', ...idStrings, ...idStrings, ...cleanIds, ...cleanIds],
      );

      final result = <int, Cliente>{};
      for (final r in rows) {
        try {
          final extraStr = r['extra_json'] as String?;
          Map<String, dynamic> map = {};
          if (extraStr != null && extraStr.isNotEmpty) {
            map = jsonDecode(extraStr) as Map<String, dynamic>;
          }
          final idNum = int.tryParse((r['id'] ?? '0').toString()) ?? 0;
          final codNum = int.tryParse((r['codigo'] ?? '0').toString()) ?? 0;
          final mapIdNum = int.tryParse((map['id'] ?? '0').toString()) ?? 0;
          final mapCodNum = int.tryParse((map['codigo'] ?? map['cod'] ?? '0').toString()) ?? 0;

          final nombre = (r['nombre'] ?? map['name'] ?? map['nombre'] ?? map['raz_soc'] ?? '').toString();
          final cif = (map['cif'] ?? map['nif'] ?? '').toString();
          final tlf = (map['tlf'] ?? map['telefono'] ?? '').toString();
          final eml = (map['eml'] ?? map['email'] ?? '').toString();

          final primaryId = idNum > 0 ? idNum : (codNum > 0 ? codNum : (mapIdNum > 0 ? mapIdNum : mapCodNum));
          if (primaryId <= 0 && nombre.isEmpty) continue;

          final cliente = Cliente(
            id: primaryId > 0 ? primaryId : 1,
            nombreComercial: nombre.isNotEmpty ? nombre : (map['name'] ?? '').toString(),
            nombreFiscal: (map['name'] ?? nombre).toString(),
            cif: cif,
            email: eml,
            telefono: tlf,
          );

          if (idNum > 0) result[idNum] = cliente;
          if (codNum > 0) result[codNum] = cliente;
          if (mapIdNum > 0) result[mapIdNum] = cliente;
          if (mapCodNum > 0) result[mapCodNum] = cliente;

          for (final targetId in cleanIds) {
            final targetStr = targetId.toString();
            final rId = (r['id'] ?? '').toString().trim();
            final rCod = (r['codigo'] ?? '').toString().trim();
            if (rId == targetStr || rCod == targetStr || (int.tryParse(rId) == targetId) || (int.tryParse(rCod) == targetId)) {
              result[targetId] = cliente.copyWith(id: targetId);
            }
          }
        } catch (_) {}
      }
      return result;
    } catch (e) {
      debugPrint('[OFFLINE_DB] Error al buscar clientes por IDs: $e');
      return {};
    }
  }

  // ===========================================================================
  // OPERACIONES DE DOCUMENTOS (PEDIDOS Y PRESUPUESTOS)
  // ===========================================================================

  Future<void> savePedidosOffline(List<Pedido> pedidos, {bool clearBefore = false}) async {
    if (clearBefore) {
      await db.delete('pedidos_offline', where: 'is_outbox = 0');
      await db.execute('''
        DELETE FROM pedidos_lineas_offline 
        WHERE pedido_id IN (SELECT id FROM pedidos_offline WHERE is_outbox = 0)
      ''');
    }
    if (pedidos.isEmpty) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    final batch = db.batch();

    for (final p in pedidos) {
      final idStr = (p.id ?? p.codigo).toString();
      if (idStr.isEmpty || idStr == '0') continue;

      batch.insert(
        'pedidos_offline',
        {
          'id': idStr,
          'numero': '${p.nDocumento}',
          'fecha': p.fecha,
          'cliente_id': p.clienteId,
          'cliente_nombre': p.clienteNombre,
          'comercial_id': p.comercial,
          'estado': p.estado,
          'total': p.total,
          'json_data': jsonEncode(p.toJson()),
          'is_outbox': 0,
          'updated_at': now,
        },
        conflictAlgorithm: sqflite.ConflictAlgorithm.replace,
      );

      for (final lin in p.lineas) {
        final linIdStr = (lin.id ?? '${idStr}_${lin.codigo}').toString();
        batch.insert(
          'pedidos_lineas_offline',
          {
            'id': linIdStr,
            'pedido_id': idStr,
            'articulo_id': lin.articulo,
            'articulo_nombre': lin.articuloNombre,
            'cantidad': lin.cantidad,
            'precio': lin.precio,
            'total': lin.importe,
            'json_data': jsonEncode(lin.toJson()),
          },
          conflictAlgorithm: sqflite.ConflictAlgorithm.replace,
        );
      }
    }

    await batch.commit(noResult: true);
  }

  Future<void> savePresupuestosOffline(List<PresupuestoVenta> presupuestos, {bool clearBefore = false}) async {
    if (clearBefore) {
      await db.delete('presupuestos_offline', where: 'is_outbox = 0');
      await db.execute('''
        DELETE FROM presupuestos_lineas_offline 
        WHERE presupuesto_id IN (SELECT id FROM presupuestos_offline WHERE is_outbox = 0)
      ''');
    }
    if (presupuestos.isEmpty) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    final batch = db.batch();

    for (final p in presupuestos) {
      final idStr = (p.id ?? 0).toString();
      if (idStr.isEmpty || idStr == '0') continue;

      batch.insert(
        'presupuestos_offline',
        {
          'id': idStr,
          'numero': p.numeroPresupuesto,
          'fecha': p.fecha,
          'cliente_id': p.clienteId,
          'cliente_nombre': p.clienteNombre,
          'comercial_id': p.comercial,
          'estado': p.estado,
          'total': p.total,
          'json_data': jsonEncode(p.toJson()),
          'is_outbox': 0,
          'updated_at': now,
        },
        conflictAlgorithm: sqflite.ConflictAlgorithm.replace,
      );

      for (final lin in p.lineas) {
        final linIdStr = (lin.id ?? '${idStr}_${lin.articulo}').toString();
        batch.insert(
          'presupuestos_lineas_offline',
          {
            'id': linIdStr,
            'presupuesto_id': idStr,
            'articulo_id': lin.articulo,
            'articulo_nombre': lin.articuloNombre,
            'cantidad': lin.cantidad,
            'precio': lin.precio,
            'total': lin.importe,
            'json_data': jsonEncode(lin.toJson()),
          },
          conflictAlgorithm: sqflite.ConflictAlgorithm.replace,
        );
      }
    }

    await batch.commit(noResult: true);
  }

  // ===========================================================================
  // MOVIMIENTOS DE LÍNEAS (Base de conocimiento)
  // ===========================================================================

  /// Guarda los movimientos asociados a un artículo y cliente de línea de venta.
  Future<void> saveMovimientosArticulo(
    String articuloId,
    List<Movimiento> movimientos, {
    String? clienteId,
    bool clearBefore = true,
  }) async {
    final cleanArtId = articuloId.trim();
    final cleanCltId = clienteId?.trim() ?? '';
    if (cleanArtId.isEmpty) return;

    if (clearBefore) {
      if (cleanCltId.isNotEmpty) {
        await db.delete(
          'movimientos_lineas_offline',
          where: 'articulo_id = ? AND cliente_id = ?',
          whereArgs: [cleanArtId, cleanCltId],
        );
      } else {
        await db.delete(
          'movimientos_lineas_offline',
          where: 'articulo_id = ?',
          whereArgs: [cleanArtId],
        );
      }
    }
    if (movimientos.isEmpty) return;

    final batch = db.batch();
    final now = DateTime.now().millisecondsSinceEpoch;
    var idx = 0;

    for (final m in movimientos) {
      idx++;
      final mClt = cleanCltId.isNotEmpty ? cleanCltId : m.clienteId.trim();
      final id = '${cleanArtId}_${mClt}_${m.numDoc}_${m.fecha}_$idx';
      batch.insert(
        'movimientos_lineas_offline',
        {
          'id': id,
          'articulo_id': cleanArtId,
          'cliente_id': mClt,
          'fecha': m.fecha,
          'num_doc': m.numDoc,
          'json_data': jsonEncode(m.copyWith(clienteId: mClt).toJson()),
          'updated_at': now,
        },
        conflictAlgorithm: sqflite.ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  /// Recupera los movimientos offline guardados para un artículo y opcionalmente un cliente.
  Future<List<Movimiento>> getMovimientosArticuloOffline(
    String articuloId, {
    String? clienteId,
    int limit = 50,
    int offset = 0,
  }) async {
    final cleanArtId = articuloId.trim();
    if (cleanArtId.isEmpty) return const [];

    String where = 'articulo_id = ?';
    List<dynamic> whereArgs = [cleanArtId];

    final cleanCltId = clienteId?.trim() ?? '';
    if (cleanCltId.isNotEmpty) {
      where += ' AND (cliente_id = ? OR cliente_id = "")';
      whereArgs.add(cleanCltId);
    }

    final rows = await db.query(
      'movimientos_lineas_offline',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'fecha DESC',
      limit: limit,
      offset: offset,
    );

    return rows.map((r) {
      final jsonStr = r['json_data'] as String;
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      return Movimiento.fromJson(map);
    }).toList();
  }

  Future<List<Pedido>> getPedidosOffline({
    String? estado,
    String? comercialId,
    String? search,
  }) async {
    String where = '1 = 1';
    List<dynamic> whereArgs = [];

    if (estado != null && estado.trim().isNotEmpty) {
      where += ' AND estado = ?';
      whereArgs.add(estado.trim());
    }

    if (comercialId != null && comercialId.trim().isNotEmpty) {
      where += ' AND comercial_id = ?';
      whereArgs.add(comercialId.trim());
    }

    if (search != null && search.trim().isNotEmpty) {
      final q = '%${search.trim()}%';
      where += ' AND (numero LIKE ? OR cliente_nombre LIKE ?)';
      whereArgs.addAll([q, q]);
    }

    final rows = await db.query(
      'pedidos_offline',
      columns: ['id', 'json_data', 'is_outbox', 'total', 'cliente_id', 'cliente_nombre'],
      where: where,
      whereArgs: whereArgs,
      orderBy: 'is_outbox DESC, fecha DESC',
    );

    final pedidos = <Pedido>[];
    for (final r in rows) {
      try {
        final map = jsonDecode(r['json_data'] as String) as Map<String, dynamic>;
        var ped = Pedido.fromJson(map);
        final rowTotal = (r['total'] is num) ? (r['total'] as num).toDouble() : 0.0;
        final rowCid = (r['cliente_id'] is num) ? (r['cliente_id'] as num).toInt() : 0;
        final rowCnom = (r['cliente_nombre'] ?? '').toString();

        if (ped.total == 0.0 && rowTotal > 0.0) {
          ped = ped.copyWith(total: rowTotal);
        }
        if (ped.clienteId <= 0 && rowCid > 0) {
          ped = ped.copyWith(clienteId: rowCid);
        }
        if ((ped.clienteNombre.isEmpty || ped.clienteNombre == ped.cliente) && rowCnom.isNotEmpty) {
          ped = ped.copyWith(clienteNombre: rowCnom);
        }
        if (ped.total == 0.0) {
          final lins = await getLineasPedidoOffline(r['id'] ?? ped.id ?? ped.codigo);
          if (lins.isNotEmpty) {
            final t = lins.fold<double>(0.0, (s, l) => s + l.getLineTotal());
            ped = ped.copyWith(total: t, lineas: lins);
          }
        }
        pedidos.add(ped);
      } catch (_) {}
    }

    return pedidos;
  }

  Future<List<PresupuestoVenta>> getPresupuestosOffline({
    String? estado,
    String? comercialId,
    String? search,
  }) async {
    String where = '1 = 1';
    List<dynamic> whereArgs = [];

    if (estado != null && estado.trim().isNotEmpty) {
      where += ' AND estado = ?';
      whereArgs.add(estado.trim());
    }

    if (comercialId != null && comercialId.trim().isNotEmpty) {
      where += ' AND comercial_id = ?';
      whereArgs.add(comercialId.trim());
    }

    if (search != null && search.trim().isNotEmpty) {
      final q = '%${search.trim()}%';
      where += ' AND (numero LIKE ? OR cliente_nombre LIKE ?)';
      whereArgs.addAll([q, q]);
    }

    final rows = await db.query(
      'presupuestos_offline',
      columns: ['id', 'json_data', 'is_outbox', 'total', 'cliente_id', 'cliente_nombre'],
      where: where,
      whereArgs: whereArgs,
      orderBy: 'is_outbox DESC, fecha DESC',
    );

    final presupuestos = <PresupuestoVenta>[];
    for (final r in rows) {
      try {
        final map = jsonDecode(r['json_data'] as String) as Map<String, dynamic>;
        var pre = PresupuestoVenta.fromJson(map);
        final rowTotal = (r['total'] is num) ? (r['total'] as num).toDouble() : 0.0;
        final rowCid = (r['cliente_id'] is num) ? (r['cliente_id'] as num).toInt() : 0;
        final rowCnom = (r['cliente_nombre'] ?? '').toString();

        if (pre.total == 0.0 && rowTotal > 0.0) {
          pre = pre.copyWith(total: rowTotal);
        }
        if (pre.clienteId <= 0 && rowCid > 0) {
          pre = pre.copyWith(clienteId: rowCid);
        }
        if ((pre.clienteNombre.isEmpty || pre.clienteNombre == pre.cliente) && rowCnom.isNotEmpty) {
          pre = pre.copyWith(clienteNombre: rowCnom);
        }
        if (pre.total == 0.0) {
          final lins = await getLineasPresupuestoOffline(r['id'] ?? pre.id ?? 0);
          if (lins.isNotEmpty) {
            final t = lins.fold<double>(0.0, (s, l) => s + l.getLineTotal());
            pre = pre.copyWith(total: t, lineas: lins);
          }
        }
        presupuestos.add(pre);
      } catch (_) {}
    }

    return presupuestos;
  }

  Future<List<LineaPedido>> getLineasPedidoOffline(dynamic pedidoId) async {
    final rows = await db.query(
      'pedidos_lineas_offline',
      columns: ['json_data'],
      where: 'pedido_id = ?',
      whereArgs: ['$pedidoId'],
    );

    final lineas = <LineaPedido>[];
    for (final r in rows) {
      try {
        final map = jsonDecode(r['json_data'] as String) as Map<String, dynamic>;
        lineas.add(LineaPedido.fromJson(map));
      } catch (_) {}
    }
    return lineas;
  }

  Future<List<LineaPresupuestoVenta>> getLineasPresupuestoOffline(dynamic presupuestoId) async {
    final rows = await db.query(
      'presupuestos_lineas_offline',
      columns: ['json_data'],
      where: 'presupuesto_id = ?',
      whereArgs: ['$presupuestoId'],
    );

    final lineas = <LineaPresupuestoVenta>[];
    for (final r in rows) {
      try {
        final map = jsonDecode(r['json_data'] as String) as Map<String, dynamic>;
        lineas.add(LineaPresupuestoVenta.fromJson(map));
      } catch (_) {}
    }
    return lineas;
  }

  // ===========================================================================
  // COLA OUTBOX (Creación y edición sin conexión)
  // ===========================================================================

  Future<void> savePedidoOfflineOutbox({
    required Pedido pedido,
    List<int>? fotoBytes,
    String accion = 'crear',
    List<int>? removedLineIds,
    bool deleteFoto = false,
  }) async {
    final idStr = '${pedido.id ?? pedido.codigo}';
    final now = DateTime.now().millisecondsSinceEpoch;

    final payload = {
      'pedido': pedido.toJson(),
      if (fotoBytes != null) 'fotoBase64': base64Encode(fotoBytes),
      if (removedLineIds != null && removedLineIds.isNotEmpty) 'removedLineIds': removedLineIds,
      if (deleteFoto) 'deleteFoto': true,
    };

    final batch = db.batch();

    batch.insert(
      'outbox_cola',
      {
        'id': 'outbox_ped_$idStr',
        'tipo': 'pedido',
        'accion': accion,
        'documento_id': idStr,
        'payload_json': jsonEncode(payload),
        'estado': 'pendiente',
        'error_msg': null,
        'created_at': now,
        'intentos': 0,
      },
      conflictAlgorithm: sqflite.ConflictAlgorithm.replace,
    );

    batch.insert(
      'pedidos_offline',
      {
        'id': idStr,
        'numero': pedido.nDocumento > 0 ? '${pedido.nDocumento}' : 'OFFLINE-$idStr',
        'fecha': pedido.fecha,
        'cliente_id': pedido.clienteId,
        'cliente_nombre': pedido.clienteNombre,
        'comercial_id': pedido.comercial,
        'estado': pedido.estado,
        'total': pedido.total,
        'json_data': jsonEncode(pedido.toJson()),
        'is_outbox': 1,
        'updated_at': now,
      },
      conflictAlgorithm: sqflite.ConflictAlgorithm.replace,
    );

    // Borrar líneas previas asociadas a este documento para evitar duplicaciones
    batch.delete('pedidos_lineas_offline', where: 'pedido_id = ?', whereArgs: [idStr]);

    for (final lin in pedido.lineas) {
      final linIdStr = '${lin.id ?? "${idStr}_${lin.codigo}"}';
      batch.insert(
        'pedidos_lineas_offline',
        {
          'id': linIdStr,
          'pedido_id': idStr,
          'articulo_id': lin.articulo,
          'articulo_nombre': lin.articuloNombre,
          'cantidad': lin.cantidad,
          'precio': lin.precio,
          'total': lin.importe,
          'json_data': jsonEncode(lin.toJson()),
        },
        conflictAlgorithm: sqflite.ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
    onOutboxChanged?.call();
  }

  /// Confirma un pedido offline, actualizando SQLite y encolando en Outbox si corresponde.
  Future<void> confirmarPedidoOffline(dynamic id, {bool queueOutbox = true}) async {
    final idStr = '$id';
    final now = DateTime.now().millisecondsSinceEpoch;

    final rows = await db.query(
      'pedidos_offline',
      where: 'id = ?',
      whereArgs: [idStr],
      limit: 1,
    );

    if (rows.isNotEmpty) {
      try {
        final map = jsonDecode(rows.first['json_data'] as String) as Map<String, dynamic>;
        map['con_kyr'] = 1;
        map['conKyr'] = true;

        await db.update(
          'pedidos_offline',
          {
            'json_data': jsonEncode(map),
            'updated_at': now,
          },
          where: 'id = ?',
          whereArgs: [idStr],
        );
      } catch (e) {
        debugPrint('[OFFLINE_DB] Error al actualizar json de pedido a confirmado: $e');
      }
    }

    // Comprobar si ya existe en la cola Outbox
    final outboxRows = await db.query(
      'outbox_cola',
      where: 'tipo = ? AND documento_id = ? AND estado != ?',
      whereArgs: ['pedido', idStr, 'completado'],
      limit: 1,
    );

    if (outboxRows.isNotEmpty) {
      // Ya estaba en la cola: actualizar el payload con con_kyr: 1
      try {
        final item = outboxRows.first;
        final payload = jsonDecode(item['payload_json'] as String) as Map<String, dynamic>;
        if (payload['pedido'] is Map) {
          final pMap = payload['pedido'] as Map<String, dynamic>;
          pMap['con_kyr'] = 1;
          pMap['conKyr'] = true;
        }
        await db.update(
          'outbox_cola',
          {
            'payload_json': jsonEncode(payload),
          },
          where: 'id = ?',
          whereArgs: [item['id']],
        );
      } catch (e) {
        debugPrint('[OFFLINE_DB] Error al actualizar outbox de pedido confirmado: $e');
      }
    } else if (queueOutbox) {
      // Pedido existente en servidor: registrar acción de confirmación pendiente
      await db.insert(
        'outbox_cola',
        {
          'id': 'outbox_ped_conf_$idStr',
          'tipo': 'pedido',
          'accion': 'confirmar',
          'documento_id': idStr,
          'payload_json': jsonEncode({'id': id, 'con_kyr': 1}),
          'estado': 'pendiente',
          'error_msg': null,
          'created_at': now,
          'intentos': 0,
        },
        conflictAlgorithm: sqflite.ConflictAlgorithm.replace,
      );
    }

    onOutboxChanged?.call();
  }

  Future<void> savePresupuestoOfflineOutbox({
    required PresupuestoVenta presupuesto,
    String accion = 'crear',
    List<int>? removedLineIds,
  }) async {
    final idStr = '${presupuesto.id ?? 0}';
    final now = DateTime.now().millisecondsSinceEpoch;

    final payload = {
      'presupuesto': presupuesto.toJson(),
      if (removedLineIds != null && removedLineIds.isNotEmpty) 'removedLineIds': removedLineIds,
    };

    final batch = db.batch();

    batch.insert(
      'outbox_cola',
      {
        'id': 'outbox_pre_$idStr',
        'tipo': 'presupuesto',
        'accion': accion,
        'documento_id': idStr,
        'payload_json': jsonEncode(payload),
        'estado': 'pendiente',
        'error_msg': null,
        'created_at': now,
        'intentos': 0,
      },
      conflictAlgorithm: sqflite.ConflictAlgorithm.replace,
    );

    batch.insert(
      'presupuestos_offline',
      {
        'id': idStr,
        'numero': presupuesto.numeroPresupuesto.isNotEmpty ? presupuesto.numeroPresupuesto : 'OFFLINE-$idStr',
        'fecha': presupuesto.fecha,
        'cliente_id': presupuesto.clienteId,
        'cliente_nombre': presupuesto.clienteNombre,
        'comercial_id': presupuesto.comercial,
        'estado': presupuesto.estado,
        'total': presupuesto.total,
        'json_data': jsonEncode(presupuesto.toJson()),
        'is_outbox': 1,
        'updated_at': now,
      },
      conflictAlgorithm: sqflite.ConflictAlgorithm.replace,
    );

    // Borrar líneas previas asociadas a este documento para evitar duplicaciones
    batch.delete('presupuestos_lineas_offline', where: 'presupuesto_id = ?', whereArgs: [idStr]);

    for (final lin in presupuesto.lineas) {
      final linIdStr = '${lin.id ?? "${idStr}_${lin.articulo}"}';
      batch.insert(
        'presupuestos_lineas_offline',
        {
          'id': linIdStr,
          'presupuesto_id': idStr,
          'articulo_id': lin.articulo,
          'articulo_nombre': lin.articuloNombre,
          'cantidad': lin.cantidad,
          'precio': lin.precio,
          'total': lin.importe,
          'json_data': jsonEncode(lin.toJson()),
        },
        conflictAlgorithm: sqflite.ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
    onOutboxChanged?.call();
  }

  /// Marca un presupuesto como aceptado en SQLite (estado='A', etc.) y encola en outbox si corresponde.
  Future<void> marcarPresupuestoAceptadoOffline(dynamic budgetId, {bool queueOutbox = true}) async {
    final idStr = '$budgetId';
    final now = DateTime.now().millisecondsSinceEpoch;

    final rows = await db.query(
      'presupuestos_offline',
      where: 'id = ?',
      whereArgs: [idStr],
      limit: 1,
    );

    if (rows.isNotEmpty) {
      try {
        final map = jsonDecode(rows.first['json_data'] as String) as Map<String, dynamic>;
        map['est'] = 'A';
        map['estado'] = 'A';

        await db.update(
          'presupuestos_offline',
          {
            'estado': 'A',
            'json_data': jsonEncode(map),
            'updated_at': now,
          },
          where: 'id = ?',
          whereArgs: [idStr],
        );
      } catch (e) {
        debugPrint('[OFFLINE_DB] Error al actualizar json de presupuesto a aceptado: $e');
      }
    }

    // Comprobar si ya existe en la cola Outbox
    final outboxRows = await db.query(
      'outbox_cola',
      where: 'tipo = ? AND documento_id = ? AND estado != ?',
      whereArgs: ['presupuesto', idStr, 'completado'],
      limit: 1,
    );

    if (outboxRows.isNotEmpty) {
      // Ya estaba en la cola: actualizar el payload con est: 'A'
      try {
        final item = outboxRows.first;
        final payload = jsonDecode(item['payload_json'] as String) as Map<String, dynamic>;
        if (payload['presupuesto'] is Map) {
          final pMap = payload['presupuesto'] as Map<String, dynamic>;
          pMap['est'] = 'A';
          pMap['estado'] = 'A';
        }
        await db.update(
          'outbox_cola',
          {
            'payload_json': jsonEncode(payload),
          },
          where: 'id = ?',
          whereArgs: [item['id']],
        );
      } catch (e) {
        debugPrint('[OFFLINE_DB] Error al actualizar outbox de presupuesto aceptado: $e');
      }
    } else if (queueOutbox) {
      // Presupuesto existente en servidor: registrar acción de aceptar pendiente
      await db.insert(
        'outbox_cola',
        {
          'id': 'outbox_pre_acep_$idStr',
          'tipo': 'presupuesto',
          'accion': 'marcarAceptado',
          'documento_id': idStr,
          'payload_json': jsonEncode({'id': budgetId, 'est': 'A'}),
          'estado': 'pendiente',
          'error_msg': null,
          'created_at': now,
          'intentos': 0,
        },
        conflictAlgorithm: sqflite.ConflictAlgorithm.replace,
      );
    }

    onOutboxChanged?.call();
  }

  /// Enlaza un presupuesto con un pedido en SQLite (vta_ped_g y est='A').
  Future<void> linkPedidoPresupuestoOffline(dynamic budgetId, dynamic pedidoId) async {
    final idStr = '$budgetId';
    final pedIdNum = int.tryParse('$pedidoId') ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;

    final rows = await db.query(
      'presupuestos_offline',
      where: 'id = ?',
      whereArgs: [idStr],
      limit: 1,
    );

    if (rows.isNotEmpty) {
      try {
        final map = jsonDecode(rows.first['json_data'] as String) as Map<String, dynamic>;
        map['est'] = 'A';
        map['estado'] = 'A';
        map['vta_ped_g'] = pedIdNum;

        await db.update(
          'presupuestos_offline',
          {
            'estado': 'A',
            'json_data': jsonEncode(map),
            'updated_at': now,
          },
          where: 'id = ?',
          whereArgs: [idStr],
        );
      } catch (e) {
        debugPrint('[OFFLINE_DB] Error al enlazar presupuesto a pedido offline: $e');
      }
    }

    // Comprobar si ya existe en outbox_cola
    final outboxRows = await db.query(
      'outbox_cola',
      where: 'tipo = ? AND documento_id = ? AND estado != ?',
      whereArgs: ['presupuesto', idStr, 'completado'],
      limit: 1,
    );

    if (outboxRows.isNotEmpty) {
      try {
        final item = outboxRows.first;
        final payload = jsonDecode(item['payload_json'] as String) as Map<String, dynamic>;
        if (payload['presupuesto'] is Map) {
          final pMap = payload['presupuesto'] as Map<String, dynamic>;
          pMap['est'] = 'A';
          pMap['estado'] = 'A';
          pMap['vta_ped_g'] = pedIdNum;
        }
        await db.update(
          'outbox_cola',
          {
            'payload_json': jsonEncode(payload),
          },
          where: 'id = ?',
          whereArgs: [item['id']],
        );
      } catch (e) {
        debugPrint('[OFFLINE_DB] Error al actualizar payload outbox con link pedido: $e');
      }
    }

    onOutboxChanged?.call();
  }

  /// Elimina un elemento de la cola outbox por su id.
  Future<void> removeOutboxItem(String outboxId) async {
    await db.delete('outbox_cola', where: 'id = ?', whereArgs: [outboxId]);
    onOutboxChanged?.call();
  }

  /// Descarta y elimina un elemento de la cola outbox por su ID (o ID de documento).
  /// Si el documento asociado era temporal (creado offline, con ID negativo o acción 'crear'),
  /// también se eliminan sus registros locales de pedidos_offline / presupuestos_offline.
  Future<void> discardOutboxItem(String outboxId) async {
    final cleanId = outboxId.trim();
    if (cleanId.isEmpty) return;

    final rows = await db.query(
      'outbox_cola',
      where: 'id = ? OR documento_id = ?',
      whereArgs: [cleanId, cleanId],
      limit: 1,
    );
    if (rows.isEmpty) return;

    final item = rows.first;
    final realOutboxId = (item['id'] ?? '').toString();
    final tipo = (item['tipo'] ?? '').toString();
    final accion = (item['accion'] ?? 'crear').toString();
    final docId = (item['documento_id'] ?? '').toString();

    final batch = db.batch();
    batch.delete('outbox_cola', where: 'id = ?', whereArgs: [realOutboxId]);

    final isTempDoc = docId.startsWith('-') ||
        (int.tryParse(docId) != null && int.parse(docId) < 0) ||
        docId.startsWith('OFFLINE-') ||
        accion == 'crear';

    if (tipo == 'pedido') {
      if (isTempDoc) {
        batch.delete('pedidos_offline', where: 'id = ?', whereArgs: [docId]);
        batch.delete('pedidos_lineas_offline', where: 'pedido_id = ?', whereArgs: [docId]);
      } else {
        if (accion == 'confirmar') {
          final pedRows = await db.query('pedidos_offline', where: 'id = ?', whereArgs: [docId], limit: 1);
          if (pedRows.isNotEmpty) {
            try {
              final map = jsonDecode(pedRows.first['json_data'] as String) as Map<String, dynamic>;
              map['con_kyr'] = 0;
              map['conKyr'] = false;
              batch.update(
                'pedidos_offline',
                {'json_data': jsonEncode(map), 'is_outbox': 0},
                where: 'id = ?',
                whereArgs: [docId],
              );
            } catch (_) {
              batch.update('pedidos_offline', {'is_outbox': 0}, where: 'id = ?', whereArgs: [docId]);
            }
          }
        } else {
          batch.update('pedidos_offline', {'is_outbox': 0}, where: 'id = ?', whereArgs: [docId]);
        }
      }
    } else if (tipo == 'presupuesto') {
      if (isTempDoc) {
        batch.delete('presupuestos_offline', where: 'id = ?', whereArgs: [docId]);
        batch.delete('presupuestos_lineas_offline', where: 'presupuesto_id = ?', whereArgs: [docId]);
      } else {
        if (accion == 'marcarAceptado') {
          final preRows = await db.query('presupuestos_offline', where: 'id = ?', whereArgs: [docId], limit: 1);
          if (preRows.isNotEmpty) {
            try {
              final map = jsonDecode(preRows.first['json_data'] as String) as Map<String, dynamic>;
              map['est'] = 'P';
              map['estado'] = 'P';
              batch.update(
                'presupuestos_offline',
                {'estado': 'P', 'json_data': jsonEncode(map), 'is_outbox': 0},
                where: 'id = ?',
                whereArgs: [docId],
              );
            } catch (_) {
              batch.update('presupuestos_offline', {'is_outbox': 0}, where: 'id = ?', whereArgs: [docId]);
            }
          }
        } else {
          batch.update('presupuestos_offline', {'is_outbox': 0}, where: 'id = ?', whereArgs: [docId]);
        }
      }
    }

    await batch.commit(noResult: true);
    onOutboxChanged?.call();
  }

  /// Descarta y elimina todos los elementos pendientes de la cola outbox.
  Future<void> discardAllOutboxItems() async {
    final pending = await getPendingOutbox();
    for (final item in pending) {
      final id = (item['id'] ?? '').toString();
      if (id.isNotEmpty) {
        await discardOutboxItem(id);
      }
    }
  }

  Future<List<Map<String, dynamic>>> getPendingOutbox() async {
    return db.query(
      'outbox_cola',
      where: 'estado != ?',
      whereArgs: ['completado'],
      orderBy: 'created_at ASC',
    );
  }

  Future<Map<String, dynamic>?> getOutboxItem(String outboxId) async {
    final rows = await db.query(
      'outbox_cola',
      where: 'id = ? OR documento_id = ?',
      whereArgs: [outboxId, outboxId],
      limit: 1,
    );
    return rows.isNotEmpty ? rows.first : null;
  }

  Future<int> getPendingOutboxCount() async {
    final res = await db.rawQuery(
      "SELECT COUNT(*) as count FROM outbox_cola WHERE estado != 'completado'",
    );
    return sqflite.Sqflite.firstIntValue(res) ?? 0;
  }

  Future<void> updateOutboxStatus(
    String id, {
    required String estado,
    String? errorMsg,
  }) async {
    final intentos = sqflite.Sqflite.firstIntValue(
          await db.rawQuery('SELECT intentos FROM outbox_cola WHERE id = ?', [id]),
        ) ?? 0;

    await db.update(
      'outbox_cola',
      {
        'estado': estado,
        'error_msg': errorMsg,
        'intentos': intentos + 1,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    onOutboxChanged?.call();
  }

  Future<void> markOutboxCompleted({
    required String outboxId,
    required String tempDocId,
    required String tipo,
    required Map<String, dynamic> docReal,
  }) async {
    final batch = db.batch();

    batch.delete('outbox_cola', where: 'id = ?', whereArgs: [outboxId]);

    final realIdStr = '${docReal['id'] ?? docReal['codigo']}';

    if (tipo == 'pedido') {
      batch.delete('pedidos_offline', where: 'id = ?', whereArgs: [tempDocId]);
      batch.delete('pedidos_lineas_offline', where: 'pedido_id = ?', whereArgs: [tempDocId]);

      final tot = (docReal['tot_ped'] ?? docReal['total'] ?? 0.0);
      final totDouble = tot is num ? tot.toDouble() : (double.tryParse(tot.toString()) ?? 0.0);

      batch.insert(
        'pedidos_offline',
        {
          'id': realIdStr,
          'numero': '${docReal['n_doc'] ?? docReal['numero'] ?? realIdStr}',
          'fecha': '${docReal['fch'] ?? docReal['fecha'] ?? ''}',
          'cliente_id': docReal['clt'] ?? docReal['clienteId'] ?? 0,
          'cliente_nombre': '${docReal['clt_nom'] ?? docReal['clienteNombre'] ?? ''}',
          'comercial_id': '${docReal['cmr'] ?? docReal['comercial'] ?? ''}',
          'estado': '${docReal['est'] ?? docReal['estado'] ?? 'PENDIENTE'}',
          'total': totDouble,
          'json_data': jsonEncode(docReal),
          'is_outbox': 0,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: sqflite.ConflictAlgorithm.replace,
      );

      final lineasRaw = docReal['lineas'];
      if (lineasRaw is List) {
        for (final linMap in lineasRaw) {
          if (linMap is Map) {
            final m = Map<String, dynamic>.from(linMap);
            final linIdStr = '${m['id'] ?? "${realIdStr}_${m['articulo'] ?? m['art']}"}';
            batch.insert(
              'pedidos_lineas_offline',
              {
                'id': linIdStr,
                'pedido_id': realIdStr,
                'articulo_id': '${m['articulo'] ?? m['art'] ?? ''}',
                'articulo_nombre': '${m['articuloNombre'] ?? m['art_nom'] ?? ''}',
                'cantidad': (m['cantidad'] ?? m['can'] ?? 1.0) is num ? (m['cantidad'] ?? m['can'] ?? 1.0).toDouble() : 1.0,
                'precio': (m['precio'] ?? m['pre'] ?? 0.0) is num ? (m['precio'] ?? m['pre'] ?? 0.0).toDouble() : 0.0,
                'total': (m['importe'] ?? m['imp'] ?? 0.0) is num ? (m['importe'] ?? m['imp'] ?? 0.0).toDouble() : 0.0,
                'json_data': jsonEncode(m),
              },
              conflictAlgorithm: sqflite.ConflictAlgorithm.replace,
            );
          }
        }
      }

      final realIdNum = int.tryParse(realIdStr) ?? 0;
      if (realIdNum > 0) {
        batch.rawUpdate('''
          UPDATE presupuestos_offline
          SET json_data = REPLACE(json_data, '"vta_ped_g":$tempDocId', '"vta_ped_g":$realIdNum')
          WHERE json_data LIKE '%"vta_ped_g":$tempDocId%'
        ''');
        batch.rawUpdate('''
          UPDATE outbox_cola
          SET payload_json = REPLACE(payload_json, '"vta_ped_g":$tempDocId', '"vta_ped_g":$realIdNum')
          WHERE tipo = 'presupuesto' AND payload_json LIKE '%"vta_ped_g":$tempDocId%'
        ''');
      }
    } else {
      batch.delete('presupuestos_offline', where: 'id = ?', whereArgs: [tempDocId]);
      batch.delete('presupuestos_lineas_offline', where: 'presupuesto_id = ?', whereArgs: [tempDocId]);

      final tot = (docReal['total'] ?? docReal['tot_pre'] ?? 0.0);
      final totDouble = tot is num ? tot.toDouble() : (double.tryParse(tot.toString()) ?? 0.0);

      batch.insert(
        'presupuestos_offline',
        {
          'id': realIdStr,
          'numero': '${docReal['numero'] ?? docReal['num_pre'] ?? realIdStr}',
          'fecha': '${docReal['fch'] ?? docReal['fecha'] ?? ''}',
          'cliente_id': docReal['clt'] ?? docReal['clienteId'] ?? 0,
          'cliente_nombre': '${docReal['clt_nom'] ?? docReal['clienteNombre'] ?? ''}',
          'comercial_id': '${docReal['cmr'] ?? docReal['comercial'] ?? ''}',
          'estado': '${docReal['est'] ?? docReal['estado'] ?? 'PENDIENTE'}',
          'total': totDouble,
          'json_data': jsonEncode(docReal),
          'is_outbox': 0,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: sqflite.ConflictAlgorithm.replace,
      );

      final lineasRaw = docReal['lineas'];
      if (lineasRaw is List) {
        for (final linMap in lineasRaw) {
          if (linMap is Map) {
            final m = Map<String, dynamic>.from(linMap);
            final linIdStr = '${m['id'] ?? "${realIdStr}_${m['articulo'] ?? m['art']}"}';
            batch.insert(
              'presupuestos_lineas_offline',
              {
                'id': linIdStr,
                'presupuesto_id': realIdStr,
                'articulo_id': '${m['articulo'] ?? m['art'] ?? ''}',
                'articulo_nombre': '${m['articuloNombre'] ?? m['art_nom'] ?? ''}',
                'cantidad': (m['cantidad'] ?? m['can'] ?? 1.0) is num ? (m['cantidad'] ?? m['can'] ?? 1.0).toDouble() : 1.0,
                'precio': (m['precio'] ?? m['pre'] ?? 0.0) is num ? (m['precio'] ?? m['pre'] ?? 0.0).toDouble() : 0.0,
                'total': (m['importe'] ?? m['imp'] ?? 0.0) is num ? (m['importe'] ?? m['imp'] ?? 0.0).toDouble() : 0.0,
                'json_data': jsonEncode(m),
              },
              conflictAlgorithm: sqflite.ConflictAlgorithm.replace,
            );
          }
        }
      }

      final realIdNum = int.tryParse(realIdStr) ?? 0;
      if (realIdNum > 0) {
        batch.rawUpdate('''
          UPDATE pedidos_offline
          SET json_data = REPLACE(json_data, '"num_pre":"$tempDocId"', '"num_pre":"$realIdNum"')
          WHERE json_data LIKE '%"num_pre":"$tempDocId"%'
        ''');
        batch.rawUpdate('''
          UPDATE outbox_cola
          SET payload_json = REPLACE(payload_json, '"num_pre":"$tempDocId"', '"num_pre":"$realIdNum"')
          WHERE tipo = 'pedido' AND payload_json LIKE '%"num_pre":"$tempDocId"%'
        ''');
        batch.rawUpdate('''
          UPDATE outbox_cola
          SET payload_json = REPLACE(payload_json, '"numeroPresupuesto":"$tempDocId"', '"numeroPresupuesto":"$realIdNum"')
          WHERE tipo = 'pedido' AND payload_json LIKE '%"numeroPresupuesto":"$tempDocId"%'
        ''');
      }
    }

    await batch.commit(noResult: true);
    onOutboxChanged?.call();
  }

  /// Obtiene la fila única de la tabla licencia en SQLite (id = 1).
  Future<Map<String, dynamic>?> getLicencia() async {
    final results = await db.query('licencia', where: 'id = 1', limit: 1);
    return results.isNotEmpty ? results.first : null;
  }

  /// Guarda o actualiza la licencia en SQLite (id = 1).
  Future<void> saveLicencia(Map<String, dynamic> data) async {
    final values = Map<String, dynamic>.from(data);
    values['id'] = 1;
    await db.insert(
      'licencia',
      values,
      conflictAlgorithm: sqflite.ConflictAlgorithm.replace,
    );
  }

  /// Resetea la configuración de licencia en SQLite a sus valores por defecto.
  Future<void> resetLicencia({String uuid = ''}) async {
    await db.update(
      'licencia',
      {
        'tecnico': '',
        'id_licencia': '',
        'identificador': '',
        'licencia_codigo': '',
        'uuid': uuid,
        'server_api': 'https://tecerp.nunsys.com:4331',
        'version': 'v1',
        'validada': 0,
        'ent_m': '',
        'contraclave': '',
        'offline_intentos': 0,
        'api_key': '',
      },
      where: 'id = 1',
    );
  }
}

