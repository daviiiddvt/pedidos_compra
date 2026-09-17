// ============================================================================
//  campo_fecha.dart  —  CAMPO DE FECHA (abre un calendario)
// ============================================================================
//
//  ¿Qué es?
//  --------
//  Un campo que PARE CE un texto pero, al tocarlo, abre el calendario
//  (showDatePicker). Es EstatelessWidget porque no guarda nada: le dicen el
//  valor (value) y él avisa cuando se elige una fecha (onChanged).
//
//  El valor se guarda SIEMPRE en formato ISO "2026-09-10" (es lo que entiende
//  VELNEO), pero en pantalla se muestra como "10/09/2026" vía formatDate.
// ============================================================================

import 'package:flutter/material.dart';

import '../theme/app_theme.dart'; // Colores.
import '../core/formatters.dart'; // formatDate (mostrar la fecha en español).

/// CampoFecha: campo de fecha con calendario emergente.
class CampoFecha extends StatelessWidget {
  final String label; // Etiqueta ("Fecha", "Previsto para"...).
  final String? value; // Fecha actual en ISO (o null = no hay).
  final ValueChanged<String> onChanged; // Avisa con la nueva fecha en ISO.
  final bool required; // Muestra el "*".

  const CampoFecha({
    super.key,
    required this.label,
    this.value,
    required this.onChanged,
    this.required = false,
  });

  /// _seleccionar: abre el calendario y, si elige fecha, avisa en ISO.
  Future<void> _seleccionar(BuildContext context) async {
    // Interpretamos el valor actual para que el calendario abra en esa fecha
    // (si hay alguna); si no hay, abre en la fecha de hoy.
    final initial = value != null && value!.isNotEmpty
        ? DateTime.tryParse(value!.contains('T') ? value! : '${value!}T00:00:00')
        : null;

    // showDatePicker: el calendario del sistema operativo.
    final picked = await showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now(), // Fecha en la que abre.
      firstDate: DateTime(2000), // No se puede elegir antes de 2000.
      lastDate: DateTime(2100), // Ni después de 2100.
    );
    if (picked != null) {
      // El usuario eligió. Lo convertimos a "2026-09-10" (ISO) y avisamos.
      onChanged(
        '${picked.year}-'
        '${picked.month.toString().padLeft(2, '0')}-'
        '${picked.day.toString().padLeft(2, '0')}',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final hayValor = value != null && value!.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Etiqueta.
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            if (required)
              const Text(
                ' *',
                style: TextStyle(fontSize: 13, color: AppColors.error),
              ),
          ],
        ),
        const SizedBox(height: 6),

        // Zona clicable con aspecto de campo.
        InkWell(
          onTap: () => _seleccionar(context), // Tocar = abrir calendario.
          borderRadius: BorderRadius.circular(10),
          child: InputDecorator(
            decoration: const InputDecoration(),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween, // Fecha ✓ icono.
              children: [
                Expanded(
                  child: Text(
                    // Mostramos la fecha en formato español; si no hay, el mensaje.
                    hayValor ? formatDate(value) : 'Seleccionar fecha',
                    style: TextStyle(
                      fontSize: 15,
                      color: hayValor ? AppColors.text : AppColors.disabled,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Icono de calendario.
                const Icon(Icons.calendar_today_outlined,
                    color: AppColors.textSecondary, size: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }
}