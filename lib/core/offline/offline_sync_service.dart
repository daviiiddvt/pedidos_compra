import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../models/articulo.dart';
import '../../models/models.dart';
import '../api_client.dart';
import '../api_service.dart';
import '../articulos_service.dart';
import '../config.dart';
import '../presupuesto_service.dart';
import '../search/local_cache_db.dart';
import 'offline_database.dart';

class SyncProgress {
  final String stage;
  final double progress; // 0.0 a 1.0
  final String detail;

  const SyncProgress({
    required this.stage,
    required this.progress,
    required this.detail,
  });
}

/// Servicio encargado de la sincronización bidireccional:
/// - Botón 1: Sincronización masiva de Maestros (18 tablas)
/// - Botón 2: Sincronización de Pedidos y Presupuestos con sus líneas
class OfflineSyncService {
  static final OfflineSyncService instance = OfflineSyncService._();
  OfflineSyncService._();

  final _api = ApiClient.instance;
  final _db = OfflineDatabase.instance;

  bool _isSyncingMasters = false;
  bool _isSyncingDocuments = false;

  bool get isSyncingMasters => _isSyncingMasters;
  bool get isSyncingDocuments => _isSyncingDocuments;

  // ===========================================================================
  // COMPROBACIÓN DE CONECTIVIDAD
  // ===========================================================================

  /// Comprueba rápidamente si el servidor está accesible.
  Future<bool> isServerReachable({Duration timeout = const Duration(seconds: 3)}) async {
    try {
      final host = AppConfig.serverHost.trim();
      final apiKey = AppConfig.apiKey.trim();
      if (host.isEmpty || apiKey.isEmpty) return false;

      // Consulta ligera a series
      await _api
          .get(
            AppConfig.endpoint('series'),
            params: {'page[size]': 1},
          )
          .timeout(timeout);
      return true;
    } catch (_) {
      return false;
    }
  }

  // ===========================================================================
  // BOTÓN 1: SINCRONIZACIÓN DE MAESTROS
  // ===========================================================================

  Future<void> syncMasters({
    Function(SyncProgress progress)? onProgress,
  }) async {
    if (_isSyncingMasters) return;
    _isSyncingMasters = true;

    try {
      await _db.init();

      final standardMasters = const [
        _MasterTask(endpointKey: 'usuarios', tabla: 'USR_M', label: 'usuarios'),
        _MasterTask(endpointKey: 'gruposUsuarios', tabla: 'USR_GRP_USR_M', label: 'permisos de acceso'),
        _MasterTask(endpointKey: 'clientes', tabla: 'ENT_M', label: 'clientes y comerciales'),
        _MasterTask(endpointKey: 'direcciones', tabla: 'DIR_M', label: 'direcciones de entrega'),
        _MasterTask(endpointKey: 'empresa', tabla: 'EMP_M', label: 'datos de empresa'),
        _MasterTask(endpointKey: 'familias', tabla: 'FAM_M', label: 'familias de artículos'),
        _MasterTask(endpointKey: 'descuentosPorFamilia', tabla: 'DTO_POR_FAM', label: 'descuentos comerciales'),
        _MasterTask(endpointKey: 'tarifasCliente', tabla: 'vta_tar_cli_g', label: 'tarifas de clientes'),
        _MasterTask(endpointKey: 'tarifasArticulo', tabla: 'vta_tar_art_g', label: 'tarifas de artículos'),
        _MasterTask(endpointKey: 'tarifas', tabla: 'VTA_TAR_G', label: 'tarifas generales'),
        _MasterTask(endpointKey: 'almacenes', tabla: 'ALM_M', label: 'almacenes'),
        _MasterTask(endpointKey: 'series', tabla: 'SER_M', label: 'series de documentos'),
        _MasterTask(endpointKey: 'formasPago', tabla: 'FPG_M', label: 'formas de pago'),
        _MasterTask(endpointKey: 'zonasTecnicas', tabla: 'ZN_TCN', label: 'zonas técnicas'),
        _MasterTask(endpointKey: 'zonasComerciales', tabla: 'ZN_TCN_CMR', label: 'zonas comerciales'),
        _MasterTask(endpointKey: 'poblaciones', tabla: 'POB', label: 'poblaciones y códigos postales'),
      ];

      var completed = 0;
      onProgress?.call(
        const SyncProgress(
          stage: 'Sincronizando información general...',
          progress: 0.05,
          detail: 'Iniciando descarga de datos...',
        ),
      );

      // 1. Descarga concurrente de información general (4 conexiones en paralelo)
      await _runConcurrentPool<_MasterTask>(standardMasters, 4, (task) async {
        try {
          final items = await _fetchAllPages(task.endpointKey);
          await _db.saveMaestrosBatch(
            tabla: task.tabla,
            items: items,
            clearBefore: true,
          );

          if (task.tabla == 'ENT_M') {
            final clientesOptions = items.where((it) {
              final esClt = it['es_clt'] ?? it['ES_CLT'] ?? 1;
              return esClt != 0 && esClt != false && esClt != '0' && esClt != 'false';
            }).map((it) {
              final id = '${it['id'] ?? it['codigo'] ?? ''}';
              final nom = '${it['name'] ?? it['nombre'] ?? it['raz_soc'] ?? id}';
              return OpcionMaestra(codigo: id, nombre: nom);
            }).toList();

            await localCacheDbInstance.upsertMany('cliente', clientesOptions);
          }
        } catch (e) {
          final errStr = e.toString().toLowerCase();
          if (!errStr.contains('no es válido para este api key') && !errStr.contains('405')) {
            debugPrint('[OFFLINE_SYNC] Advertencia al sincronizar ${task.label}: $e');
          }
        } finally {
          completed++;
          final p = 0.05 + (0.35 * (completed / standardMasters.length));
          onProgress?.call(
            SyncProgress(
              stage: 'Sincronizando información general...',
              progress: p,
              detail: 'Actualizando ${task.label}...',
            ),
          );
        }
      });

      // 2. Descarga del catálogo de artículos (concurrente y paginada)
      onProgress?.call(
        const SyncProgress(
          stage: 'Sincronizando catálogo de artículos...',
          progress: 0.40,
          detail: 'Consultando catálogo...',
        ),
      );

      await _syncArticulosCatalog(
        onProgress: (downloaded, total) {
          final p = total > 0 ? (downloaded / total).clamp(0.0, 1.0) : 0.90;
          onProgress?.call(
            SyncProgress(
              stage: 'Sincronizando catálogo de artículos...',
              progress: 0.40 + (p * 0.55),
              detail: total > 0 ? '$downloaded de $total artículos' : '$downloaded artículos...',
            ),
          );
        },
      );

      // Guardar fecha de última sincronización
      final nowIso = DateTime.now().toIso8601String();
      await _db.setMetadata('last_sync_masters', nowIso);

      onProgress?.call(
        const SyncProgress(
          stage: '¡Sincronización completada con éxito!',
          progress: 1.0,
          detail: 'Todos los datos están listos para trabajar sin conexión.',
        ),
      );
    } finally {
      _isSyncingMasters = false;
    }
  }

  /// Descarga paginada concurrente de artículos en bloques de 500
  Future<void> _syncArticulosCatalog({
    required Function(int downloaded, int total) onProgress,
  }) async {
    const pageSize = 500;

    // Descargar primera página
    final jsonPage1 = await _api.get(
      AppConfig.endpoint('articulos'),
      params: {
        'page[number]': 1,
        'page[size]': pageSize,
        'filter[baj]': 0,
      },
    );

    final listPage1 = payloadLista(jsonPage1);
    if (listPage1.isEmpty) {
      onProgress(0, 0);
      return;
    }

    final totalEstimated = payloadTotal(jsonPage1);
    var downloadedCount = listPage1.length;

    await _processAndSaveArticulosPage(listPage1, clearBefore: true);
    onProgress(downloadedCount, totalEstimated > 0 ? totalEstimated : downloadedCount);

    if (listPage1.length < pageSize) {
      return;
    }

    final totalPages = totalEstimated > 0 ? (totalEstimated / pageSize).ceil() : 0;

    if (totalPages > 1) {
      final remainingPages = List.generate(totalPages - 1, (i) => i + 2);
      await _runConcurrentPool<int>(remainingPages, 3, (page) async {
        try {
          final pageJson = await _api.get(
            AppConfig.endpoint('articulos'),
            params: {
              'page[number]': page,
              'page[size]': pageSize,
              'filter[baj]': 0,
            },
          );
          final rawList = payloadLista(pageJson);
          if (rawList.isEmpty) return;

          await _processAndSaveArticulosPage(rawList, clearBefore: false);
          downloadedCount += rawList.length;
          onProgress(downloadedCount, totalEstimated);
        } catch (e) {
          debugPrint('[OFFLINE_SYNC] Error al descargar página $page de artículos: $e');
        }
      });
    } else {
      var page = 2;
      while (true) {
        final pageJson = await _api.get(
          AppConfig.endpoint('articulos'),
          params: {
            'page[number]': page,
            'page[size]': pageSize,
            'filter[baj]': 0,
          },
        );
        final rawList = payloadLista(pageJson);
        if (rawList.isEmpty) break;

        await _processAndSaveArticulosPage(rawList, clearBefore: false);
        downloadedCount += rawList.length;
        onProgress(downloadedCount, downloadedCount);

        if (rawList.length < pageSize) break;
        page++;
      }
    }
  }

  Future<void> _processAndSaveArticulosPage(
    List<Map<String, dynamic>> rawList, {
    required bool clearBefore,
  }) async {
    final validItems = rawList.where((map) {
      final art = Articulo.fromJson(map);
      return art.tieneFamilia;
    }).toList();

    await _db.saveMaestrosBatch(
      tabla: 'ART_M',
      items: validItems,
      clearBefore: clearBefore,
    );

    final pageOptions = <OpcionMaestra>[];
    for (final item in validItems) {
      final id = '${item['id'] ?? item['codigo'] ?? ''}';
      final nom = '${item['name'] ?? item['nombre'] ?? item['dsc'] ?? id}';
      final ref = '${item['ref'] ?? item['referencia'] ?? ''}';
      pageOptions.add(OpcionMaestra(codigo: id, nombre: nom, referencia: ref));
    }
    if (pageOptions.isNotEmpty) {
      await localCacheDbInstance.upsertMany('articulo', pageOptions);
    }
  }

  /// Descarga todas las páginas de un maestro estándar
  Future<List<Map<String, dynamic>>> _fetchAllPages(String endpointKey) async {
    final all = <Map<String, dynamic>>[];
    const pageSize = 500;
    var page = 1;

    if (endpointKey == 'series') {
      try {
        final json = await _api.get(
          AppConfig.endpoint(endpointKey),
          params: {'page[size]': 1},
        );
        final list = payloadLista(json);
        if (list.isNotEmpty) return list;
      } catch (_) {
        try {
          final json = await _api.get('${AppConfig.endpoint(endpointKey)}/1');
          final data = payloadData(json);
          if (data is Map) return [Map<String, dynamic>.from(data)];
        } catch (_) {
          return [];
        }
      }
      return [];
    }

    while (true) {
      final json = await _api.get(
        AppConfig.endpoint(endpointKey),
        params: {
          'page[number]': page,
          'page[size]': pageSize,
        },
      );

      final list = payloadLista(json);
      if (list.isEmpty) break;

      all.addAll(list);
      if (list.length < pageSize) break;
      page++;
    }

    return all;
  }

  // ===========================================================================
  // BOTÓN 2: SINCRONIZACIÓN DE PEDIDOS Y PRESUPUESTOS (ÚLTIMOS N DÍAS)
  // ===========================================================================

  Future<void> syncDocuments({
    int days = 30,
    User? currentUser,
    Function(SyncProgress progress)? onProgress,
  }) async {
    if (_isSyncingDocuments) return;
    _isSyncingDocuments = true;

    try {
      await _db.init();

      final cutoffDate = DateTime.now().subtract(Duration(days: days));
      final cutoffStr = cutoffDate.toIso8601String().substring(0, 10); // "YYYY-MM-DD"

      final roleLower = (currentUser?.role ?? '').toLowerCase();
      final isAdmin = roleLower == 'administrador' || roleLower == 'admin';
      final commercialId = currentUser?.contactId;

      // -----------------------------------------------------------------------
      // 1. Sincronizar Pedidos
      // -----------------------------------------------------------------------
      onProgress?.call(
        const SyncProgress(
          stage: 'Sincronizando pedidos de venta...',
          progress: 0.05,
          detail: 'Consultando pedidos recientes...',
        ),
      );

      final pedidosDescargados = <Pedido>[];
      const pageSize = 50;
      var pagePed = 1;

      while (true) {
        final params = <String, dynamic>{
          'page[number]': pagePed,
          'page[size]': pageSize,
          'sort': '-fch',
        };

        if (!isAdmin && commercialId != null && commercialId.isNotEmpty) {
          params['filter[cmr]'] = commercialId;
        }

        final json = await _api.get(AppConfig.endpoint('pedidos'), params: params);
        final list = payloadLista(json);
        if (list.isEmpty) break;

        var reachedOld = false;
        for (final item in list) {
          final p = Pedido.fromJson(item);
          final fch = p.fecha.trim();

          if (fch.isNotEmpty && fch.length >= 10 && fch.substring(0, 10).compareTo(cutoffStr) < 0) {
            reachedOld = true;
            break;
          }
          pedidosDescargados.add(p);
        }

        if (reachedOld || list.length < pageSize) break;
        pagePed++;
      }

      // Descargar líneas para cada pedido (4 concurrentes)
      final totalPeds = pedidosDescargados.length;
      final pedidosConLineas = List<Pedido?>.filled(totalPeds, null);
      var pedsDone = 0;

      await _runConcurrentPool<int>(
        List.generate(totalPeds, (i) => i),
        4,
        (i) async {
          final ped = pedidosDescargados[i];
          final id = ped.id ?? ped.codigo;
          try {
            final lineas = await PedidosService.getLineasPedido(id);
            pedidosConLineas[i] = ped.copyWith(lineas: lineas);
          } catch (_) {
            pedidosConLineas[i] = ped;
          }
          pedsDone++;
          final p = 0.10 + (0.35 * (pedsDone / (totalPeds > 0 ? totalPeds : 1)));
          onProgress?.call(
            SyncProgress(
              stage: 'Sincronizando pedidos de venta...',
              progress: p,
              detail: 'Descargando líneas ($pedsDone de $totalPeds)...',
            ),
          );
        },
      );

      final pedidosToSave = await PedidosService.enrichPedidosWithMasterData(
        pedidosConLineas.whereType<Pedido>().toList(),
      );
      await _db.savePedidosOffline(
        pedidosToSave,
        clearBefore: true,
      );

      // -----------------------------------------------------------------------
      // 2. Sincronizar Presupuestos
      // -----------------------------------------------------------------------
      onProgress?.call(
        const SyncProgress(
          stage: 'Sincronizando presupuestos...',
          progress: 0.45,
          detail: 'Consultando presupuestos recientes...',
        ),
      );

      final presupuestosDescargados = <PresupuestoVenta>[];
      var pagePre = 1;

      while (true) {
        final params = <String, dynamic>{
          'page[number]': pagePre,
          'page[size]': pageSize,
          'sort': '-fch',
        };

        if (!isAdmin && commercialId != null && commercialId.isNotEmpty) {
          params['filter[cmr]'] = commercialId;
        }

        final json = await _api.get(AppConfig.endpoint('presupuestos'), params: params);
        final list = payloadLista(json);
        if (list.isEmpty) break;

        var reachedOld = false;
        for (final item in list) {
          final pre = PresupuestoVenta.fromJson(item);
          final fch = pre.fecha.trim();

          if (fch.isNotEmpty && fch.length >= 10 && fch.substring(0, 10).compareTo(cutoffStr) < 0) {
            reachedOld = true;
            break;
          }
          presupuestosDescargados.add(pre);
        }

        if (reachedOld || list.length < pageSize) break;
        pagePre++;
      }

      // Descargar líneas para cada presupuesto (4 concurrentes)
      final totalPres = presupuestosDescargados.length;
      final presupuestosConLineas = List<PresupuestoVenta?>.filled(totalPres, null);
      var presDone = 0;

      await _runConcurrentPool<int>(
        List.generate(totalPres, (i) => i),
        4,
        (i) async {
          final pre = presupuestosDescargados[i];
          final id = pre.id;
          if (id != null) {
            try {
              final lineas = await PresupuestosService.getLineasPresupuesto(id);
              presupuestosConLineas[i] = pre.copyWith(lineas: lineas);
            } catch (_) {
              presupuestosConLineas[i] = pre;
            }
          } else {
            presupuestosConLineas[i] = pre;
          }
          presDone++;
          final p = 0.50 + (0.30 * (presDone / (totalPres > 0 ? totalPres : 1)));
          onProgress?.call(
            SyncProgress(
              stage: 'Sincronizando presupuestos...',
              progress: p,
              detail: 'Descargando líneas ($presDone de $totalPres)...',
            ),
          );
        },
      );

      final presupuestosToSave = await PresupuestosService.enrichPresupuestosWithMasterData(
        presupuestosConLineas.whereType<PresupuestoVenta>().toList(),
      );
      await _db.savePresupuestosOffline(
        presupuestosToSave,
        clearBefore: true,
      );

      // -----------------------------------------------------------------------
      // 3. Sincronizar Base de Conocimiento de Líneas (Movimientos artículo + cliente)
      // -----------------------------------------------------------------------
      final uniquePairs = <String, ({String artId, String cltId})>{};

      for (final p in pedidosConLineas) {
        if (p == null) continue;
        final clt = p.clienteId > 0 ? p.clienteId.toString() : p.cliente.trim();
        for (final l in p.lineas) {
          final artId = l.articulo.trim();
          if (artId.isNotEmpty) {
            final lineClt = clt.isNotEmpty ? clt : l.clienteVenta.trim();
            final key = '$artId#$lineClt';
            uniquePairs[key] = (artId: artId, cltId: lineClt);
          }
        }
      }

      for (final pre in presupuestosConLineas) {
        if (pre == null) continue;
        final clt = pre.clienteId > 0 ? pre.clienteId.toString() : pre.cliente.trim();
        for (final l in pre.lineas) {
          final artId = l.articulo.trim();
          if (artId.isNotEmpty) {
            final lineClt = clt;
            final key = '$artId#$lineClt';
            uniquePairs[key] = (artId: artId, cltId: lineClt);
          }
        }
      }

      if (uniquePairs.isNotEmpty) {
        final pairList = uniquePairs.values.toList();
        var movsProcessed = 0;
        onProgress?.call(
          SyncProgress(
            stage: 'Sincronizando histórico de ventas de líneas...',
            progress: 0.82,
            detail: 'Descargando histórico (${pairList.length} combinaciones)...',
          ),
        );

        await _runConcurrentPool<({String artId, String cltId})>(
          pairList,
          4,
          (pair) async {
            try {
              final res = await ArticulosService.getMovimientosArticulo(
                articuloId: pair.artId,
                clienteId: pair.cltId.isNotEmpty ? pair.cltId : null,
                page: 1,
                pageSize: 50,
              );
              if (res.items.isNotEmpty) {
                await _db.saveMovimientosArticulo(
                  pair.artId,
                  res.items,
                  clienteId: pair.cltId.isNotEmpty ? pair.cltId : null,
                );
              }
            } catch (_) {}
            movsProcessed++;
            final p = 0.82 + (0.16 * (movsProcessed / pairList.length));
            onProgress?.call(
              SyncProgress(
                stage: 'Sincronizando histórico de ventas de líneas...',
                progress: p,
                detail: 'Histórico de ventas ($movsProcessed de ${pairList.length})...',
              ),
            );
          },
        );
      }

      // Guardar metadatos
      final nowIso = DateTime.now().toIso8601String();
      await _db.setMetadata('last_sync_documents', nowIso);
      await _db.setMetadata('sync_days_history', '$days');

      onProgress?.call(
        SyncProgress(
          stage: '¡Sincronización completada con éxito!',
          progress: 1.0,
          detail: '$totalPeds pedidos y $totalPres presupuestos guardados.',
        ),
      );
    } finally {
      _isSyncingDocuments = false;
    }
  }

  /// Ejecuta tareas concurrentemente con un límite de trabajadores simultáneos.
  Future<void> _runConcurrentPool<T>(
    List<T> items,
    int concurrency,
    Future<void> Function(T item) worker,
  ) async {
    if (items.isEmpty) return;
    var index = 0;
    Future<void> runWorker() async {
      while (true) {
        if (index >= items.length) break;
        final current = items[index++];
        await worker(current);
      }
    }

    final poolSize = items.length < concurrency ? items.length : concurrency;
    await Future.wait(List.generate(poolSize, (_) => runWorker()));
  }

  // ===========================================================================
  // CONSULTA DE METADATOS
  // ===========================================================================

  Future<DateTime?> getLastSyncMasters() async {
    final val = await _db.getMetadata('last_sync_masters');
    if (val == null || val.isEmpty) return null;
    return DateTime.tryParse(val);
  }

  Future<DateTime?> getLastSyncDocuments() async {
    final val = await _db.getMetadata('last_sync_documents');
    if (val == null || val.isEmpty) return null;
    return DateTime.tryParse(val);
  }

  Future<int> getSyncDaysHistory() async {
    final val = await _db.getMetadata('sync_days_history');
    if (val == null || val.isEmpty) return 30;
    return int.tryParse(val) ?? 30;
  }

  Future<void> setSyncDaysHistory(int days) async {
    await _db.setMetadata('sync_days_history', '$days');
  }
}

class _MasterTask {
  final String endpointKey;
  final String tabla;
  final String label;

  const _MasterTask({
    required this.endpointKey,
    required this.tabla,
    required this.label,
  });
}

