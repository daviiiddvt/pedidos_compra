// ============================================================================
//  fila_linea.dart  —  LA "TARJETA" DE UNA LÍNEA DE PEDIDO
// ============================================================================
//
//  ¿Qué es?
//  --------
//  Cada tarjeta dentro de la pestaña "Líneas". Muestra un artículo con:
//     - El código del artículo y su estado.
//     - La descripción (2 líneas como máximo).
//     - Cantidad, pendiente, precio, % dto. e IVA (5 "celdas" pequeñas).
//     - El importe de la línea, destacado.
//
//  CONCEPTO:
//  - _Celda: una clase PRIVADA (con _) que dibuja "etiqueta + valor" en
//    pequeño. Es un mini-widget solo para este archivo (reduciendo código).
// ============================================================================

import 'package:flutter/material.dart';

import '../models.dart'; // LineaPedido.
import '../theme/app_theme.dart'; // Colores.
import '../core/formatters.dart'; // formatNumber.
import 'estado_badge.dart'; // Píldora del estado.

/// FilaLinea: tarjeta de una línea (una fila de artículo del pedido).
class FilaLinea extends StatelessWidget {
  final LineaPedido linea; // La línea a dibujar.
  final VoidCallback? onTap; // Al tocar (en el formulario permite editar). Puede ser null.

  const FilaLinea({super.key, required this.linea, this.onTap});

  @override
  Widget build(BuildContext context) {
    // Descripción mostrada: la de la línea; si no, el nombre del artículo;
    // si no, el código del artículo.
    final descripcion = linea.descripcion.isNotEmpty
        ? linea.descripcion
        : (linea.articuloNombre.isNotEmpty ? linea.articuloNombre : linea.articulo);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap, // null = no clicable (vista de detalle).
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ---- Fila superior: artículo + estado ----
              Row(
                children: [
                  Expanded(
                    child: Text(
                        linea.articuloNombre.isNotEmpty
                          ? linea.articuloNombre
                          : (linea.articulo.isNotEmpty ? linea.articulo : '—'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Si la línea está cancelada, mostramos "Cancelado" sí o sí.
                  EstadoBadge(
                    estado: linea.cancelado ? 'Cancelado' : linea.estado,
                    small: true,
                  ),
                ],
              ),

              // ---- Descripción (si existe) ----
              if (descripcion.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    descripcion,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              const SizedBox(height: 8),

              // ---- Las 5 celdas de datos (horizontal) ----
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _Celda('Cantidad', formatNumber(linea.cantidad)),
                  _Celda('Pendiente', formatNumber(linea.pendiente)),
                  _Celda('Precio', '${formatNumber(linea.precio)} €'),
                  _Celda('Dto.', '${formatNumber(linea.dto)} %'),
                  _Celda('IVA', '${formatNumber(linea.tipoIva)} %'),
                ],
              ),
              const SizedBox(height: 6),

              // ---- Importe de la línea (destacado) ----
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Importe',
                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                  Text(
                    '${formatNumber(linea.importe)} €',
                    style: const TextStyle(
                      fontSize: 14,
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

/// _Celda: mini-widget "etiqueta encima + valor debajo" (privado a este archivo).
class _Celda extends StatelessWidget {
  final String label; // "Cantidad"
  final String value; // "3"

  const _Celda(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontSize: 13, color: AppColors.text),
        ),
      ],
    );
  }
}