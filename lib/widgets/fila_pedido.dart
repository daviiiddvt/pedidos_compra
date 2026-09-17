// ============================================================================
//  fila_pedido.dart  —  LA "TARJETA" DE UN PEDIDO EN LA LISTA
// ============================================================================
//
//  ¿Qué es?
//  --------
//  Cada tarjeta de la lista de pedidos. Muestra de un vistazo:
//     - El código del pedido (etiqueta azul).
//     - El estado (píldora de color, a la derecha).
//     - El cliente.
//     - N° de pedido y fecha.
//     - El total, en azul y bien grande.
//  Al tocar la tarjeta → onTap (la lista navega al detalle).
//
//  Es StatelessWidget: no guarda nada, solo le dicen qué pedido dibujar.
// ============================================================================

import 'package:flutter/material.dart';

import '../models.dart'; // Pedido + calcularTotales.
import '../theme/app_theme.dart'; // Colores.
import '../core/formatters.dart'; // formatDate y formatNumber.
import 'estado_badge.dart'; // La píldora del estado.

/// FilaPedido: una tarjeta de la lista con el resumen del pedido.
class FilaPedido extends StatelessWidget {
  final Pedido pedido; // El pedido a dibujar.
  final VoidCallback onTap; // Qué hacer al tocar (navegar al detalle).

  const FilaPedido({super.key, required this.pedido, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // Total del pedido: si tiene líneas las suma; si no, usamos el total que
    // manda el servidor en la cabecera (tot_ped). Así la lista no muestra 0.
    final total = (pedido.lineas.isNotEmpty)
        ? calcularTotales(pedido.lineas).total
        : pedido.total;
    final nPedido = pedido.nPedido; // N° de pedido (num_ped).
    final fecha = pedido.fecha.isNotEmpty ? formatDate(pedido.fecha) : '';

    return Card(
      child: InkWell( // Hace toda la tarjeta clicable.
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ---- Fila superior: código (izquierda) + estado (derecha) ----
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Etiqueta azul con el código (o el id, o "—").
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${pedido.codigo ?? pedido.id ?? '—'}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  EstadoBadge(estado: pedido.estado), // Píldora del estado.
                ],
              ),
              const SizedBox(height: 10),

              // ---- Cliente ----
              Text(
                // Nombre; si no, código; si no, "Sin cliente".
                pedido.clienteNombre.isNotEmpty
                    ? pedido.clienteNombre
                    : (pedido.cliente.isNotEmpty ? pedido.cliente : 'Sin cliente'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis, // "..."
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 4),

              // ---- N° pedido (izquierda) + fecha (derecha) ----
              Row(
                children: [
                  if (nPedido.isNotEmpty)
                    Expanded(
                      child: Text(
                        'N° pedido: $nPedido',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  if (fecha.isNotEmpty)
                    Text(
                      fecha, // "10/09/2026"
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
              const Divider(height: 20), // Línea separadora.

              // ---- Total ----
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total pedido',
                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                  Text(
                    '${formatNumber(total)} €', // "1.234,56 €"
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}