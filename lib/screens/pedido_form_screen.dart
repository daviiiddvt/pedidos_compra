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

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api_service.dart'; // PedidosService (guardar + cargar detalle).
import '../core/formatters.dart'; // todayIso (fecha de hoy por defecto).
import '../models/models.dart'; // Modelos y calcularTotales.
import '../state/auth_state.dart';
import '../state/pedido_form_cubit.dart';
import '../theme/app_theme.dart'; // Colores.
import '../widgets/cabecera_form.dart'; // Formulario de la cabecera.
import '../widgets/estado_badge.dart'; // Etiqueta del estado.
import '../widgets/linea_form_modal.dart'; // El "modal" para añadir/editar línea.
import '../widgets/lineas_table.dart'; // Tabla de líneas (editable).
import '../widgets/segment_tabs.dart'; // Pestañas.
import '../widgets/totales_card.dart'; // Tarjeta de totales.
import '../widgets/pedido_foto_tab.dart';
import '../core/presupuesto_service.dart';
import '../core/licencia/licencia_service.dart';

/// PedidoFormScreen: pantalla de ALTA/EDICIÓN de pedidos.
class PedidoFormScreen extends StatefulWidget {
  final dynamic pedidoId; // null = pedido nuevo. Número = editar existente.

  const PedidoFormScreen({super.key, this.pedidoId});

  @override
  State<PedidoFormScreen> createState() => _PedidoFormScreenState();
}

class _PedidoFormScreenState extends State<PedidoFormScreen> {
  late final PedidoFormCubit _cubit; // Estado de la cabecera (compartido).
  List<LineaPedido> _lineas = []; // Las líneas del pedido (en memoria).
  Set<int> _lineasOriginalesIds = {};
  bool _cargandoDetalle = false; // ¿Cargando el detalle (modo editar)?
  bool _guardando = false; // ¿Estamos guardando ya? (para no doble enviar).
  Uint8List? _fotoBytes;
  late final PageController _pageController;
  int _tabIndex = 0;

  List<String> get _tabs => [
    'cabecera',
    'lineas',
    'totales',
    if (_editando) 'foto',
  ];

  dynamic get _pedidoIdReal =>
      widget.pedidoId is Pedido ? (widget.pedidoId as Pedido).id : widget.pedidoId;

  bool get _esConversionDesdePresupuesto {
    if (widget.pedidoId is! Pedido) return false;
    final pedido = widget.pedidoId as Pedido;
    return pedido.id != null &&
        pedido.codigo == 0 &&
        pedido.numeroPedido.isEmpty;
  }

  bool get _editando => _pedidoIdReal != null && !_esConversionDesdePresupuesto;

  /// El pedido en construcción vive en el cubit (fuente de verdad única).
  Pedido get _pedido => _cubit.state.pedido;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _checkRecoveredPhoto();
    if (widget.pedidoId is Pedido) {
      final initial = widget.pedidoId as Pedido;
      _cubit = PedidoFormCubit(initial);
      _lineas = [...initial.lineas];
      _lineasOriginalesIds = initial.lineas
          .where((linea) => linea.id != null)
          .map((linea) => linea.id!)
          .toSet();
      if (initial.fotoBase64.isNotEmpty) {
        _fotoBytes = base64Decode(initial.fotoBase64);
      }
      _cargandoDetalle = false;
      _cubit.init(initial);
      if (initial.conKyr) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Un pedido confirmado no puede editarse.'),
                backgroundColor: Colors.orange,
              ),
            );
            Navigator.of(context).pop();
          }
        });
      }
    } else {
      _cubit = PedidoFormCubit(Pedido(fecha: todayIso()));
      if (_editando) {
        _cargarDetalle();
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _cubit.close();
    super.dispose();
  }

  /// _cargarDetalle: (modo editar) pide el pedido al servidor y lo mete en
  /// el cubit (_pedido y _lineas) para que el usuario lo vea y modifique.
  Future<void> _cargarDetalle() async {
    setState(() => _cargandoDetalle = true);
    try {
      final detalle = await PedidosService.getById(widget.pedidoId);
      if (!mounted) return;
      if (detalle.conKyr) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Un pedido confirmado no puede editarse.'),
            backgroundColor: Colors.orange,
          ),
        );
        Navigator.of(context).pop();
        return;
      }
      _cubit.init(detalle);
      setState(() {
        _lineas = [...detalle.lineas]; // Copiamos las líneas.
        _lineasOriginalesIds = detalle.lineas
          .where((linea) => linea.id != null)
          .map((linea) => linea.id!)
          .toSet();
        if (detalle.fotoBase64.isNotEmpty) {
          _fotoBytes = base64Decode(detalle.fotoBase64);
        } else {
          _fotoBytes = null;
        }
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
  /// algo en la cabecera. Guardamos el pedido nuevo en el cubit.
  ///
  /// REGLA DE NEGOCIO: si el usuario pone el estado a "Cancelado" (código "A"),
  /// todas las líneas pasan a "Cancelado" automáticamente.
  void _onCambioCabecera(Pedido nuevo) {
    _cubit.update(nuevo);
    if (AppColors.estadoCodigo(nuevo.estado) == 'C') {
      setState(() {
        // Reconstruimos cada línea con estado "Cancelado" y cancelado=true.
        // (No modificamos las originales directamente por inmutabilidad.)
        _lineas = _lineas
            .map(
              (l) => l.copyWith(
                estado: 'Cancelado',
                cancelado: true,
              ),
            )
            .toList();
      });
    }
  }

  /// _editarLinea: abre el modal para editar UNA línea existente.
  Future<void> _editarLinea(LineaPedido linea, int index) async {
    final cltId = _pedido.clienteId > 0 ? _pedido.clienteId : (int.tryParse(_pedido.cliente) ?? 0);
    final resultado = await mostrarLineaForm(
      context,
      linea: linea, // Enviamos la línea actual para que salga rellena.
      clienteId: cltId,
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
  Future<void> _anadirLinea() async {
    final cltId = _pedido.clienteId > 0 ? _pedido.clienteId : (int.tryParse(_pedido.cliente) ?? 0);
    final resultado = await mostrarLineaForm(
      context,
      clienteId: cltId,
    );
    if (resultado != null) {
      setState(() => _lineas = [..._lineas, resultado]); // La añadimos al final.
    }
  }

  bool _fotoNueva = false;

  Future<void> _checkRecoveredPhoto() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString('recovered_photo_path');
    if (path != null) {
      await prefs.remove('recovered_photo_path');
      try {
        final xfile = XFile(path);
        final bytes = await xfile.readAsBytes();
        if (mounted) {
          final fotoIdx = _tabs.indexOf('foto');
          setState(() {
            _fotoBytes = bytes;
            _fotoNueva = true;
            _fotoEliminada = false;
            if (fotoIdx != -1) _tabIndex = fotoIdx;
          });
          if (fotoIdx != -1 && _pageController.hasClients) {
            _pageController.jumpToPage(fotoIdx);
          }
        }
      } catch (e) {
        debugPrint('Error leyendo foto recuperada: $e');
      }
    }
  }

  Future<void> _seleccionarFoto(ImageSource source) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('picking_photo_pedido_id', _pedidoIdReal?.toString() ?? '');
    
    final selected = await ImagePicker().pickImage(
      source: source,
      imageQuality: 50,
      maxWidth: 800,
      maxHeight: 800,
    );
    
    await prefs.remove('picking_photo_pedido_id');
    
    if (selected == null || !mounted) return;
    final bytes = await selected.readAsBytes();
    if (mounted) {
      setState(() {
        _fotoBytes = bytes;
        _fotoEliminada = false;
        _fotoNueva = true;
      });
    }
  }

  bool _fotoEliminada = false;

  Future<void> _eliminarFoto() async {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar foto'),
        content: const Text('¿Seguro que quieres eliminar esta foto?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(), // Cerrar sin borrar.
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop(); // Cerramos la ventana...
              setState(() {
                _fotoBytes = null;
                _fotoEliminada = true;
                _cubit.update(_pedido.copyWith(fotoBase64: ''));
              });
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error), // Rojito.
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
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
    final user = context.read<AuthState>().currentUser;
    if (user?.role.toLowerCase() == 'comercial' &&
        (user?.contactId.isEmpty ?? true)) {
      _snack('El usuario comercial no tiene contacto asociado.');
      return false;
    }
    return true;
  }

  /// _snack: atajo para mostrar un mensaje flotante.
  void _snack(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje)));
  }

  Future<void> _confirmarEliminar() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar pedido'),
        content: const Text('¿Estás seguro de que quieres eliminar este pedido de venta? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      setState(() => _guardando = true);
      // Velneo may prevent deleting an order if it still has lines.
      // So we explicitly delete all lines first.
      for (final linea in _lineas) {
        if (linea.id != null) {
          try {
            await PedidosService.eliminarLinea(linea.id!);
          } catch (_) {} // Ignore errors for individual lines (e.g. already deleted)
        }
      }
      
      await PedidosService.remove(_pedidoIdReal);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pedido eliminado correctamente')),
      );
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/pedidos',
        (route) => route.settings.name == '/home' || route.isFirst,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al eliminar: $e')),
      );
      setState(() => _guardando = false);
    }
  }

  /// _guardar: valida y envía al servidor (POST si es nuevo, PUT si edita).
  Future<void> _guardar() async {
    if (_editando && AppColors.estadoCodigo(_pedido.estado) == 'S') {
      _snack('Los pedidos SERVIDOS no se pueden editar.');
      return;
    }
    if (!_validar()) return; // No cumple reglas → nos quedamos aquí.
    setState(() => _guardando = true); // Bloqueamos el botón "Guardar".

    try {
      final removedLineIds = _lineasOriginalesIds
          .difference(
            _lineas
                .where((linea) => linea.id != null)
                .map((linea) => linea.id!)
                .toSet(),
          );
      final user = context.read<AuthState>().currentUser;
      final pedidoConComercial = user?.role.toLowerCase() == 'comercial'
          ? _pedido.copyWith(
              comercial: user!.contactId,
              comercialNombre: user.name,
            )
          : _pedido;
      final totales = calcularTotales(_lineas);
      final pedidoParaGuardar = pedidoConComercial.copyWith(
        lineas: _lineas,
        total: totales.total,
      );
      if (_editando) {
        await PedidosService.updateComplete(
          _pedidoIdReal,
          pedidoParaGuardar,
          removedLineIds,
          fotoBytes: _fotoNueva ? _fotoBytes : null,
          deleteFoto: _fotoEliminada,
        );
      } else {
        final nuevoPedido = await PedidosService.createComplete(
          pedidoParaGuardar,
          fotoBytes: _fotoNueva ? _fotoBytes : null,
        );
          if (widget.pedidoId is Pedido && (widget.pedidoId as Pedido).id != null) {
            await PresupuestosService.linkPedido(
              (widget.pedidoId as Pedido).id,
              nuevoPedido.id ?? nuevoPedido.codigo,
            );
          }
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pedido guardado correctamente')),
      );
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/pedidos',
        (route) => route.settings.name == '/home' || route.isFirst,
      );
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
    return BlocProvider<PedidoFormCubit>(
      // El cubit lo creamos en initState; aquí solo lo exponemos al árbol.
      create: (_) => _cubit,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
                      if (_editando) (key: 'foto', label: 'Foto'),
                    ],
                    active: _tabIndex < _tabs.length ? _tabs[_tabIndex] : 'cabecera',
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
                  // Contenido según la pestaña activa con deslizamiento.
                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      onPageChanged: (index) {
                        setState(() => _tabIndex = index);
                      },
                      children: [
                        // Cabecera: el formulario, que avisa en cada cambio.
                        BlocBuilder<PedidoFormCubit, PedidoFormState>(
                          builder: (context, state) => CabeceraForm(
                            pedido: state.pedido,
                            onChanged: _onCambioCabecera,
                          ),
                        ),
                        // Líneas: versión editable (permite editar y añadir).
                        LineasTable(
                          lineas: _lineas,
                          onEdit: _editarLinea,
                          onAdd: _anadirLinea,
                        ),
                        // Totales: resumen de las líneas en memoria.
                        _totales(),
                        // Foto (si está en modo edición).
                        if (_editando)
                          PedidoFotoTab(
                            imageBytes: _fotoBytes,
                            uploading: false,
                            onCamera: () => _seleccionarFoto(ImageSource.camera),
                            onGallery: () => _seleccionarFoto(ImageSource.gallery),
                            onDelete: _eliminarFoto,
                          ),
                      ],
                    ),
                  ),

                  // ---- Barra inferior: Cancelar | Guardar ----
                  Material(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            if (_editando) ...[
                              Tooltip(
                                message: 'Eliminar pedido',
                                child: SizedBox.square(
                                  dimension: 48,
                                  child: OutlinedButton(
                                    onPressed: _confirmarEliminar,
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.error,
                                      side: const BorderSide(color: AppColors.error),
                                      padding: EdgeInsets.zero,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    child: const Icon(Icons.delete_outline, size: 20),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                            ],
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.of(context).pop(), // Salir sin guardar.
                                child: const Text('Cancelar'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _guardando || context.watch<LicenciaService>().esSoloLec ? null : _guardar, // Deshabilitado mientras guarda o si es solo lectura.
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
