import 'package:flutter/material.dart';

import '../core/articulos_service.dart';
import '../core/formatters.dart';
import '../models/models.dart';
import '../models/movimiento.dart';
import '../theme/app_theme.dart';

class LineaDetailScreen extends StatefulWidget {
  final LineaPedido linea;

  const LineaDetailScreen({super.key, required this.linea});

  @override
  State<LineaDetailScreen> createState() => _LineaDetailScreenState();
}

class _LineaDetailScreenState extends State<LineaDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  final List<Movimiento> _movimientos = [];
  bool _cargandoMovimientos = false;
  bool _hayMasMovs = true;
  int _pageMovs = 1;
  final ScrollController _scrollControllerMovs = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _scrollControllerMovs.addListener(_onScrollMovs);
    if (widget.linea.articulo.isNotEmpty) {
      _cargarMovimientos();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollControllerMovs.dispose();
    super.dispose();
  }

  void _onScrollMovs() {
    if (_scrollControllerMovs.position.pixels >= _scrollControllerMovs.position.maxScrollExtent - 200) {
      if (!_cargandoMovimientos && _hayMasMovs) {
        _cargarMovimientos();
      }
    }
  }

  Future<void> _cargarMovimientos() async {
    if (!_hayMasMovs || _cargandoMovimientos) return;
    setState(() => _cargandoMovimientos = true);
    
    // El artículo guardado en LineaPedido.articulo es el ID (código).
    final res = await ArticulosService.getMovimientosArticulo(
      articuloId: widget.linea.articulo,
      page: _pageMovs,
      pageSize: 50,
    );
    
    if (mounted) {
      setState(() {
        _cargandoMovimientos = false;
        _movimientos.addAll(res.items);
        if (res.items.length < 50 || res.items.isEmpty) {
          _hayMasMovs = false;
        } else {
          _pageMovs++;
        }
      });
    }
  }

  Widget _buildInfoBox(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(title, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color.withValues(alpha: 0.9))),
        ],
      ),
    );
  }

  Widget _buildMiniDato(String title, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildDetalleTab() {
    final l = widget.linea;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Card (Artículo y Descripción)
          Card(
            elevation: 0,
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.inventory_2_outlined, color: Theme.of(context).colorScheme.onPrimaryContainer, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l.articuloNombre.isNotEmpty ? l.articuloNombre : l.articulo,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Cód: ${l.articulo}',
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (l.descripcion.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 12),
                    Text(
                      'Descripción',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
                    ),
                    const SizedBox(height: 4),
                    Text(l.descripcion, style: const TextStyle(fontSize: 15)),
                  ],
                  if (l.nReferencia.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.tag, size: 16, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text('Ref: ${l.nReferencia}', style: const TextStyle(fontSize: 14)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Row of info blocks
          Row(
            children: [
              Expanded(
                child: _buildInfoBox('Cantidad', formatNumber(l.cantidad), Icons.numbers, AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInfoBox('Estado', AppColors.estadoLabel(l.estado), Icons.info_outline, AppColors.estadoColor(l.estado)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Economicos Card
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Datos Económicos', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildMiniDato('Precio', '${formatNumber(l.precio)} €'),
                      _buildMiniDato('IVA', '${formatNumber(l.tipoIva)} %'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildMiniDato('% Dto.', '${formatNumber(l.dto)} %'),
                      _buildMiniDato('% dto 1', '${formatNumber(l.dto1)} %'),
                      _buildMiniDato('% dto 2', '${formatNumber(l.dto2)} %'),
                      _buildMiniDato('% dto 3', '${formatNumber(l.dto3)} %'),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Divider(),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Importe Total',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                      Text(
                        '${formatNumber(l.importe)} €',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          if (l.previstoPara.isNotEmpty) ...[
            const SizedBox(height: 12),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ListTile(
                leading: const Icon(Icons.calendar_today, color: AppColors.primary),
                title: const Text('Entrega prevista'),
                subtitle: Text(l.previstoPara, style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBaseConocimientoTab() {
    if (_cargandoMovimientos && _movimientos.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_movimientos.isEmpty) {
      return Center(
        child: Text(
          'No hay movimientos para este artículo.',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollControllerMovs,
      padding: const EdgeInsets.all(8),
      itemCount: _movimientos.length + (_hayMasMovs ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _movimientos.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final m = _movimientos[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '${m.articuloRef} - ${m.articuloNombre}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      formatDate(m.fecha),
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Entrada: ${formatNumber(m.entrada)}'),
                    Text('Salida: ${formatNumber(m.salida)}'),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Precio: ${formatNumber(m.precio)} €'),
                    Text('Nº Doc: ${m.numDoc}'),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle de Línea'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Detalle'),
            Tab(text: 'Histórico de Ventas'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDetalleTab(),
          _buildBaseConocimientoTab(),
        ],
      ),
    );
  }
}
