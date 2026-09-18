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

/// Convierte el porcentaje de IVA usado por la interfaz al código de registro
/// que espera Velneo en `reg_iva_vta`.
///
/// La correspondencia actual es: 21% o más -> `G`, 10% o más -> `R`,
/// cualquier porcentaje positivo -> `S` y 0% -> `E`.
String regIvaCodigo(double tipoIva) {
  if (tipoIva >= 20) return 'G';
  if (tipoIva >= 10) return 'R';
  if (tipoIva > 0) return 'S';
  return 'E';
}

/// Resultado de una petición paginada de pedidos.
///
/// [items] contiene únicamente la página solicitada. [total] procede de
/// `total_count` o `meta.total` cuando Velneo lo devuelve; [page] es el número
/// de página utilizado en la petición.
class ResultadoLista<T> {
  /// Registros recibidos en la página actual.
  final List<T> items;

  /// Número total de registros informado por Velneo.
  final int total;

  /// Número de página de esta respuesta, empezando en 1.
  final int page;

  /// Crea el resultado de una página.
  ResultadoLista({required this.items, required this.total, required this.page});
}

/// PedidosService: la clase con TODAS las operaciones del API.
class PedidosService {
  // El mensajero único que hará las llamadas HTTP.
  static final _api = ApiClient.instance;

  /// Extrae el identificador de una referencia Velneo.
  ///
  /// Una referencia puede llegar como valor plano (`"25"`) o como objeto con
  /// id/value. Este método unifica ambos formatos para poder reutilizar el
  /// identificador en un filtro posterior.
  static String _referenceId(Map<String, dynamic> record, String field) {
    final value = record.raw(field);
    if (value is Map) {
      return '${value['id'] ?? value['value'] ?? ''}';
    }
    return value == null ? '' : '$value';
  }

  static OpcionMaestra _opcionFromRecord(Map<String, dynamic> record) {
    return OpcionMaestra(
      codigo: _referenceId(record, 'id').isNotEmpty
          ? _referenceId(record, 'id')
          : record.s('codigo'),
      nombre: record.s('name').isNotEmpty
          ? record.s('name')
          : (record.s('nom_com').isNotEmpty
              ? record.s('nom_com')
              : record.s('descripcion')),
    );
  }

  /// Valida las credenciales de un usuario y construye su sesión.
  ///
  /// Flujo de autorización:
  /// 1. Busca el usuario en `USR_M` usando [AppConfig.usuarioField].
  /// 2. Comprueba la contraseña contra [AppConfig.passwordField].
  /// 3. Obtiene el contacto referenciado por [AppConfig.usuarioContactoField].
  /// 4. Para usuarios no administradores exige `ES_CMR` en `ENT_M`.
  /// 5. Los pedidos se filtran posteriormente comparando `VTA_PED_G.CMR` con
  ///    el contacto comercial autenticado.
  ///
  /// La API key ya debe estar configurada en [ApiClient]. Lanza [ApiException]
  /// si las credenciales, la relación o los permisos no son válidos.
  static Future<User> authenticateUser({
    required String username,
    required String password,
  }) async {
    final json = await _api.get(
      AppConfig.endpoint('usuarios'),
      params: {
        'filter[${AppConfig.usuarioField}]': username,
        'page[size]': 10,
      },
    );
    final users = payloadLista(json);
    Map<String, dynamic>? user;
    for (final candidate in users) {
      if (candidate.s(AppConfig.usuarioField) == username &&
          candidate.s(AppConfig.passwordField) == password) {
        user = candidate;
        break;
      }
    }
    if (user == null) {
      throw ApiException('Usuario o contraseña incorrectos.');
    }

    final contactId = _referenceId(user, AppConfig.usuarioContactoField);
    if (contactId.isEmpty) {
      throw ApiException('El usuario no tiene un contacto asociado.');
    }
    final contact = await _getContact(contactId);
    final roleValue = user.s(AppConfig.usuarioRolField).toLowerCase();
    final isAdmin = roleValue == 'admin' || roleValue == 'administrador';
    if (!isAdmin && !contact.b(AppConfig.contactoComercialField)) {
      throw ApiException('El contacto asociado no está marcado como comercial.');
    }

    return User(
      id: user.s('id'),
      name: user.s('name').isEmpty ? username : user.s('name'),
      role: isAdmin ? 'Administrador' : 'Comercial',
      contactId: contactId,
    );
  }

  /// Lee un contacto de `ENT_M` por identificador.
  ///
  /// Se utiliza para resolver el campo `ENT` de `USR_M` y comprobar si el
  /// contacto representa a un comercial mediante `ES_CMR`.
  static Future<Map<String, dynamic>> _getContact(String id) async {
    final json = await _api.get(
      AppConfig.endpoint('clientes'),
      params: {'filter[id]': id, 'page[size]': 1},
    );
    final contacts = payloadLista(json);
    if (contacts.isEmpty) {
      throw ApiException('No se encontró el contacto asociado al usuario.');
    }
    return contacts.first;
  }

  static Future<String> _getContactName(String id) async {
    final contact = await _getContact(id);
    final name = contact.s('name');
    return name.isNotEmpty ? name : contact.s('nom_com');
  }

  static Future<String> _getArticleName(String id) async {
    final json = await _api.get(
      AppConfig.endpoint('articulos'),
      params: {'filter[id]': id, 'page[size]': 1},
    );
    final records = payloadLista(json);
    if (records.isEmpty) return '';
    final record = records.first;
    return record.s('name').isNotEmpty
        ? record.s('name')
        : record.s('descripcion');
  }

  static Future<List<LineaPedido>> _enrichLineArticleNames(
    List<LineaPedido> lineas,
  ) async {
    final missing = lineas
        .where((linea) => linea.articuloNombre.isEmpty && linea.articulo.isNotEmpty)
        .map((linea) => linea.articulo)
        .toSet();
    if (missing.isEmpty) return lineas;

    final names = <String, String>{};
    await Future.wait(
      missing.map((id) async {
        try {
          final name = await _getArticleName(id);
          if (name.isNotEmpty) names[id] = name;
        } on ApiException {
          // El código del artículo sigue siendo un fallback válido.
        }
      }),
    );
    return lineas
        .map(
          (linea) => linea.copyWith(
            articuloNombre: names[linea.articulo] ?? linea.articuloNombre,
          ),
        )
        .toList();
  }

  /// Solicita una página de cabeceras de pedido a `VTA_PED_G`.
  ///
  /// Filtros opcionales:
  /// [estado] se transforma de texto de interfaz a código Velneo mediante
  /// [AppColors.estadoCodigo]. [cliente] filtra por `CLT` y [search] se envía
  /// como `filter[words]` cuando se utiliza este método directamente.
  ///
  /// La pantalla principal usa normalmente [listAll] y filtra en memoria.
  /// Devuelve [ResultadoLista] con los pedidos deserializados mediante
  /// `Pedido.fromJson`.
  static Future<ResultadoLista<Pedido>> list({
    int page = 1, // Página que queremos (por defecto la primera).
    String? estado,
    String? cliente,
    String? search,
    String? comercial,
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
      if (comercial != null && comercial.isNotEmpty) 'filter[cmr]': comercial,
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

  /// Descarga todas las cabeceras de pedido por páginas.
  ///
  /// Repite peticiones a [list] hasta alcanzar el total informado o recibir
  /// una página incompleta/vacía. Cada petición contiene un `await`, por lo
  /// que el event loop de Flutter conserva el control mientras se descarga.
  static Future<List<Pedido>> listAll({String? comercial}) async {
    final all = <Pedido>[];
    var page = 1;
    var total = 0;
    var lastPageSize = 0;

    do {
      final result = await list(page: page, comercial: comercial);
      all.addAll(result.items);
      lastPageSize = result.items.length;
      total = result.total;
      page++;
      if (result.items.isEmpty) break;
      if (total > 0 && all.length >= total) break;
    } while (lastPageSize >= AppConfig.pageSize);

    return all;
  }

  /// Obtiene un pedido de `VTA_PED_G` junto con sus líneas.
  ///
  /// Primero consulta la cabecera por [id] y después `VTA_PED_LIN_G` usando
  /// `filter[vta_ped]`. Si la lectura de líneas falla por permisos, devuelve
  /// la cabecera con la lista de líneas que tuviera el pedido, en lugar de
  /// descartar todo el detalle.
  static Future<Pedido> getById(dynamic id) async {
    final json = await _api.get('${AppConfig.endpoint('pedidos')}/$id');
    final data = payloadData(json);
    if (data is! Map) {
      // Si el servidor responde algo que no es un mapa, avisamos con un error claro.
      throw ApiException('No se pudo leer el pedido.');
    }
    var pedido = Pedido.fromJson(Map<String, dynamic>.from(data));

    // Las líneas y los datos auxiliares del cliente son independientes.
    // Se solicitan a la vez para no sumar sus latencias.
    final lineasFuture = _api.get(
      AppConfig.endpoint('lineas'),
      params: {'filter[vta_ped]': '$id', 'page[size]': 100},
    );
    final clienteFuture = getClientesByIds([pedido.clienteId]).catchError(
      (_) => <Cliente>[],
    );
    final comercialFuture = pedido.comercial.isEmpty
        ? Future.value('')
        : _getContactName(pedido.comercial).catchError((_) => '');

    try {
      final results = await Future.wait([
        lineasFuture,
        clienteFuture,
        comercialFuture,
      ]);
      final lineas = payloadLista(results[0])
          .map(LineaPedido.fromJson)
          .toList();
      final clientes = results[1] as List<Cliente>;
      final comercialNombre = results[2] as String;
      if (clientes.isNotEmpty) {
        final cliente = clientes.first;
        pedido = pedido.copyWith(
          clienteNombre: cliente.nombreComercial,
          clienteTelefono: cliente.telefono,
          clienteCif: cliente.cif,
        );
      }
      if (comercialNombre.isNotEmpty) {
        pedido = pedido.copyWith(comercialNombre: comercialNombre);
      }
      final enrichedLineas = await _enrichLineArticleNames(lineas);
      return pedido.copyWith(lineas: enrichedLineas);
    } on ApiException {
      // Sin permiso sobre las líneas: devolvemos el pedido con las de vacío.
      return pedido;
    }
  }

  /// Crea una cabecera de pedido mediante `POST VTA_PED_G`.
  ///
  /// [payload] debe contener las claves publicadas por Velneo. Normalmente se
  /// obtiene con `pedido.copyWith(lineas: lineas).toJson()` desde el formulario.
  /// Las líneas se guardan separadamente mediante [enviarLineas].
  static Future<Pedido> create(Map<String, dynamic> payload) async {
    final json = await _api.post(AppConfig.endpoint('pedidos'), body: payload);
    final data = payloadData(json);
    if (data is Map) {
      return Pedido.fromJson(Map<String, dynamic>.from(data)); // El pedido creado.
    }
    throw ApiException('No se pudo crear el pedido.');
  }

  static Map<String, dynamic> _pedidoPayload(Pedido pedido) {
    return {
      'clt': pedido.clienteId,
      'est': AppColors.estadoCodigo(pedido.estado),
      'ser': pedido.serie,
      'cmr': pedido.comercial,
      'alm': pedido.almacen,
      'fch': pedido.fecha,
      'fch_ent': pedido.previstoPara,
      'fpg': pedido.formaPago,
      'dir_env': pedido.direccionEnvio,
      'obs': pedido.observaciones,
    };
  }

  static Future<Pedido> createComplete(Pedido pedido) async {
    late final Pedido created;
    try {
      created = await create(_pedidoPayload(pedido));
    } on ApiException catch (error) {
      throw ApiException('No se pudo crear la cabecera del pedido: $error');
    }
    final pedidoId = created.id ?? (created.codigo == 0 ? null : created.codigo);
    if (pedidoId == null) {
      throw ApiException('Velneo no devolvió el ID del pedido creado.');
    }
    try {
      await enviarLineas(pedidoId, pedido.lineas);
    } on ApiException catch (error) {
      throw ApiException(
        'La cabecera se creó, pero no se pudieron guardar las líneas: $error',
      );
    }
    return created.copyWith(id: pedidoId, lineas: pedido.lineas);
  }

  static Future<Pedido> updateComplete(
    dynamic id,
    Pedido pedido,
    Set<int> removedLineIds,
  ) async {
    final updated = await update(id, _pedidoPayload(pedido));
    for (final lineId in removedLineIds) {
      await eliminarLinea(lineId);
    }
    await enviarLineas(id, pedido.lineas);
    return updated.copyWith(id: updated.id ?? pedido.id, lineas: pedido.lineas);
  }

  /// Actualiza una cabecera existente mediante `POST VTA_PED_G/{id}`.
  ///
  /// Aunque conceptualmente es una actualización, esta instalación de Velneo
  /// no utiliza `PUT` para este recurso.
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

  /// Crea o actualiza las líneas de un pedido en `VTA_PED_LIN_G`.
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

  /// Elimina una línea mediante `DELETE VTA_PED_LIN_G/{id}`.
  static Future<void> eliminarLinea(dynamic id) async {
    await _api.delete('${AppConfig.endpoint('lineas')}/$id');
  }

  /// Elimina una cabecera mediante `DELETE VTA_PED_G/{id}`.
  static Future<void> remove(dynamic id) async {
    await _api.delete('${AppConfig.endpoint('pedidos')}/$id');
  }

  /// Carga una lista maestra genérica como [OpcionMaestra].
  ///
  /// [key] debe existir en `AppConfig.endpoints`. Se utiliza para artículos,
  /// almacenes y formas de pago, solicitando hasta [size] registros.
  static Future<List<OpcionMaestra>> _maestros(String key, {int size = 1000}) async {
    final json = await _api.get(
      AppConfig.endpoint(key),
      params: {'page[size]': size},
    );
    return payloadLista(json).map(_opcionFromRecord).toList();
  }

  /// Carga los clientes de [ids] desde `ENT_M`.
  ///
  /// Se utiliza para enriquecer los pedidos de la caché con nombre comercial,
  /// teléfono y CIF. Si [ids] está vacío no realiza ninguna petición.
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

  /// Carga los contactos comerciales de `ENT_M`.
  ///
  /// El filtro final por `ES_CMR` se aplica en Dart para tolerar instalaciones
  /// donde Velneo no interpreta correctamente filtros booleanos.
  static Future<List<OpcionMaestra>> getComerciales() async {
    final json = await _api.get(
      AppConfig.endpoint('comerciales'),
      params: {'page[size]': 1000},
    );
    return payloadLista(json)
        .where((r) => r.b('es_cmr') || r.b('cmr'))
        .map(
          (r) => OpcionMaestra(
            codigo: r.s('id'),
            nombre: r.s('name').isNotEmpty ? r.s('name') : r.s('nom_com'),
          ),
        )
        .toList();
  }

  /// Carga artículos desde `ART_M`.
  static Future<List<OpcionMaestra>> getArticulos() => _maestros('articulos');

  /// Carga almacenes desde `ALM_M`.
  static Future<List<OpcionMaestra>> getAlmacenes() => _maestros('almacenes');

  /// Carga formas de pago desde `FPG_M`.
  static Future<List<OpcionMaestra>> getFormasPago() => _maestros('formasPago');

  /// Carga únicamente series de venta (`ser_tip == 'V'`) desde `SER_M`.
  static Future<List<OpcionMaestra>> getSeries() async {
    final json = await _api.get(
      AppConfig.endpoint('series'),
      params: {'page[size]': 500},
    );
    return payloadLista(json)
        .where((r) => r.s('ser_tip') == 'V')
        .map(_opcionFromRecord)
        .toList();
  }

  /// Comprueba que la API key puede leer `VTA_PED_G`.
  ///
  /// No autentica a un usuario funcional; esa responsabilidad corresponde a
  /// [authenticateUser]. Lanza [ApiException] si Velneo rechaza la petición.
  static Future<bool> checkConnection() async {
    await _api.get(AppConfig.endpoint('pedidos'), params: {'page[size]': 1});
    return true; // Respondió sin error → conexión OK.
  }

  /// Devuelve opciones de clientes para el selector del formulario.
  ///
  /// Actualmente es un punto de extensión y devuelve una lista vacía. La
  /// autorización de pedidos no depende de este método: se realiza mediante
  /// `VTA_PED_G.CMR` y el contacto comercial de la sesión.
  static Future<List<OpcionMaestra>> getClientes() async {
    final json = await _api.get(
      AppConfig.endpoint('clientes'),
      params: {'page[size]': 1000},
    );
    return payloadLista(json)
        .map(
          (r) => OpcionMaestra(
            codigo: r.s('id'),
            nombre: r.s('nom_com').isNotEmpty ? r.s('nom_com') : r.s('name'),
          ),
        )
        .toList();
  }
}