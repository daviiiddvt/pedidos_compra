import 'package:flutter/foundation.dart';

import 'api_client.dart';
import 'api_service.dart';
import 'config.dart';
import '../models/articulo.dart';
import '../models/models.dart';
import '../models/tarifa_articulo.dart';
import '../models/movimiento.dart';
import 'offline/offline_database.dart';

class ArticulosService {
  static final _api = ApiClient.instance;

  static final Map<String, String> _familiaCache = {};
  static final Map<String, String> _proveedorCache = {};

  static Future<ResultadoLista<Articulo>> list({
    int page = 1,
    int pageSize = AppConfig.pageSize,
    String? search,
  }) async {
    final q = search?.trim() ?? '';
    final Map<String, dynamic> params;
    if (q.isNotEmpty) {
      params = PedidosService.buildArticuloSearchParams(
        q,
        limit: pageSize,
        page: page,
      );
    } else {
      params = {
        'page[number]': page,
        'page[size]': pageSize,
        'filter[baj]': 0,
      };
    }

    try {
      final json = await _api.get(
        AppConfig.endpoint('articulos'),
        params: params,
      );

      final rawItems = payloadLista(json).map((r) => Articulo.fromJson(r)).toList();
      final items = rawItems.where((art) => art.tieneFamilia).toList();
      final reportedTotal = payloadTotal(json);
      final total = reportedTotal == rawItems.length && rawItems.length >= pageSize
          ? 0
          : reportedTotal;

      return ResultadoLista<Articulo>(
        items: items,
        total: total,
        page: page,
      );
    } catch (e) {
      debugPrint('[ARTICULOS] Error al conectar con el servidor, leyendo de SQLite: $e');
      return OfflineDatabase.instance.getArticulosOffline(
        query: search,
        page: page,
        pageSize: pageSize,
      );
    }
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
            : (rec.s('name').isNotEmpty ? rec.s('name') : rec.s('nombre'));
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

  static List<OpcionMaestra>? _familiasCache;
  static List<OpcionMaestra>? _proveedoresCache;

  /// Carga el maestro de familias desde `FAM_M`.
  static Future<List<OpcionMaestra>> getFamilias({bool forceRefresh = false}) async {
    if (!forceRefresh && _familiasCache != null && _familiasCache!.isNotEmpty) {
      return _familiasCache!;
    }
    try {
      final json = await _api.get(
        AppConfig.endpoint('familias'),
        params: {'page[size]': 500},
      );
      final records = payloadLista(json);
      final list = records
          .map((r) {
            final id = r.s('id').isNotEmpty ? r.s('id') : r.s('codigo');
            final name = r.s('name').isNotEmpty
                ? r.s('name')
                : (r.s('nombre').isNotEmpty ? r.s('nombre') : r.s('nom'));
            if (id.isNotEmpty && name.isNotEmpty) {
              _familiaCache[id] = name;
            }
            return OpcionMaestra(codigo: id, nombre: name.isNotEmpty ? name : id);
          })
          .where((f) => f.codigo.isNotEmpty && f.codigo != '0')
          .toList();
      _familiasCache = list;
      return list;
    } catch (e) {
      debugPrint('[FAMILIAS] Error al obtener familias: $e');
      return _familiasCache ?? [];
    }
  }

  /// Carga el maestro de proveedores desde `ENT_M`.
  static Future<List<OpcionMaestra>> getProveedores({bool forceRefresh = false}) async {
    if (!forceRefresh && _proveedoresCache != null && _proveedoresCache!.isNotEmpty) {
      return _proveedoresCache!;
    }
    try {
      final json = await _api.get(
        AppConfig.endpoint('proveedores'),
        params: {'page[size]': 500, 'filter[es_prv]': 1},
      );
      var records = payloadLista(json);
      if (records.isEmpty) {
        final jsonAll = await _api.get(
          AppConfig.endpoint('proveedores'),
          params: {'page[size]': 200},
        );
        records = payloadLista(jsonAll);
      }
      final list = records
          .map((r) {
            final id = r.s('id').isNotEmpty ? r.s('id') : r.s('codigo');
            final name = r.s('name').isNotEmpty
                ? r.s('name')
                : (r.s('nombre').isNotEmpty ? r.s('nombre') : r.s('nom'));
            if (id.isNotEmpty && name.isNotEmpty) {
              _proveedorCache[id] = name;
            }
            return OpcionMaestra(codigo: id, nombre: name.isNotEmpty ? name : id);
          })
          .where((p) => p.codigo.isNotEmpty && p.codigo != '0')
          .toList();
      _proveedoresCache = list;
      return list;
    } catch (e) {
      debugPrint('[PROVEEDORES] Error al obtener proveedores: $e');
      return _proveedoresCache ?? [];
    }
  }

  /// Crea un nuevo artículo en `ART_M`.
  ///
  /// Es imprescindible que cuente con una familia asignada para que el artículo
  /// sea visible en el catálogo y en las búsquedas con `filter[PARTS_BAJ]`.
  static Future<Articulo> create({
    required String nombre,
    required String familiaId,
    String referencia = '',
    double precio = 0.0,
    String codigoBarras = '',
    String proveedorId = '',
    String descripcion = '',
  }) async {
    final cleanFam = familiaId.trim();
    if (cleanFam.isEmpty || cleanFam == '0') {
      throw ApiException('El artículo debe tener una familia asignada obligatoriamente.');
    }

    final payload = <String, dynamic>{
      'name': nombre.trim(),
      'fam': int.tryParse(cleanFam) ?? cleanFam,
      'fam_m': int.tryParse(cleanFam) ?? cleanFam,
      'FAM_M': int.tryParse(cleanFam) ?? cleanFam,
      if (referencia.trim().isNotEmpty) ...{
        'ref': referencia.trim(),
        'REF': referencia.trim(),
      },
      'pvp': precio,
      'pre': precio,
      if (codigoBarras.trim().isNotEmpty) ...{
        'cod_bar': codigoBarras.trim(),
        'COD_BAR': codigoBarras.trim(),
      },
      if (proveedorId.trim().isNotEmpty) ...{
        'prv': int.tryParse(proveedorId) ?? proveedorId.trim(),
        'PRV': int.tryParse(proveedorId) ?? proveedorId.trim(),
      },
      if (descripcion.trim().isNotEmpty) ...{
        'dsc': descripcion.trim(),
        'DSC': descripcion.trim(),
      },
      'emp': '1',
      'emp_div': '1',
      'baj': 0,
    };

    final json = await _api.post(
      AppConfig.endpoint('articulos'),
      body: payload,
    );

    final data = payloadData(json);
    Articulo created;
    if (data is Map) {
      created = Articulo.fromJson(Map<String, dynamic>.from(data));
    } else if (json is Map) {
      created = Articulo.fromJson(Map<String, dynamic>.from(json));
    } else {
      throw ApiException('El servidor no devolvió los datos del artículo tras su creación.');
    }

    return created.copyWith(
      id: created.id.isNotEmpty ? created.id : (created.codigo.isNotEmpty ? created.codigo : ''),
      nombre: created.nombre.isNotEmpty ? created.nombre : nombre.trim(),
      referencia: created.referencia.isNotEmpty ? created.referencia : referencia.trim(),
      familiaId: created.familiaId.isNotEmpty ? created.familiaId : cleanFam,
      precio: created.precio > 0 ? created.precio : precio,
      codigoBarras: created.codigoBarras.isNotEmpty ? created.codigoBarras : codigoBarras.trim(),
      proveedorId: created.proveedorId.isNotEmpty ? created.proveedorId : proveedorId.trim(),
    );
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
    String? clienteId,
    int page = 1,
    int pageSize = 50,
  }) async {
    if (articuloId.trim().isEmpty) {
      return ResultadoLista<Movimiento>(items: [], total: 0, page: page);
    }
    
    final cleanClt = clienteId?.trim() ?? '';

    try {
      final params = <String, dynamic>{
        'filter[ART]': articuloId.trim(),
        'sort': '-fch',
        'page[number]': page,
        'page[size]': pageSize,
      };
      if (cleanClt.isNotEmpty) {
        params['filter[CLT_ENT]'] = cleanClt;
      }

      final json = await _api.get(
        AppConfig.endpoint('movimientos'),
        params: params,
      );
      final rawList = payloadLista(json);
      
      final result = <Movimiento>[];
      final Map<String, Articulo> cacheArticulos = {};

      for (final r in rawList) {
        var m = Movimiento.fromJson(r);

        // Si el movimiento no traía clienteId explícito, asignamos el consultado
        if (m.clienteId.isEmpty && cleanClt.isNotEmpty) {
          m = m.copyWith(clienteId: cleanClt);
        }

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
      debugPrint('[MOVIMIENTOS] Error o sin conexión al obtener movimientos del artículo $articuloId (cliente $cleanClt): $e');

      // Fallback offline: buscar en la base de datos local
      try {
        final offlineMovs = await OfflineDatabase.instance.getMovimientosArticuloOffline(
          articuloId.trim(),
          clienteId: cleanClt.isNotEmpty ? cleanClt : null,
          limit: pageSize,
          offset: (page - 1) * pageSize,
        );
        if (offlineMovs.isNotEmpty) {
          return ResultadoLista<Movimiento>(
            items: offlineMovs,
            total: offlineMovs.length,
            page: page,
          );
        }
      } catch (dbErr) {
        debugPrint('[MOVIMIENTOS] Error al consultar movimientos offline: $dbErr');
      }

      return ResultadoLista<Movimiento>(items: [], total: 0, page: page);
    }
  }
}
