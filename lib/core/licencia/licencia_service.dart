import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

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

  /// Cliente HTTP con tolerancia a certificados intermedios no provistos por el servidor TLS.
  static final http.Client _client = IOClient(
    HttpClient()
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true,
  );

  Licencia? _licencia;

  LicenciaService();

  Licencia? get licencia => _licencia;
  bool get isValida => _licencia?.validada ?? false;
  bool get esAdmin => _licencia?.esAdmin ?? false;
  bool get esSoloLec => _licencia?.esSoloLec ?? false;

  /// Clave interna para ofuscar los datos almacenados.
  static const List<int> _obfKey = [0x54, 0x65, 0x63, 0x50, 0x45, 0x44, 0x5F, 0x4B];

  static String _encrypt(String text) {
    final bytes = utf8.encode(text);
    final encrypted = List<int>.generate(bytes.length, (i) => bytes[i] ^ _obfKey[i % _obfKey.length]);
    return base64Encode(encrypted);
  }

  static String _decrypt(String encoded) {
    try {
      final bytes = base64Decode(encoded);
      final decrypted = List<int>.generate(bytes.length, (i) => bytes[i] ^ _obfKey[i % _obfKey.length]);
      return utf8.decode(decrypted);
    } catch (_) {
      return encoded; // Fallback si estuviera en JSON plano
    }
  }

  /// Inicializa cargando la licencia y ejecutando revalidación si procede.
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

  /// Carga la licencia almacenada en el almacenamiento persistente seguro.
  Future<Licencia> load() async {
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
        return lic;
      }
    } catch (e) {
      debugPrint('⚠️ Error leyendo Licencia de almacenamiento: $e');
    }

    // Licencia vacía por defecto con UUID asignado
    final uuid = await getOrCreateUuid();
    return Licencia(uuid: uuid);
  }

  /// Guarda la licencia en el almacenamiento persistente ofuscado.
  Future<void> save(Licencia lic) async {
    _licencia = lic;
    try {
      final jsonStr = jsonEncode(lic.toJson());
      final encrypted = _encrypt(jsonStr);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, encrypted);
      debugPrint('💾 Licencia guardada en almacenamiento persistente');
    } catch (e) {
      debugPrint('⚠️ Error guardando Licencia en almacenamiento: $e');
    }
    notifyListeners();
  }

  /// Limpia los datos de la licencia.
  Future<void> reset() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
      debugPrint('🗑️ Licencia reseteada');
    } catch (e) {
      debugPrint('⚠️ Error reseteando Licencia: $e');
    }
    final uuid = await getOrCreateUuid();
    _licencia = Licencia(uuid: uuid);
    notifyListeners();
  }

  /// Obtiene o genera el UUID del dispositivo.
  Future<String> getOrCreateUuid() => DeviceIdService.getOrCreateUuid();

  /// Valida la licencia contra el endpoint app_ent de Velneo.
  Future<LicenciaResult> validate(Licencia lic) async {
    final url = lic.buildValidateUrl();
    debugPrint('🔍 Validando licencia: $url');

    try {
      final response = await _client.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      ).timeout(_timeout);

      final body = response.body;
      debugPrint('📥 Respuesta validación [${response.statusCode}]: $body');

      if (response.statusCode != 200) {
        return LicenciaResult(
          estado: LicenciaEstado.denegada,
          mensaje: 'Error en el servidor de licencias (${response.statusCode})',
          rawResponse: body,
        );
      }

      final doc = jsonDecode(body) as Map<String, dynamic>;

      // En Velneo, la lista puede venir en 'app_ent' o clave equivalente
      Map<String, dynamic> record;
      final dynamic rawList = doc['app_ent'] ?? doc['APP_ENT'] ?? doc['data'];
      if (rawList is List && rawList.isNotEmpty) {
        record = rawList.first as Map<String, dynamic>;
      } else if (doc.containsKey('contraclave') || doc.containsKey('CONTRACLAVE')) {
        record = doc;
      } else {
        return LicenciaResult(
          estado: LicenciaEstado.denegada,
          mensaje: 'No se encontró la licencia en el servidor',
          rawResponse: body,
        );
      }

      // Comprobación 1: Baja
      final baj = record['baj'] == true || record['BAJ'] == true || record['baj'] == 1 || record['BAJ'] == 1;
      if (baj) {
        return LicenciaResult(
          estado: LicenciaEstado.denegada,
          mensaje: 'Licencia dada de baja. Contacte con el administrador.',
          rawResponse: body,
        );
      }

      // Comprobación 2: Contraclave (debe coincidir con el UUID del dispositivo)
      final contraclave = (record['contraclave'] ?? record['CONTRACLAVE'] ?? '').toString().trim();
      if (contraclave.isEmpty) {
        return LicenciaResult(
          estado: LicenciaEstado.denegada,
          mensaje: 'Validación denegada: la licencia no tiene contraclave registrada en el servidor.',
          rawResponse: body,
        );
      }

      final uuidLocal = lic.uuid.trim().toLowerCase();
      final contraRemota = contraclave.toLowerCase();

      if (uuidLocal != contraRemota) {
        return LicenciaResult(
          estado: LicenciaEstado.denegada,
          mensaje: 'UUID no autorizado. El dispositivo no coincide con la contraclave de la licencia.',
          rawResponse: body,
        );
      }

      // Validada con éxito: actualizar datos
      lic.id = (record['id'] ?? record['ID'] ?? '').toString();
      final appEntVal = record['app_ent'] ?? record['APP_ENT'];
      lic.mainLicenseAppEntId = appEntVal != null ? appEntVal.toString() : lic.id;
      lic.esAdmin = record['es_admin'] == true || record['ES_ADMIN'] == true;
      lic.esSoloLec = record['es_solo_lec'] == true || record['ES_SOLO_LEC'] == true;
      lic.equipo = (record['equipo'] ?? record['EQUIPO'] ?? '').toString();
      lic.validada = true;
      lic.offlineIntentos = 0;

      await save(lic);

      return LicenciaResult(
        estado: LicenciaEstado.valida,
        mensaje: 'Licencia validada correctamente',
        rawResponse: body,
      );
    } on SocketException catch (e) {
      debugPrint('⚠️ Error de red al validar licencia: $e');
      return const LicenciaResult(
        estado: LicenciaEstado.errorConexion,
        mensaje: 'Sin conexión con el servidor de licencias',
      );
    } on HandshakeException catch (e) {
      debugPrint('⚠️ Error SSL/TLS al validar licencia: $e');
      return LicenciaResult(
        estado: LicenciaEstado.errorConexion,
        mensaje: 'Error de certificado de seguridad SSL/TLS: $e',
      );
    } on TimeoutException catch (e) {
      debugPrint('⚠️ Timeout al validar licencia: $e');
      return const LicenciaResult(
        estado: LicenciaEstado.errorConexion,
        mensaje: 'Tiempo de espera agotado al conectar con el servidor',
      );
    } catch (e) {
      debugPrint('⚠️ Error inesperado al validar licencia: $e');
      return LicenciaResult(
        estado: LicenciaEstado.errorConexion,
        mensaje: 'Error de conexión: $e',
      );
    }
  }
}
