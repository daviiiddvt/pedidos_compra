import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/formatters.dart';
import '../models/models.dart';
import '../core/presupuesto_service.dart';
import '../theme/app_theme.dart';
import '../state/auth_state.dart';
import '../state/pedido_form_cubit.dart';
import '../widgets/presupuesto_cabecera_form.dart';
import '../widgets/presupuesto_linea_form_modal.dart';
import '../widgets/lineas_table.dart';
import '../widgets/segment_tabs.dart';
import '../widgets/totales_card.dart';

class PresupuestoFormScreen extends StatefulWidget {
  final dynamic presupuestoId;

  const PresupuestoFormScreen({super.key, this.presupuestoId});

  @override
  State<PresupuestoFormScreen> createState() => _PresupuestoFormScreenState();
}

class _PresupuestoFormScreenState extends State<PresupuestoFormScreen> {
  late final PedidoFormCubit _cubit;
  List<LineaPedido> _lineas = [];
  Set<int> _lineasOriginalesIds = {};
  bool _cargando = false;
  bool _guardando = false;
  String _tab = 'cabecera';

  dynamic get _presupuestoIdReal =>
      widget.presupuestoId is PresupuestoVenta
          ? (widget.presupuestoId as PresupuestoVenta).id
          : (widget.presupuestoId is Pedido
              ? (widget.presupuestoId as Pedido).id
              : widget.presupuestoId);

  bool get _editando => _presupuestoIdReal != null;

  Pedido get _presupuesto => _cubit.state.pedido;

  @override
  void initState() {
    super.initState();
    if (widget.presupuestoId is PresupuestoVenta) {
      final p = widget.presupuestoId as PresupuestoVenta;
      final visual = p.toPedidoVisual();
      _cubit = PedidoFormCubit(visual);
      _lineas = [...visual.lineas];
      _lineasOriginalesIds = p.lineas.where((l) => l.id != null).map((l) => l.id!).toSet();
      _cargando = false;
      _cubit.init(visual);
    } else if (widget.presupuestoId is Pedido) {
      final visual = widget.presupuestoId as Pedido;
      _cubit = PedidoFormCubit(visual);
      _lineas = [...visual.lineas];
      _lineasOriginalesIds = visual.lineas.where((l) => l.id != null).map((l) => l.id!).toSet();
      _cargando = false;
      _cubit.init(visual);
    } else {
      _cubit = PedidoFormCubit(Pedido(fecha: todayIso()));
      if (_editando) _cargar();
    }
  }

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final presupuesto = await PresupuestosService.getById(widget.presupuestoId);
      if (!mounted) return;
      _cubit.init(presupuesto.toPedidoVisual());
      setState(() {
        _lineas = [...presupuesto.toPedidoVisual().lineas];
        _lineasOriginalesIds = presupuesto.lineas
            .where((line) => line.id != null)
            .map((line) => line.id!)
            .toSet();
        _cargando = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _cargando = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  Future<void> _editarLinea(LineaPedido line, int index) async {
    final result = await mostrarPresupuestoLineaForm(
      context,
      linea: line,
      clienteId: _presupuesto.clienteId,
      onDelete: () => setState(() => _lineas = [..._lineas]..removeAt(index)),
    );
    if (result != null && mounted) setState(() => _lineas[index] = result);
  }

  Future<void> _anadirLinea() async {
    final result = await mostrarPresupuestoLineaForm(
      context,
      clienteId: _presupuesto.clienteId,
    );
    if (result != null && mounted) {
      setState(() => _lineas = [..._lineas, result]);
    }
  }

  Future<void> _guardar() async {
    if (_editando && AppColors.estadoCodigo(_presupuesto.estado) == 'A') {
      _mostrarMensaje('Los presupuestos ACEPTADOS no se pueden editar.');
      return;
    }
    if (_presupuesto.clienteId <= 0) {
      _mostrarMensaje('Selecciona un cliente.');
      return;
    }
    if (_lineas.isEmpty) {
      _mostrarMensaje('El presupuesto debe tener al menos una línea.');
      return;
    }
    setState(() => _guardando = true);
    try {
      final user = context.read<AuthState>().currentUser;
      final pedidoVisual = user?.role.toLowerCase() == 'comercial'
          ? _presupuesto.copyWith(
              comercial: user!.contactId,
              comercialNombre: user.name,
            )
          : _presupuesto;
      final presupuesto = PresupuestoVenta.fromPedidoVisual(pedidoVisual);
      final removed = _lineasOriginalesIds.difference(
        _lineas
            .where((line) => line.id != null)
            .map((line) => line.id!)
            .toSet(),
      );
      if (_editando) {
        await PresupuestosService.updateComplete(
          _presupuestoIdReal,
          presupuesto.copyWith(
            lineas: _lineas
                .map(
                  (linea) => LineaPresupuestoVenta(
                    id: linea.id,
                    articulo: linea.articulo,
                    articuloNombre: linea.articuloNombre,
                    descripcion: linea.descripcion,
                    cantidad: linea.cantidad,
                    precio: linea.precio,
                    dto: linea.dto,
                    importe: linea.importe,
                    tipoIva: linea.tipoIva,
                    regIvaVta: linea.regIvaVta,
                    estado: linea.estado,
                  ),
                )
                .toList(),
          ),
          removed,
        );
      } else {
        await PresupuestosService.createComplete(
          presupuesto.copyWith(
            lineas: _lineas
                .map(
                  (linea) => LineaPresupuestoVenta(
                    id: linea.id,
                    articulo: linea.articulo,
                    articuloNombre: linea.articuloNombre,
                    descripcion: linea.descripcion,
                    cantidad: linea.cantidad,
                    precio: linea.precio,
                    dto: linea.dto,
                    importe: linea.importe,
                    tipoIva: linea.tipoIva,
                    regIvaVta: linea.regIvaVta,
                    estado: linea.estado,
                  ),
                )
                .toList(),
          ),
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Presupuesto guardado correctamente')),
      );
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/presupuestos',
        (route) => route.settings.name == '/home' || route.isFirst,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _guardando = false);
      _mostrarMensaje('Error al guardar: $error');
    }
  }

  void _mostrarMensaje(String mensaje) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(mensaje)));

  @override
  Widget build(BuildContext context) {
    return BlocProvider<PedidoFormCubit>(
      create: (_) => _cubit,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text(_editando ? 'Editar presupuesto' : 'Nuevo presupuesto'),
        ),
        body: _cargando
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  SegmentTabs(
                    tabs: [
                      (key: 'cabecera', label: 'Cabecera'),
                      (key: 'lineas', label: 'Líneas (${_lineas.length})'),
                      (key: 'totales', label: 'Totales'),
                    ],
                    active: _tab,
                    onChanged: (tab) => setState(() => _tab = tab),
                  ),
                  Expanded(
                    child: switch (_tab) {
                      'lineas' => LineasTable(
                        lineas: _lineas,
                        onEdit: _editarLinea,
                        onAdd: _anadirLinea,
                      ),
                      'totales' => SingleChildScrollView(
                        padding: const EdgeInsets.all(12),
                        child: TotalesCard(
                          base: calcularTotales(_lineas).base,
                          iva: calcularTotales(_lineas).iva,
                          total: calcularTotales(_lineas).total,
                          labelTotal: 'Total Presupuesto',
                        ),
                      ),
                      _ => BlocBuilder<PedidoFormCubit, PedidoFormState>(
                        builder: (context, state) => PresupuestoCabeceraForm(
                          pedido: state.pedido,
                          onChanged: (value) => _cubit.update(value),
                        ),
                      ),
                    },
                  ),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Cancelar'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _guardando ? null : _guardar,
                              child: _guardando
                                  ? const CircularProgressIndicator()
                                  : const Text('Guardar'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

