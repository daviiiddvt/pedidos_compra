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

import 'api_client.dart'; // ApiClient (el mensajero) + ApiException.
import 'config.dart';
import 'master_cache_service.dart'; // AppConfig (para saber a qué endpoint llamar).
import '../models/models.dart'; // Nuestros modelos (Pedido, OpcionMaestra).
import '../theme/app_theme.dart'; // AppColors (para traducir el estado a código VELNEO).

/// Convierte el porcentaje de IVA usado por la interfaz al código de registro
/// que espera Velneo en `reg_iva_vta`.
///
/// La correspondencia actual es: 21% o más -> `G`, 10% o más -> `R`,
/// cualquier porcentaje positivo -> `S` y 0% -> `E`.
String regIvaCodigo(double tipoIva, [String? regIva]) {
  if (regIva != null && regIva.trim().isNotEmpty) {
    return regIva.trim().toUpperCase();
  }
  return regimenIvaPorPorcentaje(tipoIva).codigo;
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
  ResultadoLista({
    required this.items,
    required this.total,
    required this.page,
  });
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

  static String resolveDefaultValue(
    Map<String, dynamic> record,
    List<String> fields,
  ) {
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

  static String _firstNonEmpty(
    Map<String, dynamic> record,
    List<String> fields,
  ) {
    return resolveDefaultValue(record, fields);
  }

  static OpcionMaestra? findMatchingOption(
    List<OpcionMaestra> options,
    String? rawValue,
  ) {
    final value = (rawValue ?? '').trim();
    if (value.isEmpty) return null;

    final normalized = value.toLowerCase();
    final intVal = int.tryParse(value);
    for (final option in options) {
      final code = option.codigo.trim();
      final name = option.nombre.trim();
      if (code.isNotEmpty && code.toLowerCase() == normalized) return option;
      if (name.isNotEmpty && name.toLowerCase() == normalized) return option;
      if (intVal != null && int.tryParse(code) == intVal) return option;
      if (code.isNotEmpty && code.toLowerCase().contains(normalized)) {
        return option;
      }
      if (name.isNotEmpty && name.toLowerCase().contains(normalized)) {
        return option;
      }
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
    final art = record.s('art').isNotEmpty ? record.s('art') : record.s('ART');
    return OpcionMaestra(
      // Para ART_M el código real es 'art'; en clientes (ENT_M) no existe y
      // caemos al id. Así el código que se guarda en la línea coincide con el
      // valor 'art' que espera Velneo en el POST de líneas.
      codigo: art.isNotEmpty
          ? art
          : (_referenceId(record, 'id').isNotEmpty
                ? _referenceId(record, 'id')
                : record.s('codigo')),
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
      params: {'filter[${AppConfig.usuarioField}]': username, 'page[size]': 10},
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

    final userId = user.s('id').trim();
    debugPrint('[AUTH] Usuario autenticado en USR_M: id=$userId, name=${user.s('name')}');
    final isAdmin = await isAdministrator(userId);
    final contactId = _referenceId(user, AppConfig.usuarioContactoField);
    debugPrint(
      '[AUTH] Resultado administrador: userId=$userId, '
      'contactId=${contactId.isEmpty ? '(vacío)' : contactId}, isAdmin=$isAdmin',
    );

    if (isAdmin) {
      debugPrint('[AUTH] Rol final: Administrador');
      return User(
        id: userId,
        name: user.s('name').isEmpty ? username : user.s('name'),
        role: 'Administrador',
        contactId: contactId,
      );
    }

    if (contactId.isEmpty) {
      throw ApiException('El usuario no tiene un contacto asociado.');
    }
    final contact = await _getContact(contactId);
    if (!contact.b(AppConfig.contactoComercialField)) {
      throw ApiException(
        'El contacto asociado no está marcado como comercial.',
      );
    }

    debugPrint('[AUTH] Rol final: Comercial');
    return User(
      id: userId,
      name: user.s('name').isEmpty ? username : user.s('name'),
      role: 'Comercial',
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

  static Future<bool> isAdministrator(String userId) async {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) {
      debugPrint('[AUTH] USR_M vacío: no se puede validar administrador.');
      return false;
    }
    debugPrint(
      '[AUTH] Consultando USR_GRP_USR_M: '
      'filter[usr_usr_grp]=$normalizedUserId,1',
    );
    final json = await _api.get(
      AppConfig.endpoint('gruposUsuarios'),
      params: {
        'filter[usr_usr_grp]': '$normalizedUserId,1',
        'page[size]': 1,
      },
    );
    final matches = payloadLista(json);
    final countFromApi = payloadTotal(json);
    final count = countFromApi == 0 ? matches.length : countFromApi;
    debugPrint(
      '[AUTH] USR_GRP_USR_M count=$count '
      '(items=${matches.length}); isAdmin=${count == 1}',
    );
    return count == 1;
  }

  static Future<bool> esContactoComercial(String contactId) async {
    if (contactId.trim().isEmpty) return false;
    final contact = await _getContact(contactId.trim());
    return contact.b(AppConfig.contactoComercialField);
  }

  static Future<String> getContactName(String id) => _getContactName(id);

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
        .where(
          (linea) => linea.articuloNombre.isEmpty && linea.articulo.isNotEmpty,
        )
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
    final items = payloadLista(json).map(Pedido.fromJson).toList();

    // En VTA_PED_G, "count" puede ser el número de registros de esta página,
    // no el total global. Si coincide con una página completa, dejamos el total
    // como desconocido para que la pantalla solicite la página siguiente.
    final reportedTotal = payloadTotal(json);
    final total = reportedTotal == items.length &&
        items.length >= AppConfig.pageSize
      ? 0
      : reportedTotal;
    debugPrint(
      '[PEDIDOS] página=$page, recibidos=${items.length}, '
      'total=${total == 0 ? "no informado" : total}',
    );

    return ResultadoLista<Pedido>(items: items, total: total, page: page);
  }

  /// Descarga todas las cabeceras de pedido por páginas.
  ///
  /// Repite peticiones a [list] hasta alcanzar el total informado o recibir
  /// una página incompleta/vacía. Cada petición contiene un `await`, por lo
  /// que el event loop de Flutter conserva el control mientras se descarga.
  static Future<List<Pedido>> listAll({
    String? comercial,
    bool porZona = false,
  }) async {
    final all = <Pedido>[];

    if (porZona && comercial != null && comercial.isNotEmpty) {
      debugPrint('\n=== MODO ZONA TÉCNICA INICIADO ===');
      debugPrint('Comercial ID: $comercial');

      // 1. Zonas del comercial
      final znJson = await _api.get(
        AppConfig.endpoint('zonasComerciales'),
        params: {'filter[cmr]': comercial, 'page[size]': 1000},
      );
      final znList = payloadLista(znJson);
      final znIds = znList
          .map((r) => r['ZN_TCN'] ?? r['zn_tcn'])
          .where((x) => x != null && x != 0)
          .map((x) => x.toString())
          .toSet();

      debugPrint('Zonas técnicas encontradas para el comercial: $znIds');

      if (znIds.isEmpty) {
        debugPrint(
          'El comercial no tiene zonas técnicas asignadas. Abortando.',
        );
        return [];
      }

      // 2. PRIMERO COGER LOS CLIENTES Y SACAR SU DIR_PRI_ID
      debugPrint('Descargando todos los clientes...');
      final allClients = <Cliente>[];
      var page = 1;
      while (true) {
        final cliJson = await _api.get(
          AppConfig.endpoint('clientes'),
          params: {'page[size]': 1000, 'page[number]': page},
        );
        final items = payloadLista(cliJson);
        for (var c in items) {
          allClients.add(Cliente.fromJson(c));
        }
        if (items.length < 1000) break;
        page++;
      }
      debugPrint('Total de clientes obtenidos: ${allClients.length}');

      // 3. DESPUES CARGAR LA DIRECCION EN LA TABLA DIR_M
      debugPrint('Descargando direcciones (DIR_M)...');
      final dirPobMap = <int, String>{}; // DIR_PRI_ID -> POB_EXT
      page = 1;
      while (true) {
        final dJson = await _api.get(
          AppConfig.endpoint('direcciones'),
          params: {'page[size]': 1000, 'page[number]': page},
        );
        final items = payloadLista(dJson);
        for (var d in items) {
          final dId = d['ID'] ?? d['id'];
          final pobExt =
              d['POB_EXT']?.toString() ?? d['pob_ext']?.toString() ?? '';
          if (dId != null) dirPobMap[dId] = pobExt;
        }
        if (items.length < 1000) break;
        page++;
      }
      debugPrint('Total de direcciones cargadas: ${dirPobMap.length}');

      // 4. SACAR LA POBLACION Y SU ZONA TECNICA
      debugPrint('Descargando poblaciones y zonas técnicas (POB)...');
      final pobZnMap = <String, String>{}; // POB_ID -> ZN_TCN
      page = 1;
      while (true) {
        final pJson = await _api.get(
          'TecERPv7_dat_dat/v1/POB',
          params: {'page[size]': 1000, 'page[number]': page},
        );
        final items = payloadLista(pJson);
        for (var p in items) {
          final pId = p['ID']?.toString() ?? p['id']?.toString() ?? '';
          final znTcn =
              p['ZN_TCN']?.toString() ?? p['zn_tcn']?.toString() ?? '';
          pobZnMap[pId] = znTcn;
        }
        if (items.length < 1000) break;
        page++;
      }
      debugPrint('Total de poblaciones cargadas: ${pobZnMap.length}');

      // 5. SI ALGUNA DE ELLAS COINCIDE CON LAS ZONAS TECNICAS DEL COMERCIAL
      final matchingClientIds = <int>{};
      for (final c in allClients) {
        final pobId = dirPobMap[c.dirPriId] ?? '';
        final znTcn = pobZnMap[pobId] ?? '';
        if (znIds.contains(znTcn)) {
          matchingClientIds.add(c.id);
        }
      }
      debugPrint(
        'Clientes con zona técnica coincidente: ${matchingClientIds.length}',
      );

      if (matchingClientIds.isEmpty) {
        debugPrint('No hay clientes en estas zonas. Abortando.');
        return [];
      }

      // 6. ENTONCES CARGAS LOS PEDIDOS DE VENTA DE LOS CLIENTES COINCIDENTES
      debugPrint('Cargando pedidos de venta de clientes coincidentes...');
      // Descargamos globales y filtramos en memoria por rendimiento de la API
      page = 1;
      while (true) {
        final result = await list(page: page);
        for (final p in result.items) {
          if (matchingClientIds.contains(p.clienteId)) {
            all.add(p);
          }
        }
        if (result.items.length < AppConfig.pageSize) break;
        page++;
      }

      debugPrint(
        'Total de pedidos de la zona técnica encontrados: ${all.length}',
      );
      debugPrint('=== FIN MODO ZONA TÉCNICA ===\n');
      return all;
    }

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
    final clienteFuture = getClientesByIds([pedido.clienteId])
        .catchError((_) => <Cliente>[]);
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

      final cache = MasterCacheService();
      final cachedSeries = cache.getSync<List<OpcionMaestra>>('series');
      final cachedFpg = cache.getSync<List<OpcionMaestra>>('formas_pago');
      final cachedAlm = cache.getSync<List<OpcionMaestra>>('almacenes');
      final s = findMatchingOption(cachedSeries ?? [], pedido.serie);
      final f = findMatchingOption(cachedFpg ?? [], pedido.formaPago);
      final a = findMatchingOption(cachedAlm ?? [], pedido.almacen);

      return pedido.copyWith(
        serieNombre: s?.nombre ?? pedido.serieNombre,
        formaPagoNombre: f?.nombre ?? pedido.formaPagoNombre,
        almacenNombre: a?.nombre ?? pedido.almacenNombre,
        lineas: enrichedLineas,
      );
    } on ApiException {
      final cache = MasterCacheService();
      final cachedSeries = cache.getSync<List<OpcionMaestra>>('series');
      final cachedFpg = cache.getSync<List<OpcionMaestra>>('formas_pago');
      final cachedAlm = cache.getSync<List<OpcionMaestra>>('almacenes');
      final s = findMatchingOption(cachedSeries ?? [], pedido.serie);
      final f = findMatchingOption(cachedFpg ?? [], pedido.formaPago);
      final a = findMatchingOption(cachedAlm ?? [], pedido.almacen);

      return pedido.copyWith(
        serieNombre: s?.nombre ?? pedido.serieNombre,
        formaPagoNombre: f?.nombre ?? pedido.formaPagoNombre,
        almacenNombre: a?.nombre ?? pedido.almacenNombre,
      );
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
      return Pedido.fromJson(
        Map<String, dynamic>.from(data),
      ); // El pedido creado.
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
      'emp': '1',
      'emp_div': '1',
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

  static Future<String> _ensureDireccionId(int clienteId, String dirEnv) async {
    if (dirEnv.isEmpty) return dirEnv;
    // Si contiene letras (no es puramente numérico), es muy probable que sea un texto
    if (int.tryParse(dirEnv.trim()) != null) return dirEnv;

    try {
      final direcciones = await getDireccionesCliente(clienteId);
      for (final d in direcciones) {
        if (d.nombre.trim().toLowerCase() == dirEnv.trim().toLowerCase()) {
          return d.codigo;
        }
      }
    } catch (_) {}
    return dirEnv;
  }

  static Future<Pedido> createComplete(Pedido pedido) async {
    late final Pedido created;
    try {
      final dirId = await _ensureDireccionId(
        pedido.clienteId,
        pedido.direccionEnvio,
      );
      final pedidoMapeado = pedido.copyWith(direccionEnvio: dirId);
      created = await create(_pedidoPayload(pedidoMapeado));
    } on ApiException catch (error) {
      throw ApiException('No se pudo crear la cabecera del pedido: $error');
    }
    final pedidoId =
        created.id ?? (created.codigo == 0 ? null : created.codigo);
    if (pedidoId == null) {
      throw ApiException('Velneo no devolvió el ID del pedido creado.');
    }
    try {
      await enviarLineas(pedidoId, pedido.lineas);
    } on ApiException catch (error) {
      throw ApiException('Cabecera creada, pero fallaron las líneas: $error');
    }
    return created.copyWith(id: pedidoId, lineas: pedido.lineas);
  }

  static Future<Pedido> updateComplete(
    dynamic id,
    Pedido pedido,
    Set<int> removedLineIds,
  ) async {
    final dirId = await _ensureDireccionId(
      pedido.clienteId,
      pedido.direccionEnvio,
    );
    final pedidoMapeado = pedido.copyWith(direccionEnvio: dirId);
    final updated = await update(id, _pedidoPayload(pedidoMapeado));
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
      return Pedido.fromJson(
        Map<String, dynamic>.from(data),
      ); // El pedido actualizado.
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
  /// Ejecuta el proceso de Velneo ACT_VTA_PED_LIN_G_APP.pro para una línea.
  /// Método GET con parámetros: ID, ART, CAN, PRE, EST, REG_IVA_VTA.
  static Future<void> ejecutarProcesoActualizarLinea({
    required dynamic id,
    required dynamic articulo,
    required num cantidad,
    required num precio,
    required String estado,
    required String regIvaVta,
  }) async {
    final params = <String, dynamic>{
      'VTA_PED_LIN_G': id,
      'ART': articulo,
      'CAN': cantidad,
      'PRE': precio,
      'EST': estado,
      'REG_IVA': regIvaVta,
    };
    debugPrint('Ejecutando proceso ACT_VTA_PED_LIN_G_APP.pro: $params');
    await _api.get(
      AppConfig.endpoint('procesoActualizarLinea'),
      params: params,
    );
  }

  static Future<void> enviarEmailPedido(dynamic pedidoId) async {
    if (pedidoId == null) {
      throw ApiException('El pedido no tiene un identificador válido.');
    }
    await _api.get(
      AppConfig.endpoint('procesoEnviarEmailPedido'),
      params: {'VTA_PED_G': pedidoId},
    );
  }

  /// Crea o actualiza las líneas de un pedido en `VTA_PED_LIN_G` y llama
  /// al proceso de Velneo `ACT_VTA_PED_LIN_G_APP.pro`.
  static Future<void> enviarLineas(
    dynamic pedidoId,
    List<LineaPedido> lineas,
  ) async {
    for (final linea in lineas) {
      final body = <String, dynamic>{
        'vta_ped': pedidoId,
        'art': linea.articulo,
        'dsc': linea.descripcion,
        'ref_man': linea.nReferencia,
        'can_ped': linea.cantidad,
        'can_srv': linea.cantidadServida,
        'pre': linea.precio,
        'por_dto': linea.dto,
        'imp': linea.importe,
        'reg_iva_vta': regIvaCodigo(linea.tipoIva, linea.regIvaVta),
        'fch_ent': linea.previstoPara,
        'est': AppColors.estadoCodigo(linea.estado),
        'cnc': linea.cancelado,
      };
      try {
        int? lineaId = linea.id;
        if (lineaId == null) {
          final res = await _api.post(AppConfig.endpoint('lineas'), body: body);
          final data = payloadData(res);
          if (data is Map) {
            final idVal = data['id'] ?? data['ID'];
            if (idVal != null) {
              lineaId = int.tryParse(idVal.toString());
            }
          } else if (res is Map) {
            final idVal = res['id'] ?? res['ID'];
            if (idVal != null) {
              lineaId = int.tryParse(idVal.toString());
            }
          }
          if (lineaId == null) {
            final linesRes = await _api.get(
              AppConfig.endpoint('lineas'),
              params: {
                'filter[vta_ped]': '$pedidoId',
                'sort': '-id',
                'page[size]': 1,
              },
            );
            final items = payloadLista(linesRes);
            if (items.isNotEmpty) {
              final idVal = items.first['id'] ?? items.first['ID'];
              if (idVal != null) {
                lineaId = int.tryParse(idVal.toString());
              }
            }
          }
        } else {
          await _api.post(
            '${AppConfig.endpoint('lineas')}/$lineaId',
            body: body,
          );
        }

        if (lineaId != null && lineaId > 0) {
          final artVal = int.tryParse(linea.articulo) ?? linea.articulo;
          final canVal = (linea.cantidad % 1 == 0)
              ? linea.cantidad.toInt()
              : linea.cantidad;
          final preVal = (linea.precio % 1 == 0)
              ? linea.precio.toInt()
              : linea.precio;
          final estVal = AppColors.estadoCodigo(linea.estado);
          final ivaVal = regIvaCodigo(linea.tipoIva, linea.regIvaVta);

          await ejecutarProcesoActualizarLinea(
            id: lineaId,
            articulo: artVal,
            cantidad: canVal,
            precio: preVal,
            estado: estVal,
            regIvaVta: ivaVal,
          );
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
  static Future<List<OpcionMaestra>> _maestros(
    String key, {
    int size = 1000,
  }) async {
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
            nombreComercial: record.s('nom_com').isNotEmpty
                ? record.s('nom_com')
                : record.s('name'),
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
      return {
        'serie': '',
        'direccion': '',
        'email': '',
        'almacen': '',
        'formaPago': '',
      };
    }

    try {
      final clienteJson = await _api.get(
        AppConfig.endpoint('clientes'),
        params: {'filter[id]': '$clienteId', 'page[size]': 1},
      );
      final clientes = payloadLista(clienteJson);
      debugPrint('🛑🛑🛑 JSON DEL SERVIDOR VELNEO: $clientes');
      if (clientes.isEmpty) {
        return {
          'serie': '',
          'direccion': '',
          'email': '',
          'almacen': '',
          'formaPago': '',
        };
      }
      final cliente = clientes.first;

      // ── DEPURACIÓN: mostrar el JSON exacto que devuelve VELNEO ────────
      // Para que puedas ver TODAS las claves que manda la API al elegir un
      // cliente y decidir con cuáles mapear serie/formaPago/almacén.
      debugPrint(
        '\n━━━ [VELNEO] Cliente $clienteId → JSON completo (${cliente.keys.length} claves) ━━━',
      );
      for (final entry in cliente.entries) {
        debugPrint('  ${entry.key}: ${entry.value}');
      }
      debugPrint('━━━ /FIN JSON cliente $clienteId ━━━');

      final serie = resolveDefaultValue(cliente, [
        'ser_vta',
        'SER_VTA',
        'serie',
        'ser',
      ]);
      final formaPago = resolveDefaultValue(cliente, [
        'fpg_clt',
        'fpg',
        'FPG',
        'forma_pago',
        'formaPago',
        'fpg_def',
      ]);
      var direccionId = resolveDefaultValue(cliente, [
        'dir',
        'DIR_M_VTA_PED_ENV',
        'dir_env_clt',
        'dir_env',
        'direccion_envio',
        'dir_env_def',
      ]);

      if (direccionId.isEmpty) {
        direccionId = _referenceId(cliente, 'DIR_PRI').isNotEmpty
            ? _referenceId(cliente, 'DIR_PRI')
            : _referenceId(cliente, 'DIR_PRI.ID');
      }

      final email = resolveDefaultValue(cliente, [
        'eml',
        'EML',
        'email',
        'mail',
      ]);

      final resultado = {
        'serie': serie,
        'direccion': direccionId,
        'email': email,
        'almacen': '',
        'formaPago': formaPago,
        'tarifa': resolveDefaultValue(cliente, [
          '#VTA_TAR',
          'VTA_TAR',
          'vta_tar',
          'VTA_TAR.ID',
          'tarifa',
        ]),
      };
      debugPrint('[VELNEO] Defaults del cliente $clienteId → $resultado');
      return resultado;
    } catch (_) {
      return {
        'serie': '',
        'direccion': '',
        'email': '',
        'almacen': '',
        'formaPago': '',
      };
    }
  }

  static Future<List<OpcionMaestra>> getDireccionesCliente(
    int clienteId,
  ) async {
    if (clienteId <= 0) return [];
    try {
      final json = await _api.get(
        AppConfig.endpoint('direcciones'),
        params: {
          'page[size]': 100,
          'page[number]': 1,
          "filter['ENT']": '$clienteId',
        },
      );
      return payloadLista(json)
          .map(
            (r) => OpcionMaestra(
              codigo: r.s('id').isNotEmpty ? r.s('id') : r.s('codigo'),
              nombre: r.s('DIR_COM').isNotEmpty
                  ? r.s('DIR_COM')
                  : (r.s('dir_com').isNotEmpty ? r.s('dir_com') : r.s('DIR')),
            ),
          )
          .where((opcion) => opcion.codigo.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Crea un nuevo cliente en ENT_M
  static Future<Cliente> crearCliente({
    required String nombre,
    String? cif,
    String? telefono,
    String? email,
  }) async {
    final payload = {
      'name': nombre.toUpperCase(),
      'nom_com': nombre.toUpperCase(),
      'es_clt': 1,
      'emp': '1', // Empresa habitual
      'emp_div': '1', // División habitual
      if (cif != null && cif.isNotEmpty) 'cif': cif.toUpperCase(),
      if (telefono != null && telefono.isNotEmpty) 'tlf': telefono,
      if (email != null && email.isNotEmpty) 'eml': email,
    };

    final json = await _api.post(AppConfig.endpoint('clientes'), body: payload);
    final data = payloadData(json);

    if (data is Map) {
      return Cliente.fromJson(Map<String, dynamic>.from(data));
    }
    throw ApiException(
      'El servidor no devolvió los datos del cliente tras su creación.',
    );
  }

  static Future<Map<String, dynamic>> getEmpresaDefaults({
    String? contactId,
  }) async {
    try {
      final contactIdValue = (contactId ?? '').trim();
      Map<String, dynamic>? empresaEncontrada;
      String almacenDirecto = '';

      if (contactIdValue.isNotEmpty) {
        try {
          final contactoJson = await _api.get(
            AppConfig.endpoint('clientes'),
            params: {'filter[id]': contactIdValue, 'page[size]': 1},
          );
          final contactos = payloadLista(contactoJson);
          if (contactos.isNotEmpty) {
            final contacto = contactos.first;
            almacenDirecto = _firstNonEmpty(contacto, [
              'ALM',
              'alm',
              'almacen',
              'alm_def',
            ]);

            final empresaId = resolveDefaultValue(contacto, [
              'emp',
              'EMP',
              'empresa',
              'id_emp',
              'emp_id',
            ]);
            if (empresaId.isNotEmpty) {
              final detalleEmpresa = payloadData(
                await _api.get('${AppConfig.endpoint('empresa')}/$empresaId'),
              );
              if (detalleEmpresa is Map) {
                empresaEncontrada = Map<String, dynamic>.from(detalleEmpresa);
              }
            }
          }
        } on ApiException {
          // Se intenta con la ruta global si el contacto no expone la empresa.
        }
      }

      if (empresaEncontrada == null) {
        try {
          final detalle = payloadData(
            await _api.get('${AppConfig.endpoint('empresa')}/1'),
          );
          if (detalle is Map) {
            empresaEncontrada = Map<String, dynamic>.from(detalle);
          }
        } on ApiException {
          try {
            final lista = payloadLista(
              await _api.get(AppConfig.endpoint('empresa')),
            );
            if (lista.isNotEmpty) {
              empresaEncontrada = lista.first;
            }
          } on ApiException {
            // Fallback silencioso si no se encuentra detalle de empresa
          }
        }
      }

      final almacenFinal = almacenDirecto.isNotEmpty
          ? almacenDirecto
          : (empresaEncontrada != null
                ? resolveDefaultValue(empresaEncontrada, [
                    'ALM',
                    'alm',
                    'almacen',
                    'alm_def',
                  ])
                : '');

      final preValDia = empresaEncontrada != null
          ? resolveDefaultValue(empresaEncontrada, [
              'PRE_VAL_DIA',
              'pre_val_dia',
            ])
          : '';

      debugPrint('============================================');
      debugPrint(
        '[getEmpresaDefaults] Valor bruto de PRE_VAL_DIA extraído: "$preValDia"',
      );
      if (empresaEncontrada != null) {
        debugPrint('[getEmpresaDefaults] Todo el JSON de la empresa:');
        for (final entry in empresaEncontrada.entries) {
          debugPrint('  ${entry.key}: ${entry.value}');
        }
      }
      debugPrint('============================================');

      return {'almacen': almacenFinal, 'preValDia': preValDia};
    } catch (_) {
      return {'almacen': '', 'preValDia': ''};
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
  static Future<List<OpcionMaestra>> getArticulosPage(
    int page, {
    int size = 500,
  }) async {
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
  static Future<List<OpcionMaestra>> getClientesPage(
    int page, {
    int size = 500,
  }) async {
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
      nombre: records.first.s('nom_com').isNotEmpty
          ? records.first.s('nom_com')
          : records.first.s('name'),
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
      final nombre =
          (record.s('nom_com').isNotEmpty
                  ? record.s('nom_com')
                  : record.s('name'))
              .toLowerCase();
      final codigo = record.s('id').toLowerCase();
      return nombre.contains(q) || codigo.contains(q);
    }).toList();
  }

  static Future<List<OpcionMaestra>> searchClientes(
    String texto, {
    int limit = 25,
  }) async {
    final query = texto.trim();
    if (query.isEmpty) return const [];

    try {
      final params = buildClienteSearchParams(query, limit: limit);
      debugPrint(
        '🔧 searchClientes → ${AppConfig.endpoint('clientes')} $params',
      );
      final json = await _api.get(
        AppConfig.endpoint('clientes'),
        params: params,
      );

      final resultado = filterClienteRecords(payloadLista(json), query)
          .take(limit)
          .map(
            (r) => OpcionMaestra(
              codigo: r.s('id'),
              nombre: r.s('nom_com').isNotEmpty ? r.s('nom_com') : r.s('name'),
            ),
          )
          .toList();
      debugPrint('🔧 searchClientes("$query") → ${resultado.length} clientes.');
      return resultado;
    } catch (e) {
      debugPrint('💥💥 searchClientes("$query") LLANZÓ ERROR: $e');
      return const [];
    }
  }

  /// Traduce el código de IVA Velneo (G/R/S/E) a su porcentaje, igual que la
  /// interfaz. Si el campo ya llega como número (21.0), lo devuelve tal cual.
  static double _ivaPorcentaje(String value) {
    switch (value.trim().toUpperCase()) {
      case 'G':
        return 21.0;
      case 'R':
        return 10.0;
      case 'S':
        return 4.0;
      case 'E':
        return 0.0;
      default:
        return double.tryParse(value) ?? 0.0;
    }
  }

  /// Obtiene los datos por defecto de un artículo (`ART_M`) para rellenar la
  /// línea: descripción, nombre, precio de tarifa e IVA.
  ///
  /// Devuelve un mapa con 'codigo', 'nombre', 'descripcion', 'precio' y
  /// 'tipoIva' (porcentaje). Si algo falla o no hay resultado, claves vacías.
  static Future<Map<String, dynamic>> getArticuloDefaults(
    String articuloCodigo,
  ) async {
    final vacio = {
      'codigo': '',
      'nombre': '',
      'descripcion': '',
      'precio': '',
      'tipoIva': '',
    };
    final codigo = articuloCodigo.trim();
    if (codigo.isEmpty) return vacio;

    try {
      // El código del artículo puede vivir en distinto campo según la
      // instalación (ART_M cambia entre versiones): probamos los filtros más
      // habituales hasta encontrar el registro. El que responda queda en el log.
      Map<String, dynamic> articulo = const {};
      String filtroUsado = '';
      for (final filtro in ['id', 'art', 'codigo']) {
        final json = await _api.get(
          AppConfig.endpoint('articulos'),
          params: {'filter[$filtro]': codigo, 'page[size]': 1},
        );
        final lista = payloadLista(json);
        debugPrint(
          '🛑🛑🛑 JSON DEL SERVIDOR (ARTICULO) filter[$filtro]=$codigo → $lista',
        );
        if (lista.isNotEmpty) {
          articulo = lista.first;
          filtroUsado = filtro;
          break;
        }
      }
      if (articulo.isEmpty) {
        debugPrint(
          '💥💥 getArticuloDefaults("$codigo") → SIN RESULTADO en ningún filtro.',
        );
        return vacio;
      }
      debugPrint(
        '🔧 getArticuloDefaults("$codigo") → encontrado con filter[$filtroUsado].',
      );

      final nombre = resolveDefaultValue(articulo, [
        'name',
        'ART_NOM',
        'art_nom',
        'descripcion',
      ]);
      final descripcion = resolveDefaultValue(articulo, [
        'dsc',
        'descripcion',
        'name',
      ]);
      final precio = resolveDefaultValue(articulo, [
        'pre',
        'PVP',
        'pvp',
        'precio',
      ]);
      final tipoIva = _ivaPorcentaje(
        resolveDefaultValue(articulo, [
          'por_iva',
          'tipo_iva',
          'reg_iva_vta',
          'iva',
          'IVA',
        ]),
      );

      final resultado = {
        'codigo': codigo,
        'nombre': nombre,
        'descripcion': descripcion,
        'precio': precio,
        'tipoIva': '$tipoIva',
      };
      debugPrint('[VELNEO] Defaults del artículo $codigo → $resultado');
      return resultado;
    } catch (e) {
      debugPrint('💥💥 getArticuloDefaults("$codigo") LLANZÓ ERROR: $e');
      return vacio;
    }
  }

  /// Obtiene los datos de línea aplicando las tarifas de venta de Velneo.
  ///
  /// La prioridad es: tarifa específica cliente/artículo, tarifa del cliente
  /// para el artículo y, por último, el PVP de ART_M con descuento cero.
  static Future<Map<String, dynamic>> getArticuloDefaultsParaCliente(
    String articuloCodigo, {
    int clienteId = 0,
  }) async {
    final codigo = articuloCodigo.trim();
    if (codigo.isEmpty) return getArticuloDefaults(codigo);

    if (clienteId > 0) {
      final tarifaCliente = await _buscarTarifa(
        endpointKey: 'tarifasCliente',
        filtro: 'clt_art',
        valor: '$clienteId,$codigo',
      );
      if (tarifaCliente != null) {
        return _aplicarTarifa(
          await getArticuloDefaults(codigo),
          tarifaCliente,
          origen: 'cliente',
        );
      }

      try {
        final clienteDefaults = await getClienteDefaults(clienteId);
        final tarifaId = (clienteDefaults['tarifa'] ?? '').toString().trim();
        if (tarifaId.isNotEmpty) {
          final tarifaArticulo = await _buscarTarifa(
            endpointKey: 'tarifasArticulo',
            filtro: 'tar_art',
            valor: '$tarifaId,$codigo',
          );
          if (tarifaArticulo != null) {
            return _aplicarTarifa(
              await getArticuloDefaults(codigo),
              tarifaArticulo,
              origen: 'tarifa $tarifaId',
            );
          }
        }
      } catch (e) {
        debugPrint('⚠️ No se pudo resolver la tarifa del cliente $clienteId: $e');
      }
    }

    final articulo = await getArticuloDefaults(codigo);
    return {...articulo, 'dto': '0'};
  }

  static Future<Map<String, dynamic>?> _buscarTarifa({
    required String endpointKey,
    required String filtro,
    required String valor,
  }) async {
    try {
      final json = await _api.get(
        AppConfig.endpoint(endpointKey),
        params: {'filter[$filtro]': valor, 'page[size]': 1},
      );
      final registros = payloadLista(json);
      if (registros.isEmpty) return null;
      return registros.first;
    } catch (e) {
      debugPrint('⚠️ Error consultando $endpointKey ($valor): $e');
      return null;
    }
  }

  static Map<String, dynamic> _aplicarTarifa(
    Map<String, dynamic> defaults,
    Map<String, dynamic> tarifa, {
    required String origen,
  }) {
    final precio = resolveDefaultValue(tarifa, ['PRE', 'pre', 'precio']);
    final dto = resolveDefaultValue(tarifa, ['POR_DTO', 'por_dto', 'dto']);
    debugPrint('💶 Tarifa $origen aplicada → precio=$precio, dto=$dto');
    return {
      ...defaults,
      if (precio.isNotEmpty) 'precio': precio,
      'dto': dto.isNotEmpty ? dto : '0',
    };
  }

  /// Busca artículos del catálogo (`ART_M`) por nombre, descripción o código.
  /// Devuelve una lista acotada de [limit] opciones; si algo falla, lista vacía.
  static Future<List<OpcionMaestra>> searchArticulos(
    String texto, {
    int limit = 25,
  }) async {
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

      final records = payloadLista(json)
          .where((record) {
            final nombre =
                (record.s('name').isNotEmpty
                        ? record.s('name')
                        : record.s('descripcion'))
                    .toLowerCase();
            final codigo =
                (record.s('art').isNotEmpty ? record.s('art') : record.s('id'))
                    .toLowerCase();
            return nombre.contains(query.toLowerCase()) ||
                codigo.contains(query.toLowerCase());
          })
          .take(limit)
          .map(_opcionFromRecord)
          .toList();

      return records;
    } catch (_) {
      return const [];
    }
  }
}
