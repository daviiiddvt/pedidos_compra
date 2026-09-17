import 'package:flutter_bloc/flutter_bloc.dart';
import '../core/order_repository.dart';
import '../models.dart';

class OrderState {
  final List<Pedido> filteredOrders;
  final String query;
  final String? statusFilter;
  
  OrderState({this.filteredOrders = const [], this.query = '', this.statusFilter});
}

class OrderCubit extends Cubit<OrderState> {
  final OrderRepository _repository;
  
  OrderCubit(this._repository) : super(OrderState());
  
  void loadOrders(List<Pedido> orders) {
    _repository.setOrders(orders);
    emit(OrderState(filteredOrders: orders));
  }

  void loadClientes(List<Cliente> clientes) {
    _repository.setClientes(clientes);
    // Tras enriquecer, volvemos a filtrar con el estado actual para refrescar la vista
    final filtered = _repository.filterOrders(query: state.query, statusFilter: state.statusFilter);
    emit(OrderState(filteredOrders: filtered, query: state.query, statusFilter: state.statusFilter));
  }

  void filter(String query, String? statusFilter) {
    final filtered = _repository.filterOrders(query: query, statusFilter: statusFilter);
    emit(OrderState(filteredOrders: filtered, query: query, statusFilter: statusFilter));
  }
}
