import 'dart:async';

import 'package:diacritic/diacritic.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/clientes_service.dart';
import '../core/config.dart';
import '../models/models.dart';
import '../state/auth_state.dart';

class ClientesListScreen extends StatefulWidget {
  const ClientesListScreen({super.key});

  @override
  State<ClientesListScreen> createState() => _ClientesListScreenState();
}

class _ClientesListScreenState extends State<ClientesListScreen> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  Timer? _searchDebounce;

  List<Cliente> _todos = [];
  List<Cliente> _visibles = [];
  bool _cargando = true;
  bool _cargandoPagina = false;
  bool _hayMas = true;
  int _pagina = 1;
  int _totalClientes = 0;
  String _busqueda = '';
  int _busquedaVersion = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargarInicial());
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_busqueda.trim().isNotEmpty) return;
    if (_scrollController.position.extentAfter < 400) {
      _cargarPagina();
    }
  }

  Future<void> _cargarInicial() async {
    await _cargarPagina(reset: true);
  }

  void _aplicarFiltros() {
    final q = removeDiacritics(_busqueda.trim().toLowerCase());
    final tokens = q.isEmpty
        ? <String>[]
        : q.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();

    final filtrados = _todos.where((cliente) {
      if (tokens.isEmpty) return true;

      final nombre = removeDiacritics(cliente.nombreComercial.toLowerCase());
      final cif = removeDiacritics(cliente.cif.toLowerCase());
      final searchable = '$nombre $cif';

      return tokens.every((token) => searchable.contains(token));
    }).toList();

    if (mounted) setState(() => _visibles = filtrados);
  }

  Future<void> _cargarBusquedaCompleta(int version) async {
    while (mounted && version == _busquedaVersion && _cargandoPagina) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    if (!mounted || version != _busquedaVersion) return;

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

    if (reset) {
      _pagina = 1;
      _totalClientes = 0;
      _hayMas = true;
    }

    setState(() {
      _cargandoPagina = true;
      if (reset) _cargando = true;
    });

      try {
        final auth = context.read<AuthState>();
        String? comercialId;
        if (auth.canViewTechnicalZone && auth.currentUser?.contactId.isNotEmpty == true) {
          comercialId = auth.currentUser!.contactId;
        }

        final resultado = await ClientesService.list(
          page: _pagina,
          pageSize: AppConfig.pageSize,
          comercialId: comercialId,
        );

      if (!mounted) return;

      final nuevos = reset
          ? resultado.items
          : [..._todos, ...resultado.items];

      _pagina++;
      _totalClientes = resultado.total;
      _hayMas = _totalClientes > 0
          ? nuevos.length < _totalClientes
          : resultado.items.length >= AppConfig.pageSize;

      _todos = nuevos;
      _aplicarFiltros();

      setState(() {
        _cargando = false;
        _cargandoPagina = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _cargandoPagina = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar clientes: $e')),
      );
    }
  }

  bool get _estaCargandoOBuscando =>
      _cargando ||
      _cargandoPagina ||
      (_searchDebounce?.isActive ?? false) ||
      (_busqueda.trim().isNotEmpty && _hayMas);

  void _onSearchChanged(String value) {
    _busqueda = value;
    _aplicarFiltros();
    _busquedaVersion++;
    final version = _busquedaVersion;
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (_busqueda.trim().isNotEmpty && _hayMas) {
        _cargarBusquedaCompleta(version);
      }
    });
    setState(() {});
  }

  void _abrirDetalle(Cliente cliente) {
    Navigator.of(context).pushNamed('/cliente', arguments: cliente);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Clientes'),
      ),
      body: Column(
        children: [
          // Buscador por nombre o referencia + check Desactivados
          Container(
            color: colorScheme.surfaceContainerHighest,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 48,
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: (_cargandoPagina || (_searchDebounce?.isActive ?? false))
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : (_searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                    _onSearchChanged('');
                                  },
                                )
                              : null),
                      hintText: 'Buscar por nombre o CIF...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Contador de clientes
          if (_visibles.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 2),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${_visibles.length} ${_visibles.length == 1 ? 'cliente' : 'clientes'}${_busqueda.trim().isNotEmpty && _hayMas ? ' (buscando más...)' : ''}',
                  style: TextStyle(
                    fontSize: 11,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),

          // Lista de clientes
          Expanded(
            child: (_estaCargandoOBuscando && _visibles.isEmpty)
                ? const Center(child: CircularProgressIndicator())
                : _visibles.isEmpty
                    ? Center(
                        child: Text(
                          _busqueda.trim().isNotEmpty
                              ? 'Sin clientes que coincidan con "$_busqueda".'
                              : 'Sin clientes que mostrar.',
                          style: TextStyle(color: colorScheme.onSurfaceVariant),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () => _cargarPagina(reset: true),
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: _visibles.length + (_hayMas ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == _visibles.length) {
                              return const Padding(
                                padding: EdgeInsets.all(16),
                                child: Center(child: CircularProgressIndicator()),
                              );
                            }
                            final cliente = _visibles[index];
                            return _FilaCliente(
                              cliente: cliente,
                              onTap: () => _abrirDetalle(cliente),
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

class _FilaCliente extends StatelessWidget {
  final Cliente cliente;
  final VoidCallback onTap;

  const _FilaCliente({
    required this.cliente,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: colorScheme.primaryContainer,
                child: Icon(Icons.business, color: colorScheme.onPrimaryContainer),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cliente.nombreComercial.isNotEmpty ? cliente.nombreComercial : '—',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (cliente.cif.isNotEmpty) ...[
                          Icon(Icons.badge_outlined, size: 14, color: colorScheme.onSurfaceVariant),
                          const SizedBox(width: 4),
                          Text(
                            cliente.cif,
                            style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
                          ),
                          const SizedBox(width: 12),
                        ],
                        if (cliente.telefono.isNotEmpty) ...[
                          Icon(Icons.phone_outlined, size: 14, color: colorScheme.onSurfaceVariant),
                          const SizedBox(width: 4),
                          Text(
                            cliente.telefono,
                            style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                size: 20,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

