import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../presupuesto_service.dart';
import '../state/auth_state.dart';
import '../theme/app_theme.dart';
import '../widgets/fila_pedido.dart';

class PresupuestosListScreen extends StatefulWidget {
  const PresupuestosListScreen({super.key});

  @override
  State<PresupuestosListScreen> createState() => _PresupuestosListScreenState();
}

class _PresupuestosListScreenState extends State<PresupuestosListScreen> {
  final _search = TextEditingController();
  List<Pedido> _all = [];
  List<Pedido> _visible = [];
  bool _loading = true;
  String _status = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final user = context.read<AuthState>().currentUser;
      final budgets = await PresupuestosService.listAll(
        comercial: user?.role.toLowerCase() == 'comercial'
            ? user?.contactId
            : null,
      );
      if (!mounted) return;
      setState(() {
        _all = budgets;
        _loading = false;
      });
      _applyFilters();
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  void _applyFilters() {
    final query = _search.text.trim().toLowerCase();
    final user = context.read<AuthState>().currentUser;
    setState(() {
      _visible = _all.where((budget) {
        if (user?.role.toLowerCase() == 'comercial' &&
            budget.comercial != user?.contactId) {
          return false;
        }
        if (_status.isNotEmpty &&
            AppColors.estadoCodigo(budget.estado) !=
                AppColors.estadoCodigo(_status)) {
          return false;
        }
        final text =
            '${budget.clienteNombre} ${budget.cliente} ${budget.numeroPedido}'
                .toLowerCase();
        return query.isEmpty || text.contains(query);
      }).toList();
    });
  }

  Future<void> _openForm([dynamic id]) async {
    await Navigator.of(context).pushNamed('/presupuesto/form', arguments: id);
    if (mounted) await _load();
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
        onPressed: () => _openForm(),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: TextField(
              controller: _search,
              onChanged: (_) => _applyFilters(),
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
              children: ['', 'Pendiente', 'Servido', 'Cancelado'].map((status) {
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(status.isEmpty ? 'Todos' : status),
                    selected: _status == status,
                    onSelected: (_) {
                      setState(() => _status = status);
                      _applyFilters();
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _visible.isEmpty
                    ? const Center(child: Text('Sin presupuestos de venta que mostrar.'))
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: _visible.length,
                          itemBuilder: (_, index) => FilaPedido(
                            pedido: _visible[index],
                            onTap: () => Navigator.of(context).pushNamed(
                              '/presupuesto',
                              arguments: _visible[index].id,
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
