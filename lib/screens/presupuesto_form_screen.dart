import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../presupuesto_service.dart';
import '../state/auth_state.dart';
import '../theme/app_theme.dart';
import '../core/formatters.dart';
import '../widgets/cabecera_form.dart';
import '../widgets/linea_form_modal.dart';
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
  late Pedido _presupuesto;
  List<LineaPedido> _lineas = [];
  Set<int> _originalLineIds = {};
  bool _loading = false;
  bool _saving = false;
  String _tab = 'cabecera';

  bool get _editing => widget.presupuestoId != null;

  @override
  void initState() {
    super.initState();
    _presupuesto = Pedido(fecha: todayIso());
    if (_editing) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final budget = await PresupuestosService.getById(widget.presupuestoId);
      if (!mounted) return;
      setState(() {
        _presupuesto = budget;
        _lineas = [...budget.lineas];
        _originalLineIds = budget.lineas
            .where((line) => line.id != null)
            .map((line) => line.id!)
            .toSet();
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  Future<void> _editLine(LineaPedido line, int index) async {
    final result = await mostrarLineaForm(
      context,
      linea: line,
      onDelete: () => setState(() => _lineas = [..._lineas]..removeAt(index)),
    );
    if (result != null && mounted) setState(() => _lineas[index] = result);
  }

  Future<void> _addLine() async {
    final result = await mostrarLineaForm(context);
    if (result != null && mounted) setState(() => _lineas = [..._lineas, result]);
  }

  Future<void> _save() async {
    if (_presupuesto.clienteId <= 0) {
      _snack('Selecciona un cliente.');
      return;
    }
    if (_lineas.isEmpty) {
      _snack('El presupuesto debe tener al menos una línea.');
      return;
    }
    setState(() => _saving = true);
    try {
      final user = context.read<AuthState>().currentUser;
      final budget = user?.role.toLowerCase() == 'comercial'
          ? _presupuesto.copyWith(comercial: user!.contactId, comercialNombre: user.name)
          : _presupuesto;
      final removed = _originalLineIds
          .difference(_lineas.where((line) => line.id != null).map((line) => line.id!).toSet());
      if (_editing) {
        await PresupuestosService.updateComplete(
          widget.presupuestoId,
          budget.copyWith(lineas: _lineas),
          removed,
        );
      } else {
        await PresupuestosService.createComplete(budget.copyWith(lineas: _lineas));
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      _snack('Error al guardar: $error');
    }
  }

  void _snack(String message) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(_editing ? 'Editar presupuesto' : 'Nuevo presupuesto')),
      body: _loading
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
                        onEdit: _editLine,
                        onAdd: _addLine,
                      ),
                    'totales' => SingleChildScrollView(
                        padding: const EdgeInsets.all(12),
                        child: TotalesCard(
                          base: calcularTotales(_lineas).base,
                          iva: calcularTotales(_lineas).iva,
                          total: calcularTotales(_lineas).total,
                        ),
                      ),
                    _ => CabeceraForm(
                        pedido: _presupuesto,
                        onChanged: (value) => setState(() => _presupuesto = value),
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
                            onPressed: _saving ? null : _save,
                            child: _saving
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
    );
  }
}
