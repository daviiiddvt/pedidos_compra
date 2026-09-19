import 'package:flutter/material.dart';

import '../models.dart';
import '../presupuesto_service.dart';
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
  State<PresupuestoDetailScreen> createState() => _PresupuestoDetailScreenState();
}

class _PresupuestoDetailScreenState extends State<PresupuestoDetailScreen> {
  Pedido? _presupuesto;
  bool _loading = true;
  String _tab = 'cabecera';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final budget = await PresupuestosService.getById(widget.presupuestoId);
      if (mounted) setState(() { _presupuesto = budget; _loading = false; });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final budget = _presupuesto;
    return Scaffold(
      appBar: AppBar(
        title: Text(budget == null ? 'Presupuesto' : 'Presupuesto ${budget.codigo}'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : budget == null
              ? const Center(child: Text('No se encontró el presupuesto'))
              : Column(
                  children: [
                    _summary(budget),
                    SegmentTabs(
                      tabs: [
                        (key: 'cabecera', label: 'Cabecera'),
                        (key: 'lineas', label: 'Líneas (${budget.lineas.length})'),
                        (key: 'totales', label: 'Totales'),
                      ],
                      active: _tab,
                      onChanged: (tab) => setState(() => _tab = tab),
                    ),
                    Expanded(
                      child: switch (_tab) {
                        'lineas' => LineasTable(lineas: budget.lineas),
                        'totales' => SingleChildScrollView(
                            padding: const EdgeInsets.all(12),
                            child: TotalesCard(
                              base: calcularTotales(budget.lineas).base,
                              iva: calcularTotales(budget.lineas).iva,
                              total: calcularTotales(budget.lineas).total,
                            ),
                          ),
                        _ => CabeceraView(pedido: budget),
                      },
                    ),
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              await Navigator.of(context).pushNamed(
                                '/presupuesto/form',
                                arguments: budget.id,
                              );
                              if (mounted) _load();
                            },
                            icon: const Icon(Icons.edit),
                            label: const Text('Editar'),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _summary(Pedido budget) => Container(
        color: AppColors.surface,
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Código ${budget.codigo == 0 ? '' : budget.codigo}',
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            EstadoBadge(estado: budget.estado),
          ],
        ),
      );
}
