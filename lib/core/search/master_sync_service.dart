// ============================================================================
//  master_sync_service.dart  —  SINCRONIZACIÓN DIFERIDA EN SEGUNDO PLANO
// ============================================================================
//
//  ¿Qué hace?
//  ----------
//  Mantiene la caché local (SQLite) con una "lista ligera" de clientes y
//  artículos SIN bloquear la interfaz:
//
//    - Tras el login arranca un Timer periódico (15 min por defecto).
//    - En cada ciclo, si la caché de un maestro está por debajo de un tope
//      (por ejemplo primera ejecución), descarga ALGUNAS páginas pequeñas de
//      Velneo (incremental, página a página) y las persiste. Así la app queda
//      útil sin descargar el catálogo entero.
//
//  ¿Por qué "páginas" y no una descarga completa?
//  ---------------------------------------------
//  Velneo (en este proyecto) no expone un campo de fecha de modificación
//  fiable para filtrar cambios, así que la sincronización se hace por lotes
//  acotados. El resto de novedades llega "por demanda": cada búsqueda del
//  usuario rellena la caché (write-through en EntitySearchRepository).
//
//  NOTA: el Timer corre en el hilo principal pero solo lanza peticiones
//  asíncronas pequeñas (500 ítems por página) y efectúa escrituras SQLite
//  ligeras; no congela la UI. Se puede migrar a un Isolate (compute) cuando
//  el volumen lo exija sin cambiar la interfaz pública.
// ============================================================================

import 'dart:async';
import 'package:flutter/foundation.dart';

import '../../api_service.dart'; // PedidosService (páginas de maestros).
import '../../models.dart'; // OpcionMaestra.
import 'entity_search_repository.dart'; // EntityKind + repositorio.

/// Sincroniza maestros pesados (clientes/artículos) en segundo plano.
class MasterSyncService {
  /// Instancia única (singleton).
  static final MasterSyncService instance = MasterSyncService._();

MasterSyncService._() : _repo = EntitySearchRepository();

  /// Repositorio inyectable para tests; en producción usa la caché local real.
  MasterSyncService({EntitySearchRepository? repository})
      : _repo = repository ?? EntitySearchRepository();

  final EntitySearchRepository _repo;

  /// Tope de filas por tipo: evita descargar la entidad completa.
  static const int maxCachedRowsPerKind = 500;
  static const int pageSize = 500;
  static const int maxPagesPerCycle = 3;

  Timer? _timer;
  bool _started = false;
  bool _running = false;

  /// Arranca el timer de sincronización (idempotente).
  void ensureStarted({Duration interval = const Duration(minutes: 15)}) {
    if (_started) return;
    _started = true;
    _timer = Timer.periodic(interval, (_) => syncHeavy());
    // Un primer ciclo inmediato en segundo plano (sin esperar 15 min).
    scheduleMicrotask(syncHeavy);
  }

  /// Una pasada de sincronización pesada (clientes + artículos) por lotes.
  Future<void> syncHeavy({
    Future<List<OpcionMaestra>> Function(EntityKind kind, int page)? fetchPage,
  }) async {
    if (_running) return;
    _running = true;
    try {
      await _syncIncremental(EntityKind.cliente, fetchPage: fetchPage);
      await _syncIncremental(EntityKind.articulo, fetchPage: fetchPage);
    } catch (e) {
      debugPrint('Sincronización diferida fallida: $e');
    } finally {
      _running = false;
    }
  }

  Future<void> _syncIncremental(
    EntityKind kind, {
    Future<List<OpcionMaestra>> Function(EntityKind kind, int page)? fetchPage,
  }) async {
    // Solo descargamos si la caché local tiene hueco (primera vez o recién
    // vaciada). Si ya está poblada, no re-descargamos el catálogo.
    final count = await _repo.count(kind);
    if (count >= maxCachedRowsPerKind) return;

    for (var page = 1; page <= maxPagesPerCycle; page++) {
      final items = await (fetchPage ?? _fetchPage)(kind, page);
      if (items.isEmpty) break;
      await _repo.upsert(kind, items);
    }
  }

  Future<List<OpcionMaestra>> _fetchPage(EntityKind kind, int page) {
    switch (kind) {
      case EntityKind.cliente:
        return PedidosService.getClientesPage(page, size: pageSize);
      case EntityKind.articulo:
        return PedidosService.getArticulosPage(page, size: pageSize);
    }
  }

  /// Detiene el timer (al desconectar).
  void stop() {
    _timer?.cancel();
    _timer = null;
    _started = false;
  }
}