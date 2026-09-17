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

  void loadOrders(List<Pedido> orders, User? currentUser) {
    _repository.setOrders(orders);
    filter(state.query, state.statusFilter, currentUser);
  }

  void loadClientes(List<Cliente> clientes, User? currentUser) {
    _repository.setClientes(clientes);
    filter(state.query, state.statusFilter, currentUser);
  }

  void filter(String query, String? statusFilter, User? currentUser) {
    final filtered = _repository.filterOrders(
      query: query, 
      statusFilter: statusFilter, 
      currentUser: currentUser
    );
    emit(OrderState(filteredOrders: filtered, query: query, statusFilter: statusFilter));
  }
}