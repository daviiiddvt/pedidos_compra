// ============================================================================
//  local_cache_db_io.dart  —  CACHÉ LOCAL con SQLite (Android/iOS/escritorio)
// ============================================================================
//
//  Implementación de SQLite mediante sqflite (móvil) y sqflite_common_ffi
//  (escritorio). Se selecciona de forma automática desde local_cache_db.dart
//  usando un import condicional (dart.library.io). En web se usa la "stub".
//
//  Tabla "maestro_cache":
//    type      → 'cliente', 'articulo', ... (para poder ampliar maestros).
//    codigo    → el código que se envía a Velneo.
//    nombre    → el nombre legible que se muestra.
//    last_used → cuándo se consultó (para ordenar por "más usados").
//    synced_at → cuándo se sincronizó desde el servidor (para el sync diferido).
// ============================================================================

import 'dart:io' show Platform;

import 'package:path/path.dart' as p;
// sqflite_common_ffi re-exporta toda la API común de sqflite (Database,
// DatabaseFactory, OpenDatabaseOptions, ConflictAlgorithm, ...).
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart' as sqflite;

import '../../models.dart'; // OpcionMaestra.
import 'local_cache_db_base.dart'; // Contrato LocalCacheDb.

/// Implementación SQLite de la caché local.
class LocalCacheDbSqlite implements LocalCacheDb {
  static const _table = 'maestro_cache';
  static const _version = 1;

  /// Ruta de la base de datos; null = ruta estándar de la plataforma.
  /// Se puede inyectar en tests para usar un archivo temporal.
  final String? dbPath;

  /// Fábrica inyectable (tests) para no depender del plugin real.
  final DatabaseFactory? factoryOverride;

  Database? _db;
  bool _initialized = false;

  LocalCacheDbSqlite({this.dbPath, this.factoryOverride});

  @override
  Future<void> init() async {
    if (_initialized) return;
    final factory = factoryOverride ?? _defaultFactory();
    final path = dbPath ?? await _defaultPath(factory);
    _db = await factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: _version,
        onCreate: _onCreate,
      ),
    );
    _initialized = true;
  }

  /// En Android/iOS sqflite usan su propia fábrica; en escritorio, FFI.
  DatabaseFactory _defaultFactory() {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      return databaseFactoryFfi;
    }
    return sqflite.databaseFactory;
  }

  Future<String> _defaultPath(DatabaseFactory factory) async {
    final dir = await factory.getDatabasesPath();
    return p.join(dir, 'pedidos_venta_cache.db');
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $_table (
        type      TEXT NOT NULL,
        codigo    TEXT NOT NULL,
        nombre    TEXT NOT NULL,
        last_used INTEGER NOT NULL,
        synced_at INTEGER NOT NULL,
        PRIMARY KEY (type, codigo)
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_maestro_nombre ON $_table(type, nombre)',
    );
    await db.execute(
      'CREATE INDEX idx_maestro_codigo ON $_table(type, codigo)',
    );
  }

  @override
  Future<List<OpcionMaestra>> search(
    String type,
    String query, {
    int limit = 20,
  }) async {
    final db = _requireDb();
    final like = '%${_escapeLike(query)}%';
    // LIKE de SQLite no distingue mayúsculas para ASCII; el paso de red
    // posterior (Velneo) además tolera acentos.
    final rows = await db.query(
      _table,
      where: 'type = ? AND (nombre LIKE ? OR codigo LIKE ?)',
      whereArgs: [type, like, like],
      columns: ['codigo', 'nombre'],
      orderBy: 'last_used DESC',
      limit: limit,
    );
    return rows.map(_fromRow).toList();
  }

  @override
  Future<List<OpcionMaestra>> listRecent(String type, {int limit = 20}) async {
    final db = _requireDb();
    final rows = await db.query(
      _table,
      where: 'type = ?',
      whereArgs: [type],
      columns: ['codigo', 'nombre'],
      orderBy: 'last_used DESC',
      limit: limit,
    );
    return rows.map(_fromRow).toList();
  }

  @override
  Future<int> upsertMany(String type, Iterable<OpcionMaestra> items) async {
    final db = _requireDb();
    final now = DateTime.now().millisecondsSinceEpoch;
    final batch = db.batch();
    for (final item in items) {
      batch.insert(
        _table,
        {
          'type': type,
          'codigo': item.codigo,
          'nombre': item.nombre,
          'last_used': now,
          'synced_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    final results = await batch.commit(noResult: true);
    return results.length;
  }

  @override
  Future<int> count(String type) async {
    final db = _requireDb();
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS n FROM $_table WHERE type = ?',
      [type],
    );
    return rows.firstOrNull?['n'] as int? ?? 0;
  }

  @override
  Future<void> clear(String type) async {
    final db = _requireDb();
    await db.delete(_table, where: 'type = ?', whereArgs: [type]);
  }

  @override
  Future<void> close() async {
    await _db?.close();
    _db = null;
    _initialized = false;
  }

  Database _requireDb() {
    final db = _db;
    if (db == null) {
      throw StateError('LocalCacheDbSqlite no inicializado. Llama a init() antes.');
    }
    return db;
  }

  OpcionMaestra _fromRow(Map<String, Object?> row) {
    return OpcionMaestra(
      codigo: '${row['codigo'] ?? ''}',
      nombre: '${row['nombre'] ?? ''}',
    );
  }

  static String _escapeLike(String value) {
    // Escapamos los metacaracteres de LIKE ('/' como escape).
    return value.replaceAll('/', '//').replaceAll('%', '/%').replaceAll('_', '/_');
  }
}

/// Instancia singleton de la caché SQLite.
LocalCacheDb get localCacheDbInstance => _singleton;
final LocalCacheDb _singleton = LocalCacheDbSqlite();