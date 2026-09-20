// ============================================================================
//  local_cache_db_stub.dart  —  CACHÉ LOCAL EN MEMORIA (web / fallback)
// ============================================================================
//
//  Implementación sin base de datos, 100% en Dart puro. Se usa en NAVEGADOR
//  (donde SQLite nativo no existe) y como respaldo para tests. Mantiene la
//  MISMA interfaz para que EntitySearchRepository no cambie.
// ============================================================================

import '../../models.dart'; // OpcionMaestra.
import 'local_cache_db_base.dart'; // Contrato LocalCacheDb.

/// Implementación en memoria de la caché local.
class LocalCacheDbMemory implements LocalCacheDb {
  final Map<String, Map<String, CachedOption>> _byType = {};

  @override
  Future<void> init() async {} // Nada que abrir.

  @override
  Future<List<OpcionMaestra>> search(
    String type,
    String query, {
    int limit = 20,
  }) async {
    final q = query.toLowerCase();
    final hits = _byType[type]
            ?.values
            .where((e) =>
                e.nombre.toLowerCase().contains(q) ||
                e.codigo.toLowerCase().contains(q))
            .toList() ??
        const <CachedOption>[];
    hits.sort((a, b) => b.lastUsed.compareTo(a.lastUsed));
    return hits.take(limit).map((e) => OpcionMaestra(codigo: e.codigo, nombre: e.nombre)).toList();
  }

  @override
  Future<List<OpcionMaestra>> listRecent(String type, {int limit = 20}) async {
    final entries = _byType[type]?.values.toList() ?? const <CachedOption>[];
    entries.sort((a, b) => b.lastUsed.compareTo(a.lastUsed));
    return entries.take(limit).map((e) => OpcionMaestra(codigo: e.codigo, nombre: e.nombre)).toList();
  }

  @override
  Future<int> upsertMany(String type, Iterable<OpcionMaestra> items) async {
    final bucket = _byType.putIfAbsent(type, () => {});
    final now = DateTime.now();
    var count = 0;
    for (final item in items) {
      bucket[item.codigo] = CachedOption(
        type: type,
        codigo: item.codigo,
        nombre: item.nombre,
        lastUsed: now,
      );
      count++;
    }
    return count;
  }

  @override
  Future<int> count(String type) async => _byType[type]?.length ?? 0;

  @override
  Future<void> clear(String type) async => _byType.remove(type);

  @override
  Future<void> close() async {}
}

/// Instancia singleton de la caché en memoria.
LocalCacheDb get localCacheDbInstance => _singleton;
final LocalCacheDb _singleton = LocalCacheDbMemory();