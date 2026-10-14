import 'package:flutter_bloc/flutter_bloc.dart';
import '../core/repositorio_pedidos.dart';
import '../models/models.dart';

class OrderState {
  final List<Pedido> filteredOrders;
  final String query;
  final String? statusFilter;
  
  OrderState({this.filteredOrders = const [], this.query = '', this.statusFilter});
}

class OrderCubit extends Cubit<OrderState> {
  final RepositorioPedidos _repository;
  
  OrderCubit(this._repository) : super(OrderState());
  
  void loadOrders(List<Pedido> orders) {
    _repository.setOrders(orders);
    emit(OrderState(filteredOrders: orders));
  }

  void loadClientes(List<Cliente> clientes) {
    _repository.setClientes(clientes);
    // Tras enriquecer, volvemos a filtrar con el estado actual para refrescar la vista
    final filtered = _repository.filtrarPedidos(
      query: state.query,
      statusFilter: state.statusFilter,
      currentUser: null,
    );
    emit(OrderState(filteredOrders: filtered, query: state.query, statusFilter: state.statusFilter));
  }

  void filter(String query, String? statusFilter) {
    final filtered = _repository.filtrarPedidos(
      query: query,
      statusFilter: statusFilter,
      currentUser: null,
    );
    emit(OrderState(filteredOrders: filtered, query: query, statusFilter: statusFilter));
  }
}
