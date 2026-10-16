import 'package:diacritic/diacritic.dart';

import '../models/models.dart';
import '../theme/app_theme.dart';

class RepositorioPedidos {
  List<Pedido> _todosLosPedidos = [];
  Map<int, Cliente> _clienteCache = {};

  List<Pedido> get pedidosCacheados => List.unmodifiable(_todosLosPedidos);

  void setOrders(List<Pedido> orders) {
    _todosLosPedidos = orders;
    for (final o in orders) {
      final cid = o.clienteId > 0 ? o.clienteId : (int.tryParse(o.cliente) ?? 0);
      final nom = o.clienteNombre.trim();
      final esNumero = int.tryParse(nom) != null;
      if (cid > 0 && nom.isNotEmpty && nom != o.cliente.trim() && !esNumero) {
        _clienteCache[cid] = Cliente(
          id: cid,
          nombreComercial: nom,
          cif: o.clienteCif,
          telefono: o.clienteTelefono,
        );
      }
    }
    _enrichOrders();
  }

  void setClientes(List<Cliente> clientes) {
    _clienteCache = {..._clienteCache, for (var c in clientes) c.id: c};
    _enrichOrders();
  }

  void setClientesMap(Map<int, Cliente> clientesMap) {
    _clienteCache = {..._clienteCache, ...clientesMap};
    _enrichOrders();
  }

  void _enrichOrders() {
    if (_clienteCache.isEmpty) return;

    _todosLosPedidos = _todosLosPedidos.map((order) {
      final cid = order.clienteId > 0 ? order.clienteId : (int.tryParse(order.cliente) ?? 0);
      final cliente = _clienteCache[cid] ?? (order.clienteId > 0 ? _clienteCache[order.clienteId] : null);
      if (cliente == null) return order;
      return order.copyWith(
        clienteId: cid > 0 ? cid : order.clienteId,
        clienteNombre: cliente.nombreComercial.isNotEmpty ? cliente.nombreComercial : order.clienteNombre,
        clienteTelefono: cliente.telefono.isNotEmpty ? cliente.telefono : order.clienteTelefono,
        clienteCif: cliente.cif.isNotEmpty ? cliente.cif : order.clienteCif,
      );
    }).toList();
  }

  void clearCache() {
    _todosLosPedidos = [];
  }

  void clearAll() {
    _todosLosPedidos = [];
    _clienteCache = {};
  }

  List<Pedido> filtrarPedidos({
    required String query,
    String? statusFilter,
    required User? currentUser,
  }) {
    final normalizedQuery = removeDiacritics(query.toLowerCase());

    final role = currentUser?.role.toLowerCase();
    final commercialId = currentUser?.contactId ?? '';

    return _todosLosPedidos.where((order) {
      if (role != 'administrador' && role != 'admin' && role != 'comercial') {
        return false;
      }
      if (role == 'comercial' && order.comercial != commercialId) {
        return false;
      }

      final matchesStatus =
          statusFilter == null ||
          statusFilter.isEmpty ||
          AppColors.estadoCodigo(order.estado) ==
              AppColors.estadoCodigo(statusFilter);
      if (!matchesStatus) return false;

      // 3. Filtro de Texto (Cliente, Teléfono, CIF, Pedido)
      final searchableText = removeDiacritics(
        '${order.clienteNombre} ${order.clienteTelefono} ${order.clienteCif} ${order.numeroPedido}'
            .toLowerCase(),
      );
      return normalizedQuery.isEmpty ||
          searchableText.contains(normalizedQuery);
    }).toList();
  }
}
