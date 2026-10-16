import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../core/articulos_service.dart';
import '../core/formatters.dart';
import '../models/articulo.dart';
import '../models/tarifa_articulo.dart';

class ArticuloDetailScreen extends StatefulWidget {
  final Articulo? initialArticulo;
  final String? articuloId;

  const ArticuloDetailScreen({
    super.key,
    this.initialArticulo,
    this.articuloId,
  });

  @override
  State<ArticuloDetailScreen> createState() => _ArticuloDetailScreenState();
}

class _ArticuloDetailScreenState extends State<ArticuloDetailScreen> {
  Articulo? _articulo;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _articulo = widget.initialArticulo;
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargarDetalle());
  }

  Future<void> _cargarDetalle() async {
    final routeArg = ModalRoute.of(context)?.settings.arguments;
    String id = widget.articuloId ?? '';
    Articulo? art = _articulo;

    if (routeArg is Articulo) {
      art = routeArg;
      id = art.id.isNotEmpty ? art.id : art.codigo;
    } else if (routeArg is String && routeArg.isNotEmpty) {
      id = routeArg;
    }

    if (art != null) {
      setState(() {
        _articulo = art;
        _cargando = false;
      });
      // Completar familia y proveedor si faltan los nombres
      await _completarRelaciones(art);
      return;
    }

    if (id.isNotEmpty) {
      setState(() => _cargando = true);
      final fetched = await ArticulosService.getById(id);
      if (mounted) {
        setState(() {
          _articulo = fetched;
          _cargando = false;
        });
      }
    } else {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _completarRelaciones(Articulo art) async {
    String famNombre = art.familiaNombre;
    String prvNombre = art.proveedorNombre;
    bool cambio = false;

    if (famNombre.isEmpty && art.familiaId.isNotEmpty) {
      famNombre = await ArticulosService.getFamiliaNombre(art.familiaId);
      cambio = true;
    }
    if (prvNombre.isEmpty && art.proveedorId.isNotEmpty) {
      prvNombre = await ArticulosService.getProveedorNombre(art.proveedorId);
      cambio = true;
    }

    if (cambio && mounted) {
      setState(() {
        _articulo = _articulo?.copyWith(
          familiaNombre: famNombre,
          proveedorNombre: prvNombre,
        );
      });
    }
  }

  Uint8List? _decodeImage(String raw) {
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
    final art = _articulo;

    if (_cargando) {
      return Scaffold(
        appBar: AppBar(title: const Text('Cargando...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (art == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detalle de Artículo')),
        body: Center(
          child: Text(
            'No se pudo encontrar la información del artículo.',
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
        ),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            art.nombre.isNotEmpty ? art.nombre : 'Detalle de Artículo',
          ),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Datos'),
              Tab(text: 'Tarifas de Venta'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildTabDatos(art, colorScheme),
            _TabTarifas(articuloId: art.id.isNotEmpty ? art.id : art.codigo),
          ],
        ),
      ),
    );
  }

  Widget _buildTabDatos(Articulo art, ColorScheme colorScheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ---- Imagen del artículo (Campo IMG) ----
          _buildImageCard(art.imagen, colorScheme),
          const SizedBox(height: 16),

          // ---- Formulario con los datos del artículo ----
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: colorScheme.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'INFORMACIÓN DEL ARTÍCULO',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.primary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  if (art.desactivado) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.block, size: 16, color: Colors.red),
                          SizedBox(width: 8),
                          Text(
                            'Artículo desactivado (OFF = 1)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),

                  // N/Referencia: Campo REF en la tabla ART_M
                  _DatoFila(
                    icon: Icons.tag,
                    label: 'N/Referencia',
                    valor: art.referencia.isNotEmpty ? art.referencia : '—',
                  ),
                  const Divider(height: 20),

                  // Nombre: Campo NAME en la tabla ART_M
                  _DatoFila(
                    icon: Icons.inventory_2_outlined,
                    label: 'Nombre',
                    valor: art.nombre.isNotEmpty ? art.nombre : '—',
                  ),
                  const Divider(height: 20),

                  // Familia: Campo maestro FAM en ART_M (FAM_M)
                  _DatoFila(
                    icon: Icons.category_outlined,
                    label: 'Familia',
                    valor: art.familiaNombre.isNotEmpty
                        ? (art.familiaId.isNotEmpty && art.familiaId != art.familiaNombre
                            ? '${art.familiaNombre} (${art.familiaId})'
                            : art.familiaNombre)
                        : (art.familiaId.isNotEmpty ? art.familiaId : '—'),
                  ),
                  const Divider(height: 20),

                  // Proveedor: Campo PRV en ART_M (ENT_M)
                  _DatoFila(
                    icon: Icons.business_outlined,
                    label: 'Proveedor',
                    valor: art.proveedorNombre.isNotEmpty
                        ? (art.proveedorId.isNotEmpty && art.proveedorId != art.proveedorNombre
                            ? '${art.proveedorNombre} (${art.proveedorId})'
                            : art.proveedorNombre)
                        : (art.proveedorId.isNotEmpty ? art.proveedorId : '—'),
                  ),
                  const Divider(height: 20),

                  // Código de barras: Campo COD_BAR en ART_M
                  _DatoFila(
                    icon: Icons.qr_code_scanner,
                    label: 'Código de barras',
                    valor: art.codigoBarras.isNotEmpty ? art.codigoBarras : '—',
                  ),
                  const Divider(height: 20),

                  // Precio: Campo PVP en ART_M
                  _DatoFila(
                    icon: Icons.euro,
                    label: 'Precio',
                    valor: '${formatNumber(art.precio)} €',
                    destacada: true,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageCard(String imagenRaw, ColorScheme colorScheme) {
    final imageBytes = _decodeImage(imagenRaw);
    final isUrl = Uri.tryParse(imagenRaw)?.isAbsolute == true;

    return Container(
      constraints: const BoxConstraints(minHeight: 200, maxHeight: 320),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      alignment: Alignment.center,
      child: imageBytes != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: Image.memory(
                imageBytes,
                width: double.infinity,
                fit: BoxFit.contain,
              ),
            )
          : isUrl
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(11),
                  child: Image.network(
                    imagenRaw,
                    width: double.infinity,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => _placeholderIcon(colorScheme),
                  ),
                )
              : _placeholderIcon(colorScheme),
    );
  }

  Widget _placeholderIcon(ColorScheme colorScheme) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.image_not_supported_outlined,
          size: 56,
          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
        ),
        const SizedBox(height: 8),
        Text(
          'Sin imagen disponible',
          style: TextStyle(
            fontSize: 13,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _DatoFila extends StatelessWidget {
  final IconData icon;
  final String label;
  final String valor;
  final bool destacada;

  const _DatoFila({
    required this.icon,
    required this.label,
    required this.valor,
    this.destacada = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 20,
          color: destacada ? colorScheme.primary : colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                valor,
                style: TextStyle(
                  fontSize: destacada ? 17 : 15,
                  fontWeight: destacada ? FontWeight.bold : FontWeight.w500,
                  color: destacada ? colorScheme.primary : colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TabTarifas extends StatefulWidget {
  final String articuloId;

  const _TabTarifas({required this.articuloId});

  @override
  State<_TabTarifas> createState() => _TabTarifasState();
}

class _TabTarifasState extends State<_TabTarifas> {
  bool _cargando = true;
  List<TarifaArticulo> _tarifas = [];

  @override
  void initState() {
    super.initState();
    _cargarTarifas();
  }

  Future<void> _cargarTarifas() async {
    final tarifas = await ArticulosService.getTarifasArticulo(widget.articuloId);
    if (mounted) {
      setState(() {
        _tarifas = tarifas;
        _cargando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_tarifas.isEmpty) {
      return Center(
        child: Text(
          'No hay tarifas de venta configuradas para este artículo.',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _tarifas.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final tarifa = _tarifas[index];
        return Card(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tarifa: ${tarifa.tarifaNombre.isNotEmpty ? tarifa.tarifaNombre : (tarifa.tarifaId.isNotEmpty ? tarifa.tarifaId : 'Desconocida')}',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Precio: ${formatNumber(tarifa.precio, decimals: 3)} €',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary, 
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      'Dto.: ${formatNumber(tarifa.descuento, decimals: 3)}%',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: tarifa.descuento > 0 ? Colors.green : Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
