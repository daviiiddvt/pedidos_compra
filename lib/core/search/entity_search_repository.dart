// ============================================================================
//  entity_search_repository.dart  —  REPOSITORIO LOCAL-FIRST (OFFLINE-FIRST)
// ============================================================================
//
//  ¿Qué es?
//  --------
//  El único punto por el que la UI busca clientes y artículos. Estrategia:
//
//    1. Pregunta PRIMERO a la caché local (SQLite) → respuesta instantánea.
//    2. Si no hay coincidencias locales, pregunta a Velneo (búsqueda acotada,
//       2-20 resultado) y GUARDA el resultado para el futuro sin conexión.
//
//  Así la segunda búsqueda del mismo término es instantánea y offline, y
//  nunca se descarga el catálogo completo.
//
//  Limpieza:
//  - La UI (AutocompleteField → RemoteSearchCubit) nunca habla con Velneo:
//    habla con este repositorio.
//  - Añadir un maestro nuevo (ej. almacenes) = añadir un valor a EntityKind.
// ============================================================================

import '../../api_service.dart'; // PedidosService (búsqueda remota acotada).
import '../../models.dart'; // OpcionMaestra.
import 'local_cache_db.dart'; // LocalCacheDb + localCacheDbInstance.

/// Tipos de entidad buscables. Cada valor sabe el 'type' usado en la caché.
enum EntityKind {
  cliente('cliente'),
  articulo('articulo');

  final String type;
  const EntityKind(this.type);
}

/// Repositorio de búsqueda con estrategia "caché local primero, API después".
class EntitySearchRepository {
  final LocalCacheDb _db;

  /// Fábrica de búsqueda remota inyectable (tests). null = PedidosService.
  final Future<List<OpcionMaestra>> Function(
    EntityKind kind,
    String query, {
    required int limit,
  })? _remoteOverride;

  EntitySearchRepository({
    LocalCacheDb? db,
    Future<List<OpcionMaestra>> Function(
      EntityKind kind,
      String query, {
      required int limit,
    })? remoteSearch,
  })  : _db = db ?? localCacheDbInstance,
        _remoteOverride = remoteSearch;

  /// Busca [query] entre las opciones de [kind].
  ///
  /// Primero consulta la caché local; si no hay coincidencias o la búsqueda
  /// local no basta, consulta a Velneo y persiste los resultados.
  Future<List<OpcionMaestra>> search(
    EntityKind kind,
    String query, {
    int limit = 20,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];

    final local = await _db.search(kind.type, trimmed, limit: limit);
    if (local.isNotEmpty) return local;

    final remote = await _remoteSearch(kind, trimmed, limit: limit);
    if (remote.isNotEmpty) {
      await _db.upsertMany(kind.type, remote);
    }
    return remote;
  }

  /// Opciones consultadas más recientemente (para sugerir sin teclear).
  Future<List<OpcionMaestra>> recent(EntityKind kind, {int limit = 20}) {
    return _db.listRecent(kind.type, limit: limit);
  }

  /// Guarda opciones en la caché local (usado por la sincronización diferida).
  Future<int> upsert(EntityKind kind, Iterable<OpcionMaestra> items) {
    return _db.upsertMany(kind.type, items);
  }

  /// Número de opciones cacheadas de un tipo (para decidir si sincronizar).
  Future<int> count(EntityKind kind) => _db.count(kind.type);

  Future<void> clear(EntityKind kind) => _db.clear(kind.type);

  /// Delegación a la búsqueda remota. Si hay override (tests) se usa ese;
  /// en producción se delega a Velneo. Solo se invoca cuando la caché falla.
  Future<List<OpcionMaestra>> _remoteSearch(
    EntityKind kind,
    String query, {
    required int limit,
  }) {
    if (_remoteOverride != null) {
      return _remoteOverride(kind, query, limit: limit);
    }
    switch (kind) {
      case EntityKind.cliente:
        return PedidosService.searchClientes(query, limit: limit);
      case EntityKind.articulo:
        return PedidosService.searchArticulos(query, limit: limit);
    }
  }
}