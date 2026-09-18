// ============================================================================
//  linea_form_modal.dart  —  MODAL DE UNA LÍNEA (añadir o editar artículo)
// ============================================================================
//
//  ¿Qué es?
//  --------
//  La ventana que sale desde abajo (bottom sheet) para RELLENAR UNA LÍNEA:
//     - Artículo (se elige con el selector del catálogo).
//     - Descripción, referencias, cantidades, precios, % dto., IVA, estado...
//  Muestra el IMPORTE calculado en vivo (cantidad × precio − descuento).
//
//  Se usa con la función mostrarLineaForm():
//     final resultado = await mostrarLineaForm(context, linea: laLinea);
//     // resultado es null si se canceló, o una LineaPedido si se aceptó.
//
//  CONCEPTO:
//  - showModalBottomSheet: la "hoja" que sube desde abajo.
//  - Form + _formKey: el "Form" agrupa los campos y valida (validator).
//  - Controller por cada campo: para leer lo escrito con _xxx.text.
// ============================================================================

import 'package:flutter/material.dart';

import '../api_service.dart'; // PedidosService (cargar artículos del catálogo).
import '../models.dart'; // LineaPedido, OpcionMaestra.
import '../core/formatters.dart'; // formatNumber y parseNumber.
import '../theme/app_theme.dart'; // Colores.
import 'campo_form.dart'; // CampoForm y CampoSelect.
import 'campo_fecha.dart'; // CampoFecha.
import 'modal_selector.dart'; // mostrarSelector.

/// LineaFormModal: la ventana para introducir/editar una línea de pedido.
class LineaFormModal extends StatefulWidget {
  final LineaPedido? linea; // La línea a editar (null = línea nueva).
  final VoidCallback? onDelete; // Qué hacer si se pulsa "Eliminar" (solo modo editar).

  const LineaFormModal({super.key, this.linea, this.onDelete});

  @override
  State<LineaFormModal> createState() => _LineaFormModalState();
}

class _LineaFormModalState extends State<LineaFormModal> {
  // Valores "fijos" que se pueden elegir:
  static const _tiposIva = [21, 10, 4, 0]; // Tipos de IVA españoles.
  static const _estados = ['Pendiente', 'Cancelado']; // Estados posibles de la línea.

  late final _formKey = GlobalKey<FormState>(); // Llave del formulario (para validar).

  // Controllers: UNO por cada campo editable de la línea.
  late final TextEditingController _articulo;
  late final TextEditingController _descripcion;
  late final TextEditingController _nReferencia;
  late final TextEditingController _cantidad;
  late final TextEditingController _pendiente;
  late final TextEditingController _precio;
  late final TextEditingController _dto;
  late final TextEditingController _retencionIrpf;
  late final TextEditingController _retencionAlquiler;

  // Estado "elegido" (no con controller porque son selectores):
  late String _tipoIva; // "21", "10", "4" o "0" (como texto).
  late String _estado; // 'Pendiente' o 'Cancelado'.
  String? _articuloId; // El CÓDIGO del artículo elegido (lo que se guarda).
  String _previstoPara = ''; // Fecha prevista de entrega (ISO).

  // Catálogo de artículos bajado del servidor (para el selector).
  List<OpcionMaestra> _articulos = [];

  // ¿Es modo edición? Sí, si nos pasaron una línea.
  bool get _editando => widget.linea != null;

  @override
  void initState() {
    super.initState();
    final l = widget.linea; // Atajo.

    // Rellenamos cada controller con el valor existente (o vacío/por defecto).
    // El artículo se muestra con su NOMBRE bonito, pero se guarda el CÓDIGO.
    _articulo = TextEditingController(
      text: (l?.articuloNombre.isNotEmpty ?? false) ? l!.articuloNombre : (l?.articulo ?? ''),
    );
    _articuloId = (l?.articulo.isNotEmpty ?? false) ? l!.articulo : null;
    _descripcion = TextEditingController(text: l?.descripcion ?? '');
    _nReferencia = TextEditingController(text: l?.nReferencia ?? '');
    _cantidad = TextEditingController(
      text: l != null ? formatNumber(l.cantidad, decimals: 2) : '1', // 1 por defecto.
    );
    final pendienteBase = l != null
        ? (l.pendiente > 0 ? l.pendiente : l.pendienteCalculada)
        : 1.0;
    _pendiente = TextEditingController(
      text: formatNumber(pendienteBase, decimals: 2),
    );
    _precio = TextEditingController(
      text: l != null ? formatNumber(l.precio, decimals: 2) : '0',
    );
    _dto = TextEditingController(
      text: l != null ? formatNumber(l.dto, decimals: 2) : '0',
    );
    _retencionIrpf = TextEditingController(
      text: l != null ? formatNumber(l.retencionIrpf, decimals: 2) : '0',
    );
    _retencionAlquiler = TextEditingController(
      text: l != null ? formatNumber(l.retencionAlquiler, decimals: 2) : '0',
    );

    // Selectores con valor por defecto:
    _tipoIva = (l?.tipoIva ?? 21).toStringAsFixed(0); // "21" por defecto.
    // Si edito una línea ya cancelada, el estado sale "Cancelado".
    // (l.estado puede venir como código VELNEO "C"... → lo normalizamos.)
    final esCancelada = _editando && (l!.cancelado || AppColors.estadoCodigo(l.estado) == 'C');
    _estado = esCancelada ? 'Cancelado' : 'Pendiente';
    _previstoPara = l?.previstoPara ?? '';

    _cargarArticulos(); // Bajamos el catálogo de artículos.
  }

  @override
  void dispose() {
    // Liberamos TODOS los controllers que creamos.
    _articulo.dispose();
    _descripcion.dispose();
    _nReferencia.dispose();
    _cantidad.dispose();
    _pendiente.dispose();
    _precio.dispose();
    _dto.dispose();
    _retencionIrpf.dispose();
    _retencionAlquiler.dispose();
    super.dispose();
  }

  /// _cargarArticulos: baja el catálogo de artículos del servidor.
  Future<void> _cargarArticulos() async {
    try {
      final lista = await PedidosService.getArticulos();
      if (mounted) setState(() => _articulos = lista);
    } catch (e) {
      // Endpoint sin configurar → no rompemos, solo lo anotamos.
      debugPrint('No se pudieron cargar artículos: $e');
    }
  }

  /// _importeCalculado: el importe en vivo = cantidad × precio − descuento.
  /// Se recalcula solo cada vez que se pinta (leyendo los controllers).
  double get _importeCalculado {
    final cantidad = parseNumber(_cantidad.text);
    final precio = parseNumber(_precio.text);
    final dto = parseNumber(_dto.text);
    final base = cantidad * precio;
    return base - base * (dto / 100); // Le restamos el % de descuento.
  }

  /// _elegirArticulo: abre el catálogo; al elegir, rellena nombre y código.
  Future<void> _elegirArticulo() async {
    if (_articulos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Configura el endpoint de artículos.')),
      );
      return;
    }
    final seleccionado = await mostrarSelector(
      context,
      title: 'Seleccionar artículo',
      options: _articulos,
      textOf: (o) => (o as OpcionMaestra).nombre,
    );
    if (seleccionado != null) {
      setState(() {
        _articulo.text = seleccionado.nombre; // Mostramos el nombre.
        _articuloId = seleccionado.codigo; // Guardamos el código.
      });
    }
  }

  /// _guardar: valida el formulario, construye la LINEA y cierra devolviéndola.
  /// (Navigator.pop(linea) → quien llamó a mostrarLineaForm recibe la línea).
  void _guardar() {
    // Si no pasa la validación (ej. cantidad 0), no hacemos nada.
    if (!_formKey.currentState!.validate()) return;

    final cantidad = parseNumber(_cantidad.text);
    final cantidadServida = widget.linea?.cantidadServida ?? 0.0;
    final pendiente = cantidad - cantidadServida;

    final linea = LineaPedido(
      // Conservamos id/código si venían de una línea ya existente.
      id: widget.linea?.id,
      codigo: widget.linea?.codigo,
      // Almacenamos el código del artículo elegido (o el texto si no eligió).
      articulo: _articuloId ?? _articulo.text,
      articuloNombre: _articulo.text, // El nombre es lo que se muestra.
      descripcion: _descripcion.text.trim(),
      nReferencia: _nReferencia.text.trim(),
      cantidad: cantidad,
      cantidadServida: cantidadServida,
      pendiente: pendiente,
      precio: parseNumber(_precio.text),
      dto: parseNumber(_dto.text),
      importe: _importeCalculado, // El importe calculado en vivo.
      tipoIva: double.parse(_tipoIva), // "21" → 21.0
      retencionIrpf: parseNumber(_retencionIrpf.text),
      retencionAlquiler: parseNumber(_retencionAlquiler.text),
      estado: _estado,
      cancelado: _estado == 'Cancelado', // Si estado = Cancelado → sí cancelada.
      previstoPara: _previstoPara,
    );
    Navigator.of(context).pop(linea); // Cerramos y entregamos la línea.
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Padding extra abajo para que el teclado no tape el contenido.
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Form(
        key: _formKey, // El formulario que agrupa las validaciones.
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),

            // ---- Zona con SCROLL de los campos ----
            Flexible(
              child: SingleChildScrollView( // Permite hacer scroll si no caben.
                child: Column(
                  children: [
                    // Artículo: campo selector (no texto).
                    CampoSelect(
                      label: 'Artículo',
                      value: _articulo.text,
                      required: true,
                      onTap: _elegirArticulo,
                    ),

                    // Descripción (obligatoria, multilínea).
                    CampoForm(
                      label: 'Descripción',
                      value: _descripcion.text,
                      onChanged: (v) => _descripcion.text = v,
                      placeholder: 'Descripción del artículo',
                      required: true,
                      multiline: true,
                    ),

                    // N/Referencia.
                    CampoForm(
                      label: 'N/Referencia',
                      value: _nReferencia.text,
                      onChanged: (v) => _nReferencia.text = v,
                    ),

                    // Cantidad y cantidad pendiente (lado a lado).
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: CampoForm(
                            label: 'Cantidad',
                            controller: _cantidad,
                            // setState(() {}) fuerza a repintar el importe.
                            onChanged: (v) => setState(() {}),
                            keyboardType: TextInputType.numberWithOptions(decimal: true),
                            required: true,
                            validator: (v) =>
                                parseNumber(v ?? '') <= 0 ? 'Debe ser mayor que 0' : null,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: CampoForm(
                            label: 'Cantidad pendiente',
                            controller: _pendiente,
                            keyboardType: TextInputType.numberWithOptions(decimal: true),
                          ),
                        ),
                      ],
                    ),

                    // Precio y % descuento (lado a lado).
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: CampoForm(
                            label: 'Precio',
                            controller: _precio,
                            onChanged: (v) => setState(() {}), // Recalcula importe.
                            keyboardType: TextInputType.numberWithOptions(decimal: true),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: CampoForm(
                            label: '% descuento',
                            controller: _dto,
                            onChanged: (v) => setState(() {}), // Recalcula importe.
                            keyboardType: TextInputType.numberWithOptions(decimal: true),
                          ),
                        ),
                      ],
                    ),

                    // Tipo de IVA (selector con los 4 tipos).
                    CampoSelect(
                      label: 'Tipo de IVA',
                      value: '$_tipoIva %', // "21 %"
                      onTap: () async {
                        final sel = await mostrarSelector(
                          context,
                          title: 'Seleccionar tipo de IVA',
                          options: _tiposIva, // [21, 10, 4, 0]
                          searchable: false,
                        );
                        if (sel != null) setState(() => _tipoIva = '$sel');
                      },
                    ),

                    // Estado de la línea (Pendiente / Cancelado).
                    CampoSelect(
                      label: 'Estado',
                      value: _estado,
                      onTap: () async {
                        final sel = await mostrarSelector(
                          context,
                          title: 'Seleccionar estado',
                          options: _estados,
                          searchable: false,
                        );
                        if (sel != null) setState(() => _estado = sel);
                      },
                    ),

                    // Fecha prevista de entrega (calendario).
                    CampoFecha(
                      label: 'Entrega prevista',
                      value: _previstoPara,
                      onChanged: (v) => setState(() => _previstoPara = v),
                    ),

                    // Retenciones (lado a lado).
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: CampoForm(
                            label: 'Retención IRPF',
                            controller: _retencionIrpf,
                            keyboardType: TextInputType.numberWithOptions(decimal: true),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: CampoForm(
                            label: 'Retención alquiler',
                            controller: _retencionAlquiler,
                            keyboardType: TextInputType.numberWithOptions(decimal: true),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // ---- El importe calculado en vivo (azul, destacado) ----
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Importe',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Text(
                            '${formatNumber(_importeCalculado)} €',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ---- Botones: Eliminar (si es edición) | Cancelar | Aceptar ----
            Row(
              children: [
                if (widget.onDelete != null) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop(); // Cerramos el modal...
                        widget.onDelete!(); // ...y avisamos para eliminar.
                      },
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('Eliminar'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error, // Rojo.
                        side: const BorderSide(color: AppColors.error),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(), // Cerrar sin guardar → null.
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _guardar, // Validar y devolver la línea.
                    child: const Text('Aceptar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
//  mostrarLineaForm: la función "abrela" — muestra el modal y devuelve la línea.
// ============================================================================
/// Uso:
///   final linea = await mostrarLineaForm(context, linea: existente, onDelete: ...);
///   if (linea != null) { /* el usuario pulsó Aceptar → linea es la nueva línea */ }
Future<LineaPedido?> mostrarLineaForm(
  BuildContext context, {
  LineaPedido? linea, // null = línea nueva.
  VoidCallback? onDelete, // Para mostrar el botón "Eliminar".
}) {
  return showModalBottomSheet<LineaPedido>( // La "hoja" que sube desde abajo.
    context: context,
    isScrollControlled: true, // Permite que la hoja ocupe casi toda la pantalla.
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(14)), // Esquinas arriba.
    ),
    builder: (_) => LineaFormModal(linea: linea, onDelete: onDelete),
  );
}