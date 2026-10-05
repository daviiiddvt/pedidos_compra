// ============================================================================
//  segment_tabs.dart  —  PESTAÑAS (Cabecera | Líneas | Totales)
// ============================================================================
//
//  ¿Qué es?
//  --------
//  Una "barra de pestañas" como la de las webs. La pestaña activa sale en
//  azul y las demás en blanco. Al tocar una, avisa con onChanged(key).
//
//  Se usa en el DETALLE y en el FORMULARIO del pedido.
//
//  CONCEPTO:
//  - "record" List<({String key, String label})>: cada pestaña es una "tupla"
//    con dos campos: key (para identificar) y label (el texto que se ve).
// ============================================================================

import 'package:flutter/material.dart';


/// SegmentTabs: barra de pestañas con aspecto de "botones segmentados".
class SegmentTabs extends StatelessWidget {
  final List<({String key, String label})> tabs; // Lista de pestañas (clave + texto).
  final String active; // Clave de la pestaña activa ahora mismo.
  final ValueChanged<String> onChanged; // Aviso al tocar una pestaña (le pasa su clave).

  const SegmentTabs({
    super.key,
    required this.tabs,
    required this.active,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Row(
        children: tabs
            .map(
              (tab) => Expanded( // Cada pestaña ocupa el mismo ancho.
                child: Material(
                  // La pestaña ACTIVA tiene fondo azul; las demás transparente.
                  color: tab.key == active
                              ? Theme.of(context).colorScheme.primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () => onChanged(tab.key), // Avisamos con la clave tocada.
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      alignment: Alignment.center,
                      child: Text(
                        tab.label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          // Texto blanco si está activa, gris si no.
                          color: tab.key == active
                              ? Theme.of(context).colorScheme.onPrimary
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            )
            .toList(), // .map() devuelve un iterable; .toList() lo hace lista.
      ),
    );
  }
}