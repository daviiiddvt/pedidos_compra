// ============================================================================
//  cabecera_view.dart  —  VISTA DE LA CABECERA DEL PEDIDO (SOLO LECTURA)
// ============================================================================
//
//  ¿Qué es?
//  --------
//  La pestaña "Cabecera" del DETALLE del pedido. Muestra TODOS los datos
//  generales en forma de lista: proveedor, serie, fechas, envío, etc.
//  Es de solo lectura (no se puede editar aquí; para eso está cabecera_form).
//
//  CONCEPTO:
//  - _Campo : mini-widget "etiqueta gris + valor" (privado a este archivo).
//  - _Seccion: el título de una sección ("DATOS GENERALES", "ENVÍO...").
// ============================================================================

import 'package:flutter/material.dart';

import '../models.dart'; // Pedido + calcularTotales.
import '../theme/app_theme.dart'; // Colores.
import '../core/formatters.dart'; // formatDate y formatNumber.
import 'estado_badge.dart'; // Píldora del estado.

/// CabeceraView: lista de datos generales del pedido (solo lectura).
class CabeceraView extends StatelessWidget {
  final Pedido pedido; // El pedido cuyos datos mostrar.

  const CabeceraView({super.key, required this.pedido});

  @override
  Widget build(BuildContext context) {
    // Total del pedido: si tiene líneas las suma; si no, usamos el total de
    // la cabecera que manda el servidor (tot_ped).
    final total = pedido.lineas.isNotEmpty ? calcularTotales(pedido.lineas).total : pedido.total;

    return ListView( // Toda la información en scroll vertical.
      padding: const EdgeInsets.all(16),
      children: [
        // ---- Fila superior: código (si lo hay) + estado ----
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (pedido.codigo != 0)
              Text(
                'Código: ${pedido.codigo}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              )
            else
              const SizedBox.shrink(), // Si no hay código, no ponemos nada.
            EstadoBadge(estado: pedido.estado),
          ],
        ),

        // ---- Sección 1: DATOS GENERALES ----
        const _Seccion('Datos generales'),
        _Campo('N° pedido', pedido.nPedido),
        _Campo('N° documento', pedido.nDocumento.toString()),
        // Mostramos el nombre del cliente; si no, su código.
        _Campo('Cliente',
            pedido.clienteNombre.isNotEmpty ? pedido.clienteNombre : pedido.cliente),
        _Campo('Serie ventas', pedido.serieNombre.isNotEmpty ? pedido.serieNombre : pedido.serie),
        _Campo('Comercial',
            pedido.comercialNombre.isNotEmpty ? pedido.comercialNombre : pedido.comercial),
        _Campo('Almacén',
            pedido.almacenNombre.isNotEmpty ? pedido.almacenNombre : pedido.almacen),
        _Campo('Fecha', formatDate(pedido.fecha)), // Formato "10/09/2026".
        _Campo('Entregar el', formatDate(pedido.previstoPara)),
        _Campo('Forma de pago',
            pedido.formaPagoNombre.isNotEmpty ? pedido.formaPagoNombre : pedido.formaPago),

        // ---- Sección 2: ENVÍO ----
        const _Seccion('Envío'),
        _Campo('Dirección de envío', pedido.direccionEnvio),
        _Campo('Email', pedido.email),

        // ---- Sección 3: OTROS ----
        const _Seccion('Otros'),
        _Campo('Observaciones', pedido.observaciones),
        const SizedBox(height: 8),

        // ---- Total al final ----
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Total pedido',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            Text(
              '${formatNumber(total)} €',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// _Campo: "etiqueta gris pequeña + valor grande" (privado a este archivo).
class _Campo extends StatelessWidget {
  final String label; // "Proveedor"
  final String? valor; // "Ferretería SL" (si está vacío, se muestra "—").

  const _Campo(this.label, this.valor);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 2),
          Text(
            (valor == null || valor!.isEmpty) ? '—' : valor!, // Guion si está vacío.
            style: const TextStyle(fontSize: 15, color: AppColors.text),
          ),
        ],
      ),
    );
  }
}

/// _Seccion: título de una sección (en MAYÚSCULAS y en azul).
class _Seccion extends StatelessWidget {
  final String texto;

  const _Seccion(this.texto);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 12),
      child: Text(
        texto.toUpperCase(), // Lo ponemos todo en mayúsculas.
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
          letterSpacing: 0.5, // Un pelín de espacio entre letras.
        ),
      ),
    );
  }
}