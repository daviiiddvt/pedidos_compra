// ============================================================================
//  api_client.dart  —  EL "MENSAJERO" DE LA APP (HTTP + utilidades JSON)
// ============================================================================
//
//  ¿Para qué sirve?
//  ----------------
//  Toda la comunicación con el servidor VELNEO pasa por AQUÍ. Este archivo:
//     1) Hace peticiones HTTP (GET, POST, PUT, DELETE) al API.
//     2) Añade automáticamente la "api_key" de autenticación.
//     3) Convierte la respuesta JSON en algo que Dart entienda.
//     4) Ofrece ayudas para leer JSON de forma "tolerante":
//        si un campo falta o viene raro, NO rompe la app, devuelve 0 o ''.
//
//  Se define así porque NO nos fiamos del formato exacto de VELNEO:
//  a veces un valor llega como "12.5" y otras como {"value": "12.5"}.
//
//  CONCEPTOS:
//  - Singleton: clase que solo existe UNA vez en toda la app (ApiClient.instance).
//  - Extensión: "añadir poderes extra" a un tipo ya existente (Map con .s(), .d()...).
// ============================================================================

import 'dart:async'; // Utilidades para asíncrono.
import 'dart:convert'; // Convertir JSON <-> texto.
import 'dart:io'; // Constantes de HTTP como los encabezados.

import 'package:http/http.dart' as http; // La librería "http" para hacer llamadas.
import 'package:http/io_client.dart'; // IOClient: cliente HTTP con control del certificado TLS.

import 'config.dart'; // Necesitamos AppConfig (baseUrl, endpoints).

/// ApiException es un ERROR PROPIO de la app.
/// Se usa en lugar de los errores genéricos para que las pantallas puedan
/// mostrar un mensaje legible ("No se pudo contactar con el servidor").
class ApiException implements Exception {
  final String message; // Texto que puede mostrarse al usuario.
  final int? statusCode; // Código HTTP (200, 404...) si lo hay. null = no hubo respuesta.
  ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

/// ApiClient: el cliente HTTP único (singleton) de la aplicación.
///
/// Se usa así en el resto del código:
///     final json = await ApiClient.instance.get('/proveedores');
///
/// Fíjate en el constructor PRIVADO  ApiClient._() : eso impide crear otra
/// copia desde fuera (new ApiClient() daría error de compilación).
class ApiClient {
  static final ApiClient instance = ApiClient._(); // La única instancia.
  ApiClient._(); // Constructor privado: nadie más puede crear otra.

  // El cliente HTTP con verificación de certificado adaptada a VELNEO.
  // El servidor VELNEO no envía el certificado intermedio en la cadena TLS.
  // En PC y navegador funciona porque buscan el intermedio automáticamente
  // (AIA); dart:io no lo hace y falla con "unable to get local issuer".
  // Solución: aceptar el certificado del servidor conocido (tecerp.nunsys.com)
  // siempre que el host coincida, validando la conexión HTTPS de todos modos.
  final _client = IOClient(
    HttpClient()
      ..badCertificateCallback = (X509Certificate cert, String host, int port) {
        return host == 'tecerp.nunsys.com';
      },
  );
  String? _apiKey; // La clave API guardada (se pone al hacer login).

  // Guarda (o borra, con '') la clave API. La llama AuthState.
  void setApiKey(String value) => _apiKey = value;

  // --------------------------------------------------------------------------
  // Las 4 operaciones HTTP. Todas devuelven "dynamic" porque el JSON puede
  // ser un mapa, una lista, un texto o null. Quien llama decide cómo leerlo.
  // --------------------------------------------------------------------------

  /// Petición GET: pedir datos al servidor (lista, detalle...).
  Future<dynamic> get(String path, {Map<String, dynamic>? params}) async {
    return _send('GET', path, params: params);
  }

  /// Petición POST: crear algo nuevo (un pedido).
  Future<dynamic> post(String path, {Map<String, dynamic>? params, dynamic body}) async {
    return _send('POST', path, params: params, body: body);
  }

  /// Petición PUT: actualizar algo existente (editar un pedido).
  Future<dynamic> put(String path, {Map<String, dynamic>? params, dynamic body}) async {
    return _send('PUT', path, params: params, body: body);
  }

  /// Petición DELETE: borrar algo.
  Future<dynamic> delete(String path, {Map<String, dynamic>? params}) async {
    return _send('DELETE', path, params: params);
  }

  // --------------------------------------------------------------------------
  // _send: el cerebro de todas las peticiones.
  // Hace la llamada, revisa la respuesta y devuelve el JSON ya "decodificado".
  // --------------------------------------------------------------------------
  Future<dynamic> _send(
    String method, // 'GET', 'POST', 'PUT' o 'DELETE'
    String path, {
    Map<String, dynamic>? params, // Parámetros en la URL (?clave=valor).
    dynamic body, // Cuerpo de la petición (para POST/PUT). Se envía como JSON.
  }) async {
    final uri = _buildUri(path, params); // 1) Construimos la URL completa.
    final headers = {
      HttpHeaders.acceptHeader: 'application/json', // "Quiero JSON como respuesta".
      if (body != null) HttpHeaders.contentTypeHeader: 'application/json', // "Envío JSON".
    };

    late http.Response response; // "late" = se le asigna valor dentro del switch.
    try {
      // 2) Hacemos la llamada según el método.
      switch (method) {
        case 'GET':
          response = await _client.get(uri, headers: headers);
          break;
        case 'DELETE':
          response = await _client.delete(uri, headers: headers);
          break;
        case 'POST':
          response = await _client.post(
            uri,
            headers: headers,
            body: body == null ? null : jsonEncode(body),
          );
          break;
        case 'PUT':
          response = await _client.put(
            uri,
            headers: headers,
            body: body == null ? null : jsonEncode(body),
          );
          break;
        default:
          // Un método que no soportamos: error claro.
          throw ApiException('Método no soportado: $method');
      }
    } catch (e) {
      // Cualquier fallo de red (sin internet, servidor apagado, certificado...)
      // → error claro. Incluimos la causa real para poder diagnosticar.
      throw ApiException('No se pudo contactar con el servidor. ($e)');
    }

    // 3) Respuestas OK (200-299): devolvemos el contenido decodificado.
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null; // Respuesta vacía → null.
      try {
        final decoded = jsonDecode(response.body); // JSON → mapa/lista/texto.
        // ¡OJO, VELNEO! Aunque el servidor responda 200, puede llegar un error
        // dentro del cuerpo:  { "errors": [ "texto" ] }  o
        // { "errors": [ { "status": "405", "message": "..." } ] }.
        // Se lo convertimos en ApiException para que la app muestre el mensaje.
        if (decoded is Map && decoded.containsKey('errors')) {
          throw ApiException(
            _mensajeErrorVelneo(decoded, response.statusCode),
            statusCode: response.statusCode,
          );
        }
        return decoded;
      } on ApiException {
        rethrow; // El error que detectamos lo dejamos pasar tal cual.
      } catch (_) {
        return response.body; // Si no es JSON, devolvemos el texto tal cual.
      }
    }

    // 4) Respuesta de ERROR: intentamos sacar un mensaje legible.
    String message = 'Error del servidor (${response.statusCode})';
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map) {
        // VELNEO puede llamar al mensaje de error de varias formas.
        message =
            decoded['message'] ??
            decoded['error'] ??
            decoded['errorMsg'] ??
            message;
      }
    } catch (_) {
      // Si no se puede leer, dejamos el mensaje genérico.
    }

    throw ApiException(message, statusCode: response.statusCode);
  }

  // --------------------------------------------------------------------------
  // _buildUri: construye la URL final.
  // Une baseUrl + ruta, añade los parámetros dados y SIEMPRE añade api_key.
  // --------------------------------------------------------------------------
  Uri _buildUri(String path, Map<String, dynamic>? params) {
    // Copiamos los parámetros que nos pasaron, como texto.
    final merged = <String, String>{
      ...?params?.map((k, v) => MapEntry(k, v.toString())),
    };
    // Añadimos la api_key si existe.
    if (_apiKey != null && _apiKey!.isNotEmpty) {
      merged['api_key'] = _apiKey!;
    }

    // ¡IMPORTANTE! Unimos baseUrl y path garantizando EXACTAMENTE UNA "/" entre
    // ellos. Esto evita el error 404 cuando la baseUrl NO termina en "/" (tras
    // el login se quitan las barras finales) y el endpoint NO empieza por "/".
    final base = AppConfig.baseUrl.replaceAll(RegExp(r'/+$'), ''); // sin "/" final
    final ruta = path.startsWith('/') ? path : '/$path'; // con "/" delante
    var uri = Uri.parse('$base$ruta');
    if (merged.isNotEmpty) {
      // Mezclamos los parámetros (por si la URL ya traía alguno).
      uri = uri.replace(queryParameters: {...uri.queryParameters, ...merged});
    }
    return uri;
  }
}

// ============================================================================
//  FUNCIONES "DE APOYO" PARA LEER EL JSON DE VELNEO SIN ROMPER NADA
// ============================================================================
//  Estas ayudas existen porque VELNEO no siempre responde igual:
//    - La respuesta normal es un SOBRE: { "count": n, "total_count": total,
//      "<entidad>": [ ...registros... ] }. La lista real vive bajo la clave
//      con el nombre de la entidad ("com_ped_g", "ent_m"...).
//    - A veces la lista viene dentro de {"data": [...]} (otras versiones).
//    - A veces un campo numérico llega como "12,5" (coma) o anidado {"value": "x"}.
//  Con estas funciones la app aguanta TODO sin dar error.
// ============================================================================

/// Extrae un mensaje legible del bloque "errors" que manda VELNEO (HTTP 200).
/// Puede venir como:
///   { "errors": [ "El API Key no es válido" ] }
///   { "errors": [ { "status": "405", "message": "..." } ] }
String _mensajeErrorVelneo(Map json, int statusCode) {
  final errors = json['errors'];
  if (errors is List && errors.isNotEmpty) {
    final primero = errors.first;
    if (primero is Map) {
      final m = primero['message'];
      if (m != null && '$m'.isNotEmpty) return '$m';
      return 'Error del servidor (${primero['status'] ?? statusCode})';
    }
    if (primero is String && primero.isNotEmpty) return primero;
  }
  return 'Error del servidor ($statusCode)';
}

/// Si la respuesta tiene "data", devuelve SU contenido; si no, la respuesta entera.
dynamic normalizeData(dynamic json) {
  if (json is Map && json.containsKey('data')) {
    return json['data'];
  }
  return json;
}

/// Clave "entidad" de la respuesta VELNEO: la única clave cuyo valor es una
/// Lista (p. ej. "com_ped_g", "ent_m", "errors"...). Excluye "errors" para no
/// confundir un error (que también es una lista) con datos reales.
String? _entityKey(Map json) {
  for (final k in json.keys) {
    if (k != 'errors' && json[k] is List) return k;
  }
  return null;
}

/// Convierte cualquier valor a número decimal, aceptando comas y puntos.
double _toDoubleOrZero(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value.replaceAll(',', '.')) ?? 0;
  return 0;
}

/// Convierte cualquier valor a entero.
int _toIntOrZero(dynamic value) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

/// Convierte cualquier valor a booleano.
bool _toBoolOrFalse(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  return false;
}

/// Convierte cualquier valor a texto (null → '').
String _toStr(dynamic value) => value == null ? '' : '$value';

/// Extrae un campo de un registro JSON, DESENVOLVIENDO el caso raro de VELNEO:
/// si el valor llega como {"value": "12.5"}, devuelve "12.5".
dynamic _fieldValue(dynamic reg, String key) {
  if (reg is! Map) return null;
  final value = reg[key];
  if (value is Map && value.containsKey('value')) return value['value'];
  return value;
}

/// EXTENSIÓN: añade "atajos" a los mapas JSON. Ahora cualquier
/// `Map<String, dynamic>` puede usar json.s('nombre'), json.d('precio')...
extension JsonHelpers on Map<String, dynamic> {
  double d(String key) => _toDoubleOrZero(_fieldValue(this, key)); // como double
  int i(String key) => _toIntOrZero(_fieldValue(this, key)); // como int
  bool b(String key) => _toBoolOrFalse(_fieldValue(this, key)); // como bool
  String s(String key) => _toStr(_fieldValue(this, key)); // como String
  dynamic raw(String key) => _fieldValue(this, key); // sin transformar
}

/// Devuelve la LISTA de registros de una respuesta, esté donde esté
/// (sobre VELNEO, en "data"...). Siempre como `List<Map<String, dynamic>>`.
List<Map<String, dynamic>> payloadLista(dynamic json) {
  dynamic data = normalizeData(json);
  if (data is Map) {
    // Formato VELNEO: la lista vive en la clave con el nombre de la entidad
    // (ej. { "com_ped_g": [ ... ] }). Buscamos esa clave y la usamos.
    final key = _entityKey(data);
    if (key != null) data = data[key];
  }
  if (data is List) {
    return data.map((e) {
      if (e is Map) return Map<String, dynamic>.from(e);
      return <String, dynamic>{}; // Elemento raro → lo convertimos en mapa vacío.
    }).toList();
  }
  return []; // No hay lista → lista vacía (mejor que un error).
}

/// Devuelve el registro único (mapa) de una respuesta de DETALLE.
/// VELNEO también lo envuelve en el sobre: `{ "entidad": [ { ... } ] }`,
/// así que nos quedamos con el PRIMER elemento de la lista de la entidad.
dynamic payloadData(dynamic json) {
  final data = normalizeData(json);
  if (data is Map) {
    final key = _entityKey(data);
    final lista = key != null ? data[key] : null;
    if (lista is List && lista.isNotEmpty) return lista.first;
  }
  return data;
}

/// Devuelve el TOTAL de registros que informa la respuesta VELNEO
/// (el campo "total_count", que la app usa para la paginación).
int payloadTotal(dynamic json) {
  final data = normalizeData(json);
  if (data is Map) {
    final v = data['total_count'];
    if (v != null) {
      final n = int.tryParse('$v');
      if (n != null) return n;
    }
    // Otras versiones del API lo llaman "meta.total".
    final meta = data['meta'];
    if (meta is Map && meta['total'] != null) {
      return int.tryParse('${meta['total']}') ?? 0;
    }
  }
  return 0;
}