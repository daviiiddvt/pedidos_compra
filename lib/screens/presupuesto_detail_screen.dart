import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/licencia/licencia_service.dart';
import '../models/models.dart';
import '../core/presupuesto_service.dart';
import '../core/formatters.dart';
import '../theme/app_theme.dart';
import '../widgets/cabecera_view.dart';
import '../widgets/estado_badge.dart';
import '../widgets/lineas_table.dart';
import '../widgets/segment_tabs.dart';
import '../widgets/totales_card.dart';
import '../core/offline/connection_status_service.dart';
import '../core/offline/offline_database.dart';
import '../core/offline/offline_outbox_service.dart';

class PresupuestoDetailScreen extends StatefulWidget {
  final dynamic presupuestoId;

  const PresupuestoDetailScreen({super.key, required this.presupuestoId});

  @override
  State<PresupuestoDetailScreen> createState() =>
      _PresupuestoDetailScreenState();
}

class _PresupuestoDetailScreenState extends State<PresupuestoDetailScreen> {
  PresupuestoVenta? _presupuesto;
  bool _cargando = true;
  late final PageController _pageController;
  int _tabIndex = 0;
  static const _tabs = ['cabecera', 'lineas', 'totales'];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _cargar();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    try {
      final presupuestoRecibido = await PresupuestosService.getById(widget.presupuestoId);
      if (mounted) {
        setState(() {
          _presupuesto = presupuestoRecibido;
          _cargando = false;
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _cargando = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  Future<void> _convertirAPedidoOffline({
    required PresupuestoVenta presupuesto,
    required Pedido pedidoVisual,
    required ScaffoldMessengerState messenger,
    required NavigatorState navigator,
  }) async {
    final tempPedidoId = -(DateTime.now().millisecondsSinceEpoch % 1000000000);
    final nuevoPedidoOffline = pedidoVisual.copyWith(
      id: tempPedidoId,
      codigo: tempPedidoId,
      nDocumento: 0,
      numeroPedido: 'OFFLINE-${tempPedidoId.abs()}',
      numeroPresupuesto: presupuesto.numeroPresupuesto.isNotEmpty
          ? presupuesto.numeroPresupuesto
          : '${presupuesto.id}',
      fecha: todayIso(),
      estado: 'P',
      lineas: pedidoVisual.lineas
          .map((l) => l.copyWith(id: null))
          .toList(),
    );

    // 1. Guardar nuevo pedido en SQLite y cola Outbox
    await OfflineDatabase.instance.savePedidoOfflineOutbox(
      pedido: nuevoPedidoOffline,
      accion: 'crear',
    );

    // 2. Enlazar presupuesto con el pedido y marcar aceptado en SQLite
    await OfflineDatabase.instance.linkPedidoPresupuestoOffline(
      presupuesto.id,
      tempPedidoId,
    );
    await PresupuestosService.marcarAceptado(presupuesto.id);
    await OfflineOutboxService.instance.refreshPendingCount();

    if (!mounted) return;
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Presupuesto aceptado. Pedido creado y pendiente de subir.'),
      ),
    );
    _cargar();

    await navigator.pushNamed(
      '/pedido/form',
      arguments: nuevoPedidoOffline,
    );
    if (mounted) _cargar();
  }

  @override
  Widget build(BuildContext context) {
    final presupuesto = _presupuesto;
    final pedidoVisual = presupuesto?.toPedidoVisual();
    final licService = context.watch<LicenciaService>();
    final puedeEditar = presupuesto != null &&
      AppColors.estadoCodigo(presupuesto.estado) != 'A' &&
      !licService.esSoloLec;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          presupuesto == null ||
                  (presupuesto.numeroPresupuesto.isEmpty &&
                      (presupuesto.id == null || presupuesto.id == 0))
              ? 'Presupuesto'
              : (presupuesto.numeroPresupuesto.isNotEmpty
                  ? 'Presupuesto ${presupuesto.numeroPresupuesto}'
                  : 'Presupuesto ${presupuesto.id}'),
        ),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : presupuesto == null || pedidoVisual == null
              ? const Center(child: Text('No se encontró el presupuesto'))
              : Column(
                  children: [
                    _resumen(presupuesto),
                    SegmentTabs(
                      tabs: [
                        (key: 'cabecera', label: 'Cabecera'),
                        (
                          key: 'lineas',
                          label: 'Líneas (${presupuesto.lineas.length})',
                        ),
                        (key: 'totales', label: 'Totales'),
                      ],
                      active: _tabs[_tabIndex],
                      onChanged: (key) {
                        final idx = _tabs.indexOf(key);
                        if (idx != -1 && _pageController.hasClients) {
                          _pageController.animateToPage(
                            idx,
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeInOut,
                          );
                        }
                      },
                    ),
                    Expanded(
                      child: PageView(
                        controller: _pageController,
                        onPageChanged: (index) {
                          setState(() => _tabIndex = index);
                        },
                        children: [
                          CabeceraView(
                            pedido: pedidoVisual,
                            mostrarAlmacen: false,
                            mostrarFechaEntrega: false,
                            mostrarEmail: true,
                            mostrarFechaValidez: true,
                            mostrarNumeroPresupuesto: true,
                          ),
                          LineasTable(
                            lineas: pedidoVisual.lineas,
                            clienteId: presupuesto.clienteId > 0
                                ? presupuesto.clienteId.toString()
                                : (presupuesto.cliente.isNotEmpty
                                    ? presupuesto.cliente
                                    : (pedidoVisual.clienteId > 0
                                        ? pedidoVisual.clienteId.toString()
                                        : pedidoVisual.cliente)),
                            clienteNombre: presupuesto.clienteNombre.isNotEmpty
                                ? presupuesto.clienteNombre
                                : pedidoVisual.clienteNombre,
                          ),
                          SingleChildScrollView(
                            padding: const EdgeInsets.all(12),
                            child: TotalesCard(
                              base: calcularTotales(pedidoVisual.lineas).base,
                              iva: calcularTotales(pedidoVisual.lineas).iva,
                              total: calcularTotales(pedidoVisual.lineas).total,
                              labelTotal: 'Total Presupuesto',
                            ),
                          ),
                        ],
                      ),
                    ),
                    Material(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: SafeArea(
                        top: false,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: puedeEditar ? () async {
                                    await Navigator.of(context).pushNamed(
                                      '/presupuesto/form',
                                      arguments: presupuesto,
                                    );
                                    if (mounted) _cargar();
                                  } : null,
                                  icon: const Icon(Icons.edit),
                                  label: Text(puedeEditar ? 'Editar' : 'ACEPTADO'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: licService.esSoloLec ? null : () async {
                                    if (presupuesto.vtaPedG > 0 ||
                                      AppColors.estadoCodigo(presupuesto.estado) == 'A') {
                                      showDialog(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: const Text('Aviso'),
                                          content: const Text(
                                            'Este presupuesto ya ha sido aceptado o convertido a un pedido de venta previamente y no puede volver a convertirse.',
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.of(ctx).pop(),
                                              child: const Text('Aceptar'),
                                            ),
                                          ],
                                        ),
                                      );
                                      return;
                                    }

                                    final messenger = ScaffoldMessenger.of(context);
                                    final navigator = Navigator.of(context);

                                    try {
                                      final isOnline = ConnectionStatusService.instance.isOnline;
                                      if (!isOnline) {
                                        await _convertirAPedidoOffline(
                                          presupuesto: presupuesto,
                                          pedidoVisual: pedidoVisual,
                                          messenger: messenger,
                                          navigator: navigator,
                                        );
                                      } else {
                                        try {
                                          await PresupuestosService.marcarAceptado(
                                            presupuesto.id,
                                          );
                                          if (!mounted) return;
                                          messenger.showSnackBar(
                                            const SnackBar(
                                              content: Text('Presupuesto aceptado'),
                                            ),
                                          );
                                          _cargar();

                                          await navigator.pushNamed(
                                            '/pedido/form',
                                            arguments: pedidoVisual.copyWith(
                                              fecha: todayIso(),
                                              codigo: 0,
                                              numeroPedido: '',
                                              estado: 'P',
                                              lineas: pedidoVisual.lineas
                                                  .map((l) => l.copyWith(id: null))
                                                  .toList(),
                                            ),
                                          );
                                          if (mounted) _cargar();
                                        } catch (e) {
                                          // Si falla la conexión online, recurrir al flujo offline
                                          debugPrint('Fallo online en A Pedido, usando fallback offline: $e');
                                          await _convertirAPedidoOffline(
                                            presupuesto: presupuesto,
                                            pedidoVisual: pedidoVisual,
                                            messenger: messenger,
                                            navigator: navigator,
                                          );
                                        }
                                      }
                                    } catch (e) {
                                      if (!mounted) return;
                                      messenger.showSnackBar(
                                        SnackBar(
                                          content: Text('Error al procesar presupuesto: $e'),
                                          backgroundColor: AppColors.error,
                                        ),
                                      );
                                    }
                                  },
                                  icon: const Icon(Icons.shopping_cart_checkout),
                                  label: Text(
                                    (presupuesto.vtaPedG > 0 ||
                                            presupuesto.estado == 'A')
                                        ? 'Aceptado'
                                        : 'A Pedido',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  /// _resumen: bloque superior idéntico en estructura y alineación al de pedidos.
  Widget _resumen(PresupuestoVenta presupuesto) {
    final numeroPresupuesto = presupuesto.numeroPresupuesto.isNotEmpty
        ? presupuesto.numeroPresupuesto
        : (presupuesto.id != null ? '#${presupuesto.id}' : '');

    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Etiqueta azul con el código/número de presupuesto
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Nº de presupuesto: $numeroPresupuesto',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Etiqueta de color según el estado
              EstadoBadge(estado: presupuesto.estado),
            ],
          ),
          const SizedBox(height: 8),

          // Cliente: el nombre si lo hay; si no, el código; si no, "Sin cliente".
          Text(
            presupuesto.clienteNombre.isNotEmpty
                ? presupuesto.clienteNombre
                : (presupuesto.cliente.isNotEmpty
                    ? presupuesto.cliente
                    : 'Sin cliente'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),

          // Fecha y Pedido asociado (si lo hay)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (presupuesto.fecha.isNotEmpty)
                Text(
                  'Fecha: ${formatDate(presupuesto.fecha)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                )
              else
                const SizedBox.shrink(),
              if (presupuesto.vtaPedG > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Pedido asociado: ${presupuesto.vtaPedG}',
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

