import 'package:flutter/material.dart';

import '../core/api_service.dart';
import '../core/clientes_service.dart';
import '../core/formatters.dart';
import '../models/models.dart';
import '../models/movimiento.dart';

class ClienteDetailScreen extends StatefulWidget {
  const ClienteDetailScreen({super.key});

  @override
  State<ClienteDetailScreen> createState() => _ClienteDetailScreenState();
}

class _ClienteDetailScreenState extends State<ClienteDetailScreen> {
  late Cliente _cliente;
  bool _initialized = false;

  bool _cargandoDirecciones = true;
  String _direccionPorDefecto = 'Sin dirección';

  final _scrollControllerMovs = ScrollController();
  bool _cargandoMovimientos = true;
  bool _cargandoPaginaMovs = false;
  bool _hayMasMovs = true;
  int _paginaMovs = 1;
  List<Movimiento> _movimientos = [];

  @override
  void initState() {
    super.initState();
    _scrollControllerMovs.addListener(_onScrollMovs);
  }

  @override
  void dispose() {
    _scrollControllerMovs.dispose();
    super.dispose();
  }

  void _onScrollMovs() {
    if (_scrollControllerMovs.position.extentAfter < 400) {
      _cargarMovimientosPagina();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _cliente = ModalRoute.of(context)!.settings.arguments as Cliente;
      _initialized = true;
      _cargarDatosAdicionales();
    }
  }

  Future<void> _cargarDatosAdicionales() async {
    // Cargar dirección por defecto
    try {
      final direcciones = await PedidosService.getDireccionesCliente(_cliente.id);
      if (direcciones.isNotEmpty) {
        OpcionMaestra? dirPri;
        if (_cliente.dirPriId > 0) {
          try {
            dirPri = direcciones.firstWhere((d) => d.codigo == _cliente.dirPriId.toString());
          } catch (_) {}
        }
        dirPri ??= direcciones.first;
        _direccionPorDefecto = dirPri.nombre;
      }
    } catch (e) {
      debugPrint('Error al cargar direcciones: $e');
    }
    if (mounted) {
      setState(() => _cargandoDirecciones = false);
    }

    await _cargarMovimientosPagina(reset: true);
  }

  Future<void> _cargarMovimientosPagina({bool reset = false}) async {
    if (_cargandoPaginaMovs || (!reset && !_hayMasMovs)) return;

    if (reset) {
      _paginaMovs = 1;
      _hayMasMovs = true;
    }

    setState(() {
      _cargandoPaginaMovs = true;
      if (reset) _cargandoMovimientos = true;
    });

    try {
      final resultado = await ClientesService.getMovimientosCliente(
        clienteId: _cliente.id.toString(),
        page: _paginaMovs,
        pageSize: 50,
      );

      if (!mounted) return;

      final nuevos = reset ? resultado.items : [..._movimientos, ...resultado.items];

      _paginaMovs++;
      _hayMasMovs = resultado.total > 0
          ? nuevos.length < resultado.total
          : resultado.items.length >= 50;
      
      setState(() {
        _movimientos = nuevos;
        _cargandoMovimientos = false;
        _cargandoPaginaMovs = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargandoMovimientos = false;
        _cargandoPaginaMovs = false;
      });
    }
  }

  Widget _buildSeccionInfo(String titulo, String valor, IconData icono) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 20, color: colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  valor.isEmpty ? '—' : valor,
                  style: TextStyle(
                    fontSize: 15,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDatosTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSeccionInfo('Nombre Comercial', _cliente.nombreComercial, Icons.business),
              _buildSeccionInfo('Nombre Fiscal', _cliente.nombreFiscal, Icons.account_balance),
              _buildSeccionInfo('NIF / CIF', _cliente.cif, Icons.badge),
              _buildSeccionInfo('Email', _cliente.email, Icons.email),
              _buildSeccionInfo('Teléfono', _cliente.telefono, Icons.phone),
              if (_cargandoDirecciones)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                _buildSeccionInfo('Dirección Principal', _direccionPorDefecto, Icons.location_on),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBaseConocimientoTab() {
    if (_cargandoMovimientos) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_movimientos.isEmpty) {
      return Center(
        child: Text(
          'No hay movimientos para este cliente.',
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
    if (!_initialized) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _cliente.nombreComercial.isNotEmpty ? _cliente.nombreComercial : 'Cliente',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Datos', icon: Icon(Icons.info_outline)),
              Tab(text: 'Base de conocimiento', icon: Icon(Icons.menu_book)),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildDatosTab(),
            _buildBaseConocimientoTab(),
          ],
        ),
      ),
    );
  }
}
