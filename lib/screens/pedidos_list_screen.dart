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

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api_service.dart'; // PedidosService (pide datos al servidor).
import '../models.dart'; // El modelo Pedido.
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
  static const _estados = ['Pendiente', 'Servido', 'Cancelado'];

  final _scrollController = ScrollController();
  final _searchController = TextEditingController();

  // --- "Memoria" de la lista ---
  List<Pedido> _pedidos = []; // Los pedidos cargados hasta ahora.
  bool _cargando = true; // ¿Estamos pidiendo datos ahora mismo?
  String _filtroEstado = ''; // Filtro activo ('' = sin filtrar = "Todos").
  String _busqueda = '';

  /// initState: al nacer la pantalla, nos suscribimos al scroll y cargamos la
  /// primera página. El addPostFrameCallback espera a que la pantalla esté
  /// dibujada para hacer la primera carga (más seguro).
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargarInicial());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// _cargar: pide una página de pedidos al servidor.
  /// - pagina: qué página pedimos.
  /// - estado: filtro activo ('' = todos).
  /// - refresh: si es true, REEMPLAZA la lista; si no, AÑADE al final (scroll).
  /// - search: término de búsqueda.
  Future<void> _cargarInicial() async {
    try {
      final auth = context.read<AuthState>();
      final user = auth.currentUser;
      final pedidos = await PedidosService.listAll(
        comercial: user?.role.toLowerCase() == 'comercial'
            ? user?.contactId
            : null,
      );
      if (!mounted) return; // Si la pantalla ya se cerró, no seguimos.
      final repository = context.read<OrderRepository>();
      repository.setOrders(pedidos);
      _aplicarFiltros();
      setState(() => _cargando = false);

      // Los datos auxiliares no bloquean la primera pintura de la lista.
      try {
        final clienteIds = pedidos.map((pedido) => pedido.clienteId).toSet().toList();
        final clientes = await PedidosService.getClientesByIds(clienteIds);
        if (!mounted) return;
        repository.setClientes(clientes);
        _aplicarFiltros();
      } catch (_) {
        // Los pedidos siguen siendo utilizables si el endpoint de clientes no responde.
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _cargando = false);
      // Mostramos el error del servidor en un snackbar.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
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
    setState(() => _cargando = true);
    await _cargarInicial();
  }

  /// _cambiarFiltro: al tocar un filtro (ej. "Recibido"), vuelve a la página 1.
  void _cambiarFiltro(String estado) {
    if (estado == _filtroEstado) return; // Tocar el filtro ya activo → no hacer nada.
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
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),

          // ---- La zona de la lista (Expandida = ocupa el resto del alto) ----
          Expanded(
            child: _cargando && _pedidos.isEmpty
                ? const Center(child: CircularProgressIndicator()) // Cargando 1ª vez.
                : _pedidos.isEmpty
                    ? const Center(
                        child: Text(
                          'Sin pedidos de venta que mostrar.',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      )
                    : RefreshIndicator(
                        // Gestazo de "tirar hacia abajo" = recargar.
                        onRefresh: _refrescar,
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: _pedidos.length,
                          itemBuilder: (context, index) {
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

  /// _filtros: la fila de "chips" (píldoras) para filtrar por estado.
    Widget _filtros() {
    return Container(
      color: AppColors.surface, // Fondo blanco
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column( // Usamos Column para apilar los chips y el buscador
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                contentPadding: const EdgeInsets.symmetric(horizontal: 12), // Ajusta el padding horizontal según tus necesidades
              ),
              controller: _searchController,
              onChanged: (value) {
                _busqueda = value;
                _aplicarFiltros();
              },
            ),
          ),
        ],
      ),
    );
  }
}