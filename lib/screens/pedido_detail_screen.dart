// ============================================================================
//  pedido_detail_screen.dart  —  DETALLE DE UN PEDIDO (ver un solo pedido)
// ============================================================================
//
//  ¿Qué es?
//  --------
//  Muestra toda la información de UN pedido. Está dividido en 3 pestañas:
//     - Cabecera → los datos generales (proveedor, fecha, serie...).
//     - Líneas  → la lista de artículos con el botón para editarlo.
//     - Totales → la suma de bases, IVA y total.
//  Al llegar, pide al servidor el detalle completo (PedidosService.getById).
//
//  CONCEPTOS FLUTTER QUE APARECEN:
//  - widget.pedidoId: accedemos al parámetro que nos pasó la ruta (main.dart).
//  - switch (_tab): "expresión switch" (Dart moderno) que elige qué dibujar.
//  - mounted: false si la pantalla ya se cerró; evita errores al usar setState.
// ============================================================================

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/licencia/licencia_service.dart';
import '../core/api_service.dart'; // PedidosService (pedir el detalle).
import '../models/models.dart'; // Modelos y cálculo de totales.
import '../theme/app_theme.dart'; // Colores.
import '../core/formatters.dart'; // formatDate (fecha en formato español).
import '../widgets/segment_tabs.dart'; // Las pestañas (Cabecera/Líneas/Totales).
import '../widgets/cabecera_view.dart'; // Vista de la cabecera del pedido.
import '../widgets/lineas_table.dart'; // Tabla con las líneas.
import '../widgets/totales_card.dart'; // Tarjeta de totales.
import '../widgets/estado_badge.dart'; // "Etiqueta" de color con el estado.
import '../widgets/pedido_foto_tab.dart';
import '../core/offline/connection_status_service.dart';
import '../core/offline/offline_outbox_service.dart';


/// PedidoDetailScreen: pantalla de DETALLE (no se edita aquí, solo se ve).
class PedidoDetailScreen extends StatefulWidget {
  final dynamic pedidoId; // Id del pedido a mostrar (lo manda la lista).

  const PedidoDetailScreen({super.key, required this.pedidoId});

  @override
  State<PedidoDetailScreen> createState() => _PedidoDetailScreenState();
}

class _PedidoDetailScreenState extends State<PedidoDetailScreen> {
  Pedido? _pedido; // El pedido cargado (null mientras carga o si falla).
  bool _cargando = true; // ¿Estamos pidiendo el detalle?
  bool _confirmando = false;
  late final PageController _pageController;
  int _tabIndex = 0;
  static const _tabs = ['cabecera', 'lineas', 'totales', 'foto'];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _cargar(); // Nada más nacer, pedimos el detalle.
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// _cargar: pide la información completa del pedido al servidor.
  Future<void> _cargar() async {
    try {
      final pedido = await PedidosService.getById(widget.pedidoId);
      if (!mounted) return;
      setState(() {
        _pedido = pedido;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _cargando = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  /// build: pantalla = barra + (spinner | error | contenido).
  @override
  Widget build(BuildContext context) {
    final pedido = _pedido;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        // Título: "Pedido 123" si tiene código, si no simplemente "Pedido".
        title: Text(
          pedido != null && pedido.codigo != 0
              ? 'Pedido ${pedido.numeroPedido}'
              : 'Pedido',
        ),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator()) // Mientras carga.
          : pedido == null
              ? const Center(child: Text('No se encontró el pedido')) // Fallo.
              : _buildContenido(pedido), // ¡Todo bien! Mostramos el contenido.
    );
  }

  /// _buildContenido: el cuerpo completo cuando ya tenemos los datos.
  Widget _buildContenido(Pedido pedido) {
    final lineas = pedido.lineas;
    final totales = calcularTotales(lineas); // Sumamos todas las líneas.
    final licService = context.watch<LicenciaService>();
    final esServido = AppColors.estadoCodigo(pedido.estado) == 'S';
    final esConfirmado = pedido.conKyr;
    final puedeEditar = !esServido && !esConfirmado && !licService.esSoloLec;

    String labelEditar = 'Editar';
    if (!puedeEditar) {
      if (esConfirmado) {
        labelEditar = 'CONFIRMADO';
      } else if (esServido) {
        labelEditar = 'SERVIDO';
      } else {
        labelEditar = 'Solo lectura';
      }
    }

    return Column(
      children: [
        _resumen(pedido), // Resumen superior (código, proveedor, fecha).

        // Pestañas: Cabecera | Líneas (5) | Totales | Foto
        SegmentTabs(
          tabs: [
            (key: 'cabecera', label: 'Cabecera'),
            (key: 'lineas', label: 'Líneas (${lineas.length})'),
            (key: 'totales', label: 'Totales'),
            (key: 'foto', label: 'Foto'),
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

        // Contenido con deslizamiento horizontal entre pestañas.
        Expanded(
          child: PageView(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() => _tabIndex = index);
            },
            children: [
              CabeceraView(pedido: pedido),
              LineasTable(
                lineas: lineas,
                clienteId: pedido.clienteId > 0 ? pedido.clienteId.toString() : pedido.cliente,
                clienteNombre: pedido.clienteNombre,
              ),
              SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: TotalesCard(
                  base: totales.base,
                  iva: totales.iva,
                  total: totales.total,
                ),
              ),
              PedidoFotoTab(
                imageBytes: pedido.fotoBase64.isNotEmpty ? base64Decode(pedido.fotoBase64) : null,
                uploading: false,
                onCamera: () {},
                onGallery: () {},
                readOnly: true,
              ),
            ],
          ),
        ),

        // ---- Barra inferior ----
        Material(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  if (!pedido.conKyr) ...[
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.yellow,
                          foregroundColor: Colors.black,
                        ),
                        onPressed: _confirmando ? null : () => _confirmar(pedido),
                        child: _confirmando
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                              )
                            : const Text('Confirmar', style: TextStyle(fontSize: 12)),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: puedeEditar ? () => _editar(pedido) : null,
                      icon: Icon(puedeEditar ? Icons.edit : (esConfirmado ? Icons.lock : Icons.lock_outline), size: 18),
                      label: Text(labelEditar, style: const TextStyle(fontSize: 12)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// _resumen: el bloque superior (código, estado, cliente, fecha).
  Widget _resumen(Pedido pedido) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Etiqueta azul con el código.
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Nº de pedido: ${pedido.numeroPedido.isNotEmpty ? pedido.numeroPedido : (pedido.codigo > 0 ? pedido.codigo.toString() : '')}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ), 
                ),
              ),
              const SizedBox(height: 8),
              // Etiqueta de color según el estado
              EstadoBadge(estado: pedido.estado),
            ],
          ),
          const SizedBox(height: 8),

          // Cliente: el nombre si lo hay; si no, el código; si no, "Sin cliente".
          Text(
            pedido.clienteNombre.isNotEmpty
                ? pedido.clienteNombre
                : (pedido.cliente.isNotEmpty ? pedido.cliente : 'Sin cliente'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis, // Si es muy largo, "..." al final.
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),

          // Fecha y CONFIRMADO (si lo está)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (pedido.fecha.isNotEmpty)
                Text(
                  'Fecha: ${formatDate(pedido.fecha)}', // Formato "10/09/2026".
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                )
              else
                const SizedBox.shrink(),
              if (pedido.conKyr)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'CONFIRMADO',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// _editar: abre el formulario para editar. Al volver, recarga el detalle
  /// para que se vean los cambios guardados.
  Future<void> _editar(Pedido pedido) async {
    await Navigator.of(context)
        .pushNamed('/pedido/form', arguments: pedido);
    if (mounted) _cargar();
  }




  Future<void> _confirmar(Pedido pedido) async {
    setState(() => _confirmando = true);
    try {
      final isOnline = ConnectionStatusService.instance.isOnline;
      await PedidosService.confirmarPedido(pedido.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isOnline
                ? 'Pedido confirmado correctamente'
                : 'Pedido confirmado (se sincronizará al recuperar la conexión)',
          ),
        ),
      );
      OfflineOutboxService.instance.refreshPendingCount();
      // Navegar a la lista y refrescar (elimina las vistas hasta /home)
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/pedidos',
        (route) => route.settings.name == '/home' || route.isFirst,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo confirmar: $error')),
      );
    } finally {
      if (mounted) setState(() => _confirmando = false);
    }
  }
}