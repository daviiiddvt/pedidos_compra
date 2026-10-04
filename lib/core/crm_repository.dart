// ============================================================================
//  crm_repository.dart  —  ACCESO A TABLAS CRM DE VELNEO
// ============================================================================

import 'package:flutter/foundation.dart' show debugPrint;

import '../models/models.dart';
import 'api_client.dart';
import 'config.dart';

/// Repositorio de CRM. Las pantallas no hablan con HTTP: pasan por aquí.
class CrmRepository {
  CrmRepository({ApiClient? api}) : _api = api ?? ApiClient.instance;

  final ApiClient _api;

  /// Crea o actualiza una visita de agenda en `CRM_AGE`.
  Future<void> guardarVisita(VisitaAgenda visita) async {
    final payload = visita.toJson()
      ..remove('ID')
      ..remove('emp')
      ..remove('emp_div')
      ..removeWhere((_, value) => value == null)
      ..['TOD_DIA'] = visita.todoElDia ? 1 : 0
      ..['NO_GEN_PRO_VIS'] = visita.cerrar ? 1 : 0;

    payload['FCH_INI'] = _fechaVelneo(visita.fechaInicio);
    for (final clave in const ['FCH_FIN', 'FCH_PRO_VIS']) {
      if (payload.containsKey(clave)) {
        payload[clave] = _fechaVelneo(payload[clave] as String?);
      }
    }

    final endpoint = AppConfig.endpoint('agenda');
    if (visita.id == null) {
      await _api.post(endpoint, body: payload);
    } else {
      await _api.post('$endpoint/${visita.id}', body: payload);
    }
  }

  /// Elimina una visita de agenda (`CRM_AGE`).
  Future<void> eliminarVisita(int id) async {
    await _api.delete('${AppConfig.endpoint('agenda')}/$id');
  }

  /// Visitas de agenda (`CRM_AGE`) del comercial [comercialId] (`COM`).
  Future<List<VisitaAgenda>> getVisitasAgenda(String comercialId) async {
    final id = comercialId.trim();
    if (id.isEmpty) return const [];

    final records = await _fetchAllRecords(
      AppConfig.endpoint('agenda'),
      extraParams: {'filter[COM]': id},
    );

    var visitas = records.map((raw) {
      return VisitaAgenda.fromJson(_recordParaVisita(raw));
    }).toList();

    try {
      final futures = await Future.wait([
        getCampanas(),
        getTiposVisita(),
      ]);
      final campanas = futures[0];
      final tipos = futures[1];

      final campanasCache = <String, Future<String>>{};
      final tiposCache = <String, Future<String>>{};
      final clientesCache = <String, Future<String>>{};

      visitas = await Future.wait(visitas.map((v) async {
        String campanaNom = v.campanaId;
        String tipoNom = v.tipoVisitaId;
        String clienteNom = v.clienteId;

        if (v.campanaId.isNotEmpty) {
          final c = campanas.where((x) => x.codigo == v.campanaId).toList();
          if (c.isNotEmpty) {
            campanaNom = c.first.nombre;
          } else {
            campanasCache[v.campanaId] ??= () async {
              try {
                final j = await _api.get(AppConfig.endpoint('campanas'), params: {'filter[id]': v.campanaId, 'page[size]': 1});
                final l = payloadLista(j);
                if (l.isNotEmpty) return (l.first['NAME'] ?? l.first['name'] ?? v.campanaId).toString();
              } catch (_) {}
              return v.campanaId;
            }();
            campanaNom = await campanasCache[v.campanaId]!;
          }
        }

        if (v.tipoVisitaId.isNotEmpty) {
          final t = tipos.where((x) => x.codigo == v.tipoVisitaId).toList();
          if (t.isNotEmpty) {
            tipoNom = t.first.nombre;
          } else {
            tiposCache[v.tipoVisitaId] ??= () async {
              try {
                final j = await _api.get(AppConfig.endpoint('tiposVisita'), params: {'filter[id]': v.tipoVisitaId, 'page[size]': 1});
                final l = payloadLista(j);
                if (l.isNotEmpty) return (l.first['NAME'] ?? l.first['name'] ?? v.tipoVisitaId).toString();
              } catch (_) {}
              return v.tipoVisitaId;
            }();
            tipoNom = await tiposCache[v.tipoVisitaId]!;
          }
        }

        if (v.clienteId.isNotEmpty) {
          clientesCache[v.clienteId] ??= () async {
            try {
              final jsonC = await _api.get(
                AppConfig.endpoint('clientes'),
                params: {'filter[id]': v.clienteId, 'page[size]': 1},
              );
              final list = payloadLista(jsonC);
              if (list.isNotEmpty) {
                final r = list.first;
                return (r['NAME'] ?? r['name'] ?? v.clienteId).toString();
              }
            } catch (_) {}
            return v.clienteId;
          }();
          clienteNom = await clientesCache[v.clienteId]!;
        }

        debugPrint('--- MAPEO VISITA ${v.id ?? 'NUEVA'} ---');
        debugPrint('Campaña ID: "${v.campanaId}" -> Nombre: "$campanaNom"');
        debugPrint('Tipo ID: "${v.tipoVisitaId}" -> Nombre: "$tipoNom"');
        debugPrint('Cliente ID: "${v.clienteId}" -> Nombre: "$clienteNom"');
        debugPrint('-----------------------------------');

        return v.copyWith(
          campanaNombre: campanaNom,
          tipoVisitaNombre: tipoNom,
          clienteNombre: clienteNom,
        );
      }));
    } catch (_) {
      // Si falla el mapeo, devolvemos las visitas con los IDs crudos
    }

    debugPrint('✅ CRM_AGE comercial=$id - ${visitas.length} visitas');
    return visitas;
  }

  /// Campañas comerciales (`CRM_CAM_COM`).
  /// Sin `filter['PARTS']` Velneo suele devolver  /// Campañas comerciales (`CRM_CAM_COM`).
  Future<List<OpcionMaestra>> getCampanas() => searchCampanas('', limit: 200);

  /// Tipos de visita (`TIP_VIS`).
  Future<List<OpcionMaestra>> getTiposVisita() => searchTiposVisita('', limit: 200);

  /// Búsqueda acotada de campañas por el índice `PARTS` de Velneo.
  /// Equivale a `.../CRM_CAM_COM?filter['PARTS']="KIT"`.
  Future<List<OpcionMaestra>> searchCampanas(String query, {int limit = 20}) {
    return _searchMaestro(endpointKey: 'campanas', query: query, limit: limit);
  }

  /// Búsqueda acotada de tipos de visita por el índice `PARTS`.
  Future<List<OpcionMaestra>> searchTiposVisita(
    String query, {
    int limit = 20,
  }) {
    return _searchMaestro(
      endpointKey: 'tiposVisita',
      query: query,
      limit: limit,
    );
  }

  Future<List<OpcionMaestra>> _searchMaestro({
    required String endpointKey,
    required String query,
    int limit = 20,
  }) async {
    final trimmed = query.trim();
    String token = '';
    final params = <String, dynamic>{
      'page[size]': limit,
      'page[number]': 1,
    };

    if (trimmed.isNotEmpty) {
      token = trimmed.split(RegExp(r'\s+')).first;
      params["filter['PARTS']"] = '"$token"';
    }

    final json = await _api.get(
      AppConfig.endpoint(endpointKey),
      params: params,
    );
    final records = payloadLista(json);
    if (records.isNotEmpty) {
      debugPrint('🔍 $endpointKey claves=${records.first.keys.toList()}');
    }

    final opciones = records
        .map(_opcionFromMaestro)
        .where(_opcionValida)
        .toList();
    debugPrint(
      '🔍 $endpointKey PARTS="$token" ➔ ${opciones.length} opciones: $opciones',
    );
    return opciones.take(limit).toList();
  }

  /// Direcciones del cliente (`DIR_M`) filtradas por `filter['ENT']`.
  /// El texto visible es `DIR_COM` (dirección completa).
  Future<List<OpcionMaestra>> getDireccionesCliente(String clienteId) async {
    final id = clienteId.trim();
    if (id.isEmpty) return const [];

    final records = await _fetchAllRecords(
      AppConfig.endpoint('direcciones'),
      extraParams: {"filter['ENT']": id},
    );
    if (records.isNotEmpty) {
      debugPrint('🏠 DIR_M ENT=$id claves=${records.first.keys.toList()}');
    }

    final opciones = records
        .map((raw) {
          final codigo = _primerTexto(raw, const [
            'ID',
            'id',
            'codigo',
            'code',
          ]);
          final nombre = _primerTexto(raw, const [
            'DIR_COM',
            'dir_com',
            'DIR',
            'dir',
            'direccion',
          ]);
          return OpcionMaestra(
            codigo: codigo,
            nombre: nombre.isNotEmpty ? nombre : codigo,
          );
        })
        .where((o) => o.codigo.isNotEmpty)
        .toList();

    debugPrint('🏠 DIR_M ENT=$id → ${opciones.length} direcciones');
    return opciones;
  }

  bool _opcionValida(OpcionMaestra o) => o.codigo.isNotEmpty;

  OpcionMaestra _opcionFromMaestro(Map<String, dynamic> raw) {
    final codigo = _primerTexto(raw, const [
      'ID',
      'id',
      'codigo',
      'code',
      'CAM',
      'cam',
    ]);
    var nombre = _primerTexto(raw, const [
      'NAME',
      'name',
      'NOM',
      'nom',
      'nombre',
      'nom_com',
      'NOM_COM',
      'descripcion',
      'DSC',
      'dsc',
      'cam_com',
      'CAM_COM',
    ]);
    if (nombre.isEmpty) {
      for (final entry in raw.entries) {
        final key = entry.key.toString().toLowerCase();
        if (key.contains('name') ||
            key.contains('nom') ||
            key.contains('desc')) {
          final valor = _asString(_unwrap(entry.value));
          if (valor.isNotEmpty) {
            nombre = valor;
            break;
          }
        }
      }
    }
    return OpcionMaestra(
      codigo: codigo,
      nombre: nombre.isNotEmpty ? nombre : codigo,
    );
  }

  String _primerTexto(Map<String, dynamic> raw, List<String> claves) {
    for (final clave in claves) {
      final valor = _asString(_unwrap(raw[clave]));
      if (valor.isNotEmpty) return valor;
    }
    return '';
  }

  Future<List<Map<String, dynamic>>> _fetchAllRecords(
    String endpoint, {
    Map<String, dynamic>? extraParams,
    int pageSize = 200,
  }) async {
    final allRecords = <Map<String, dynamic>>[];
    var pageNumber = 1;

    while (true) {
      final json = await _api.get(
        endpoint,
        params: {
          'page[size]': pageSize,
          'page[number]': pageNumber,
          ...?extraParams,
        },
      );
      final records = payloadLista(json);
      if (records.isEmpty) break;

      allRecords.addAll(records);
      final total = payloadTotal(json);
      final completa = records.length >= pageSize;
      final quedan = total > 0 && allRecords.length < total;
      if (!completa && !quedan) break;
      if (total > 0 && allRecords.length >= total) break;
      pageNumber++;
    }

    return allRecords;
  }

  /// Normaliza tipos y mayúsculas/minúsculas de Velneo al contrato de
  /// [VisitaAgenda.fromJson] (IDs numéricos, booleanos 0/1, `{value: ...}`).
  Map<String, dynamic> _recordParaVisita(Map<String, dynamic> raw) {
    dynamic campo(String upper) {
      final lower = upper.toLowerCase();
      return _unwrap(raw[upper]) ?? _unwrap(raw[lower]);
    }

    return {
      'ID': _asInt(campo('ID')),
      'CLI': _asString(campo('CLI')),
      'CRM_CAM_COM': _asString(campo('CRM_CAM_COM')),
      'TIP_VIS': _asString(campo('TIP_VIS')),
      'COM': _asString(campo('COM')),
      'DIR_M': _asString(campo('DIR_M')),
      'ASU': _asString(campo('ASU')),
      'TOD_DIA': _asBool(campo('TOD_DIA')),
      'FCH_INI': _asDate(campo('FCH_INI')) ?? '',
      'HOR_INI': _asTime(campo('HOR_INI')),
      'FCH_FIN': _asDate(campo('FCH_FIN')),
      'HOR_FIN': _asTime(campo('HOR_FIN')),
      'VTA_PRE_G': _asNullableString(campo('VTA_PRE_G')),
      'FCH_PRO_VIS': _asDate(campo('FCH_PRO_VIS')),
      'HOR_PRO_VIS': _asTime(campo('HOR_PRO_VIS')),
      'NO_GEN_PRO_VIS': _asBool(campo('NO_GEN_PRO_VIS')),
      'DSC': _asNullableString(campo('DSC')),
      'emp': _asString(raw['emp'] ?? campo('EMP'), fallback: '1'),
      'emp_div': _asString(raw['emp_div'] ?? campo('EMP_DIV'), fallback: '1'),
    };
  }

  dynamic _unwrap(dynamic value) {
    if (value is Map && value.containsKey('value')) return value['value'];
    return value;
  }

  int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toInt();
    return int.tryParse('$value');
  }

  String _asString(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    final text = '$value'.trim();
    return text.isEmpty ? fallback : text;
  }

  String? _asNullableString(dynamic value) {
    if (value == null) return null;
    final text = '$value'.trim();
    return text.isEmpty ? null : text;
  }

  String? _asDate(dynamic value) {
    if (value == null) return null;
    final text = '$value'.trim();
    if (text.isEmpty || text == 'null') return null;

    final d = DateTime.tryParse(text);
    if (d != null) {
      return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    }

    final regexIso = RegExp(r'\b(\d{4})-(\d{2})-(\d{2})\b');
    final matchIso = regexIso.firstMatch(text);
    if (matchIso != null) return matchIso.group(0);

    final months = {'Jan': 1, 'Feb': 2, 'Mar': 3, 'Apr': 4, 'May': 5, 'Jun': 6, 'Jul': 7, 'Aug': 8, 'Sep': 9, 'Oct': 10, 'Nov': 11, 'Dec': 12};
    final regexJs = RegExp(r'([A-Z][a-z]{2})\s+(\d{1,2})\s+\d{2}:\d{2}:\d{2}\s+(\d{4})');
    final matchJs = regexJs.firstMatch(text);
    if (matchJs != null) {
      final month = months[matchJs.group(1)!];
      if (month != null) {
        final year = matchJs.group(3)!;
        final day = matchJs.group(2)!.padLeft(2, '0');
        final mm = month.toString().padLeft(2, '0');
        return '$year-$mm-$day';
      }
    }
    return text;
  }

  String? _asTime(dynamic value) {
    if (value == null) return null;
    final text = '$value'.trim();
    if (text.isEmpty || text == 'null') return null;

    final regex = RegExp(r'\b([01]?\d|2[0-3]):([0-5]\d)(?::[0-5]\d)?\b');
    final match = regex.firstMatch(text);
    if (match != null) {
      final hh = match.group(1)!.padLeft(2, '0');
      final mm = match.group(2)!;
      final time = '$hh:$mm';
      if (time == '00:00') return null; // Velneo usa 00:00 para tiempos vacíos en exportaciones de fechas
      return time;
    }
    return text;
  }

  String? _fechaVelneo(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    return text.split('T').first;
  }

  bool _asBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = '$value'.trim().toLowerCase();
    return text == 'true' || text == '1' || text == 's' || text == 'si';
  }
}
