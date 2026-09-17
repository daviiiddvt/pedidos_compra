// ============================================================================
//  totales_card.dart  —  TARJETA DE TOTALES (el "recibo" del pedido)
// ============================================================================
//
//  ¿Qué es?
//  --------
//  Muestra el resumen económico de un pedido:
//     - Base total   (suma sin impuestos)
//     - Total IVA    (lo que corresponde de impuestos)
//     - Total Pedido (lo que cuesta en realidad, en grande y en azul)
//  Se usa tanto en el detalle como en el formulario. Le pasan los números ya
//  calculados y ella solo los PINTÁ.
// ============================================================================

import 'package:flutter/material.dart';

import '../theme/app_theme.dart'; // Colores.
import '../core/formatters.dart'; // formatNumber (dá formato "1.234,50").

/// TotalesCard: tarjeta con base, IVA y total.
class TotalesCard extends StatelessWidget {
  final double base; // Suma de bases (sin IVA).
  final double iva; // Suma de IVA.
  final double total; // Base + IVA.

  const TotalesCard({
    super.key,
    required this.base,
    required this.iva,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _fila('Base total', formatNumber(base)), // "Base total   1.000,00 €"
            const SizedBox(height: 8),
            _fila('Total IVA', formatNumber(iva)), // "Total IVA     210,00 €"
            const Divider(height: 24), // Separador.
            // La fila final, destacada:
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total Pedido',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                  ),
                ),
                Text(
                  '${formatNumber(total)} €', // "Total   1.210,00 €"
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// _fila: una fila "etiqueta + valor" (reutilizada por base e IVA).
  Widget _fila(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween, // Etiqueta a un lado, valor al otro.
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        Text(
          '$value €',
          style: const TextStyle(fontSize: 14, color: AppColors.text),
        ),
      ],
    );
  }
}