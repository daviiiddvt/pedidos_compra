import 'package:flutter/material.dart';

import '../models/models.dart';
import 'linea_form_modal.dart';

/// Modal independiente para líneas de presupuestos de venta.
Future<LineaPedido?> mostrarPresupuestoLineaForm(
  BuildContext context, {
  LineaPedido? linea,
  VoidCallback? onDelete,
}) {
  return mostrarLineaForm(
    context,
    linea: linea,
    onDelete: onDelete,
    mostrarFechaEntrega: false,
    mostrarReferencia: false,
    estadosDisponibles: const ['Pendiente', 'Aceptado', 'Rechazado', 'Parcialmente Servido'],
  );
}
