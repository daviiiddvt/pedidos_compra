// ============================================================================
//  pedidos_list_screen.dart  —  LISTA DE PEDIDOS (la pantalla principal)
// ============================================================================
//
//  ¿Qué es?
//  --------
//  Es el "escritorio" de la app: una lista de pedidos de venta con:
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
import 'package:provider/provider.dart';

import '../core/api_service.dart'; // PedidosService (pide datos al servidor).
import '../core/config.dart';
import '../models/models.dart'; // El modelo Pedido.
import '../core/order_repository.dart';
import '../state/auth_state.dart'; // Para el botón "Salir" (desconectar).
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
  // Los estados que ofrecen los filtros (ChoiceChip).
  static const _estados = ['PENDIENTE', 'SERVIDO', 'CANCELADO'];

  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  Timer? _searchDebounce;

  // --- "Memoria" de la lista ---
  List<Pedido> _pedidos = []; // Los pedidos cargados hasta ahora.
  bool _cargando = true; // ¿Estamos pidiendo datos ahora mismo?
  bool _cargandoPagina = false;
  bool _hayMas = true;
  int _pagina = 1;
  int _totalPedidos = 0;
  String _filtroEstado = ''; // Filtro activo ('' = sin filtrar = "Todos").
  String _busqueda = '';
  int _busquedaVersion = 0;
  bool _verPorZona = false; // Alternar modo de visión

  /// initState: al nacer la pantalla, nos suscribimos al scroll y cargamos la
  /// primera página. El addPostFrameCallback espera a que la pantalla esté
  /// dibujada para hacer la primera carga (más seguro).
  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_cargarAlLlegarAlFinal);
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargarInicial());
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _cargarInicial() async {
    await _cargarPagina(reset: true);
  }

  void _cargarAlLlegarAlFinal() {
    if (_busqueda.trim().isNotEmpty) return;
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

  /// Descarga una página y la añade a las ya cargadas. Para administradores
  /// [comercial] queda vacío, por lo que Velneo devuelve todos los pedidos.
  Future<void> _cargarPagina({bool reset = false}) async {
    if (_cargandoPagina || (!reset && !_hayMas)) return;

    final repository = context.read<OrderRepository>();
    final auth = context.read<AuthState>();
    final user = auth.currentUser;
    final comercial = user?.role.toLowerCase() == 'comercial'
        ? user?.contactId
        : null;
    final zonaComercial = auth.canViewTechnicalZone ? user?.contactId : null;

    if (reset) {
      _pagina = 1;
      _totalPedidos = 0;
      _hayMas = true;
      repository.clearCache();
    }

    setState(() {
      _cargandoPagina = true;
      if (reset) _cargando = true;
    });

    try {
      late final ResultadoLista<Pedido> resultado;
      if (_verPorZona && zonaComercial != null && zonaComercial.isNotEmpty) {
        final pedidos = await PedidosService.listAll(
          comercial: zonaComercial,
          porZona: true,
        );
        resultado = ResultadoLista<Pedido>(
          items: pedidos,
          total: pedidos.length,
          page: 1,
        );
      } else {
        resultado = await PedidosService.list(
          page: _pagina,
          comercial: comercial,
        );
      }
      if (!mounted) return; // Si la pantalla ya se cerró, no seguimos.
      repository.setOrders([
        if (!reset) ...repository.cachedOrders,
        ...resultado.items,
      ]);
      _pagina++;
      _totalPedidos = resultado.total;
      _hayMas = _totalPedidos > 0
          ? repository.cachedOrders.length < _totalPedidos
          : resultado.items.length >= AppConfig.pageSize;
      _aplicarFiltros();
      setState(() {
        _cargando = false;
        _cargandoPagina = false;
      });

      // Los datos auxiliares no bloquean la primera pintura de la lista.
      try {
        final clienteIds = resultado.items
            .map((pedido) => pedido.clienteId)
            .toSet()
            .toList();
        final clientes = await PedidosService.getClientesByIds(clienteIds);
        if (!mounted) return;
        repository.setClientes(clientes);
        _aplicarFiltros();
      } catch (_) {
        // Los pedidos siguen siendo utilizables si el endpoint de clientes no responde.
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _cargandoPagina = false;
      });
      // Mostramos el error del servidor en un snackbar.
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  void _aplicarFiltros() {
    final pedidos = context.read<OrderRepository>().filterOrders(
      query: _busqueda,
      statusFilter: _filtroEstado,
      currentUser: context.read<AuthState>().currentUser,
    );
    if (mounted) setState(() => _pedidos = pedidos);
  }

  /// _refrescar: recarga la primera página (se usa con el gesto "tirar abajo").
  Future<void> _refrescar() async {
    await _cargarInicial();
  }

  /// _cambiarFiltro: al tocar un filtro (ej. "Recibido"), vuelve a la página 1.
  void _cambiarFiltro(String estado) {
    if (estado == _filtroEstado) {
      return; // Tocar el filtro ya activo → no hacer nada.
    }
    setState(() {
      _filtroEstado = estado;
    });
    _aplicarFiltros();
  }

  /// _abrirDetalle: navega a la ruta "/pedido" pasándole el id como argumento.
  void _abrirDetalle(Pedido pedido) {
    Navigator.of(context).pushNamed('/pedido', arguments: pedido.id);
  }

  /// _nuevoPedido: abre el formulario vacío. Al volver, recarga la lista.
  Future<void> _nuevoPedido() async {
    await Navigator.of(context).pushNamed('/pedido/form');
    if (mounted) await _cargarInicial();
  }

  /// build: dibuja toda la pantalla (barra + filtros + lista).
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>(); // Para el botón de salir.

    return Scaffold(
      // ---- Barra superior ----
      appBar: AppBar(
        title: const Text('Pedidos de venta'),
        actions: [
          IconButton(
            tooltip: 'Presupuestos',
            icon: const Icon(Icons.request_quote_outlined),
            onPressed: () => Navigator.of(context).pushNamed('/presupuestos'),
          ),
          // Botón "Salir": cierra la sesión → la app vuelve al login sola.
          IconButton(
            tooltip: 'Salir',
            icon: const Icon(Icons.logout),
            onPressed: () {
              context.read<OrderRepository>().clearCache();
              auth.desconectar();
            },
          ),
        ],
      ),

      // ---- Botón flotante (+) para crear un pedido nuevo ----
      floatingActionButton: FloatingActionButton(
        onPressed: _nuevoPedido,
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        shape: const CircleBorder(),
        child: const Icon(Icons.add),
      ),

      body: Column(
        children: [
          _filtros(), // Fila con los chips (Todos/Pendiente/Recibido/Cancelado).
          // Contador: "X pedidos" (solo si hay algo).
          if (_pedidos.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${_pedidos.length} pedidos',
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),

          // ---- La zona de la lista (Expandida = ocupa el resto del alto) ----
          Expanded(
            child: _cargando && _pedidos.isEmpty
                ? Center(
                    child: CircularProgressIndicator(),
                  ) // Cargando 1ª vez.
                : _pedidos.isEmpty
                ? Center(
                  child: Text(
                      'Sin pedidos de venta que mostrar.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : RefreshIndicator(
                    // Gestazo de "tirar hacia abajo" = recargar.
                    onRefresh: _refrescar,
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _pedidos.length + (_hayMas ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _pedidos.length) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        // Un pedido normal → su tarjeta FilaPedido.
                        final pedido = _pedidos[index];
                        return FilaPedido(
                          pedido: pedido,
                          onTap: () => _abrirDetalle(pedido),
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
    final canViewTechnicalZone = context.read<AuthState>().canViewTechnicalZone;
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Selector de modo de visión
          if (canViewTechnicalZone)
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment<bool>(
                  value: false,
                  label: Text('Mis clientes asignados'),
                  icon: Icon(Icons.person),
                ),
                ButtonSegment<bool>(
                  value: true,
                  label: Text('Mi zona técnica'),
                  icon: Icon(Icons.map),
                ),
              ],
              selected: {_verPorZona},
              onSelectionChanged: (Set<bool> newSelection) {
                final newValue = newSelection.first;
                if (newValue == _verPorZona) return;

                setState(() {
                  _verPorZona = newValue;
                  _pedidos.clear();
                });
                _refrescar();
              },
            ),
          const SizedBox(height: 10),

          // 1. La fila de chips (dentro de un Wrap)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Todos'),
                selected: _filtroEstado.isEmpty,
                onSelected: (_) => _cambiarFiltro(''),
              ),
              ..._estados.map(
                (estado) => ChoiceChip(
                  label: Text(estado),
                  selected: _filtroEstado == estado,
                  onSelected: (_) => _cambiarFiltro(estado),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10), // Separación entre chips y buscador sized box es un widget que permite definir un tamaño fijo para su hijo, en este caso se utiliza para darle un alto fijo al TextField del buscador.
          // 2. El buscador (envuelto en un SizedBox para darle tamaño fijo si quieres)
          SizedBox(
            height: 48,
            child: TextField(
              decoration: InputDecoration(
                suffixIcon: const Icon(Icons.search),
                hintText: 'Buscar pedido...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                ), // Ajusta el padding horizontal según tus necesidades
              ),
              controller: _searchController,
              onChanged: (value) {
                _busqueda = value;
                _busquedaVersion++;
                final version = _busquedaVersion;
                _searchDebounce?.cancel();
                _searchDebounce = Timer(
                  const Duration(milliseconds: 350),
                  () => _busqueda.trim().isEmpty
                      ? _cargarPagina(reset: true)
                      : _cargarBusquedaCompleta(version),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
