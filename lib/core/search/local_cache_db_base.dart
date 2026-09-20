// ============================================================================
//  local_cache_db_base.dart  —  CONTRATO DE LA CACHÉ LOCAL (interfaz)
// ============================================================================
//
//  ¿Qué es?
//  --------
//  La interfaz que cualquier "caché local" debe cumplir. Tiene DOS
//  implementaciones seleccionadas automáticamente según la plataforma:
//
//    - local_cache_db_io.dart   → SQLite real (sqflite + sqflite_common_ffi).
//                                 Android/iOS y escritorio (Windows/Linux/macOS).
//    - local_cache_db_stub.dart → En memoria pura Dart. Se usa en NAVEGADOR
//                                 (web), donde SQLite nativo no existe.
//
//  La tabla guarda los maestros (clientes, artículos) UNA vez consultados,
//  de modo que una segunda búsqueda offline encuentra resultados al instante.
// ============================================================================

import '../../models.dart'; // OpcionMaestra.

/// Entrada guardada en la caché local.
class CachedOption {
  final String type; // 'cliente' | 'articulo' | 'serie' | ...
  final String codigo; // Código guardado (lo que se envía a Velneo).
  final String nombre; // Nombre legible.
  final DateTime lastUsed; // Cuándo se consultó por última vez (para ordenar).

  const CachedOption({
    required this.type,
    required this.codigo,
    required this.nombre,
    required this.lastUsed,
  });
}

/// Contrato de la caché local. Las pantallas NO usan esto directamente:
/// usan EntitySearchRepository, que consulta aquí primero y toca Velneo
/// solo si la caché no tiene respuestas.
abstract class LocalCacheDb {
  /// Abre/crea la base de datos (idempotente).
  Future<void> init();

  /// Busca opciones locales cuyo nombre O código contenga [query],
  /// ordenadas por uso más reciente, hasta [limit] resultados.
  Future<List<OpcionMaestra>> search(
    String type,
    String query, {
    int limit = 20,
  });

  /// Devuelve las opciones usadas más recientemente de un tipo.
  Future<List<OpcionMaestra>> listRecent(String type, {int limit = 20});

  /// Inserta o actualiza varias opciones de un tipo (upsert).
  Future<int> upsertMany(String type, Iterable<OpcionMaestra> items);

  /// Número de entradas almacenadas de un tipo.
  Future<int> count(String type);

  /// Borra todas las entradas de un tipo.
  Future<void> clear(String type);

  /// Cierra la base de datos.
  Future<void> close();
}