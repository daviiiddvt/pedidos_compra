import 'package:flutter/material.dart';

import '../models/models.dart';
import '../core/presupuesto_service.dart';
import '../core/formatters.dart';
import '../theme/app_theme.dart';
import '../widgets/cabecera_view.dart';
import '../widgets/estado_badge.dart';
import '../widgets/lineas_table.dart';
import '../widgets/segment_tabs.dart';
import '../widgets/totales_card.dart';

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
  String _tab = 'cabecera';

  @override
  void initState() {
    super.initState();
    _cargar();
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

  @override
  Widget build(BuildContext context) {
    final presupuesto = _presupuesto;
    final pedidoVisual = presupuesto?.toPedidoVisual();
    final puedeEditar = presupuesto != null &&
      AppColors.estadoCodigo(presupuesto.estado) != 'A';

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
                      active: _tab,
                      onChanged: (tab) => setState(() => _tab = tab),
                    ),
                    Expanded(
                      child: switch (_tab) {
                        'lineas' => LineasTable(lineas: pedidoVisual.lineas),
                        'totales' => SingleChildScrollView(
                            padding: const EdgeInsets.all(12),
                            child: TotalesCard(
                              base: calcularTotales(pedidoVisual.lineas).base,
                              iva: calcularTotales(pedidoVisual.lineas).iva,
                              total: calcularTotales(pedidoVisual.lineas).total,
                              labelTotal: 'Total Presupuesto',
                            ),
                          ),
                        _ => CabeceraView(
                            pedido: pedidoVisual,
                            mostrarAlmacen: false,
                            mostrarFechaEntrega: false,
                            mostrarEmail: true,
                            mostrarFechaValidez: true,
                            mostrarNumeroPresupuesto: true,
                          ),
                      },
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
                                  onPressed: () async {
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

                                    // Marcamos el presupuesto como aceptado en Velneo
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Etiqueta azul con el código/número de presupuesto
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Nº de presupuesto: $numeroPresupuesto',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
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

