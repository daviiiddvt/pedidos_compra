import 'package:flutter/material.dart';

import '../models/models.dart';
import 'cabecera_form.dart';

/// Cabecera independiente del formulario de presupuestos de venta.
class PresupuestoCabeceraForm extends StatelessWidget {
  final Pedido pedido;
  final ValueChanged<Pedido> onChanged;

  const PresupuestoCabeceraForm({
    super.key,
    required this.pedido,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return CabeceraForm(
      pedido: pedido,
      onChanged: onChanged,
      mostrarAlmacen: false,
      mostrarFechaEntrega: false,
      mostrarEmail: true,
      mostrarFechaValidez: pedido.id != null && pedido.id! > 0,
      mostrarNumeroPresupuesto: true,
      estadosDisponibles: const ['Pendiente', 'Aceptado', 'Rechazado', 'Parcialmente Servido'],
    );
  }
}
