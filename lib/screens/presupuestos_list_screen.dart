import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../core/api_service.dart';
import '../core/config.dart';
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
  final _scrollController = ScrollController();
  Timer? _searchDebounce;
  List<Pedido> _todos = [];
  List<Pedido> _visibles = [];
  bool _cargando = true;
  bool _cargandoPagina = false;
  bool _hayMas = true;
  int _pagina = 1;
  int _totalPresupuestos = 0;
  int _busquedaVersion = 0;
  String _filtroEstado = '';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_cargarAlLlegarAlFinal);
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargarPagina(reset: true));
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _buscadorController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _cargarAlLlegarAlFinal() {
    if (_buscadorController.text.trim().isNotEmpty) return;
    if (_scrollController.position.extentAfter < 400) {
      _cargarPagina();
    }
  }

  Future<void> _cargarBusquedaCompleta(int version) async {
    while (mounted && version == _busquedaVersion && _cargandoPagina) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    if (!mounted || version != _busquedaVersion) return;

    await _cargarPagina(reset: true);
    while (mounted && version == _busquedaVersion && _hayMas) {
      if (_cargandoPagina) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        continue;
      }
      await _cargarPagina();
    }
  }

  Future<void> _cargarPagina({bool reset = false}) async {
    if (_cargandoPagina || (!reset && !_hayMas)) return;

    final user = context.read<AuthState>().currentUser;
    final comercial = user?.role.toLowerCase() == 'comercial'
        ? user?.contactId
        : null;

    if (reset) {
      _pagina = 1;
      _totalPresupuestos = 0;
      _hayMas = true;
    }

    setState(() {
      _cargandoPagina = true;
      if (reset) {
        _cargando = true;
        _todos = [];
        _visibles = [];
      }
    });

    try {
      final resultado = await PresupuestosService.list(
        page: _pagina,
        comercial: comercial,
      );
      final presupuestosVisuales = resultado.items
          .map((presupuesto) => presupuesto.toPedidoVisual())
          .toList();
      if (!mounted) return;
      final acumulados = [
        if (!reset) ..._todos,
        ...presupuestosVisuales,
      ];
      _pagina++;
      _totalPresupuestos = resultado.total;
      _hayMas = _totalPresupuestos > 0
          ? acumulados.length < _totalPresupuestos
          : presupuestosVisuales.length >= AppConfig.pageSize;
      setState(() {
        _todos = acumulados;
        _cargando = false;
        _cargandoPagina = false;
      });
      _aplicarFiltros();

      try {
        final clienteIds = presupuestosVisuales
            .map((b) => b.clienteId)
            .toSet()
            .toList();
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
      setState(() {
        _cargando = false;
        _cargandoPagina = false;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  Future<void> _refrescar() => _cargarPagina(reset: true);

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
    if (mounted) await _cargarPagina(reset: true);
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
              onChanged: (_) {
                _busquedaVersion++;
                final version = _busquedaVersion;
                _searchDebounce?.cancel();
                _searchDebounce = Timer(
                  const Duration(milliseconds: 350),
                  () => _buscadorController.text.trim().isEmpty
                      ? _cargarPagina(reset: true)
                      : _cargarBusquedaCompleta(version),
                );
              },
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Buscar cliente o número',
              ),
            ),
          ),
          if (_visibles.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${_visibles.length} presupuestos',
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: ['', 'PENDIENTE', 'ACEPTADO', 'RECHAZADO', 'PARCIALMENTE SERVIDO'].map((status) {
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
                    onRefresh: _refrescar,
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _visibles.length + (_hayMas ? 1 : 0),
                      itemBuilder: (_, index) {
                        if (index == _visibles.length) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        return FilaPedido(
                        pedido: _visibles[index],
                        mostrarNumeroPresupuesto: true,
                        onTap: () => Navigator.of(context).pushNamed(
                          '/presupuesto',
                          arguments: _visibles[index].id,
                        ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
