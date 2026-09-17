// ============================================================================
//  api_service.dart  —  EL "INTERMEDIARIO" ENTRE LA APP Y VELNEO
// ============================================================================
//
//  ¿Para qué sirve?
//  ----------------
//  Aquí están todas las operaciones que la app puede hacer contra el API:
//
//    - listar pedidos      →  PedidosService.list()
//    - ver un pedido       →  PedidosService.getById(id)
//    - crear pedido        →  PedidosService.create(json)
//    - editar pedido       →  PedidosService.update(id, json)
//    - borrar pedido       →  PedidosService.remove(id)
//    - cargar desplegables →  getProveedores(), getArticulos(), getAlmacenes(),
//                             getSeries(), getFormasPago()
//    - probar conexión     →  checkConnection()
//
//  En resumen: las pantallas NO hablan con el servidor directamente; le piden
//  a esta clase. Si un día cambia la API, solo se toca este archivo.
//
//  CONCEPTO:
//  - Clase "static": todos los métodos se llaman sin crear instancia:
//        PedidosService.list()  (no hace falta "new").
// ============================================================================

import 'core/api_client.dart'; // ApiClient (el mensajero) + ApiException.
import 'core/config.dart'; // AppConfig (para saber a qué endpoint llamar).
import 'models.dart'; // Nuestros modelos (Pedido, OpcionMaestra).
import 'theme/app_theme.dart'; // AppColors (para traducir el estado a código VELNEO).

/// ResultadoLista: "paquete" que devuelve listar pedidos.
/// No es solo la lista: también trae el TOTAL de pedidos que hay (para saber
/// cuántas páginas hay) y la página actual.
class ResultadoLista<T> {
  final List<T> items; // Los elementos de esta página.
  final int total; // Cuántos pedidos hay en total.
  final int page; // Página actual (1 = primera).

  ResultadoLista({required this.items, required this.total, required this.page});
}

/// PedidosService: la clase con TODAS las operaciones del API.
class PedidosService {
  // El mensajero único que hará las llamadas HTTP.
  static final _api = ApiClient.instance;

  /// list: pide una página de pedidos al servidor.
  ///
  /// Filtros opcionales:
  ///  - estado   : solo pedidos en ese estado ("Pendiente", "Servido"...).
  ///  - cliente  : solo pedidos de ese cliente (código).
  ///  - search   : búsqueda libre por texto.
  static Future<ResultadoLista<Pedido>> list({
    int page = 1, // Página que queremos (por defecto la primera).
    String? estado,
    String? cliente,
    String? search,
  }) async {
    // Parámetros de la petición. Los nombres son los del API REAL de VELNEO:
    //  - page[number] y page[size]  → paginación del API.
    //  - filter[est], filter[clt], filter[words] → filtros.
    // El "estado" viene como texto bonito ("Pendiente"...); lo traducimos a
    // su CÓDIGO VELNEO (P/S/C) con AppColors.estadoCodigo.
    final params = <String, dynamic>{
      'page[number]': page, // Número de página.
      'page[size]': AppConfig.pageSize, // Cuántos pedidos por página (50).
      // Orden: de más RECIENTE a más ANTIGUO por la fecha (campo VELNEO "fch").
      // VELNEO ordena descendente poniendo un "-" delante del campo.
      'sort': '-fch',
      // "if (x != null...) 'clave': valor" → solo añade el filtro si se pidió.
      if (estado != null && estado.isNotEmpty)
        'filter[est]': AppColors.estadoCodigo(estado),
      if (cliente != null && cliente.isNotEmpty) 'filter[clt]': cliente,
      if (search != null && search.isNotEmpty) 'filter[words]': search,
    };

    // Hacemos la llamada GET y la respuesta se convierte en una lista de Pedido.
    final json = await _api.get(AppConfig.endpoint('pedidos'), params: params);
    final items = payloadLista(json)
        .map(Pedido.fromJson)
        .toList();

    // El TOTAL real de pedidos lo informa VELNEO en "total_count".
    // Si no lo encontramos, asumimos lo que trajo la página.
    final total = payloadTotal(json) != 0 ? payloadTotal(json) : items.length;

    return ResultadoLista<Pedido>(items: items, total: total, page: page);
  }

  /// getById: pide UN pedido concreto al servidor por su id, junto con sus
  /// líneas. Si el API no deja leer líneas (permisos), el detalle igualmente
  /// se muestra con la cabecera (las líneas quedan vacías, sin romper nada).
  static Future<Pedido> getById(dynamic id) async {
    final json = await _api.get('${AppConfig.endpoint('pedidos')}/$id');
    final data = payloadData(json);
    if (data is! Map) {
      // Si el servidor responde algo que no es un mapa, avisamos con un error claro.
      throw ApiException('No se pudo leer el pedido.');
    }
    final pedido = Pedido.fromJson(Map<String, dynamic>.from(data));

    // --- Líneas del pedido (tabla VTA_PED_LIN_G, filtrada por la cabecera) ---
    try {
      final lin = await _api.get(
        AppConfig.endpoint('lineas'),
        params: {'filter[vta_ped]': '$id', 'page[size]': 1000},
      );
      return pedido.copyWith(
        lineas: payloadLista(lin).map(LineaPedido.fromJson).toList(),
      );
    } on ApiException {
      // Sin permiso sobre las líneas: devolvemos el pedido con las de vacío.
      return pedido;
    }
  }

  /// create: crea un pedido nuevo enviando sus datos (payload) al API.
  static Future<Pedido> create(Map<String, dynamic> payload) async {
    final json = await _api.post(AppConfig.endpoint('pedidos'), body: payload);
    final data = payloadData(json);
    if (data is Map) {
      return Pedido.fromJson(Map<String, dynamic>.from(data)); // El pedido creado.
    }
    throw ApiException('No se pudo crear el pedido.');
  }

  /// update: guarda los cambios de un pedido existente.
  /// VELNEO NO permite PUT; la actualización se hace con POST a la URL del
  /// recurso (por ejemplo /COM_PED_G/3197). Verificado contra el API real.
  static Future<Pedido> update(dynamic id, Map<String, dynamic> payload) async {
    final json = await _api.post(
      '${AppConfig.endpoint('pedidos')}/$id',
      body: payload,
    );
    final data = payloadData(json);
    if (data is Map) {
      return Pedido.fromJson(Map<String, dynamic>.from(data)); // El pedido actualizado.
    }
    throw ApiException('No se pudo actualizar el pedido.');
  }

  /// enviarLineas: guarda las líneas de un pedido en la tabla VTA_PED_LIN_G.
  ///
  /// Las líneas NO se envían dentro de la cabecera: viven en una tabla aparte
  /// y se crean UNA POR UNA con POST (verificado contra el API real):
  ///   - Línea nueva (sin id)  → POST a /VTA_PED_LIN_G con "vta_ped" = id de la
  ///     cabecera. VELNEO asigna el número de línea solo (10, 20, 30...).
  ///   - Línea existente (con id) → POST a /VTA_PED_LIN_G/{id} (VELNEO no usa PUT).
  /// El campo "est" se manda como CÓDIGO (P/S/C); "Pendiente" → "P".
  static Future<void> enviarLineas(dynamic pedidoId, List<LineaPedido> lineas) async {
    for (final linea in lineas) {
      final body = <String, dynamic>{
        // "vta_ped" enlaza la línea con su cabecera de venta. Sin él, VELNEO
        // crea la línea huérfana y no aparecería en el pedido.
        'vta_ped': pedidoId,
        'art': linea.articulo,
        'dsc': linea.descripcion,
        'ref_man': linea.nReferencia,
        'can_ped': linea.cantidad,
        'can_pdt': linea.pendiente,
        'pre': linea.precio,
        'por_dto': linea.dto,
        'imp': linea.importe,
        'reg_iva_vta': regIvaCodigo(linea.tipoIva), // % → código (G/R/S/E).
        'fch_ent': linea.previstoPara,
        'est': AppColors.estadoCodigo(linea.estado), // "Pendiente" → "P"
        'cnc': linea.cancelado,
      };
      try {
        if (linea.id == null) {
          // Línea nueva: la creamos dentro del pedido.
          await _api.post(AppConfig.endpoint('lineas'), body: body);
        } else {
          // Línea ya existente: la actualizamos apuntando a su propio id.
          await _api.post('${AppConfig.endpoint('lineas')}/${linea.id}', body: body);
        }
      } on ApiException catch (e) {
        throw ApiException('Error al guardar las líneas: $e');
      }
    }
  }

  /// eliminarLinea: borra una línea de un pedido en la tabla VTA_PED_LIN_G.
  /// VELNEO acepta DELETE a /VTA_PED_LIN_G/{id} y devuelve "Eliminado(s) con éxito".
  static Future<void> eliminarLinea(dynamic id) async {
    await _api.delete('${AppConfig.endpoint('lineas')}/$id');
  }

  /// remove: borra un pedido del servidor. No devuelve nada (void).
  static Future<void> remove(dynamic id) async {
    await _api.delete('${AppConfig.endpoint('pedidos')}/$id');
  }

  /// _maestros: método INTERNO (empieza por _) que carga CUALQUIER lista maestro.
  /// Las funciones públicas de abajo son huecos que usan este mismo código
  /// cambiando solo qué endpoint se pide. Pedimos hasta 1000 items para tener
  /// la lista completa en los desplegables.
  static Future<List<OpcionMaestra>> _maestros(String key, {int size = 1000}) async {
    final json = await _api.get(
      AppConfig.endpoint(key),
      params: {'page[size]': size},
    );
    return payloadLista(json).map(OpcionMaestra.fromJson).toList();
  }

  /// getClientes: los CLIENTES de venta (entidad con es_clt = true).
  ///
  /// ⚠️ VELNEO no filtra bien por booleano en ENT_M (filter[es_clt=true] da 0),
  /// así que bajamos las entidades y nos quedamos con las que son clientes,
  /// filtrando aquí en memoria. El selector de clientes también busca por
  /// nombre en memoria (ModalSelector).
  static Future<List<Cliente>> getClientesByIds(List<int> ids) async {
    if (ids.isEmpty) return [];
    final json = await _api.get(
      AppConfig.endpoint('clientes'),
      params: {'page[size]': 1000},
    );
    return payloadLista(json)
        .where((r) => ids.contains(r.i('id')))
        .map((r) => Cliente(
              id: r.i('id'),
              nombreComercial: r.s('nom_com').isNotEmpty ? r.s('nom_com') : r.s('name'),
              cif: r.s('cif'),
              telefono: r.s('tlf'),
            ))
        .toList();
  }

  /// getComerciales: los COMERCIALES (entidad con es_cmr = true). Igual que
  /// los clientes: filtramos en memoria porque el filtro booleano del API no
  /// funciona (filter[es_cmr=true] → 0 resultados).
  static Future<List<OpcionMaestra>> getComerciales() async {
    final json = await _api.get(
      AppConfig.endpoint('comerciales'),
      params: {'page[size]': 1000},
    );
    return payloadLista(json)
        .where((r) => r.b('es_cmr') || r.b('cmr'))
        .map((r) => OpcionMaestra(codigo: r.s('id'), nombre: r.s('name')))
        .toList();
  }

  // Otras operaciones "maestro" (para los desplegables del formulario de venta).
  static Future<List<OpcionMaestra>> getArticulos() => _maestros('articulos');
  static Future<List<OpcionMaestra>> getAlmacenes() => _maestros('almacenes');
  static Future<List<OpcionMaestra>> getFormasPago() => _maestros('formasPago');

  /// getSeries: las SERIES DE VENTA (ser_tip = "V") para la numeración del
  /// pedido. VELNEO escribe el tipo en el campo "ser_tip"; los filtramos para
  /// no ofrecer series de compra.
  static Future<List<OpcionMaestra>> getSeries() async {
    final json = await _api.get(
      AppConfig.endpoint('series'),
      params: {'page[size]': 500},
    );
    return payloadLista(json)
        .where((r) => r.s('ser_tip') == 'V')
        .map(OpcionMaestra.fromJson)
        .toList();
  }

  /// checkConnection: comprueba si el servidor responde Y la api_key tiene
  /// acceso a los pedidos. Se llama al pulsar "Conectar" en el login.
  ///
  /// Pedimos la PRIMERA página de pedidos (con un dato solo). Si el servidor
  /// responde, hay conexión; si no, lanza ApiException (con mensaje claro).
  static Future<bool> checkConnection() async {
    await _api.get(AppConfig.endpoint('pedidos'), params: {'page[size]': 1});
    return true; // Respondió sin error → conexión OK.
  }
}