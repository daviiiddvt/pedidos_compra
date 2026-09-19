import 'core/api_client.dart';
import 'core/config.dart';
import 'models.dart';
import 'theme/app_theme.dart';
import 'api_service.dart';

/// API operations for sales budgets. Budgets use the same document models and
/// line payloads as orders, but are stored in their own Velneo tables.
class PresupuestosService {
  static final _api = ApiClient.instance;

  static Future<ResultadoLista<Pedido>> list({
    int page = 1,
    String? estado,
    String? cliente,
    String? search,
    String? comercial,
  }) async {
    final params = <String, dynamic>{
      'page[number]': page,
      'page[size]': AppConfig.pageSize,
      'sort': '-fch',
      if (estado != null && estado.isNotEmpty)
        'filter[est]': AppColors.estadoCodigo(estado),
      if (cliente != null && cliente.isNotEmpty) 'filter[clt]': cliente,
      if (search != null && search.isNotEmpty) 'filter[words]': search,
      if (comercial != null && comercial.isNotEmpty) 'filter[cmr]': comercial,
    };
    final json = await _api.get(
      AppConfig.endpoint('presupuestos'),
      params: params,
    );
    final items = payloadLista(json).map(Pedido.fromJson).toList();
    final total = payloadTotal(json) != 0 ? payloadTotal(json) : items.length;
    return ResultadoLista<Pedido>(items: items, total: total, page: page);
  }

  static Future<List<Pedido>> listAll({String? comercial}) async {
    final all = <Pedido>[];
    var page = 1;
    var total = 0;
    do {
      final result = await list(page: page, comercial: comercial);
      all.addAll(result.items);
      total = result.total;
      page++;
      if (result.items.isEmpty ||
          (total > 0 && all.length >= total) ||
          result.items.length < AppConfig.pageSize) {
        break;
      }
    } while (true);
    return all;
  }

  static Future<Pedido> getById(dynamic id) async {
    final json = await _api.get('${AppConfig.endpoint('presupuestos')}/$id');
    final data = payloadData(json);
    if (data is! Map) throw ApiException('No se pudo leer el presupuesto.');
    var presupuesto = Pedido.fromJson(Map<String, dynamic>.from(data));
    final lineasJson = await _api.get(
      AppConfig.endpoint('lineasPresupuesto'),
      params: {'filter[vta_pre]': '$id', 'page[size]': 100},
    );
    final lineas = payloadLista(lineasJson).map(LineaPedido.fromJson).toList();
    final clientes = await PedidosService.getClientesByIds(
      [presupuesto.clienteId],
    );
    if (clientes.isNotEmpty) {
      final cliente = clientes.first;
      presupuesto = presupuesto.copyWith(
        clienteNombre: cliente.nombreComercial,
        clienteTelefono: cliente.telefono,
        clienteCif: cliente.cif,
      );
    }
    return presupuesto.copyWith(lineas: lineas);
  }

  static Map<String, dynamic> _payload(Pedido pedido) => {
        'clt': pedido.clienteId,
        'est': AppColors.estadoCodigo(pedido.estado),
        'ser': pedido.serie,
        'cmr': pedido.comercial,
        'alm': pedido.almacen,
        'fch': pedido.fecha,
        'fch_ent': pedido.previstoPara,
        'fpg': pedido.formaPago,
        'dir_env': pedido.direccionEnvio,
        'email': pedido.email,
        'obs': pedido.observaciones,
        'emp': 1,
        'emp_div': 1,
      };

  static Future<Pedido> createComplete(Pedido pedido) async {
    final json = await _api.post(
      AppConfig.endpoint('presupuestos'),
      body: _payload(pedido),
    );
    final data = payloadData(json);
    if (data is! Map) throw ApiException('No se pudo crear el presupuesto.');
    final created = Pedido.fromJson(Map<String, dynamic>.from(data));
    final id = created.id ?? (created.codigo == 0 ? null : created.codigo);
    if (id == null) {
      throw ApiException('Velneo no devolvió el ID del presupuesto creado.');
    }
    await enviarLineas(id, pedido.lineas);
    return created.copyWith(id: id, lineas: pedido.lineas);
  }

  static Future<Pedido> updateComplete(
    dynamic id,
    Pedido pedido,
    Set<int> removedLineIds,
  ) async {
    final json = await _api.post(
      '${AppConfig.endpoint('presupuestos')}/$id',
      body: _payload(pedido),
    );
    final data = payloadData(json);
    if (data is! Map) throw ApiException('No se pudo actualizar el presupuesto.');
    for (final lineId in removedLineIds) {
      await eliminarLinea(lineId);
    }
    await enviarLineas(id, pedido.lineas);
    return Pedido.fromJson(Map<String, dynamic>.from(data)).copyWith(
      id: id is int ? id : pedido.id,
      lineas: pedido.lineas,
    );
  }

  static Future<void> enviarLineas(
    dynamic presupuestoId,
    List<LineaPedido> lineas,
  ) async {
    for (final linea in lineas) {
      final body = <String, dynamic>{
        'vta_pre': presupuestoId,
        'art': linea.articulo,
        'dsc': linea.descripcion,
        'ref_man': linea.nReferencia,
        'can_ped': linea.cantidad,
        'can_srv': linea.cantidadServida,
        'can_pte': linea.pendiente,
        'pre': linea.precio,
        'por_dto': linea.dto,
        'imp': linea.importe,
        'reg_iva_vta': regIvaCodigo(linea.tipoIva),
        'fch_ent': linea.previstoPara,
        'est': AppColors.estadoCodigo(linea.estado),
        'cnc': linea.cancelado,
      };
      final endpoint = AppConfig.endpoint('lineasPresupuesto');
      if (linea.id == null) {
        await _api.post(endpoint, body: body);
      } else {
        await _api.post('$endpoint/${linea.id}', body: body);
      }
    }
  }

  static Future<void> eliminarLinea(dynamic id) async {
    await _api.delete('${AppConfig.endpoint('lineasPresupuesto')}/$id');
  }

  static Future<void> remove(dynamic id) async {
    await _api.delete('${AppConfig.endpoint('presupuestos')}/$id');
  }
}
