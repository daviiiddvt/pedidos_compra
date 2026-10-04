import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../core/api_service.dart';
import '../core/presupuesto_service.dart';
import '../state/auth_state.dart';
import '../theme/app_theme.dart';
import '../widgets/fila_pedido.dart';

class PresupuestosListScreen extends StatefulWidget {
  const PresupuestosListScreen({super.key});

  @override
  State<PresupuestosListScreen> createState() => _PresupuestosListScreenState();
}

class _PresupuestosListScreenState extends State<PresupuestosListScreen> {
  final _buscadorController = TextEditingController();
  List<Pedido> _todos = [];
  List<Pedido> _visibles = [];
  bool _cargando = true;
  String _filtroEstado = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargar());
  }

  @override
  void dispose() {
    _buscadorController.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    try {
      final user = context.read<AuthState>().currentUser;
      final presupuestoModels = await PresupuestosService.listAll(
        comercial: user?.role.toLowerCase() == 'comercial'
            ? user?.contactId
            : null,
      );
      final presupuestosVisuales = presupuestoModels
          .map((presupuesto) => presupuesto.toPedidoVisual())
          .toList();
      if (!mounted) return;
      setState(() {
        _todos = presupuestosVisuales;
        _cargando = false;
      });
      _aplicarFiltros();

      try {
        final clienteIds = presupuestosVisuales.map((b) => b.clienteId).toSet().toList();
        final clientes = await PedidosService.getClientesByIds(clienteIds);
        final mapClientes = {for (var c in clientes) c.id: c};
        if (!mounted) return;
        setState(() {
          _todos = _todos.map((presupuesto) {
            final c = mapClientes[presupuesto.clienteId];
            if (c != null) {
              return presupuesto.copyWith(
                clienteNombre: c.nombreComercial,
              );
            }
            return presupuesto;
          }).toList();
        });
        _aplicarFiltros();
      } catch (_) {}
    } catch (error) {
      if (!mounted) return;
      setState(() => _cargando = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  void _aplicarFiltros() {
    final query = _buscadorController.text.trim().toLowerCase();
    final user = context.read<AuthState>().currentUser;
    setState(() {
      _visibles = _todos.where((presupuesto) {
        if (user?.role.toLowerCase() == 'comercial' &&
            presupuesto.comercial != user?.contactId) {
          return false;
        }
        if (_filtroEstado.isNotEmpty &&
            AppColors.estadoCodigo(presupuesto.estado) !=
                AppColors.estadoCodigo(_filtroEstado)) {
          return false;
        }
        final text =
            '${presupuesto.clienteNombre} ${presupuesto.cliente} ${presupuesto.numeroPresupuesto}'
                .toLowerCase();
        return query.isEmpty || text.contains(query);
      }).toList();
    });
  }

  Future<void> _abrirFormulario([dynamic id]) async {
    await Navigator.of(context).pushNamed('/presupuesto/form', arguments: id);
    if (mounted) await _cargar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Presupuestos de venta'),
        actions: [
          IconButton(
            tooltip: 'Salir',
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<AuthState>().desconectar(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _abrirFormulario(),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: TextField(
              controller: _buscadorController,
              onChanged: (_) => _aplicarFiltros(),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Buscar cliente o número',
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: ['', 'Pendiente', 'Aceptado', 'Rechazado', 'Parcialmente Servido'].map((status) {
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(status.isEmpty ? 'Todos' : status),
                    selected: _filtroEstado == status,
                    onSelected: (_) {
                      setState(() => _filtroEstado = status);
                      _aplicarFiltros();
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: _cargando
                ? const Center(child: CircularProgressIndicator())
                : _visibles.isEmpty
                ? const Center(
                    child: Text('Sin presupuestos de venta que mostrar.'),
                  )
                : RefreshIndicator(
                    onRefresh: _cargar,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _visibles.length,
                      itemBuilder: (_, index) => FilaPedido(
                        pedido: _visibles[index],
                        mostrarNumeroPresupuesto: true,
                        onTap: () => Navigator.of(context).pushNamed(
                          '/presupuesto',
                          arguments: _visibles[index].id,
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
