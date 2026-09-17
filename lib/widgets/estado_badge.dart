// ============================================================================
//  estado_badge.dart  —  ETIQUETA DE ESTADO (la "pegatina" de color)
// ============================================================================
//
//  ¿Qué es?
//  --------
//  Una pequeña "píldora" que muestra el estado de un pedido o de una línea:
//     - "Pendiente"  → naranja
//     - "Recibido"   → verde
//     - "Cancelado"  → gris
//  Se reutiliza en la lista, en el detalle, en el formulario y en las líneas.
//  Como es StatelessWidget (no guarda nada), solo PINTÁ según el estado que le den.
// ============================================================================

import 'package:flutter/material.dart';

import '../theme/app_theme.dart'; // AppColors (colores y lógica del estado).

/// EstadoBadge: "pegatina" con puntito de color + texto.
class EstadoBadge extends StatelessWidget {
  final String? estado; // El estado tal cual lo manda el servidor.
  final bool small; // true = versión compacta (se usa en las líneas).

  const EstadoBadge({super.key, this.estado, this.small = false});

  @override
  Widget build(BuildContext context) {
    // Preguntamos a AppColors qué color y qué texto le tocan a este estado.
    final color = AppColors.estadoColor(estado);
    final label = AppColors.estadoLabel(estado);

    return Container(
      // Relleno un pelín menor si es la versión pequeña.
      padding: EdgeInsets.symmetric(
        horizontal: small ? 8 : 10,
        vertical: small ? 2 : 4,
      ),
      decoration: BoxDecoration(
        // El fondo es el color del estado PERO muy transparente (alpha 0.12).
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999), // 999 = círculo perfecto.
        border: Border.all(color: color), // Borde del color del estado.
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min, // Ocupar solo lo necesario.
        children: [
          // El "puntito" de color (un círculo pequeño).
          Container(
            width: small ? 6 : 7,
            height: small ? 6 : 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          // El texto del estado, del mismo color.
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: small ? 11 : 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}