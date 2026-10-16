import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../core/api_service.dart';
import '../core/config.dart';
import '../core/presupuesto_service.dart';
import '../core/licencia/licencia_service.dart';
import '../state/auth_state.dart';
import '../theme/app_theme.dart';
import '../widgets/fila_pedido.dart';

class PresupuestosListScreen extends StatefulWidget {
  const PresupuestosListScreen({super.key});

  @override
  State<PresupuestosListScreen> createState() => _PresupuestosListScreenState();
}

class _PresupuestosListScreenState extends State<PresupuestosListScreen> {
  static const _estados = [
    'PENDIENTE',
    'ACEPTADO',
    'RECHAZADO',
    'PARCIALMENTE SERVIDO',
  ];

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

  bool get _estaCargandoOBuscando =>
      _cargando ||
      _cargandoPagina ||
      (_searchDebounce?.isActive ?? false) ||
      (_buscadorController.text.trim().isNotEmpty && _hayMas);

  void _cambiarFiltro(String estado) {
    if (estado == _filtroEstado) return;
    setState(() => _filtroEstado = estado);
    _aplicarFiltros();
  }

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
            .map((b) => b.clienteId > 0 ? b.clienteId : (int.tryParse(b.cliente) ?? 0))
            .where((id) => id > 0)
            .toSet()
            .toList();
        final mapClientes = await PedidosService.getClientesMapByIds(clienteIds);
        if (!mounted) return;
        setState(() {
          _todos = _todos.map((presupuesto) {
            final cid = presupuesto.clienteId > 0 ? presupuesto.clienteId : (int.tryParse(presupuesto.cliente) ?? 0);
            final c = mapClientes[cid];
            if (c != null && c.nombreComercial.isNotEmpty) {
              return presupuesto.copyWith(
                clienteId: cid > 0 ? cid : presupuesto.clienteId,
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
      ),
      floatingActionButton: context.watch<LicenciaService>().esSoloLec
          ? null
          : FloatingActionButton(
              onPressed: () => _abrirFormulario(),
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.white,
              shape: const CircleBorder(),
              child: const Icon(Icons.add),
            ),
      body: Column(
        children: [
          _filtros(),
          if (_visibles.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
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
          Expanded(
            child: (_estaCargandoOBuscando && _visibles.isEmpty)
                ? const Center(child: CircularProgressIndicator())
                : _visibles.isEmpty
                ? Center(
                    child: Text(
                      _buscadorController.text.trim().isNotEmpty
                          ? 'Sin presupuestos de venta que coincidan con "${_buscadorController.text.trim()}".'
                          : 'Sin presupuestos de venta que mostrar.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
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

  Widget _filtros() {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. La fila de chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFiltroChip(
                  label: 'Todos',
                  estado: '',
                  selected: _filtroEstado.isEmpty,
                  onSelected: () => _cambiarFiltro(''),
                ),
                ..._estados.map(
                  (estado) => _buildFiltroChip(
                    label: estado,
                    estado: estado,
                    selected: _filtroEstado == estado,
                    onSelected: () => _cambiarFiltro(estado),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),
          // 2. El buscador
          SizedBox(
            height: 48,
            child: TextField(
              controller: _buscadorController,
              decoration: InputDecoration(
                suffixIcon: (_cargandoPagina || (_searchDebounce?.isActive ?? false))
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : const Icon(Icons.search),
                hintText: 'Buscar cliente o número...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              onChanged: (_) {
                _busquedaVersion++;
                final version = _busquedaVersion;
                _aplicarFiltros();
                _searchDebounce?.cancel();
                _searchDebounce = Timer(
                  const Duration(milliseconds: 350),
                  () => _buscadorController.text.trim().isEmpty
                      ? _cargarPagina(reset: true)
                      : _cargarBusquedaCompleta(version),
                );
                setState(() {});
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltroChip({
    required String label,
    required String estado,
    required bool selected,
    required VoidCallback onSelected,
  }) {
    final color = estado.isEmpty
        ? Theme.of(context).colorScheme.primary
        : AppColors.estadoColor(estado);
    final selectedTextColor = estado.isEmpty
        ? Theme.of(context).colorScheme.onPrimary
        : Colors.white;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onSelected(),
        showCheckmark: false,
        selectedColor: color,
        backgroundColor: color.withValues(alpha: 0.12),
        side: BorderSide(
          color: selected ? color : color.withValues(alpha: 0.45),
        ),
        labelStyle: TextStyle(
          color: selected ? selectedTextColor : color,
          fontWeight: selected ? FontWeight.bold : FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );
  }
}
