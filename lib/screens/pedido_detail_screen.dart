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

import 'package:flutter/material.dart';

import '../api_service.dart'; // PedidosService (pedir el detalle).
import '../models.dart'; // Modelos y cálculo de totales.
import '../theme/app_theme.dart'; // Colores.
import '../core/formatters.dart'; // formatDate (fecha en formato español).
import '../widgets/segment_tabs.dart'; // Las pestañas (Cabecera/Líneas/Totales).
import '../widgets/cabecera_view.dart'; // Vista de la cabecera del pedido.
import '../widgets/lineas_table.dart'; // Tabla con las líneas.
import '../widgets/totales_card.dart'; // Tarjeta de totales.
import '../widgets/estado_badge.dart'; // "Etiqueta" de color con el estado.

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
  String _tab = 'cabecera'; // Pestaña activa: empieza en "Cabecera".

  @override
  void initState() {
    super.initState();
    _cargar(); // Nada más nacer, pedimos el detalle.
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        // Título: "Pedido 123" si tiene código, si no simplemente "Pedido".
        title: Text(
          pedido != null && pedido.codigo != 0
              ? 'Pedido ${pedido.codigo}'
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

    return Column(
      children: [
        _resumen(pedido), // Resumen superior (código, proveedor, fecha).

        // Pestañas: Cabecera | Líneas (5) | Totales.
        SegmentTabs(
          tabs: [
            (key: 'cabecera', label: 'Cabecera'),
            (key: 'lineas', label: 'Líneas (${lineas.length})'),
            (key: 'totales', label: 'Totales'),
          ],
          active: _tab,
          onChanged: (key) => setState(() => _tab = key),
        ),

        // Contenido de la pestaña activa.
        Expanded(
          child: switch (_tab) {
            // Pestaña "Líneas" → la tabla de artículos.
            'lineas' => LineasTable(lineas: lineas),
            // Pestaña "Totales" → tarjeta con base/IVA/total (con scroll).
            'totales' => SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: TotalesCard(
                  base: totales.base,
                  iva: totales.iva,
                  total: totales.total,
                ),
              ),
            // Cualquier otra (la "cabecera") → vista de datos generales.
            _ => CabeceraView(pedido: pedido),
          },
        ),

        // ---- Barra inferior con el botón "Editar" ----
        Material(
          color: AppColors.surface,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: double.infinity, // Botón a lo ancho.
                child: ElevatedButton.icon(
                  onPressed: () => _editar(pedido),
                  icon: const Icon(Icons.edit),
                  label: const Text('Editar'),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// _resumen: el bloque superior (código, estado, proveedor, fecha).
  Widget _resumen(Pedido pedido) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween, // Cada cual a su lado.
            children: [
              // Etiqueta azul con el código.
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Código ${pedido.codigo == 0 ? '' : pedido.codigo}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
              // Etiqueta de color según el estado (naranja/verde/gris).
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
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: AppColors.text,
            ),
          ),

          // Fecha (solo si hay).
          if (pedido.fecha.isNotEmpty)
            Text(
              'Fecha: ${formatDate(pedido.fecha)}', // Formato "10/09/2026".
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
        ],
      ),
    );
  }

  /// _editar: abre el formulario para editar. Al volver, recarga el detalle
  /// para que se vean los cambios guardados.
  Future<void> _editar(Pedido pedido) async {
    await Navigator.of(context)
        .pushNamed('/pedido/form', arguments: pedido.id);
    if (mounted) _cargar();
  }
}