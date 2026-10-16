// ============================================================================
//  config.dart  —  CONFIGURACIÓN GENERAL DE LA APLICACIÓN
// ============================================================================
//
//  ¿Para qué sirve?
//  ----------------
//  Este archivo es como el "cuadro de mandos" de la app: aquí se guardan los
//  datos que NO cambian casi nunca, como:
//     - La dirección del servidor VELNEO (baseUrl).
//     - La Clave API (apiKey) que autentica las peticiones.
//     - El número de resultados por página.
//     - Las "direcciones" (endpoints) de cada recurso del API.
//
//  Los endpoints ya están rellenados con las rutas REALES de VELNEO:
//  así se verifica que cada una responde 200 con la api_key actual.
//
//  ⚠️ PERMISOS: VELNEO concede permisos POR TABLA y POR MÉTODO a cada API Key
//  (si no, responde { "errors": [ ... ] }). Esta app trabaja con PEDIDOS DE
//  VENTA. La clave actual permite leer/escribir VTA_PED_G y VTA_PED_LIN_G
//  (cabecera y líneas de pedidos de venta) y leer los maestros ENT_M, ALM_M,
//  SER_M, FPG_M y ART_M.
// ============================================================================

class AppConfig {
  static const String defaultHost = 'https://tecerp.nunsys.com:4331';
  static const String datName = 'TecERPv7_dat_dat';
  static const String defaultVersion = 'v1';

  static String serverHost = defaultHost;
  static String serverInstance = '';
  static String serverVersion = defaultVersion;

  // --------------------------------------------------------------------------
  // Dirección base del servidor. NO llevará la parte del endpoint, solo el
  // dominio + raíz del API: {host}/{instancia}/TecERPv7_dat_dat/{versión}
  // --------------------------------------------------------------------------
  static String baseUrl =
      'https://tecerp.nunsys.com:XXXX/NOMBRE_API/';

  // Clave API para autenticarse contra VELNEO. Se rellena en el login y se
  // añade automáticamente como parámetro "api_key" en TODAS las peticiones.
  static String apiKey = '';

  /// Construye la URL base parametrizada:
  /// {host}/{instance}/TecERPv7_dat_dat/{version}
  static String buildBaseUrl({
    String? host,
    String? instance,
    String? version,
  }) {
    final h = (host ?? serverHost).trim().replaceAll(RegExp(r'/+$'), '');
    final inst = (instance ?? serverInstance).trim().replaceAll('/', '');
    final v = (version ?? serverVersion).trim().replaceAll('/', '');
    final safeV = v.isEmpty ? defaultVersion : v;

    if (inst.isEmpty) return h;
    return '$h/$inst/$datName/$safeV';
  }

  /// Descompone una URL existente en sus partes si coincide con la estructura de Velneo.
  static void parseAndSetBaseUrl(String url) {
    final clean = url.trim().replaceAll(RegExp(r'/+$'), '');
    if (clean.isNotEmpty) {
      baseUrl = clean;
    }
    try {
      final uri = Uri.parse(clean);
      if (uri.hasScheme && uri.host.isNotEmpty) {
        final portPart = uri.hasPort ? ':${uri.port}' : '';
        serverHost = '${uri.scheme}://${uri.host}$portPart';
        final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
        if (segments.length >= 3 && segments[1].toLowerCase() == datName.toLowerCase()) {
          serverInstance = segments[0];
          serverVersion = segments[2];
        } else if (segments.isNotEmpty && segments[0] != 'NOMBRE_API' && segments[0] != 'XXXX') {
          serverInstance = segments[0];
        }
      }
    } catch (_) {
      final reg = RegExp(r'^(https?://[^/]+)/([^/]+)/([^/]+)/([^/]+)$', caseSensitive: false);
      final match = reg.firstMatch(clean);
      if (match != null) {
        serverHost = match.group(1)!;
        serverInstance = match.group(2)!;
        if (match.group(3)!.toLowerCase() == datName.toLowerCase()) {
          serverVersion = match.group(4)!;
        }
      }
    }
  }

  // --------------------------------------------------------------------------
  // Endpoints reales de VELNEO.
  // Cada clave ('pedidos', 'proveedores'...) es un recurso del API.
  // El valor es la ruta que se añade detrás de baseUrl (sin "/" inicial).
  // --------------------------------------------------------------------------
  static const endpoints = {
    'pedidos':
        'VTA_PED_G', // Cabeceras de pedidos de VENTA.
    'usuarios': 'USR_M', // Usuarios de acceso.
    'gruposUsuarios':
        'USR_GRP_USR_M', // Asignaciones de grupos.
    'lineas': 'VTA_PED_LIN_G', // Líneas de pedido de venta.
    'procesoActualizarLinea':
        '../../ACT_VTA_PED_LIN_G_APP.pro', // Proceso Velneo para actualizar líneas.
    'procesoEnviarEmailPedido':
        '../../ENV_EML_VTA_PED.pro', // Envía el pedido al cliente por email.
    'presupuestos':
        'VTA_PRE_G', // Cabeceras de presupuestos de VENTA.
    'lineasPresupuesto': 'VTA_PRE_LIN_G',
    'procesoActualizarLineaPresupuesto':
        '../../ACT_VTA_PRE_LIN_G_APP.pro', // Líneas de presupuesto.
    'clientes': 'ENT_M', // Entidades (clientes de venta).
    'comerciales': 'ENT_M', // Entidades (comerciales).
    'movimientos': 'MOV_G', // Movimientos.
    'direcciones': 'DIR_M', // Direcciones de clientes.
    'empresa': 'EMP_M', // Datos de empresa/defaults.
    'articulos': 'ART_M', // Catálogo de artículos.
    'familias': 'FAM_M', // Familias de artículos.
    'descuentosPorFamilia': 'DTO_POR_FAM', // Descuentos de cliente por familia.
    'proveedores': 'ENT_M', // Entidades (proveedores).
    'tarifasCliente': 'vta_tar_cli_g',
    'tarifasArticulo': 'vta_tar_art_g',
    'tarifas': 'VTA_TAR_G', // Maestro de tarifas
    'almacenes': 'ALM_M', // Lista de almacenes.
    'series': 'SER_M', // Numeración de documentos.
    'formasPago': 'FPG_M', // Formas de pago aceptadas.
    'zonasTecnicas': 'ZN_TCN', // Zonas técnicas
    'zonasComerciales':
        'ZN_TCN_CMR', // Tabla intermedia zonas-comercial
    'poblaciones': 'POB', // Poblaciones
  };

  // Número de resultados que se piden por página (parámetro page[size]).
  static const pageSize = 50;

  static const usuarioField = 'name';
  static const passwordField = 'pwd';
  static const usuarioContactoField = 'ent';
  static const usuarioRolField = 'rol';
  static const contactoComercialField = 'es_cmr';

  // --------------------------------------------------------------------------
  // Devuelve la ruta de un recurso, o lanza un error claro si no está
  // configurado. Así, si olvidamos rellenar un endpoint, la app lo avisa
  // directamente en pantalla en lugar de fallar en silencio.
  // --------------------------------------------------------------------------
  static String endpoint(String key) {
    final value = endpoints[key] ?? '';
    if (value.isEmpty) {
      throw Exception('Endpoint "$key" no configurado en lib/core/config.dart');
    }
    return value;
  }
}
