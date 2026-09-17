// ============================================================================
//  pedido_form_screen.dart  —  FORMULARIO DE PEDIDO (crear o editar)
// ============================================================================
//
//  ¿Qué es?
//  --------
//  La pantalla donde se CREA un pedido nuevo (sin id) o se EDITA uno existente
//  (con id). Igual que el detalle, tiene 3 pestañas:
//     - Cabecera → formulario con los datos generales.
//     - Líneas  → tabla de líneas con botones para añadir/editar/eliminar.
//     - Totales → resumen calculado en vivo.
//  Y abajo dos botones: "Cancelar" y "Guardar".
//
//  Cómo decide si es "nuevo" o "editar":
//     widget.pedidoId == null  → NUEVO  (crea con POST)
//     widget.pedidoId != null  → EDITAR (carga y hace PUT)
//
//  CONCEPTOS FLUTTER QUE APARECEN:
//  - setState: avisamos de que _lineas o _pedido cambió → se repinta.
//  - AlertDialog: la "ventanita" de confirmación (ej. "¿Eliminar línea?").
// ============================================================================

import 'package:flutter/material.dart';

import '../api_service.dart'; // PedidosService (guardar + cargar detalle).
import '../models.dart'; // Modelos y calcularTotales.
import '../theme/app_theme.dart'; // Colores.
import '../core/formatters.dart'; // todayIso (fecha de hoy por defecto).
import '../widgets/segment_tabs.dart'; // Pestañas.
import '../widgets/cabecera_form.dart'; // Formulario de la cabecera.
import '../widgets/lineas_table.dart'; // Tabla de líneas (editable).
import '../widgets/totales_card.dart'; // Tarjeta de totales.
import '../widgets/linea_form_modal.dart'; // El "modal" para añadir/editar línea.
import '../widgets/estado_badge.dart'; // Etiqueta del estado.

/// PedidoFormScreen: pantalla de ALTA/EDICIÓN de pedidos.
class PedidoFormScreen extends StatefulWidget {
  final dynamic pedidoId; // null = pedido nuevo. Número = editar existente.

  const PedidoFormScreen({super.key, this.pedidoId});

  @override
  State<PedidoFormScreen> createState() => _PedidoFormScreenState();
}

class _PedidoFormScreenState extends State<PedidoFormScreen> {
  late Pedido _pedido; // El pedido que estamos construyendo/editando.
  List<LineaPedido> _lineas = []; // Las líneas del pedido (en memoria).
  bool _cargandoDetalle = false; // ¿Cargando el detalle (modo editar)?
  bool _guardando = false; // ¿Estamos guardando ya? (para no doble enviar).
  String _tab = 'cabecera'; // Pestaña activa.

  // ¿Estamos en modo edición? Sí, si nos pasaron un id.
  bool get _editando => widget.pedidoId != null;

  @override
  void initState() {
    super.initState();
    // Pedido nuevo con fecha de HOY por defecto.
    _pedido = Pedido(fecha: todayIso());
    if (_editando) {
      _cargarDetalle(); // Si es edición, cargamos los datos del servidor.
    }
  }

  /// _cargarDetalle: (modo editar) pide el pedido al servidor y lo mete en
  /// la memoria (_pedido y _lineas) para que el usuario lo vea y modifique.
  Future<void> _cargarDetalle() async {
    setState(() => _cargandoDetalle = true);
    try {
      final detalle = await PedidosService.getById(widget.pedidoId);
      if (!mounted) return;
      setState(() {
        _pedido = detalle;
        _lineas = [...detalle.lineas]; // Copiamos las líneas.
        _cargandoDetalle = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _cargandoDetalle = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  /// _onCambioCabecera: lo llama CabeceraForm cada vez que el usuario cambia
  /// algo en la cabecera. Guardamos el pedido nuevo en _pedido.
  ///
  /// REGLA DE NEGOCIO: si el usuario pone el estado a "Cancelado" (código "A"),
  /// todas las líneas pasan a "Cancelado" automáticamente.
  void _onCambioCabecera(Pedido nuevo) {
    setState(() {
      _pedido = nuevo;
      if (AppColors.estadoCodigo(nuevo.estado) == 'A') {
        // Reconstruimos cada línea con estado "Cancelado" y cancelado=true.
        // (No modificamos las originales directamente por inmutabilidad.)
        _lineas = _lineas
            .map(
              (l) => LineaPedido(
                id: l.id,
                codigo: l.codigo,
                articulo: l.articulo,
                articuloNombre: l.articuloNombre,
                descripcion: l.descripcion,
                referencia: l.referencia,
                referenciaProveedor: l.referenciaProveedor,
                nReferencia: l.nReferencia,
                cantidad: l.cantidad,
                pendiente: l.pendiente,
                precio: l.precio,
                dto: l.dto,
                importe: l.importe,
                tipoIva: l.tipoIva,
                retencionIrpf: l.retencionIrpf,
                retencionAlquiler: l.retencionAlquiler,
                clienteVenta: l.clienteVenta,
                estado: 'Cancelado', // ← cambiamos solo el estado
                cancelado: true, //     ← y la marca de cancelado
                previstoPara: l.previstoPara,
              ),
            )
            .toList();
      }
    });
  }

  /// _editarLinea: abre el modal para editar UNA línea existente.
  Future<void> _editarLinea(LineaPedido linea, int index) async {
    final resultado = await mostrarLineaForm(
      context,
      linea: linea, // Enviamos la línea actual para que salga rellena.
      onDelete: () => _eliminarLinea(index), // Si toca "borrar", eliminamos.
    );
    if (resultado != null) {
      // Devolvieron una línea (modificada) → la colocamos en su posición.
      setState(() {
        _lineas = [..._lineas]..[index] = resultado;
      });
    }
  }

  /// _anadirLinea: abre el modal vacío para añadir UNA línea nueva.
  Future<void>  () async {
    final resultado = await mostrarLineaForm(context);
    if (resultado != null) {
      setState(() => _lineas = [..._lineas, resultado]); // La añadimos al final.
    }
  }

  /// _eliminarLinea: pregunta con una ventana de confirmación y, si confirma,
  /// quita la línea del índice dado.
  void _eliminarLinea(int index) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar línea'),
        content: const Text('¿Seguro que quieres eliminar esta línea?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(), // Cerrar sin borrar.
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Cerramos la ventana...
              setState(() => _lineas = [..._lineas]..removeAt(index)); // ...y borramos.
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error), // Rojito.
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  /// _validar: comprueba las reglas mínimas antes de guardar.
  /// Devuelve false (y avisa) si falta algo.
  bool _validar() {
    if (_pedido.fecha.isEmpty) {
      _snack('La fecha del pedido es obligatoria.');
      return false;
    }
    if (_pedido.proveedor.isEmpty && _pedido.proveedorNombre.isEmpty) {
      _snack('Selecciona un proveedor.');
      return false;
    }
    if (_lineas.isEmpty) {
      _snack('El pedido debe tener al menos una línea.');
      return false;
    }
    return true;
  }

  /// _snack: atajo para mostrar un mensaje flotante.
  void _snack(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje)));
  }

  /// _guardar: valida y envía al servidor (POST si es nuevo, PUT si edita).
  Future<void> _guardar() async {
    if (!_validar()) return; // No cumple reglas → nos quedamos aquí.
    setState(() => _guardando = true); // Bloqueamos el botón "Guardar".

    try {
      // Construimos el JSON a enviar: copia del pedido + líneas de la memoria.
      final payload = _pedido.copyWith(lineas: _lineas).toJson();
      if (_editando) {
        await PedidosService.update(widget.pedidoId, payload);
      } else {
        await PedidosService.create(payload);
      }
      if (!mounted) return;
      // Volvemos a la pantalla anterior con "pop(true)" (= se guardó).
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false); // Rehabilitamos el botón.
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error al guardar: $e')));
    }
  }

  /// build: la pantalla completa.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(_editando ? 'Editar pedido' : 'Nuevo pedido')),
      body: _cargandoDetalle
          ? const Center(child: CircularProgressIndicator()) // Cargando (editar).
          : Column(
              children: [
                // Pestañas: Cabecera | Líneas (n) | Totales.
                SegmentTabs(
                  tabs: [
                    (key: 'cabecera', label: 'Cabecera'),
                    (key: 'lineas', label: 'Líneas (${_lineas.length})'),
                    (key: 'totales', label: 'Totales'),
                  ],
                  active: _tab,
                  onChanged: (key) => setState(() => _tab = key),
                ),
                // Contenido según la pestaña activa.
                Expanded(
                  child: switch (_tab) {
                    // Líneas: versión editable (permite editar y añadir).
                    'lineas' => LineasTable(
                        lineas: _lineas,
                        onEdit: _editarLinea,
                        onAdd: _anadirLinea,
                      ),
                    // Totales: resumen de las líneas en memoria.
                    'totales' => _totales(),
                    // Cabecera: el formulario, que avisa en cada cambio.
                    _ => CabeceraForm(
                        pedido: _pedido,
                        onChanged: _onCambioCabecera,
                      ),
                  },
                ),

                // ---- Barra inferior: Cancelar | Guardar ----
                Material(
                  color: AppColors.surface,
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.of(context).pop(), // Salir sin guardar.
                              child: const Text('Cancelar'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _guardando ? null : _guardar, // Deshabilitado mientras guarda.
                              child: _guardando
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.white,
                                      ),
                                    )
                                  : const Text('Guardar'),
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

  /// _totales: la pestaña de totales dentro del formulario.
  Widget _totales() {
    final totales = calcularTotales(_lineas); // Calculamos con las líneas actuales.
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: EstadoBadge(estado: _pedido.estado), // Estado actual del pedido.
        ),
        const SizedBox(height: 12),
        TotalesCard(
          base: totales.base,
          iva: totales.iva,
          total: totales.total,
        ),
      ],
    );
  }
}