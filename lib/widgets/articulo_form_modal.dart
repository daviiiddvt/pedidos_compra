import 'package:flutter/material.dart';

import '../core/articulos_service.dart';
import '../core/formatters.dart';
import '../models/articulo.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import 'campo_form.dart';
import 'modal_selector.dart';

/// Abre el modal emergente para crear un nuevo artículo en `ART_M`.
/// Devuelve el [Articulo] creado, o `null` si se canceló.
Future<Articulo?> mostrarCrearArticuloModal(
  BuildContext context, {
  String? initialSearch,
}) {
  return showDialog<Articulo>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _ArticuloFormModal(initialSearch: initialSearch),
  );
}

class _ArticuloFormModal extends StatefulWidget {
  final String? initialSearch;

  const _ArticuloFormModal({this.initialSearch});

  @override
  State<_ArticuloFormModal> createState() => _ArticuloFormModalState();
}

class _ArticuloFormModalState extends State<_ArticuloFormModal> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nombreCtrl;
  late final TextEditingController _referenciaCtrl;
  late final TextEditingController _precioCtrl;
  late final TextEditingController _codigoBarrasCtrl;
  late final TextEditingController _descripcionCtrl;

  OpcionMaestra? _familiaSeleccionada;
  OpcionMaestra? _proveedorSeleccionado;

  List<OpcionMaestra> _familias = [];
  List<OpcionMaestra> _proveedores = [];

  bool _cargandoFamilias = false;
  bool _cargandoProveedores = false;
  bool _guardando = false;

  String? _familiaError;

  @override
  void initState() {
    super.initState();
    final init = widget.initialSearch?.trim() ?? '';
    _nombreCtrl = TextEditingController(text: init);
    _referenciaCtrl = TextEditingController();
    _precioCtrl = TextEditingController();
    _codigoBarrasCtrl = TextEditingController();
    _descripcionCtrl = TextEditingController();

    _cargarMaestros();
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _referenciaCtrl.dispose();
    _precioCtrl.dispose();
    _codigoBarrasCtrl.dispose();
    _descripcionCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarMaestros() async {
    setState(() {
      _cargandoFamilias = true;
      _cargandoProveedores = true;
    });

    try {
      final results = await Future.wait([
        ArticulosService.getFamilias(),
        ArticulosService.getProveedores(),
      ]);

      if (mounted) {
        setState(() {
          _familias = results[0];
          _proveedores = results[1];
          _cargandoFamilias = false;
          _cargandoProveedores = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _cargandoFamilias = false;
          _cargandoProveedores = false;
        });
      }
    }
  }

  Future<void> _seleccionarFamilia() async {
    if (_cargandoFamilias) return;
    if (_familias.isEmpty) {
      setState(() => _cargandoFamilias = true);
      _familias = await ArticulosService.getFamilias();
      if (mounted) setState(() => _cargandoFamilias = false);
    }

    if (!mounted) return;
    final seleccion = await mostrarSelector(
      context,
      title: 'Seleccionar Familia',
      options: _familias,
      searchPlaceholder: 'Buscar familia por código o nombre...',
      textOf: (op) => (op as OpcionMaestra).nombre,
    );

    if (seleccion is OpcionMaestra && mounted) {
      setState(() {
        _familiaSeleccionada = seleccion;
        _familiaError = null;
      });
    }
  }

  Future<void> _seleccionarProveedor() async {
    if (_cargandoProveedores) return;
    if (_proveedores.isEmpty) {
      setState(() => _cargandoProveedores = true);
      _proveedores = await ArticulosService.getProveedores();
      if (mounted) setState(() => _cargandoProveedores = false);
    }

    if (!mounted) return;
    final seleccion = await mostrarSelector(
      context,
      title: 'Seleccionar Proveedor',
      options: _proveedores,
      searchPlaceholder: 'Buscar proveedor...',
      textOf: (op) => (op as OpcionMaestra).nombre,
    );

    if (seleccion is OpcionMaestra && mounted) {
      setState(() {
        _proveedorSeleccionado = seleccion;
      });
    }
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    if (_familiaSeleccionada == null) {
      setState(() {
        _familiaError = 'Debe seleccionar una familia obligatoriamente';
      });
      return;
    }

    setState(() => _guardando = true);

    try {
      final precioNum = parseNumber(_precioCtrl.text);

      final nuevoArticulo = await ArticulosService.create(
        nombre: _nombreCtrl.text.trim(),
        referencia: _referenciaCtrl.text.trim(),
        familiaId: _familiaSeleccionada!.codigo,
        precio: precioNum,
        proveedorId: _proveedorSeleccionado?.codigo ?? '',
        codigoBarras: _codigoBarrasCtrl.text.trim(),
        descripcion: _descripcionCtrl.text.trim(),
      );

      // Si no devolvió los nombres de familia/proveedor, los enriquecemos con los seleccionados
      final completo = nuevoArticulo.copyWith(
        familiaNombre: nuevoArticulo.familiaNombre.isNotEmpty
            ? nuevoArticulo.familiaNombre
            : _familiaSeleccionada!.nombre,
        proveedorNombre: nuevoArticulo.proveedorNombre.isNotEmpty
            ? nuevoArticulo.proveedorNombre
            : _proveedorSeleccionado?.nombre,
      );

      if (mounted) {
        Navigator.of(context).pop(completo);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _guardando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al crear el artículo: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Cabecera con título e icono
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.add_shopping_cart,
                          color: AppColors.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Nuevo Artículo',
                              style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              'Crear artículo en el catálogo (ART_M)',
                              style: TextStyle(
                                fontSize: 12,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: _guardando ? null : () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const Divider(height: 24),

                  // Nombre del artículo (Obligatorio)
                  CampoForm(
                    label: 'Nombre / Denominación',
                    controller: _nombreCtrl,
                    required: true,
                    placeholder: 'Ej. Tornillo M6 x 20mm cincado',
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'El nombre es obligatorio' : null,
                  ),
                  const SizedBox(height: 14),

                  // Familia (Obligatoria para listado y búsquedas)
                  CampoSelect(
                    label: 'Familia (obligatoria para búsquedas)',
                    required: true,
                    value: _familiaSeleccionada?.nombre,
                    placeholder: _cargandoFamilias
                        ? 'Cargando familias...'
                        : 'Toca para seleccionar una familia',
                    error: _familiaError,
                    onTap: _seleccionarFamilia,
                  ),
                  const SizedBox(height: 14),

                  // Referencia y Precio en fila horizontal
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: CampoForm(
                          label: 'Referencia / Código',
                          controller: _referenciaCtrl,
                          placeholder: 'Ej. TORN-M6-20',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: CampoForm(
                          label: 'Precio PVP (€)',
                          controller: _precioCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          placeholder: '0,00',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Proveedor habitual
                  CampoSelect(
                    label: 'Proveedor habitual',
                    value: _proveedorSeleccionado?.nombre,
                    placeholder: _cargandoProveedores
                        ? 'Cargando proveedores...'
                        : 'Opcional (seleccionar proveedor)',
                    onTap: _seleccionarProveedor,
                  ),
                  const SizedBox(height: 14),

                  // Código de barras
                  CampoForm(
                    label: 'Código de barras (EAN)',
                    controller: _codigoBarrasCtrl,
                    placeholder: 'Ej. 8412345678901',
                  ),
                  const SizedBox(height: 14),

                  // Descripción adicional
                  CampoForm(
                    label: 'Descripción / Observaciones',
                    controller: _descripcionCtrl,
                    multiline: true,
                    placeholder: 'Detalles técnicos o descripción extendida...',
                  ),
                  const SizedBox(height: 20),

                  // Botones de acción
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _guardando ? null : () => Navigator.of(context).pop(),
                        child: Text(
                          'Cancelar',
                          style: TextStyle(color: colorScheme.onSurfaceVariant),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: _guardando ? null : _guardar,
                        icon: _guardando
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.check, size: 18),
                        label: Text(_guardando ? 'Guardando...' : 'Crear Artículo'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

