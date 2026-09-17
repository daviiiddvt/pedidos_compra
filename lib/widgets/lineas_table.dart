// ============================================================================
//  lineas_table.dart  —  LA TABLA "SCROLLABLE" DE LÍNEAS DE PEDIDO
// ============================================================================
//
//  ¿Qué es?
//  --------
//  El contenedor de la pestaña "Líneas". Puede estar en dos modos:
//     - SOLO LECTURA (detalle): muestra las líneas, sin botones.
//     - EDITABLE (formulario): además hay un botón "Añadir línea" y, al tocar
//       una línea, se abre el modal de edición.
//
//  Los parámetros son OPCIONALES:
//     onEdit != null → se puede editar (tocar una línea abre el modal).
//     onAdd  != null → se muestra el botón "Añadir línea".
//
//  CONCEPTO:
//  - ListView.separated: lista con un separador entre elementos.
//  - SeparatorBuilder(_, _): recibe dos parámetros que no usamos; por eso "_".
// ============================================================================

import 'package:flutter/material.dart';

import '../models.dart'; // LineaPedido.
import '../theme/app_theme.dart'; // Colores.
import 'fila_linea.dart'; // La tarjeta de cada línea.

/// LineasTable: lista de líneas de pedido (con o sin edición).
class LineasTable extends StatelessWidget {
  final List<LineaPedido> lineas; // Las líneas a mostrar.
  final void Function(LineaPedido linea, int index)? onEdit; // Si no es null → editables.
  final VoidCallback? onAdd; // Si no es null → se muestra el botón de añadir.
  final String emptyText; // Texto cuando no hay líneas.

  const LineasTable({
    super.key,
    required this.lineas,
    this.onEdit,
    this.onAdd,
    this.emptyText = 'Sin líneas',
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ---- La lista en sí (ocupa todo el alto disponible) ----
        Expanded(
          child: lineas.isEmpty
              // Sin líneas: mensaje centrado.
              ? Center(
                  child: Text(
                    emptyText,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                )
              // Con líneas: la lista con mini-separadores.
              : ListView.separated(
                  padding: const EdgeInsets.only(top: 8, bottom: 8),
                  itemCount: lineas.length,
                  // (_, _) = los dos parámetros del builder no nos hacen falta.
                  separatorBuilder: (_, _) => const SizedBox(height: 4),
                  itemBuilder: (context, index) {
                    final linea = lineas[index];
                    return FilaLinea(
                      linea: linea,
                      // Si estamos en modo edición, al tocar → onEdit.
                      onTap: onEdit != null ? () => onEdit!(linea, index) : null,
                    );
                  },
                ),
        ),

        // ---- Botón "Añadir línea" (solo si onAdd no es null) ----
        if (onAdd != null)
          Padding(
            padding: const EdgeInsets.all(12),
            child: OutlinedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Añadir línea'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                minimumSize: const Size.fromHeight(46), // Botón a lo ancho.
              ),
            ),
          ),
      ],
    );
  }
}