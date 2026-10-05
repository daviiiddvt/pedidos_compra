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
import 'package:provider/provider.dart';

import '../core/api_service.dart'; // PedidosService (defaults del artículo).
import '../core/formatters.dart'; // formatNumber y parseNumber.
import '../core/search/entity_search_repository.dart'; // Repositorio local-first.
import '../models/models.dart'; // LineaPedido, OpcionMaestra.
import '../theme/app_theme.dart'; // Colores.
import 'autocomplete_field.dart'; // Buscador remoto con autocompletado (artículos).
import 'campo_form.dart'; // CampoForm y CampoSelect.
import 'campo_fecha.dart'; // CampoFecha.
import 'modal_selector.dart'; // mostrarSelector.

/// LineaFormModal: la ventana para introducir/editar una línea de pedido.
class LineaFormModal extends StatefulWidget {
  final LineaPedido? linea; // La línea a editar (null = línea nueva).
  final int clienteId;
  final VoidCallback?
  onDelete; // Qué hacer si se pulsa "Eliminar" (solo modo editar).
  final bool mostrarFechaEntrega;
  final bool mostrarReferencia;
  final List<String> estadosDisponibles;

  const LineaFormModal({
    super.key,
    this.linea,
    this.clienteId = 0,
    this.onDelete,
    this.mostrarFechaEntrega = true,
    this.mostrarReferencia = true,
    this.estadosDisponibles = const [
      'PENDIENTE',
      'CANCELADO',
      'PARCIALMENTE SERVIDO',
    ],
  });

  @override
  State<LineaFormModal> createState() => _LineaFormModalState();
}

class _LineaFormModalState extends State<LineaFormModal> {
  // Valores "fijos" que se pueden elegir:
  

  late final _formKey =
      GlobalKey<FormState>(); // Llave del formulario (para validar).

  // Controllers: UNO por cada campo editable de la línea.
  late final TextEditingController _articulo;
  late final TextEditingController _descripcion;
  late final TextEditingController _nReferencia;
  late final TextEditingController _cantidad;
  late final TextEditingController _precio;
  late final TextEditingController _dto;
  late final TextEditingController _retencionIrpf;
  late final TextEditingController _retencionAlquiler;

  // Estado "elegido" (no con controller porque son selectores):
  late RegimenIva _regimenIva;
  late String _estado; // 'Pendiente' o 'Cancelado'.
  String? _articuloId; // El CÓDIGO del artículo elegido (lo que se guarda).
  String _previstoPara = ''; // Fecha prevista de entrega (ISO).

  // ¿Es modo edición? Sí, si nos pasaron una línea.
  bool get _editando => widget.linea != null;

  @override
  void initState() {
    super.initState();
    final l = widget.linea; // Atajo.

    // Rellenamos cada controller con el valor existente (o vacío/por defecto).
    // El artículo se muestra con su NOMBRE bonito, pero se guarda el CÓDIGO.
    _articulo = TextEditingController(
      text: (l?.articuloNombre.isNotEmpty ?? false)
          ? l!.articuloNombre
          : (l?.articulo ?? ''),
    );
    _articuloId = (l?.articulo.isNotEmpty ?? false) ? l!.articulo : null;
    _descripcion = TextEditingController(text: l?.descripcion ?? '');
    _nReferencia = TextEditingController(text: l?.nReferencia ?? '');
    _cantidad = TextEditingController(
      text: l != null
          ? formatNumber(l.cantidad, decimals: 2)
          : '1', // 1 por defecto.
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
    if (l != null && l.regIvaVta.isNotEmpty) {
      _regimenIva = regimenIvaPorCodigo(l.regIvaVta);
    } else if (l != null) {
      _regimenIva = regimenIvaPorPorcentaje(l.tipoIva);
    } else {
      _regimenIva = kRegimenesIva.first;
    }
    // Si edito una línea ya cancelada, el estado sale "Cancelado".
    // (l.estado puede venir como código VELNEO "C"... → lo normalizamos.)
    final esCancelada =
        _editando && (l!.cancelado || AppColors.estadoCodigo(l.estado) == 'C');
    _estado = esCancelada ? 'CANCELADO' : 'PENDIENTE';
    _previstoPara = l?.previstoPara ?? '';
  }

  @override
  void dispose() {
    // Liberamos TODOS los controllers que creamos.
    _articulo.dispose();
    _descripcion.dispose();
    _nReferencia.dispose();
    _cantidad.dispose();
    _precio.dispose();
    _dto.dispose();
    _retencionIrpf.dispose();
    _retencionAlquiler.dispose();
    super.dispose();
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

  /// Busca artículos en Velneo mediante el repositorio local-first.
  /// 1º consulta la caché local (SQLite) y, si no hay, llama al API acotado.
  Future<List<OpcionMaestra>> _buscarArticulos(String query) {
    final repo = context.read<EntitySearchRepository>();
    return repo.search(EntityKind.articulo, query, limit: 20);
  }

  /// Pide a Velneo los datos por defecto del artículo elegido (precio, IVA,
  /// descripción) y los vuelca en los campos del formulario de la línea.
  Future<void> _cargarDatosArticulo(String articuloCodigo) async {
    debugPrint(
      '🔧 _cargarDatosArticulo("$articuloCodigo") → pidiendo defaults a Velneo...',
    );
    final defaults = await PedidosService.getArticuloDefaultsParaCliente(
      articuloCodigo,
      clienteId: widget.clienteId,
    );
    if (!mounted) return;
    debugPrint(
      '🔧 _cargarDatosArticulo("$articuloCodigo") → defaults recibidos: $defaults',
    );
    setState(() {
      final descripcion = (defaults['descripcion'] ?? '').toString().trim();
      if (descripcion.isNotEmpty && _descripcion.text.trim().isEmpty) {
        _descripcion.text = descripcion;
      }
      final precio =
          double.tryParse((defaults['precio'] ?? '').toString()) ?? 0;
      if (defaults['precio'] != null && defaults['precio'].toString().isNotEmpty) {
        _precio.text = formatNumber(precio, decimals: 2);
      }
      final dto =
          double.tryParse((defaults['dto'] ?? '0').toString()) ?? 0;
      _dto.text = formatNumber(dto, decimals: 2);
      final regIvaRaw = defaults['reg_iva_vta'] ?? defaults['reg_iva'];
      if (regIvaRaw != null && regIvaRaw.toString().isNotEmpty) {
        _regimenIva = regimenIvaPorCodigo(regIvaRaw.toString());
      } else {
        final tipoIva = double.tryParse((defaults['tipoIva'] ?? '').toString());
        if (tipoIva != null) {
          _regimenIva = regimenIvaPorPorcentaje(tipoIva);
        }
      }
    });
  }

  /// _guardar: valida el formulario, construye la LINEA y cierra devolviéndola.
  /// (Navigator.pop(linea) → quien llamó a mostrarLineaForm recibe la línea).
  void _guardar() {
    // Si no pasa la validación (ej. cantidad 0), no hacemos nada.
    if (!_formKey.currentState!.validate()) return;

    final cantidad = parseNumber(_cantidad.text);
    final cantidadServida = widget.linea?.cantidadServida ?? 0.0;

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
      precio: parseNumber(_precio.text),
      dto: parseNumber(_dto.text),
      importe: _importeCalculado, // El importe calculado en vivo.
      tipoIva: _regimenIva.porcentaje,
      regIvaVta: _regimenIva.codigo,
      retencionIrpf: parseNumber(_retencionIrpf.text),
      retencionAlquiler: parseNumber(_retencionAlquiler.text),
      estado: _estado,
        cancelado: AppColors.estadoCodigo(_estado) == 'C',
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
              child: SingleChildScrollView(
                // Permite hacer scroll si no caben.
                child: Column(
                  children: [
                    // Artículo: buscador con autocompletado remoto (debounce).
                    // Nada más escribir 3 caracteres consulta a Velneo y
                    // ofrece hasta 20 resultados; no se baja el catálogo.
                    AutocompleteField(
                      label: 'Artículo',
                      required: true,
                      minChars: 3,
                      debounce: const Duration(milliseconds: 400),
                      maxResults: 20,
                      initialValue: _articulo.text,
                      hint: 'Buscar por nombre o código...',
                      search: _buscarArticulos,
                      onSelected: (opcion) {
                        debugPrint('🔥🔥🔥 SE CLICÓ UN ARTICULO: $opcion');
                        // Mapeo SEGURO del artículo elegido → estado del modal.
                        // El ID real de la línea es el CÓDIGO del artículo
                        // (ART_M). El nombre es lo que se muestra y guarda en
                        // articuloNombre. Ambos se guardan explícitamente.
                        setState(() {
                          _articulo.text = opcion.nombre; // Nombre visible.
                          _articuloId =
                              opcion.codigo; // Código → 'art' en Velneo.
                        });
                        _cargarDatosArticulo(opcion.codigo);
                      },
                      onCleared: () {
                        setState(() {
                          _articulo.clear();
                          _articuloId = null;
                        });
                      },
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

                    if (widget.mostrarReferencia)
                      CampoForm(
                        label: 'N/Referencia',
                        value: _nReferencia.text,
                        onChanged: (v) => _nReferencia.text = v,
                      ),

                    // Cantidad.
                    CampoForm(
                      label: 'Cantidad',
                      controller: _cantidad,
                      onChanged: (v) {
                        setState(() {});
                      },
                      keyboardType: TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      required: true,
                      validator: (v) => parseNumber(v ?? '') <= 0
                          ? 'Debe ser mayor que 0'
                          : null,
                    ),

                    // Precio y % descuento (lado a lado).
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: CampoForm(
                            label: 'Precio',
                            controller: _precio,
                            onChanged: (v) =>
                                setState(() {}), // Recalcula importe.
                            keyboardType: TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: CampoForm(
                            label: '% descuento',
                            controller: _dto,
                            onChanged: (v) =>
                                setState(() {}), // Recalcula importe.
                            keyboardType: TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Régimen de IVA
                    CampoSelect(
                      label: 'Régimen de IVA',
                      value: _regimenIva.nombre,
                      onTap: () async {
                        final sel = await mostrarSelector(
                          context,
                          title: 'Seleccionar régimen de IVA',
                          options: kRegimenesIva,
                          textOf: (op) => (op as RegimenIva).nombre,
                          searchable: false,
                        );
                        if (sel != null && sel is RegimenIva) {
                          setState(() => _regimenIva = sel);
                        }
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
                          options: widget.estadosDisponibles,
                          searchable: false,
                        );
                        if (sel != null) setState(() => _estado = sel);
                      },
                    ),

                    if (widget.mostrarFechaEntrega)
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
                            keyboardType: TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: CampoForm(
                            label: 'Retención alquiler',
                            controller: _retencionAlquiler,
                            keyboardType: TextInputType.numberWithOptions(
                              decimal: true,
                            ),
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
                          Text(
                            'Importe',
                            style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                    onPressed: () => Navigator.of(context)
                        .pop(), // Cerrar sin guardar → null.
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
  int clienteId = 0,
  VoidCallback? onDelete, // Para mostrar el botón "Eliminar".
  bool mostrarFechaEntrega = true,
  bool mostrarReferencia = true,
  List<String> estadosDisponibles = const ['Pendiente', 'Cancelado'],
}) {
  return showModalBottomSheet<LineaPedido>(
    // La "hoja" que sube desde abajo.
    context: context,
    isScrollControlled: true, // Permite que la hoja ocupe casi toda la pantalla.
    backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(14),
      ), // Esquinas arriba.
    ),
    builder: (ctx) => LineaFormModal(
      linea: linea,
      clienteId: clienteId,
      onDelete: onDelete,
      mostrarFechaEntrega: mostrarFechaEntrega,
      mostrarReferencia: mostrarReferencia,
      estadosDisponibles: estadosDisponibles,
    ),
  );
}
