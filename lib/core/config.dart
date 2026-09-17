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
  // --------------------------------------------------------------------------
  // Dirección base del servidor. NO llevará la parte del endpoint, solo el
  // dominio + raíz del API. Esto se puede cambiar desde la pantalla de login
  // (no es "final" porque el usuario puede conectarse a otro servidor).
  // --------------------------------------------------------------------------
  static String baseUrl = 'https://tecerp.nunsys.com:4331/TECMICRO_PRUEBAS_AD_AVANZADO/';

  // Clave API para autenticarse contra VELNEO. Se rellena en el login y se
  // añade automáticamente como parámetro "api_key" en TODAS las peticiones.
  static String apiKey = '80IF1kwMQZTknj3BirIz';

  // --------------------------------------------------------------------------
  // Endpoints reales de VELNEO.
  // Cada clave ('pedidos', 'proveedores'...) es un recurso del API.
  // El valor es la ruta que se añade detrás de baseUrl (sin "/" inicial).
  // --------------------------------------------------------------------------
  static const endpoints = {
    'pedidos': 'TecERPv7_dat_dat/v1/VTA_PED_G',     // Cabeceras de pedidos de VENTA.
    'lineas': 'TecERPv7_dat_dat/v1/VTA_PED_LIN_G',   // Líneas de pedido de venta.
    'clientes': 'TecERPv7_dat_dat/v1/ENT_M',         // Entidades (clientes de venta).
    'comerciales': 'TecERPv7_dat_dat/v1/ENT_M',      // Entidades (comerciales).
    'articulos': 'TecERPv7_dat_dat/v1/ART_M',        // Catálogo de artículos.
    'almacenes': 'TecERPv7_dat_dat/v1/ALM_M',        // Lista de almacenes.
    'series': 'TecERPv7_dat_dat/v1/SER_M',           // Numeración de documentos.
    'formasPago': 'TecERPv7_dat_dat/v1/FPG_M',       // Formas de pago aceptadas.
  };

  // Número de resultados que se piden por página (parámetro page[size]).
  static const pageSize = 50;

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