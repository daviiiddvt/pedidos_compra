import 'package:diacritic/diacritic.dart';
import '../models.dart';
import '../theme/app_theme.dart';

class OrderRepository {
  List<Pedido> _allOrders = [];
  Map<int, Cliente> _clienteCache = {};

  List<Pedido> get cachedOrders => List.unmodifiable(_allOrders);

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
    required User? currentUser,
  }) {
    final normalizedQuery = removeDiacritics(query.toLowerCase());
        
    final role = currentUser?.role.toLowerCase();
    final commercialId = currentUser?.contactId ?? '';

    return _allOrders.where((order) {
      if (role != 'administrador' && role != 'admin' && role != 'comercial') {
        return false;
      }
      if (role == 'comercial' && order.comercial != commercialId) {
        return false;
      }

          final matchesStatus = statusFilter == null ||
            statusFilter.isEmpty ||
            AppColors.estadoCodigo(order.estado) ==
              AppColors.estadoCodigo(statusFilter);
      if (!matchesStatus) return false;

      // 3. Filtro de Texto (Cliente, Teléfono, CIF, Pedido)
      final searchableText = removeDiacritics(
        '${order.clienteNombre} ${order.clienteTelefono} ${order.clienteCif} ${order.numeroPedido}'
            .toLowerCase(),
      );
      return normalizedQuery.isEmpty || searchableText.contains(normalizedQuery);
    }).toList();
  }
}