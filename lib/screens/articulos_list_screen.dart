import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:diacritic/diacritic.dart';
import 'package:flutter/material.dart';

import '../core/articulos_service.dart';
import '../core/config.dart';
import '../core/formatters.dart';
import '../models/articulo.dart';
import '../theme/app_theme.dart';

class ArticulosListScreen extends StatefulWidget {
  const ArticulosListScreen({super.key});

  @override
  State<ArticulosListScreen> createState() => _ArticulosListScreenState();
}

class _ArticulosListScreenState extends State<ArticulosListScreen> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  Timer? _searchDebounce;

  List<Articulo> _todos = [];
  List<Articulo> _visibles = [];
  bool _cargando = true;
  bool _cargandoPagina = false;
  bool _hayMas = true;
  int _pagina = 1;
  int _totalArticulos = 0;
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

    final filtrados = _todos.where((art) {
      if (tokens.isEmpty) return true;

      final nombre = removeDiacritics(art.nombre.toLowerCase());
      final ref = removeDiacritics(art.referencia.toLowerCase());
      final cod = removeDiacritics(art.codigo.toLowerCase());
      final codBar = removeDiacritics(art.codigoBarras.toLowerCase());
      final searchable = '$nombre $ref $cod $codBar';

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
      _totalArticulos = 0;
      _hayMas = true;
    }

    setState(() {
      _cargandoPagina = true;
      if (reset) _cargando = true;
    });

    try {
      final resultado = await ArticulosService.list(
        page: _pagina,
        pageSize: AppConfig.pageSize,
      );

      if (!mounted) return;

      final nuevos = reset
          ? resultado.items
          : [..._todos, ...resultado.items];

      _pagina++;
      _totalArticulos = resultado.total;
      _hayMas = _totalArticulos > 0
          ? nuevos.length < _totalArticulos
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
        SnackBar(content: Text('Error al cargar artículos: $e')),
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

  void _abrirDetalle(Articulo articulo) {
    Navigator.of(context).pushNamed('/articulo', arguments: articulo);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Artículos'),
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
                      hintText: 'Buscar por nombre o referencia...',
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

          // Contador de artículos
          if (_visibles.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 2),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${_visibles.length} ${_visibles.length == 1 ? 'artículo' : 'artículos'}${_busqueda.trim().isNotEmpty && _hayMas ? ' (buscando más...)' : ''}',
                  style: TextStyle(
                    fontSize: 11,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),

          // Lista de artículos
          Expanded(
            child: (_estaCargandoOBuscando && _visibles.isEmpty)
                ? const Center(child: CircularProgressIndicator())
                : _visibles.isEmpty
                    ? Center(
                        child: Text(
                          _busqueda.trim().isNotEmpty
                              ? 'Sin artículos que coincidan con "$_busqueda".'
                              : 'Sin artículos que mostrar.',
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
                            final articulo = _visibles[index];
                            return _FilaArticulo(
                              articulo: articulo,
                              onTap: () => _abrirDetalle(articulo),
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

class _FilaArticulo extends StatelessWidget {
  final Articulo articulo;
  final VoidCallback onTap;

  const _FilaArticulo({
    required this.articulo,
    required this.onTap,
  });

  Uint8List? _decodeThumbnail(String raw) {
    if (raw.trim().isEmpty) return null;
    try {
      final clean = raw.contains(',') ? raw.split(',').last : raw;
      return base64Decode(clean.trim());
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final imageBytes = _decodeThumbnail(articulo.imagen);
    final isUrl = Uri.tryParse(articulo.imagen)?.isAbsolute == true;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Miniatura de la imagen
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colorScheme.outlineVariant),
                ),
                alignment: Alignment.center,
                child: imageBytes != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(7),
                        child: Image.memory(
                          imageBytes,
                          width: 54,
                          height: 54,
                          fit: BoxFit.cover,
                        ),
                      )
                    : isUrl
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(7),
                            child: Image.network(
                              articulo.imagen,
                              width: 54,
                              height: 54,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Icon(
                                Icons.inventory_2_outlined,
                                color: colorScheme.onSurfaceVariant,
                                size: 24,
                              ),
                            ),
                          )
                        : Icon(
                            Icons.inventory_2_outlined,
                            color: colorScheme.onSurfaceVariant,
                            size: 24,
                          ),
              ),
              const SizedBox(width: 12),

              // Información del artículo (Nombre + Referencia + Código de barras)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      articulo.nombre.isNotEmpty ? articulo.nombre : '—',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (articulo.referencia.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Ref: ${articulo.referencia}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                        if (articulo.desactivado) ...[
                          if (articulo.referencia.isNotEmpty) const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Desactivado',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.red,
                              ),
                            ),
                          ),
                        ],
                        if ((articulo.referencia.isNotEmpty || articulo.desactivado) &&
                            articulo.codigoBarras.isNotEmpty)
                          const SizedBox(width: 6),
                        if (articulo.codigoBarras.isNotEmpty)
                          Flexible(
                            child: Text(
                              articulo.codigoBarras,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Precio (PVP)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${formatNumber(articulo.precio)} €',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
