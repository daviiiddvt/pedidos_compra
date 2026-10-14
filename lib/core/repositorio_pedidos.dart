import 'package:diacritic/diacritic.dart';

import '../models/models.dart';
import '../theme/app_theme.dart';

class RepositorioPedidos {
  List<Pedido> _todosLosPedidos = [];
  Map<int, Cliente> _clienteCache = {};

  List<Pedido> get pedidosCacheados => List.unmodifiable(_todosLosPedidos);

  void setOrders(List<Pedido> orders) {
    _todosLosPedidos = orders;
    _enrichOrders();
  }

  void setClientes(List<Cliente> clientes) {
    _clienteCache = {..._clienteCache, for (var c in clientes) c.id: c};
    _enrichOrders();
  }

  void _enrichOrders() {
    if (_clienteCache.isEmpty) return;

    _todosLosPedidos = _todosLosPedidos.map((order) {
      final cliente = _clienteCache[order.clienteId];
      if (cliente == null) return order;
      return order.copyWith(
        clienteNombre: cliente.nombreComercial,
        clienteTelefono: cliente.telefono,
        clienteCif: cliente.cif,
      );
    }).toList();
  }

  void clearCache() {
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
