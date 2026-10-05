import 'package:flutter/foundation.dart';
import 'api_client.dart';
import 'config.dart';
import '../theme/app_theme.dart';
import 'api_service.dart';
import 'master_cache_service.dart';
import '../models/models.dart';

/// API operations for sales budgets. Budgets use the same document models and
/// line payloads as orders, but are stored in their own Velneo tables.
class PresupuestosService {
  static final _api = ApiClient.instance;

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
    final json = await _api.get(
      AppConfig.endpoint('presupuestos'),
      params: params,
    );
    final items = payloadLista(json).map(PresupuestoVenta.fromJson).toList();
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
  }

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
    final json = await _api.get('${AppConfig.endpoint('presupuestos')}/$id');
    final data = payloadData(json);
    if (data is! Map) throw ApiException('No se pudo leer el presupuesto.');
    var presupuesto = PresupuestoVenta.fromJson(
      Map<String, dynamic>.from(data),
    );
    final lineasJson = await _api.get(
      AppConfig.endpoint('lineasPresupuesto'),
      params: {'filter[vta_pre]': '$id', 'page[size]': 100},
    );
    final lineas = payloadLista(lineasJson)
        .map(LineaPresupuestoVenta.fromJson)
        .toList();
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
    PresupuestoVenta pedido,
  ) async {
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
      throw ApiException('Velneo no devolviÃ³ el ID del presupuesto creado.');
    }
    await enviarLineas(id, pedido.lineas);
    return created.copyWith(id: id, lineas: pedido.lineas);
  }

  static Future<void> marcarAceptado(dynamic budgetId) async {
    if (budgetId == null) return;
    await _api.post('${AppConfig.endpoint('presupuestos')}/$budgetId', body: {'est': 'A'});
    await _marcarLineasAceptadas(budgetId);
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

  static Future<void> linkPedido(dynamic budgetId, dynamic pedidoId) async {
    if (budgetId == null || pedidoId == null) return;
    try {
      // 1. Actualizamos cabecera del presupuesto
      await _api.post(
        '${AppConfig.endpoint('presupuestos')}/$budgetId',
        body: {
          'est': 'A', // Aceptado
          'vta_ped_g': pedidoId,
        },
      );
      // 2. Actualizamos las lÃ­neas a Aceptado
      await _marcarLineasAceptadas(budgetId);
    } catch (e) {
      debugPrint('Error enlazando presupuesto a pedido: $e');
    }
  }

  static Future<PresupuestoVenta> updateComplete(
    dynamic id,
    PresupuestoVenta pedido,
    Set<int> removedLineIds,
  ) async {
    final dirId = await _ensureDireccionId(pedido.clienteId, pedido.direccionEnvio);
    final pedidoMapeado = pedido.copyWith(direccionEnvio: dirId);

    final json = await _api.post(
      '${AppConfig.endpoint('presupuestos')}/$id',
      body: _payload(pedidoMapeado),
    );
    final data = payloadData(json);
    for (final lineId in removedLineIds) {
      await eliminarLinea(lineId);
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
        'imp': linea.importe,
        'reg_iva_vta': regIva,
        'est': AppColors.estadoCodigo(linea.estado),
      };
      try {
        int? lineaId = linea.id;
        if (lineaId == null) {
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




