import 'package:flutter/foundation.dart';
import 'api_client.dart';
import 'config.dart';
import '../theme/app_theme.dart';
import 'api_service.dart';
import 'master_cache_service.dart';
import '../models/models.dart';
import 'offline/offline_database.dart';
import 'offline/connection_status_service.dart';

/// API operations for sales budgets. Budgets use the same document models and
/// line payloads as orders, but are stored in their own Velneo tables.
class PresupuestosService {
  static final _api = ApiClient.instance;

  static Future<List<LineaPresupuestoVenta>> getLineasPresupuesto(dynamic id) async {
    try {
      final lineasJson = await _api.get(
        AppConfig.endpoint('lineasPresupuesto'),
        params: {'filter[vta_pre]': '$id', 'page[size]': 100},
      );
      return payloadLista(lineasJson)
          .map(LineaPresupuestoVenta.fromJson)
          .toList();
    } catch (_) {
      return OfflineDatabase.instance.getLineasPresupuestoOffline(id);
    }
  }

  static Future<ResultadoLista<PresupuestoVenta>> list({
    int page = 1,
    String? estado,
    String? cliente,
    String? search,
    String? comercial,
  }) async {
    final params = <String, dynamic>{
      'page[number]': page,
      'page[size]': AppConfig.pageSize,
      'sort': '-fch',
      if (estado != null && estado.isNotEmpty)
        'filter[est]': AppColors.estadoCodigo(estado),
      if (cliente != null && cliente.isNotEmpty) 'filter[clt]': cliente,
      if (search != null && search.isNotEmpty) 'filter[words]': search,
      if (comercial != null && comercial.isNotEmpty) 'filter[cmr]': comercial,
    };
    try {
      final json = await _api.get(
        AppConfig.endpoint('presupuestos'),
        params: params,
      );
      final rawItems = payloadLista(json).map(PresupuestoVenta.fromJson).toList();
      final items = await enrichPresupuestosWithClientNames(rawItems);
      final reportedTotal = payloadTotal(json);
      final total = reportedTotal == items.length &&
              items.length >= AppConfig.pageSize
          ? 0
          : reportedTotal;
      debugPrint(
        '[PRESUPUESTOS] página=$page, recibidos=${items.length}, '
        'total=${total == 0 ? "no informado" : total}',
      );
      return ResultadoLista<PresupuestoVenta>(
        items: items,
        total: total,
        page: page,
      );
    } catch (e) {
      debugPrint('[PRESUPUESTOS] Error al conectar con el servidor, leyendo de SQLite: $e');
      final offline = await OfflineDatabase.instance.getPresupuestosOffline(
        estado: estado,
        comercialId: comercial,
        search: search,
      );
      final enrichedOffline = await enrichPresupuestosWithClientNames(offline);
      return ResultadoLista<PresupuestoVenta>(
        items: enrichedOffline,
        total: offline.length,
        page: page,
      );
    }
  }

  /// Enriquece los presupuestos con cliente, comercial, serie, almacén y forma de pago.
  static Future<List<PresupuestoVenta>> enrichPresupuestosWithMasterData(
      List<PresupuestoVenta> presupuestos) async {
    if (presupuestos.isEmpty) return presupuestos;

    final missingClientIds = <int>{};
    final missingComercialIds = <String>{};
    final missingSeries = <String>{};
    final missingAlmacenes = <String>{};
    final missingFpg = <String>{};

    for (final p in presupuestos) {
      final cid = p.clienteId > 0 ? p.clienteId : (int.tryParse(p.cliente.trim()) ?? 0);
      final nom = p.clienteNombre.trim();
      final esNumero = int.tryParse(nom) != null;
      if ((nom.isEmpty || nom == p.cliente.trim() || esNumero) && cid > 0) {
        missingClientIds.add(cid);
      }
      final cmrNom = p.comercialNombre.trim();
      final cmrVal = p.comercial.trim();
      if ((cmrNom.isEmpty || cmrNom == cmrVal) && cmrVal.isNotEmpty) {
        missingComercialIds.add(cmrVal);
      }
      final serNom = p.serieNombre.trim();
      final serVal = p.serie.trim();
      if ((serNom.isEmpty || serNom == serVal) && serVal.isNotEmpty) {
        missingSeries.add(serVal);
      }
      final almNom = p.almacenNombre.trim();
      final almVal = p.almacen.trim();
      if ((almNom.isEmpty || almNom == almVal) && almVal.isNotEmpty) {
        missingAlmacenes.add(almVal);
      }
      final fpgNom = p.formaPagoNombre.trim();
      final fpgVal = p.formaPago.trim();
      if ((fpgNom.isEmpty || fpgNom == fpgVal) && fpgVal.isNotEmpty) {
        missingFpg.add(fpgVal);
      }
    }

    final clientesMap = missingClientIds.isNotEmpty 
        ? await PedidosService.getClientesMapByIds(missingClientIds.toList()) 
        : <int, Cliente>{};

    final comercialesMap = <String, String>{};
    for (final cmrId in missingComercialIds) {
      final nom = await PedidosService.getContactName(cmrId);
      if (nom.isNotEmpty && nom != cmrId) {
        comercialesMap[cmrId] = nom;
      }
    }

    // Series map
    final seriesMap = <String, String>{};
    if (missingSeries.isNotEmpty) {
      try {
        final seriesList = await MasterCacheService().getOrLoad(
          key: 'series',
          loader: PedidosService.getSeries,
        );
        for (final s in seriesList) {
          seriesMap[s.codigo] = s.nombre;
        }
      } catch (_) {}
      for (final sCod in missingSeries) {
        if (!seriesMap.containsKey(sCod)) {
          final nom = await OfflineDatabase.instance.getNombreMaestroOffline('SER_M', sCod);
          if (nom.isNotEmpty) seriesMap[sCod] = nom;
        }
      }
    }

    // Almacenes map
    final almacenesMap = <String, String>{};
    if (missingAlmacenes.isNotEmpty) {
      try {
        final almacenesList = await MasterCacheService().getOrLoad(
          key: 'almacenes',
          loader: PedidosService.getAlmacenes,
        );
        for (final a in almacenesList) {
          almacenesMap[a.codigo] = a.nombre;
        }
      } catch (_) {}
      for (final aCod in missingAlmacenes) {
        if (!almacenesMap.containsKey(aCod)) {
          final nom = await OfflineDatabase.instance.getNombreMaestroOffline('ALM_M', aCod);
          if (nom.isNotEmpty) almacenesMap[aCod] = nom;
        }
      }
    }

    // Formas de pago map
    final fpgMap = <String, String>{};
    if (missingFpg.isNotEmpty) {
      try {
        final fpgList = await MasterCacheService().getOrLoad(
          key: 'formas_pago',
          loader: PedidosService.getFormasPago,
        );
        for (final f in fpgList) {
          fpgMap[f.codigo] = f.nombre;
        }
      } catch (_) {}
      for (final fCod in missingFpg) {
        if (!fpgMap.containsKey(fCod)) {
          final nom = await OfflineDatabase.instance.getNombreMaestroOffline('FPG_M', fCod);
          if (nom.isNotEmpty) fpgMap[fCod] = nom;
        }
      }
    }

    return presupuestos.map((p) {
      var item = p;
      final cid = p.clienteId > 0 ? p.clienteId : (int.tryParse(p.cliente.trim()) ?? 0);
      final nom = p.clienteNombre.trim();
      final esNumero = int.tryParse(nom) != null;
      if (nom.isEmpty || nom == p.cliente.trim() || esNumero) {
        final c = clientesMap[cid];
        if (c != null && c.nombreComercial.isNotEmpty) {
          item = item.copyWith(
            clienteId: cid,
            clienteNombre: c.nombreComercial,
          );
        }
      }

      final cmrTrim = item.comercial.trim();
      if ((item.comercialNombre.trim().isEmpty || item.comercialNombre.trim() == cmrTrim) && comercialesMap.containsKey(cmrTrim)) {
        item = item.copyWith(comercialNombre: comercialesMap[cmrTrim]!);
      }
      final serTrim = item.serie.trim();
      if ((item.serieNombre.trim().isEmpty || item.serieNombre.trim() == serTrim) && seriesMap.containsKey(serTrim)) {
        item = item.copyWith(serieNombre: seriesMap[serTrim]!);
      }
      final almTrim = item.almacen.trim();
      if ((item.almacenNombre.trim().isEmpty || item.almacenNombre.trim() == almTrim) && almacenesMap.containsKey(almTrim)) {
        item = item.copyWith(almacenNombre: almacenesMap[almTrim]!);
      }
      final fpgTrim = item.formaPago.trim();
      if ((item.formaPagoNombre.trim().isEmpty || item.formaPagoNombre.trim() == fpgTrim) && fpgMap.containsKey(fpgTrim)) {
        item = item.copyWith(formaPagoNombre: fpgMap[fpgTrim]!);
      }

      return item;
    }).toList();
  }

  /// Enriquece los presupuestos con el nombre del cliente desde memoria/SQLite
  static Future<List<PresupuestoVenta>> enrichPresupuestosWithClientNames(
      List<PresupuestoVenta> presupuestos) =>
      enrichPresupuestosWithMasterData(presupuestos);

  static Future<List<PresupuestoVenta>> listAll({String? comercial}) async {
    final all = <PresupuestoVenta>[];
    var page = 1;
    var total = 0;
    do {
      final result = await list(page: page, comercial: comercial);
      all.addAll(result.items);
      total = result.total;
      page++;
      if (result.items.isEmpty ||
          (total > 0 && all.length >= total) ||
          result.items.length < AppConfig.pageSize) {
        break;
      }
    } while (true);
    return all;
  }

  static Future<PresupuestoVenta> getById(dynamic id) async {
    try {
      final json = await _api.get('${AppConfig.endpoint('presupuestos')}/$id');
      final data = payloadData(json);
      if (data is! Map) throw ApiException('No se pudo leer el presupuesto.');
      var presupuesto = PresupuestoVenta.fromJson(
        Map<String, dynamic>.from(data),
      );
      final lineas = await getLineasPresupuesto(id);
      final clientes = await PedidosService.getClientesByIds([
        presupuesto.clienteId,
      ]);
      if (clientes.isNotEmpty) {
        final cliente = clientes.first;
        presupuesto = presupuesto.copyWith(
          clienteNombre: cliente.nombreComercial,
        );
      }
      if (presupuesto.comercial.isNotEmpty &&
          presupuesto.comercialNombre.isEmpty) {
        try {
          final comercialNombre = await PedidosService.getContactName(
            presupuesto.comercial,
          );
          if (comercialNombre.isNotEmpty) {
            presupuesto = presupuesto.copyWith(comercialNombre: comercialNombre);
          }
        } catch (_) {
          // El código sigue siendo válido aunque no se pueda resolver el nombre.
        }
      }

      final cache = MasterCacheService();
      final cachedSeries = cache.getSync<List<OpcionMaestra>>('series');
      final cachedFpg = cache.getSync<List<OpcionMaestra>>('formas_pago');
      final serieOpcion = PedidosService.findMatchingOption(cachedSeries ?? [], presupuesto.serie);
      final fpgOpcion = PedidosService.findMatchingOption(cachedFpg ?? [], presupuesto.formaPago);

      return presupuesto.copyWith(
        lineas: lineas,
        serieNombre: serieOpcion?.nombre ?? presupuesto.serieNombre,
        formaPagoNombre: fpgOpcion?.nombre ?? presupuesto.formaPagoNombre,
      );
    } catch (e) {
      debugPrint('[PRESUPUESTOS] Error conectando con el servidor para presupuesto $id, buscando en SQLite: $e');
      final offlineList = await OfflineDatabase.instance.getPresupuestosOffline();
      final found = offlineList.firstWhere(
        (p) => '${p.id}' == '$id' || p.numeroPresupuesto == '$id',
        orElse: () => throw ApiException('Presupuesto no encontrado localmente ($e)'),
      );
      final lineas = await getLineasPresupuesto(id);
      final enriched = await enrichPresupuestosWithMasterData([found.copyWith(lineas: lineas)]);
      return enriched.first;
    }
  }

  static Map<String, dynamic> _payload(PresupuestoVenta pedido) => {
    'clt': pedido.clienteId,
    'est': AppColors.estadoCodigo(pedido.estado),
    'ser': pedido.serie,
    'cmr': pedido.comercial,
    'fch': _fechaVelneo(pedido.fecha),
    'fch_val': _fechaVelneo(pedido.fechaValidez),
    'fpg': pedido.formaPago,
    'dir_env': pedido.direccionEnvio,
    'EMAIL_DE_ENVIO_CLT': pedido.email,
    'obs': pedido.observaciones,
    'emp': '1',
    'emp_div': '1',
  };

  static Future<String> _ensureDireccionId(int clienteId, String dirEnv) async {
    if (dirEnv.isEmpty) return dirEnv;
    if (int.tryParse(dirEnv.trim()) != null) return dirEnv;
    try {
      final direcciones = await PedidosService.getDireccionesCliente(clienteId);
      for (final d in direcciones) {
        if (d.nombre.trim().toLowerCase() == dirEnv.trim().toLowerCase()) {
          return d.codigo;
        }
      }
    } catch (_) {}
    return dirEnv;
  }

  static Future<PresupuestoVenta> createComplete(
    PresupuestoVenta pedido, {
    bool isSync = false,
  }) async {
    try {
      final dirId = await _ensureDireccionId(pedido.clienteId, pedido.direccionEnvio);
      final pedidoMapeado = pedido.copyWith(direccionEnvio: dirId);
      
      final json = await _api.post(
        AppConfig.endpoint('presupuestos'),
        body: _payload(pedidoMapeado),
      );
      final data = payloadData(json);
      if (data is! Map) throw ApiException('No se pudo crear el presupuesto.');
      final created = PresupuestoVenta.fromJson(Map<String, dynamic>.from(data));
      final id = created.id;
      if (id == null) {
        throw ApiException('El servidor no devolvió el ID del presupuesto creado.');
      }
      await enviarLineas(id, pedido.lineas);
      return created.copyWith(id: id, lineas: pedido.lineas);
    } catch (e) {
      if (isSync) {
        // En sincronización Outbox: propagar el error para reintentar más tarde, NUNCA duplicar
        rethrow;
      }
      final tempId = (pedido.id != null && pedido.id! < 0)
          ? pedido.id!
          : -(DateTime.now().millisecondsSinceEpoch % 1000000000);
      final offlinePresupuesto = pedido.copyWith(
        id: tempId,
        numeroPresupuesto: pedido.numeroPresupuesto.isNotEmpty
            ? pedido.numeroPresupuesto
            : 'OFFLINE-${tempId.abs()}',
      );
      await OfflineDatabase.instance.savePresupuestoOfflineOutbox(
        presupuesto: offlinePresupuesto,
      );
      debugPrint('[PRESUPUESTOS] Presupuesto guardado en cola Outbox offline: $tempId');
      return offlinePresupuesto;
    }
  }

  static Future<void> marcarAceptado(dynamic budgetId, {bool isSync = false}) async {
    if (budgetId == null) return;
    final isOfflineId = (budgetId is num && budgetId < 0) || (int.tryParse('$budgetId') != null && int.parse('$budgetId') < 0);
    final isOffline = isOfflineId || !ConnectionStatusService.instance.isOnline;

    if (isOffline && !isSync) {
      await OfflineDatabase.instance.marcarPresupuestoAceptadoOffline(
        budgetId,
        queueOutbox: !isOfflineId,
      );
      return;
    }

    try {
      await _api.post('${AppConfig.endpoint('presupuestos')}/$budgetId', body: {'est': 'A'});
      await _marcarLineasAceptadas(budgetId);
      await OfflineDatabase.instance.marcarPresupuestoAceptadoOffline(
        budgetId,
        queueOutbox: false,
      );
    } catch (e) {
      if (isSync) rethrow;
      debugPrint('[PRESUPUESTOS] Error o sin conexión en marcarAceptado: $e, guardando offline');
      await OfflineDatabase.instance.marcarPresupuestoAceptadoOffline(
        budgetId,
        queueOutbox: !isOfflineId,
      );
    }
  }

  static Future<void> _marcarLineasAceptadas(dynamic budgetId) async {
    final endpoint = AppConfig.endpoint('lineasPresupuesto');
    var page = 1;
    while (true) {
      final lineasJson = await _api.get(
        endpoint,
        params: {
          'filter[vta_pre]': '$budgetId',
          'page[size]': 100,
          'page[number]': page,
        },
      );
      final lineas = payloadLista(lineasJson);
      for (final linea in lineas) {
        final lineaId = linea['id'] ?? linea['id_reg'] ?? linea['ID'];
        if (lineaId != null) {
          await _api.post('$endpoint/$lineaId', body: {'est': 'A'});
        }
      }
      if (lineas.length < 100) break;
      page++;
    }
  }

  static Future<void> linkPedido(dynamic budgetId, dynamic pedidoId, {bool isSync = false}) async {
    if (budgetId == null || pedidoId == null) return;
    final isOfflineId = (budgetId is num && budgetId < 0) || (int.tryParse('$budgetId') != null && int.parse('$budgetId') < 0);
    final isPedidoOfflineId = (pedidoId is num && pedidoId < 0) || (int.tryParse('$pedidoId') != null && int.parse('$pedidoId') < 0);
    final isOffline = isOfflineId || isPedidoOfflineId || !ConnectionStatusService.instance.isOnline;

    if (isOffline && !isSync) {
      await OfflineDatabase.instance.linkPedidoPresupuestoOffline(budgetId, pedidoId);
      return;
    }

    try {
      // 1. Actualizamos cabecera del presupuesto
      await _api.post(
        '${AppConfig.endpoint('presupuestos')}/$budgetId',
        body: {
          'est': 'A', // Aceptado
          'vta_ped_g': pedidoId,
        },
      );
      // 2. Actualizamos las líneas a Aceptado
      await _marcarLineasAceptadas(budgetId);
      await OfflineDatabase.instance.linkPedidoPresupuestoOffline(budgetId, pedidoId);
    } catch (e) {
      if (isSync) rethrow;
      debugPrint('[PRESUPUESTOS] Error o sin conexión en linkPedido: $e, actualizando offline');
      await OfflineDatabase.instance.linkPedidoPresupuestoOffline(budgetId, pedidoId);
    }
  }

  static Future<PresupuestoVenta> updateComplete(
    dynamic id,
    PresupuestoVenta pedido,
    Set<int> removedLineIds, {
    bool isSync = false,
  }) async {
    final isOfflineId = (id is num && id < 0) || (int.tryParse('$id') != null && int.parse('$id') < 0);
    if (isOfflineId && !isSync) {
      // Documento temporal creado sin conexión: guardar directamente en SQLite/Outbox
      await OfflineDatabase.instance.savePresupuestoOfflineOutbox(
        presupuesto: pedido,
        accion: 'crear',
        removedLineIds: removedLineIds.toList(),
      );
      return pedido.copyWith(id: id is int ? id : pedido.id, lineas: pedido.lineas);
    }

    try {
      final dirId = await _ensureDireccionId(pedido.clienteId, pedido.direccionEnvio);
      final pedidoMapeado = pedido.copyWith(direccionEnvio: dirId);

      final json = await _api.post(
        '${AppConfig.endpoint('presupuestos')}/$id',
        body: _payload(pedidoMapeado),
      );
      final data = payloadData(json);
      for (final lineId in removedLineIds) {
        if (lineId > 0) {
          await eliminarLinea(lineId);
        }
      }
      await enviarLineas(id, pedido.lineas);
      if (AppColors.estadoCodigo(pedido.estado) == 'A') {
        await _marcarLineasAceptadas(id);
      }
      if (data is Map) {
        return PresupuestoVenta.fromJson(Map<String, dynamic>.from(data))
            .copyWith(id: id is int ? id : pedido.id, lineas: pedido.lineas);
      }
      return pedido.copyWith(
        id: id is int ? id : pedido.id,
        lineas: pedido.lineas,
      );
    } catch (e) {
      if (isSync) {
        rethrow;
      }
      debugPrint('[PRESUPUESTOS] Sin conexión al editar presupuesto $id, guardando en Outbox offline: $e');
      await OfflineDatabase.instance.savePresupuestoOfflineOutbox(
        presupuesto: pedido,
        accion: isOfflineId ? 'crear' : 'editar',
        removedLineIds: removedLineIds.toList(),
      );
      return pedido.copyWith(
        id: id is int ? id : pedido.id,
        lineas: pedido.lineas,
      );
    }
  }

  static String _fechaVelneo(String value) {
    final text = value.trim();
    return text.isEmpty ? '' : text.split('T').first;
  }

    /// Ejecuta el proceso de Velneo ACT_VTA_PRE_LIN_G_APP.pro para una línea de presupuesto.
  /// Método GET con parámetros: ID, ART, CAN, PRE, EST, REG_IVA_VTA.
  static Future<void> ejecutarProcesoActualizarLinea({
    required dynamic id,
    required dynamic articulo,
    required num cantidad,
    required num precio,
    required String estado,
    required String regIvaVta,
  }) async {
    final params = <String, dynamic>{
      'ID': id,
      'ART': articulo,
      'CAN': cantidad,
      'PRE': precio,
      'EST': estado,
      'REG_IVA': regIvaVta,
    };
    debugPrint('Ejecutando proceso ACT_VTA_PRE_LIN_G_APP.pro: $params');
    await _api.get(AppConfig.endpoint('procesoActualizarLineaPresupuesto'), params: params);
  }

  static Future<void> enviarLineas(
    dynamic presupuestoId,
    List<LineaPresupuestoVenta> lineas,
  ) async {
    final endpoint = AppConfig.endpoint('lineasPresupuesto');
    for (final linea in lineas) {
      final regIva = (linea.regIvaVta.isNotEmpty ? linea.regIvaVta : regIvaCodigo(linea.tipoIva)).trim().toUpperCase();
      final body = <String, dynamic>{
        'vta_pre': presupuestoId,
        'art': linea.articulo,
        'dsc': linea.descripcion,
        'can': linea.cantidad,
        'pre': linea.precio,
        'por_dto': linea.dto,
        'DTO1': linea.dto1,
        'DTO2': linea.dto2,
        'DTO3': linea.dto3,
        'imp': linea.importe,
        'reg_iva_vta': regIva,
        'est': AppColors.estadoCodigo(linea.estado),
      };
      try {
        int? lineaId = linea.id;
        if (lineaId == null || lineaId <= 0) {
          final res = await _api.post(endpoint, body: body);
          final data = payloadData(res);
          if (data is Map) {
            final idVal = data['id'] ?? data['ID'];
            if (idVal != null) {
              lineaId = int.tryParse(idVal.toString());
            }
          } else if (res is Map) {
            final idVal = res['id'] ?? res['ID'];
            if (idVal != null) {
              lineaId = int.tryParse(idVal.toString());
            }
          }
          if (lineaId == null) {
            final linesRes = await _api.get(endpoint, params: {
              'filter[vta_pre]': '$presupuestoId',
              'sort': '-id',
              'page[size]': 1,
            });
            final items = payloadLista(linesRes);
            if (items.isNotEmpty) {
              final idVal = items.first['id'] ?? items.first['ID'];
              if (idVal != null) {
                lineaId = int.tryParse(idVal.toString());
              }
            }
          }
        } else {
          await _api.post('$endpoint/$lineaId', body: body);
        }

        if (lineaId != null && lineaId > 0) {
          final artVal = int.tryParse(linea.articulo) ?? linea.articulo;
          final canVal = (linea.cantidad % 1 == 0) ? linea.cantidad.toInt() : linea.cantidad;
          final preVal = (linea.precio % 1 == 0) ? linea.precio.toInt() : linea.precio;
          final estVal = AppColors.estadoCodigo(linea.estado);

          await ejecutarProcesoActualizarLinea(
            id: lineaId,
            articulo: artVal,
            cantidad: canVal,
            precio: preVal,
            estado: estVal,
            regIvaVta: regIva,
          );
        }
      } on ApiException catch (e) {
        throw ApiException('Error al guardar las líneas del presupuesto: $e');
      }
    }
  }

  static Future<void> eliminarLinea(dynamic id) async {
    await _api.delete('${AppConfig.endpoint('lineasPresupuesto')}/$id');
  }

  static Future<void> remove(dynamic id) async {
    await _api.delete('${AppConfig.endpoint('presupuestos')}/$id');
  }
}




