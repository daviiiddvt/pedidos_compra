// ============================================================================
//  local_cache_db.dart  —  PUNTO DE ENTRADA DE LA CACHÉ LOCAL
// ============================================================================
//
//  Re-exporta la implementación correcta según la plataforma:
//    - Dispositivos con sistema de archivos (Android, iOS, Windows, ...) →
//      local_cache_db_io.dart   (SQLite real).
//    - Navegador web → local_cache_db_stub.dart (memoria).
//
//  El resto de la app importa solo este archivo y usa `LocalCacheDb` y
//  `localCacheDbInstance`.
// ============================================================================

export 'local_cache_db_base.dart';
export 'local_cache_db_stub.dart'
    if (dart.library.io) 'local_cache_db_io.dart';