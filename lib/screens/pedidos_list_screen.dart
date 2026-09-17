// ============================================================================
//  pedidos_list_screen.dart  —  LISTA DE PEDIDOS (la pantalla principal)
// ============================================================================
//
//  ¿Qué es?
//  --------
//  Es el "escritorio" de la app: una lista de pedidos de compra con:
//     - Filtros por estado (Todos / Pendiente / Recibido / Cancelado).
//     - Desplazamiento INFINITO: al llegar abajo, carga más pedidos solo.
//     - Tirar hacia abajo para recargar (RefreshIndicator).
//     - Botón flotante (+) para crear un pedido nuevo.
//     - Botón de salir (cierra la sesión).
//
//  Al tocar un pedido → se abre el detalle.
//
//  CONCEPTOS FLUTTER QUE APARECEN:
//  - ListView.builder: lista que solo dibuja los elementos visibles (rápido).
//  - ScrollController: control del scroll, aquí usado para detectar "fin de lista".
//  - setState: "aviso" de que algo cambió → marca para que build() se repita.
// ============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';

import '../api_service.dart'; // PedidosService (pide datos al servidor).
import '../models.dart'; // El modelo Pedido.
import '../state/auth_state.dart'; // Para el botón "Salir" (desconectar).
import '../state/order_cubit.dart';
import '../theme/app_theme.dart'; // Colores.
import '../widgets/fila_pedido.dart'; // La "tarjeta" de un pedido en la lista.

/// PedidosListScreen: la pantalla con la lista de pedidos.
class PedidosListScreen extends StatefulWidget {
  const PedidosListScreen({super.key});

  @override
  State<PedidosListScreen> createState() => _PedidosListScreenState();
}

/// _PedidosListScreenState: TODA la "memoria" de esta pantalla va aquí.
class _PedidosListScreenState extends State<PedidosListScreen> {
  static const _estados = ['Pendiente', 'Recibido', 'Cancelado'];
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargarDatosIniciales());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatosIniciales() async {
    final resultado = await PedidosService.list(page: 1, estado: '');
    if (!mounted) return;
    
    final clienteIds = resultado.items.map((p) => p.clienteId).toSet().toList();
    final clientes = await PedidosService.getClientesByIds(clienteIds);
    
    final cubit = context.read<OrderCubit>();
    cubit.loadOrders(resultado.items);
    cubit.loadClientes(clientes);
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      final cubit = context.read<OrderCubit>();
      cubit.filter(query, cubit.state.statusFilter);
    });
  }

  void _onStatusChanged(String status) {
    final cubit = context.read<OrderCubit>();
    cubit.filter(cubit.state.query, status.isEmpty ? null : status);
  }

  void _abrirDetalle(Pedido pedido) {
    Navigator.of(context).pushNamed('/pedido', arguments: pedido.id);
  }

  Future<void> _nuevoPedido() async {
    await Navigator.of(context).pushNamed('/pedido/form');
    if (mounted) _cargarDatosIniciales();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pedidos de compra'),
        actions: [
          IconButton(
            tooltip: 'Salir',
            icon: const Icon(Icons.logout),
            onPressed: auth.desconectar,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _nuevoPedido,
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        shape: const CircleBorder(),
        child: const Icon(Icons.add),
      ),
      body: BlocBuilder<OrderCubit, OrderState>(
        builder: (context, state) {
          return Column(
            children: [
              _filtros(state.statusFilter ?? ''),
              Expanded(
                child: state.filteredOrders.isEmpty
                    ? const Center(child: Text('Sin pedidos que mostrar.'))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: state.filteredOrders.length,
                        itemBuilder: (context, index) {
                          final pedido = state.filteredOrders[index];
                          return FilaPedido(
                            pedido: pedido,
                            onTap: () => _abrirDetalle(pedido),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _filtros(String filtroActual) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Todos'),
                selected: filtroActual.isEmpty,
                onSelected: (_) => _onStatusChanged(''),
              ),
              ..._estados.map(
                (estado) => ChoiceChip(
                  label: Text(estado),
                  selected: filtroActual == estado,
                  onSelected: (_) => _onStatusChanged(estado),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 48,
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                suffixIcon: const Icon(Icons.search),
                hintText: 'Buscar pedido...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}