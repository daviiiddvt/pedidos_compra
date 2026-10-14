import 'package:flutter/foundation.dart';

import 'api_client.dart';
import 'api_service.dart';
import 'config.dart';
import '../models/articulo.dart';
import '../models/tarifa_articulo.dart';
import '../models/movimiento.dart';

class ArticulosService {
  static final _api = ApiClient.instance;

  static final Map<String, String> _familiaCache = {};
  static final Map<String, String> _proveedorCache = {};

  static Future<ResultadoLista<Articulo>> list({
    int page = 1,
    int pageSize = AppConfig.pageSize,
  }) async {
    final params = <String, dynamic>{
      'page[number]': page,
      'page[size]': pageSize,
      'filter[baj]': 0,
    };

    final json = await _api.get(
      AppConfig.endpoint('articulos'),
      params: params,
    );

    final items = payloadLista(json).map((r) => Articulo.fromJson(r)).toList();
    final reportedTotal = payloadTotal(json);
    final total = reportedTotal == items.length && items.length >= pageSize
        ? 0
        : reportedTotal;

    return ResultadoLista<Articulo>(
      items: items,
      total: total,
      page: page,
    );
  }

  static Future<Articulo?> getById(String id) async {
    if (id.trim().isEmpty) return null;
    try {
      final json = await _api.get(
        AppConfig.endpoint('articulos'),
        params: {'filter[id]': id.trim(), 'page[size]': 1},
      );
      final records = payloadLista(json);
      if (records.isEmpty) return null;

      var articulo = Articulo.fromJson(records.first);

      // Si falta nombre de familia y tenemos su ID, la resolvemos de FAM_M
      if (articulo.familiaId.isNotEmpty && articulo.familiaNombre.isEmpty) {
        final famNombre = await getFamiliaNombre(articulo.familiaId);
        articulo = articulo.copyWith(familiaNombre: famNombre);
      }

      // Si falta nombre de proveedor y tenemos su ID, lo resolvemos de ENT_M
      if (articulo.proveedorId.isNotEmpty && articulo.proveedorNombre.isEmpty) {
        final prvNombre = await getProveedorNombre(articulo.proveedorId);
        articulo = articulo.copyWith(proveedorNombre: prvNombre);
      }

      return articulo;
    } catch (e) {
      debugPrint('[ARTICULOS] Error al obtener artículo $id: $e');
      return null;
    }
  }

  static Future<String> getFamiliaNombre(String familiaId) async {
    final cleanId = familiaId.trim();
    if (cleanId.isEmpty || cleanId == '0') return '';
    if (_familiaCache.containsKey(cleanId)) {
      return _familiaCache[cleanId]!;
    }

    try {
      final json = await _api.get(
        AppConfig.endpoint('familias'),
        params: {'filter[id]': cleanId, 'page[size]': 1},
      );
      final records = payloadLista(json);
      if (records.isNotEmpty) {
        final rec = records.first;
        final name = rec.s('name').isNotEmpty
            ? rec.s('name')
            : (rec.s('nombre').isNotEmpty ? rec.s('nombre') : rec.s('nom'));
        if (name.isNotEmpty) {
          _familiaCache[cleanId] = name;
          return name;
        }
      }
    } catch (e) {
      debugPrint('[FAMILIAS] Error al resolver familia $cleanId: $e');
    }
    return '';
  }

  static Future<String> getProveedorNombre(String proveedorId) async {
    final cleanId = proveedorId.trim();
    if (cleanId.isEmpty || cleanId == '0') return '';
    if (_proveedorCache.containsKey(cleanId)) {
      return _proveedorCache[cleanId]!;
    }

    try {
      final json = await _api.get(
        AppConfig.endpoint('proveedores'),
        params: {'filter[id]': cleanId, 'page[size]': 1},
      );
      final records = payloadLista(json);
      if (records.isNotEmpty) {
        final rec = records.first;
        final name = rec.s('name').isNotEmpty
            ? rec.s('name')
            : (rec.s('nom_fis').isNotEmpty ? rec.s('nom_fis') : rec.s('nombre'));
        if (name.isNotEmpty) {
          _proveedorCache[cleanId] = name;
          return name;
        }
      }
    } catch (e) {
      debugPrint('[PROVEEDORES] Error al resolver proveedor $cleanId: $e');
    }
    return '';
  }

  static final Map<String, String> _tarifaCache = {};

  static Future<String> getTarifaNombre(String tarifaId) async {
    final cleanId = tarifaId.trim();
    if (cleanId.isEmpty || cleanId == '0') return '';
    if (_tarifaCache.containsKey(cleanId)) {
      return _tarifaCache[cleanId]!;
    }

    try {
      final json = await _api.get(
        AppConfig.endpoint('tarifas'),
        params: {'filter[id]': cleanId, 'page[size]': 1},
      );
      final records = payloadLista(json);
      if (records.isNotEmpty) {
        final rec = records.first;
        final name = rec.s('name').isNotEmpty
            ? rec.s('name')
            : (rec.s('nombre').isNotEmpty ? rec.s('nombre') : rec.s('nom'));
        if (name.isNotEmpty) {
          _tarifaCache[cleanId] = name;
          return name;
        }
      }
    } catch (e) {
      debugPrint('[TARIFAS] Error al resolver tarifa $cleanId: $e');
    }
    return '';
  }

  static Future<List<TarifaArticulo>> getTarifasArticulo(String articuloId) async {
    if (articuloId.trim().isEmpty) return [];
    try {
      final json = await _api.get(
        AppConfig.endpoint('tarifasArticulo'),
        params: {'filter[ART]': articuloId.trim(), 'page[size]': 100},
      );
      final rawList = payloadLista(json);
      
      final result = <TarifaArticulo>[];
      for (final r in rawList) {
        var tarifa = TarifaArticulo.fromJson(r);
        
        // Resolver nombre de la tarifa si no viene en el payload
        if (tarifa.tarifaId.isNotEmpty && tarifa.tarifaNombre.isEmpty) {
          final nombre = await getTarifaNombre(tarifa.tarifaId);
          tarifa = tarifa.copyWith(tarifaNombre: nombre);
        }
        
        result.add(tarifa);
      }
      return result;
    } catch (e) {
      debugPrint('[TARIFAS_ARTICULO] Error al obtener tarifas del artículo $articuloId: $e');
      return [];
    }
  }

  static Future<ResultadoLista<Movimiento>> getMovimientosArticulo({
    required String articuloId,
    int page = 1,
    int pageSize = 50,
  }) async {
    if (articuloId.trim().isEmpty) {
      return ResultadoLista<Movimiento>(items: [], total: 0, page: page);
    }
    
    try {
      final json = await _api.get(
        AppConfig.endpoint('movimientos'),
        params: {
          'filter[ART]': articuloId.trim(),
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
      debugPrint('[MOVIMIENTOS] Error al obtener movimientos del artículo $articuloId: $e');
      return ResultadoLista<Movimiento>(items: [], total: 0, page: page);
    }
  }
}
