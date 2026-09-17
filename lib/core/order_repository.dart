import 'package:diacritic/diacritic.dart';
import '../models.dart';

class OrderRepository {
  List<Pedido> _allOrders = [];
  Map<int, Cliente> _clienteCache = {};

  void setOrders(List<Pedido> orders) {
    _allOrders = orders;
    _enrichOrders();
  }
  
  void setClientes(List<Cliente> clientes) {
    _clienteCache = {for (var c in clientes) c.id: c};
    _enrichOrders();
  }

  void _enrichOrders() {
    if (_clienteCache.isEmpty) return;
    
    _allOrders = _allOrders.map((order) {
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
    _allOrders = [];
    _clienteCache = {};
  }

  List<Pedido> filterOrders({
    required String query,
    String? statusFilter,
  }) {
    final normalizedQuery = removeDiacritics(query.toLowerCase());
    
    return _allOrders.where((order) {
      // Filtro de Estado
      final matchesStatus = statusFilter == null || statusFilter.isEmpty || order.estado == statusFilter;
      if (!matchesStatus) return false;

      // Filtro de Texto (Cliente, Teléfono, CIF, Pedido)
      final searchableText = removeDiacritics(
        '${order.clienteNombre} ${order.clienteTelefono} ${order.clienteCif} ${order.numeroPedido}'
            .toLowerCase(),
      );

      return normalizedQuery.isEmpty || searchableText.contains(normalizedQuery);
    }).toList();
  }
}
