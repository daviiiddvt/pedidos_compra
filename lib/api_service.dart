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

import 'package:flutter/foundation.dart' show debugPrint; // Logging.

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
  static final Map<String, String> _articuloNombreCache = <String, String>{};

  static Map<String, String> buildArticleNameMap(
    List<Map<String, dynamic>> records,
    Set<String> requestedIds,
  ) {
    final names = <String, String>{};
    for (final record in records) {
      final id = _referenceId(record, 'id');
      final normalizedId = id.isEmpty ? record.s('codigo') : id;
      if (normalizedId.isEmpty || !requestedIds.contains(normalizedId)) {
        continue;
      }
      final name = record.s('name').isNotEmpty
          ? record.s('name')
          : record.s('descripcion');
      if (name.isNotEmpty) {
        names[normalizedId] = name;
      }
    }
    return names;
  }

  static bool shouldRequestNextPage({
    required int loadedRecords,
    required int totalRecords,
    required int pageSize,
    required int pageRecords,
  }) {
    if (pageRecords == 0) return false;
    if (totalRecords > 0) return loadedRecords < totalRecords;
    return pageRecords >= pageSize;
  }

  static Future<List<Map<String, dynamic>>> _fetchAllRecords(
    String endpoint, {
    Map<String, dynamic>? extraParams,
    int pageSize = 1000,
  }) async {
    final allRecords = <Map<String, dynamic>>[];
    var pageNumber = 1;

    while (true) {
      final params = <String, dynamic>{
        'page[size]': pageSize,
        'page[number]': pageNumber,
        ...?extraParams,
      };

      final json = await _api.get(endpoint, params: params);
      final records = payloadLista(json);
      if (records.isEmpty) break;

      allRecords.addAll(records);
      final shouldContinue = shouldRequestNextPage(
        loadedRecords: allRecords.length,
        totalRecords: payloadTotal(json),
        pageSize: pageSize,
        pageRecords: records.length,
      );

      if (!shouldContinue) break;
      pageNumber++;
    }

    return allRecords;
  }

  static String resolveDefaultValue(Map<String, dynamic> record, List<String> fields) {
    for (final field in fields) {
      final normalized = _normalizeDefaultValue(record.raw(field));
      if (normalized.isNotEmpty) return normalized;
    }
    return '';
  }

  static String _normalizeDefaultValue(dynamic value) {
    if (value == null) return '';
    if (value is List) {
      for (final item in value) {
        final normalized = _normalizeDefaultValue(item);
        if (normalized.isNotEmpty) return normalized;
      }
      return '';
    }
    if (value is Map) {
      final candidates = [
        value['value'],
        value['id'],
        value['codigo'],
        value['code'],
        value['cod'],
        value['name'],
        value['nom_com'],
        value['descripcion'],
        value['DIR'],
        value['ALM'],
        value['FPG'],
        value['EML'],
        value['ser_vta'],
      ];
      for (final candidate in candidates) {
        final normalized = _normalizeDefaultValue(candidate);
        if (normalized.isNotEmpty) return normalized;
      }
      return '';
    }
    return '$value'.trim();
  }

  static String _firstNonEmpty(Map<String, dynamic> record, List<String> fields) {
    return resolveDefaultValue(record, fields);
  }

  static OpcionMaestra? findMatchingOption(List<OpcionMaestra> options, String? rawValue) {
    final value = (rawValue ?? '').trim();
    if (value.isEmpty) return null;

    final normalized = value.toLowerCase();
    for (final option in options) {
      final code = option.codigo.trim();
      final name = option.nombre.trim();
      if (code.isNotEmpty && code.toLowerCase() == normalized) return option;
      if (name.isNotEmpty && name.toLowerCase() == normalized) return option;
      if (code.isNotEmpty && code.toLowerCase().contains(normalized)) return option;
      if (name.isNotEmpty && name.toLowerCase().contains(normalized)) return option;
    }
    return null;
  }

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

  static bool isClienteEntity(Map<String, dynamic> record) {
    final values = [
      record.raw('ES_CLT'),
      record.raw('es_clt'),
      record.raw('esCliente'),
      record.raw('es_cliente'),
      record.raw('CLT'),
      record.raw('clt'),
    ];
    for (final value in values) {
      if (value is bool && value) return true;
      if (value is num && value != 0) return true;
      if (value is String && value.trim().toLowerCase() == 'true') return true;
      if (value is String && value.trim() == '1') return true;
      if (value is String && value.trim().toLowerCase() == 's') return true;
      if (value is String && value.trim().toLowerCase() == 'si') return true;
      if (value is String && value.trim().toLowerCase() == 'sí') return true;
    }
    return false;
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

  static Future<Map<String, String>> _getArticleNamesByIds(
    Set<String> requestedIds,
  ) async {
    final cleanIds = requestedIds.where((id) => id.isNotEmpty).toSet();
    if (cleanIds.isEmpty) return {};

    final cached = <String, String>{};
    for (final id in cleanIds) {
      final cachedName = _articuloNombreCache[id];
      if (cachedName != null && cachedName.isNotEmpty) {
        cached[id] = cachedName;
      }
    }

    final missing = cleanIds.where((id) => !cached.containsKey(id)).toSet();
    if (missing.isEmpty) return cached;

    final results = await Future.wait(
      missing.map((id) async {
        try {
          final json = await _api.get(
            AppConfig.endpoint('articulos'),
            params: {'filter[id]': id, 'page[size]': 1},
          );
          final records = payloadLista(json);
          if (records.isEmpty) return null;
          final record = records.first;
          final name = record.s('name').isNotEmpty
              ? record.s('name')
              : record.s('descripcion');
          if (name.isEmpty) return null;
          _articuloNombreCache[id] = name;
          return MapEntry(id, name);
        } on ApiException {
          return null;
        }
      }),
    );

    for (final result in results) {
      if (result != null) {
        cached[result.key] = result.value;
      }
    }
    return cached;
  }

  static Future<List<LineaPedido>> _enrichLineArticleNames(
    List<LineaPedido> lineas,
  ) async {
    final missing = lineas
        .where((linea) => linea.articuloNombre.isEmpty && linea.articulo.isNotEmpty)
        .map((linea) => linea.articulo)
        .toSet();
    if (missing.isEmpty) return lineas;

    final names = await _getArticleNamesByIds(missing);
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

  static Map<String, dynamic> buildPedidoPayload(Pedido pedido) {
    final payload = <String, dynamic>{
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
      'emp': 1,
      'emp_div': 1,
    };

    if (pedido.email.trim().isNotEmpty) {
      // VELNEO rechaza este campo en la cabecera de una venta; es un dato del
      // cliente y no debe enviarse al crear/actualizar VTA_PED_G.
      // Se omite deliberadamente para evitar el 403/validation error del backend.
      payload.remove('email');
    }

    return payload;
  }

  static Map<String, dynamic> _pedidoPayload(Pedido pedido) =>
      buildPedidoPayload(pedido);

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
        'can_srv': linea.cantidadServida,
        'can_pte': linea.pendiente,
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
    final records = await _fetchAllRecords(
      AppConfig.endpoint(key),
      pageSize: size,
    );
    return records.map(_opcionFromRecord).toList();
  }

  /// Carga los clientes de [ids] desde `ENT_M`.
  ///
  /// Se utiliza para enriquecer los pedidos de la caché con nombre comercial,
  /// teléfono y CIF. Si [ids] está vacío no realiza ninguna petición.
  static Future<List<Cliente>> getClientesByIds(List<int> ids) async {
    if (ids.isEmpty) return [];
    final uniqueIds = ids.toSet().toList();
    final clientes = await Future.wait(
      uniqueIds.map((id) async {
        try {
          final json = await _api.get(
            AppConfig.endpoint('clientes'),
            params: {'filter[id]': '$id', 'page[size]': 1},
          );
          final records = payloadLista(json);
          if (records.isEmpty) return null;
          final record = records.first;
          return Cliente(
            id: record.i('id'),
            nombreComercial: record.s('nom_com').isNotEmpty ? record.s('nom_com') : record.s('name'),
            cif: record.s('cif'),
            telefono: record.s('tlf'),
          );
        } on ApiException {
          return null;
        }
      }),
    );

    return clientes.whereType<Cliente>().toList();
  }

  static Future<Map<String, dynamic>> getClienteDefaults(int clienteId) async {
    if (clienteId <= 0) {
      return {'serie': '', 'direccion': '', 'email': '', 'almacen': '', 'formaPago': ''};
    }

    try {
      final clienteJson = await _api.get(
        AppConfig.endpoint('clientes'),
        params: {'filter[id]': '$clienteId', 'page[size]': 1},
      );
      final clientes = payloadLista(clienteJson);
      if (clientes.isEmpty) {
        return {'serie': '', 'direccion': '', 'email': '', 'almacen': '', 'formaPago': ''};
      }
      final cliente = clientes.first;

      // ── DEPURACIÓN: mostrar el JSON exacto que devuelve VELNEO ────────
      // Para que puedas ver TODAS las claves que manda la API al elegir un
      // cliente y decidir con cuáles mapear serie/formaPago/almacén.
      debugPrint('\n━━━ [VELNEO] Cliente $clienteId → JSON completo (${cliente.keys.length} claves) ━━━');
      for (final entry in cliente.entries) {
        debugPrint('  ${entry.key}: ${entry.value}');
      }
      debugPrint('━━━ /FIN JSON cliente $clienteId ━━━');

      final serie = resolveDefaultValue(cliente, ['ser_vta', 'SER_VTA', 'serie', 'ser']);
      final formaPago = resolveDefaultValue(cliente, ['fpg', 'FPG', 'forma_pago', 'formaPago', 'fpg_def']);
      var direccion = resolveDefaultValue(cliente, [
        'DIR_M_VTA_PED_ENV',
        'dir_env',
        'direccion_envio',
        'dir_env_def',
      ]);
      if (direccion.isEmpty) {
        final direccionPrimariaId = _referenceId(cliente, 'DIR_PRI').isNotEmpty
            ? _referenceId(cliente, 'DIR_PRI')
            : _referenceId(cliente, 'DIR_PRI.ID');
        if (direccionPrimariaId.isNotEmpty) {
          try {
            final direccionJson = await _api.get(
              '${AppConfig.endpoint('direcciones')}/$direccionPrimariaId',
            );
            final direccionData = payloadData(direccionJson);
            if (direccionData is Map) {
              final direccionPrimaria = Map<String, dynamic>.from(direccionData);
              direccion = _firstNonEmpty(direccionPrimaria, ['DIR', 'direccion', 'dir']);
            }
          } on ApiException {
            // Se mantiene vacío si la dirección referenciada no es accesible.
          }
        }
      }
      final email = resolveDefaultValue(cliente, ['EML', 'email', 'mail']);

      final resultado = {
        'serie': serie,
        'direccion': direccion,
        'email': email,
        'almacen': '',
        'formaPago': formaPago,
      };
      debugPrint('[VELNEO] Defaults del cliente $clienteId → $resultado');
      return resultado;
    } catch (_) {
      return {'serie': '', 'direccion': '', 'email': '', 'almacen': '', 'formaPago': ''};
    }
  }

  static Future<List<OpcionMaestra>> getDireccionesCliente(int clienteId) async {
    if (clienteId <= 0) return [];
    try {
      final records = await _fetchAllRecords(AppConfig.endpoint('direcciones'));
      return records
          .where((r) => _referenceId(r, 'ENT') == '$clienteId')
          .map(
            (r) => OpcionMaestra(
              codigo: r.s('id').isNotEmpty ? r.s('id') : r.s('codigo'),
              nombre: r.s('DIR'),
            ),
          )
          .where((opcion) => opcion.codigo.isNotEmpty && opcion.nombre.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<Map<String, dynamic>> getEmpresaDefaults({String? contactId}) async {
    try {
      final contactIdValue = (contactId ?? '').trim();
      if (contactIdValue.isNotEmpty) {
        try {
          final contactoJson = await _api.get(
            AppConfig.endpoint('clientes'),
            params: {'filter[id]': contactIdValue, 'page[size]': 1},
          );
          final contactos = payloadLista(contactoJson);
          if (contactos.isNotEmpty) {
            final contacto = contactos.first;
            final almacenDirecto = _firstNonEmpty(contacto, ['ALM', 'alm', 'almacen', 'alm_def']);
            if (almacenDirecto.isNotEmpty) {
              return {'almacen': almacenDirecto};
            }

            final empresaId = resolveDefaultValue(contacto, ['emp', 'EMP', 'empresa', 'id_emp', 'emp_id']);
            if (empresaId.isNotEmpty) {
              final detalleEmpresa = payloadData(
                await _api.get('${AppConfig.endpoint('empresa')}/$empresaId'),
              );
              if (detalleEmpresa is Map) {
                final empresa = Map<String, dynamic>.from(detalleEmpresa);
                return {'almacen': resolveDefaultValue(empresa, ['ALM', 'alm', 'almacen', 'alm_def'])};
              }
            }
          }
        } on ApiException {
          // Se intenta con la ruta global si el contacto no expone la empresa.
        }
      }

      Map<String, dynamic>? empresa;
      try {
        final detalle = payloadData(
          await _api.get('${AppConfig.endpoint('empresa')}/1'),
        );
        if (detalle is Map) {
          empresa = Map<String, dynamic>.from(detalle);
        }
      } on ApiException {
        // Algunas instalaciones no exponen el recurso por ID.
      }

      if (empresa == null) {
        final json = await _api.get(
          AppConfig.endpoint('empresa'),
          params: {'page[size]': 1000},
        );
        final empresas = payloadLista(json)
            .where((item) => _firstNonEmpty(item, ['id', 'codigo']) == '1')
            .toList();
        if (empresas.isNotEmpty) {
          empresa = empresas.first;
        }
      }
      if (empresa == null) {
        return {'almacen': ''};
      }
      return {
        'almacen': resolveDefaultValue(empresa, ['ALM', 'alm', 'almacen', 'alm_def']),
      };
    } catch (_) {
      return {'almacen': ''};
    }
  }

  /// Carga los contactos comerciales de `ENT_M`.
  ///
  /// El filtro final por `ES_CMR` se aplica en Dart para tolerar instalaciones
  /// donde Velneo no interpreta correctamente filtros booleanos.
  static Future<List<OpcionMaestra>> getComerciales() async {
    final records = await _fetchAllRecords(AppConfig.endpoint('comerciales'));
    return records
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

  /// Página de artículos desde `ART_M`. Se usa en la sincronización diferida
  /// para ir llenando la caché local por lotes pequeños.
  static Future<List<OpcionMaestra>> getArticulosPage(int page, {int size = 500}) async {
    final json = await _api.get(
      AppConfig.endpoint('articulos'),
      params: {'page[number]': '$page', 'page[size]': '$size'},
    );
    return payloadLista(json).map(_opcionFromRecord).toList();
  }

  /// Artículo concreto por su id/código desde `ART_M` (sin descargar maestros).
  static Future<OpcionMaestra?> getArticuloById(String id) async {
    final json = await _api.get(
      AppConfig.endpoint('articulos'),
      params: {'filter[id]': id, 'page[size]': 1},
    );
    final records = payloadLista(json);
    return records.isEmpty ? null : _opcionFromRecord(records.first);
  }

  /// Carga almacenes desde `ALM_M`.
  static Future<List<OpcionMaestra>> getAlmacenes() => _maestros('almacenes');

  /// Carga formas de pago desde `FPG_M`.
  static Future<List<OpcionMaestra>> getFormasPago() => _maestros('formasPago');

  /// Carga únicamente series de venta (`ser_tip == 'V'`) desde `SER_M`.
  static Future<List<OpcionMaestra>> getSeries() async {
    final records = await _fetchAllRecords(
      AppConfig.endpoint('series'),
      pageSize: 500,
    );
    return records
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
    final records = await _fetchAllRecords(AppConfig.endpoint('clientes'));
    return records
        .where(isClienteEntity)
        .map(
          (r) => OpcionMaestra(
            codigo: r.s('id'),
            nombre: r.s('nom_com').isNotEmpty ? r.s('nom_com') : r.s('name'),
          ),
        )
        .toList();
  }

  /// Página de clientes desde `ENT_M` (solo entidades cliente). Se usa en la
  /// sincronización diferida para llenar la caché local por lotes pequeños.
  static Future<List<OpcionMaestra>> getClientesPage(int page, {int size = 500}) async {
    final json = await _api.get(
      AppConfig.endpoint('clientes'),
      params: {'page[number]': '$page', 'page[size]': '$size'},
    );
    return payloadLista(json)
        .where(isClienteEntity)
        .map(
          (r) => OpcionMaestra(
            codigo: r.s('id'),
            nombre: r.s('nom_com').isNotEmpty ? r.s('nom_com') : r.s('name'),
          ),
        )
        .toList();
  }

  /// Cliente concreto por su id desde `ENT_M` (sin descargar todo el maestro).
  static Future<OpcionMaestra?> getClienteById(String id) async {
    final json = await _api.get(
      AppConfig.endpoint('clientes'),
      params: {'filter[id]': id, 'page[size]': 1},
    );
    final records = payloadLista(json).where(isClienteEntity).toList();
    if (records.isEmpty) return null;
    return OpcionMaestra(
      codigo: records.first.s('id'),
      nombre: records.first.s('nom_com').isNotEmpty ? records.first.s('nom_com') : records.first.s('name'),
    );
  }

  /// Construye los parámetros de una petición de búsqueda de clientes contra
  /// el endpoint `clientes` (`ENT_M`). Se exponen como método estático para
  /// poder probar la consulta sin depender de una llamada HTTP real.
  ///
  /// El filtro obligatorio de VELNEO es `filter[TRO_ES_CLT]`, que recibe el
  /// texto del usuario ENVUELTO EN COMILLAS DOBLES (p. ej. '"audidat"'). Los
  /// demás filtros (`filter[nom_com]`, `search`...) los ignora/descarta el
  /// API, así que no se envían. `api_key` la añade ApiClient automáticamente.
  static Map<String, dynamic> buildClienteSearchParams(
    String texto, {
    int limit = 25,
    int page = 1,
  }) {
    final query = texto.trim();
    return {
      'page[size]': limit,
      'page[number]': page,
      'filter[TRO_ES_CLT]': '"$query"',
    };
  }

  /// Filtra en memoria una lista de registros de `ENT_M` dejando solo los que
  /// son clientes (`ES_CLT`) y cuyo nombre o código coincide con [query].
  static List<Map<String, dynamic>> filterClienteRecords(
    List<Map<String, dynamic>> records,
    String query,
  ) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    return records.where(isClienteEntity).where((record) {
      final nombre = (record.s('nom_com').isNotEmpty ? record.s('nom_com') : record.s('name'))
          .toLowerCase();
      final codigo = record.s('id').toLowerCase();
      return nombre.contains(q) || codigo.contains(q);
    }).toList();
  }

  static Future<List<OpcionMaestra>> searchClientes(String texto, {int limit = 25}) async {
    final query = texto.trim();
    if (query.isEmpty) return const [];

    try {
      final json = await _api.get(
        AppConfig.endpoint('clientes'),
        params: buildClienteSearchParams(query, limit: limit),
      );

      return filterClienteRecords(payloadLista(json), query).take(limit).map(
            (r) => OpcionMaestra(
              codigo: r.s('id'),
              nombre: r.s('nom_com').isNotEmpty ? r.s('nom_com') : r.s('name'),
            ),
          ).toList();
    } catch (_) {
      return const [];
    }
  }

  /// Busca artículos del catálogo (`ART_M`) por nombre, descripción o código.
  /// Devuelve una lista acotada de [limit] opciones; si algo falla, lista vacía.
  static Future<List<OpcionMaestra>> searchArticulos(String texto, {int limit = 25}) async {
    final query = texto.trim();
    if (query.isEmpty) return const [];

    try {
      final json = await _api.get(
        AppConfig.endpoint('articulos'),
        params: {
          'page[size]': limit,
          'page[number]': 1,
          'filter[name]': query,
          'filter[descripcion]': query,
          'filter[art]': query,
          'search': query,
          'q': query,
        },
      );

      final records = payloadLista(json).where((record) {
        final nombre = (record.s('name').isNotEmpty ? record.s('name') : record.s('descripcion'))
            .toLowerCase();
        final codigo = (record.s('art').isNotEmpty ? record.s('art') : record.s('id'))
            .toLowerCase();
        return nombre.contains(query.toLowerCase()) || codigo.contains(query.toLowerCase());
      }).take(limit).map(_opcionFromRecord).toList();

      return records;
    } catch (_) {
      return const [];
    }
  }
}