import 'package:flutter/foundation.dart';

import 'api_client.dart';
import 'api_service.dart';
import 'config.dart';
import 'articulos_service.dart';
import '../models/models.dart';
import '../models/articulo.dart';
import '../models/movimiento.dart';

class ClientesService {
  static final _api = ApiClient.instance;

  static Future<ResultadoLista<Cliente>> list({
    int page = 1,
    int pageSize = AppConfig.pageSize,
    String? comercialId,
  }) async {
    final params = <String, dynamic>{
      'page[number]': page,
      'page[size]': pageSize,
      'filter[es_clt]': '',
    };

    if (comercialId != null && comercialId.trim().isNotEmpty) {
      params['filter[cmr]'] = comercialId.trim();
    }

    final json = await _api.get(
      AppConfig.endpoint('clientes'),
      params: params,
    );

    final items = payloadLista(json).map((r) => Cliente.fromJson(r)).toList();
    final reportedTotal = payloadTotal(json);
    final total = reportedTotal == items.length && items.length >= pageSize
        ? 0
        : reportedTotal;

    return ResultadoLista<Cliente>(
      items: items,
      total: total,
      page: page,
    );
  }

  static Future<ResultadoLista<Movimiento>> getMovimientosCliente({
    required String clienteId,
    int page = 1,
    int pageSize = 50,
  }) async {
    if (clienteId.trim().isEmpty) {
      return ResultadoLista<Movimiento>(items: [], total: 0, page: page);
    }
    
    try {
      final json = await _api.get(
        AppConfig.endpoint('movimientos'),
        params: {
          'filter[CLT_ENT]': clienteId.trim(),
          'sort': '-fch',
          'page[number]': page,
          'page[size]': pageSize,
        },
      );
      final rawList = payloadLista(json);
      
      final result = <Movimiento>[];
      final Map<String, Articulo> cacheArticulos = {};

      for (final r in rawList) {
        var m = Movimiento.fromJson(r);

        // Resolver el nombre del artículo si no viene incluido
        if (m.articuloId.isNotEmpty && (m.articuloNombre.isEmpty || m.articuloRef.isEmpty)) {
          if (!cacheArticulos.containsKey(m.articuloId)) {
            final art = await ArticulosService.getById(m.articuloId);
            if (art != null) {
              cacheArticulos[m.articuloId] = art;
            }
          }

          final art = cacheArticulos[m.articuloId];
          if (art != null) {
            m = m.copyWith(
              articuloNombre: art.nombre,
              articuloRef: art.referencia,
            );
          }
        }
        
        result.add(m);
      }

      final reportedTotal = payloadTotal(json);
      final total = reportedTotal == result.length && result.length >= pageSize
          ? 0
          : reportedTotal;

      return ResultadoLista<Movimiento>(
        items: result,
        total: total,
        page: page,
      );
    } catch (e) {
      debugPrint('[MOVIMIENTOS] Error al obtener movimientos del cliente $clienteId: $e');
      return ResultadoLista<Movimiento>(items: [], total: 0, page: page);
    }
  }
}

