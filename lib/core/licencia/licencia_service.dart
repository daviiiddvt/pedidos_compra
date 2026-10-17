import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import '../offline/offline_database.dart';
import 'device_id_service.dart';
import 'licencia.dart';

enum LicenciaEstado {
  valida,
  denegada,
  errorConexion,
}

class LicenciaResult {
  final LicenciaEstado estado;
  final String mensaje;
  final String? rawResponse;

  const LicenciaResult({
    required this.estado,
    required this.mensaje,
    this.rawResponse,
  });

  bool get ok => estado == LicenciaEstado.valida;
}

class LicenciaService extends ChangeNotifier {
  static const String _storageKey = 'app_licencia_data_secure';
  static const Duration _timeout = Duration(seconds: 15);

  static final http.Client _defaultClient = IOClient(
    HttpClient()
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true,
  );

  final http.Client? _customClient;
  http.Client get _activeClient => _customClient ?? _defaultClient;

  Licencia? _licencia;

  LicenciaService({http.Client? httpClient}) : _customClient = httpClient;

  Licencia? get licencia => _licencia;
  bool get isValida => _licencia?.validada ?? false;
  bool get esAdmin => _licencia?.esAdmin ?? false;
  bool get esSoloLec => _licencia?.esSoloLec ?? false;

  /// Clave interna para ofuscar los datos heredados de SharedPreferences (migración).
  static const List<int> _obfKey = [0x54, 0x65, 0x63, 0x50, 0x45, 0x44, 0x5F, 0x4B];

  static String _decrypt(String encoded) {
    try {
      final bytes = base64Decode(encoded);
      final decrypted = List<int>.generate(bytes.length, (i) => bytes[i] ^ _obfKey[i % _obfKey.length]);
      return utf8.decode(decrypted);
    } catch (_) {
      return encoded;
    }
  }

  /// Inicializa cargando la licencia de SQLite y ejecutando revalidación si procede.
  Future<void> init() async {
    _licencia = await load();
    notifyListeners();
    if (_licencia != null && _licencia!.isConfigured && _licencia!.validada) {
      unawaited(_revalidarSilenciosa());
    }
  }

  Future<void> _revalidarSilenciosa() async {
    final lic = _licencia;
    if (lic == null || !lic.isConfigured || !lic.validada) return;

    try {
      final res = await validate(lic);
      if (res.estado == LicenciaEstado.denegada) {
        lic.validada = false;
        await save(lic);
        debugPrint('⚠️ Licencia invalidada por el servidor tras comprobación');
      } else if (res.estado == LicenciaEstado.valida) {
        debugPrint('✅ Licencia revalidada en segundo plano con éxito');
      }
    } catch (e) {
      debugPrint('ℹ️ Revalidación silenciosa no completada (offline): $e');
    }
  }

  /// Carga la licencia almacenada en la tabla SQLite `licencia`.
  /// Si SQLite está vacío, migra automáticamente datos existentes de SharedPreferences.
  Future<Licencia> load() async {
    try {
      await OfflineDatabase.instance.init();
      final row = await OfflineDatabase.instance.getLicencia();
      if (row != null) {
        final lic = Licencia.fromDbMap(row);
        // Si ya tiene algún dato guardado o validado en SQLite
        if (lic.isConfigured || lic.validada) {
          if (lic.uuid.isEmpty) {
            lic.uuid = await getOrCreateUuid();
          }
          return lic;
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error leyendo Licencia de SQLite: $e');
    }

    // Migración transparente desde SharedPreferences (versiones anteriores)
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null && raw.isNotEmpty) {
        final jsonStr = _decrypt(raw);
        final map = jsonDecode(jsonStr) as Map<String, dynamic>;
        final lic = Licencia.fromJson(map);
        if (lic.uuid.isEmpty) {
          lic.uuid = await getOrCreateUuid();
        }
        try {
          await OfflineDatabase.instance.saveLicencia(lic.toDbMap());
          await prefs.remove(_storageKey);
          debugPrint('🔄 Licencia migrada de SharedPreferences a SQLite (tabla licencia) con éxito');
        } catch (_) {}
        return lic;
      }
    } catch (e) {
      debugPrint('⚠️ Error migrando Licencia de SharedPreferences: $e');
    }

    // Licencia vacía por defecto con UUID asignado
    final uuid = await getOrCreateUuid();
    final defaultLic = Licencia(uuid: uuid);
    try {
      await OfflineDatabase.instance.saveLicencia(defaultLic.toDbMap());
    } catch (_) {}
    return defaultLic;
  }

  /// Guarda la licencia en la tabla SQLite `licencia`.
  Future<void> save(Licencia lic) async {
    _licencia = lic;
    try {
      await OfflineDatabase.instance.init();
      await OfflineDatabase.instance.saveLicencia(lic.toDbMap());
      debugPrint('💾 Licencia guardada en SQLite (tabla licencia)');
    } catch (e) {
      debugPrint('⚠️ Error guardando Licencia en SQLite: $e');
    }
    notifyListeners();
  }

  /// Limpia los datos de la licencia en SQLite.
  Future<void> reset() async {
    final uuid = await getOrCreateUuid();
    try {
      await OfflineDatabase.instance.init();
      await OfflineDatabase.instance.resetLicencia(uuid: uuid);
      debugPrint('🗑️ Licencia reseteada en SQLite');
    } catch (e) {
      debugPrint('⚠️ Error reseteando Licencia en SQLite: $e');
    }
    _licencia = Licencia(uuid: uuid);
    notifyListeners();
  }

  /// Obtiene o genera el UUID del dispositivo.
  Future<String> getOrCreateUuid() => DeviceIdService.getOrCreateUuid();

  /// Valida la licencia contra el endpoint app_ent de Velneo según especificación oficial.
  Future<LicenciaResult> validate(Licencia lic, {bool saveOnSuccess = true}) async {
    final url = lic.buildValidateUrl();
    debugPrint('🔍 Validando licencia: $url');

    try {
      final response = await _activeClient.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      ).timeout(_timeout);

      final rawJson = response.body;
      final displayJson = 'URL: $url\n\n$rawJson';
      debugPrint('📥 Respuesta validación [${response.statusCode}]: $rawJson');

      if (response.statusCode != 200) {
        return LicenciaResult(
          estado: LicenciaEstado.denegada,
          mensaje: 'Error HTTP ${response.statusCode}',
          rawResponse: displayJson,
        );
      }

      dynamic doc;
      try {
        doc = jsonDecode(rawJson);
      } catch (e) {
        return LicenciaResult(
          estado: LicenciaEstado.denegada,
          mensaje: 'Error al interpretar la respuesta JSON del servidor: $e',
          rawResponse: displayJson,
        );
      }

      // 4. Errores de API
      if (doc is Map<String, dynamic> &&
          doc.containsKey('errors') &&
          doc['errors'] is List &&
          (doc['errors'] as List).isNotEmpty) {
        final first = (doc['errors'] as List).first;
        String errMsg = 'Error desconocido';
        if (first is Map && first.containsKey('message')) {
          errMsg = first['message']?.toString() ?? 'Error desconocido';
        } else if (first is String) {
          errMsg = first;
        }
        return LicenciaResult(
          estado: LicenciaEstado.denegada,
          mensaje: 'API: $errMsg',
          rawResponse: displayJson,
        );
      }

      // 5. Sin registros
      dynamic rawAppEnt;
      if (doc is Map) {
        rawAppEnt = doc['app_ent'] ?? doc['APP_ENT'] ?? doc['data'];
      } else if (doc is List) {
        rawAppEnt = doc;
      }

      if (rawAppEnt == null || (rawAppEnt is List && rawAppEnt.isEmpty)) {
        return LicenciaResult(
          estado: LicenciaEstado.denegada,
          mensaje: 'No se encontraron registros en el servidor',
          rawResponse: displayJson,
        );
      }

      dynamic record;
      if (rawAppEnt is List) {
        record = rawAppEnt.first;
      } else {
        record = rawAppEnt;
      }

      // 6. Respuesta simple (no objeto) -> válida sin comparar campos
      if (record is! Map) {
        lic.entM = '';
        lic.contraclave = '';
        lic.validada = true;
        lic.offlineIntentos = 0;
        if (saveOnSuccess) {
          await save(lic);
        }
        return LicenciaResult(
          estado: LicenciaEstado.valida,
          mensaje: 'Licencia validada correctamente',
          rawResponse: displayJson,
        );
      }

      final recordMap = Map<String, dynamic>.from(record);

      String elementToString(String key) {
        final val = recordMap[key] ?? recordMap[key.toUpperCase()] ?? recordMap[key.toLowerCase()];
        if (val == null) return '';
        return val.toString().trim();
      }

      // 7.a. Baj (baja)
      final bajVal = recordMap['baj'] ?? recordMap['BAJ'];
      final baj = bajVal == true || bajVal == 1 || bajVal.toString().toLowerCase() == 'true';
      if (baj) {
        return LicenciaResult(
          estado: LicenciaEstado.denegada,
          mensaje: 'Licencia dada de baja',
          rawResponse: displayJson,
        );
      }

      // 7.b. Comparar ent_m vs ID (app_ent)
      final apiEntM = elementToString('ent_m');
      if (apiEntM.isNotEmpty && lic.id.trim().isNotEmpty && apiEntM != lic.id.trim()) {
        return LicenciaResult(
          estado: LicenciaEstado.denegada,
          mensaje: 'ent_m no coincide (API: $apiEntM, local: ${lic.id})',
          rawResponse: displayJson,
        );
      }

      // 7.c. Comparar id vs Identificador
      final apiId = elementToString('id');
      if (apiId.isNotEmpty && lic.identificador.trim().isNotEmpty && apiId != lic.identificador.trim()) {
        return LicenciaResult(
          estado: LicenciaEstado.denegada,
          mensaje: 'id no coincide (API: $apiId, local: ${lic.identificador})',
          rawResponse: displayJson,
        );
      }

      // 7.d. Comparar licencia / lic (si existe) vs LicenciaCodigo
      final rawLic = elementToString('licencia');
      final apiLic = rawLic.isNotEmpty ? rawLic : elementToString('lic');
      if (apiLic.isNotEmpty && lic.licenciaCodigo.trim().isNotEmpty && apiLic != lic.licenciaCodigo.trim()) {
        return LicenciaResult(
          estado: LicenciaEstado.denegada,
          mensaje: 'licencia no coincide (API: $apiLic, local: ${lic.licenciaCodigo})',
          rawResponse: displayJson,
        );
      }

      // 7.e. Si todo coincide -> guardar ent_m, contraclave -> VÁLIDO
      final apiContraclave = elementToString('contraclave');
      lic.entM = apiEntM;
      lic.contraclave = apiContraclave;
      if (apiId.isNotEmpty) {
        lic.identificador = apiId;
      }
      if (lic.id.trim().isEmpty && apiEntM.isNotEmpty) {
        lic.id = apiEntM;
      }
      final rawAppEntVal = recordMap['app_ent'] ?? recordMap['APP_ENT'];
      if (rawAppEntVal != null) {
        lic.mainLicenseAppEntId = rawAppEntVal.toString();
      }
      lic.esAdmin = recordMap['es_admin'] == true || recordMap['ES_ADMIN'] == true;
      lic.esSoloLec = recordMap['es_solo_lec'] == true || recordMap['ES_SOLO_LEC'] == true;
      lic.equipo = elementToString('equipo');

      lic.validada = true;
      lic.offlineIntentos = 0;

      if (saveOnSuccess) {
        await save(lic);
      }

      return LicenciaResult(
        estado: LicenciaEstado.valida,
        mensaje: 'Licencia validada correctamente',
        rawResponse: displayJson,
      );
    } on SocketException catch (e) {
      debugPrint('⚠️ Error de red al validar licencia: $e');
      return LicenciaResult(
        estado: LicenciaEstado.errorConexion,
        mensaje: 'SIN_CONEXION',
        rawResponse: 'URL: $url\n\nError de red (SocketException): $e',
      );
    } on HandshakeException catch (e) {
      debugPrint('⚠️ Error SSL/TLS al validar licencia: $e');
      return LicenciaResult(
        estado: LicenciaEstado.errorConexion,
        mensaje: 'Error de certificado de seguridad SSL/TLS: $e',
        rawResponse: 'URL: $url\n\nError SSL: $e',
      );
    } on TimeoutException {
      debugPrint('⚠️ Timeout al validar licencia');
      return LicenciaResult(
        estado: LicenciaEstado.errorConexion,
        mensaje: 'Tiempo de espera agotado al conectar con el servidor',
        rawResponse: 'URL: $url\n\nTimeout (>15s)',
      );
    } catch (e) {
      debugPrint('⚠️ Error inesperado al validar licencia: $e');
      return LicenciaResult(
        estado: LicenciaEstado.errorConexion,
        mensaje: 'Error: $e',
        rawResponse: 'URL: $url\n\nExcepción: $e',
      );
    }
  }
}
