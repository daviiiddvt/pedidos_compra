// ============================================================================
//  modal_selector.dart  —  LISTA PARA ELEGIR (ventana emergente con buscador)
// ============================================================================
//
//  ¿Qué es?
//  --------
//  La "ventana de elegir" de la app. Sirve para elegir de una lista:
//     - Proveedores, almacenes, series, formas de pago (del formulario).
//     - Artículos (en el modal de línea).
//     - Estados e IVA (listas sencillas de texto/números).
//  Tiene un campo "Buscar..." para filtrar y una lista donde se toca la opción.
//
//  DOS PARTES:
//  1) ModalSelector (widget) → el dibujo de la ventana.
//  2) mostrarSelector (función) → el "abrela" de forma fácil; devuelve lo elegido.
//
//  CONCEPTO:
//  - dynamic: la lista puede tener Strings, números u OpcionMaestra. Por eso
//    las opciones son List<dynamic> y textOf decide cómo mostrar cada una.
// ============================================================================

import 'package:flutter/material.dart';

import '../theme/app_theme.dart'; // Colores.

/// ModalSelector: la ventana emergente con la lista y el buscador.
class ModalSelector extends StatefulWidget {
  final String title; // Título ("Seleccionar proveedor"...).
  final List<dynamic> options; // Las opciones (cualquier tipo).
  final String Function(dynamic option)? textOf; // Cómo convertir opción → texto.
  final bool searchable; // true = mostrar buscador.

  const ModalSelector({
    super.key,
    required this.title,
    required this.options,
    this.textOf,
    this.searchable = true,
  });

  @override
  State<ModalSelector> createState() => _ModalSelectorState();
}

class _ModalSelectorState extends State<ModalSelector> {
  final _searchController = TextEditingController(); // Lo puesto en el buscador.
  String _search = ''; // Texto actual de búsqueda.

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// _text: devuelve el TEXTO visible de una opción.
  /// 1) Si hay textOf, lo usa (quien lo llama decide cómo mostrar).
  /// 2) Si es un String, el propio string.
  /// 3) Si es un Mapa, busca "nombre", luego "descripcion", luego "codigo".
  /// 4) Si nada funciona, lo convierte a texto con '$option'.
  String _text(dynamic option) {
    if (widget.textOf != null) return widget.textOf!(option);
    if (option is String) return option;
    if (option is Map) {
      for (final key in ['nombre', 'descripcion', 'codigo']) {
        if (option[key] != null && '$option[key]'.isNotEmpty) return '$option[key]';
      }
      return '$option';
    }
    return '$option';
  }

  /// _filtered: las opciones filtradas por el buscador (o todas si no hay búsqueda).
  List<dynamic> get _filtered {
    if (_search.trim().isEmpty) return widget.options;
    final term = _search.toLowerCase(); // Buscamos sin distinguir mayúsculas.
    return widget.options
        .where((o) => _text(o).toLowerCase().contains(term))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog( // La caja centrada de la ventana.
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Container(
        width: double.maxFinite, // Lo más ancha posible.
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75, // Máx 75% del alto.
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min, // No ocupar más de lo necesario.
          children: [
            // Título.
            Text(
              widget.title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 12),

            // Buscador (opcional).
            if (widget.searchable)
              TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _search = v), // Filtra en vivo.
                decoration: const InputDecoration(
                  hintText: 'Buscar...',
                  prefixIcon: Icon(Icons.search, size: 20), // Lupa.
                  isDense: true,
                ),
              ),
            const SizedBox(height: 8),

            // La lista de opciones.
            Flexible(
              child: widget.options.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Sin resultados',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: _filtered.length,
                      itemBuilder: (context, index) {
                        final option = _filtered[index];
                        return ListTile( // Una fila de la lista.
                          dense: true,
                          title: Text(
                            _text(option),
                            style: const TextStyle(fontSize: 15),
                          ),
                          // Al tocar, cerramos la ventana DEVOLVIENDO la opción
                          // (Navigator.pop(option) → quien llamó la recibe).
                          onTap: () => Navigator.of(context).pop(option),
                        );
                      },
                    ),
            ),

            // Botón para cerrar sin elegir (pop() sin valor → null).
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
          ],
        ),
      ),
    );
  }
}

/// mostrarSelector: la forma FÁCIL de abrir la ventana.
/// Devuelve la opción elegida (o null si se canceló).
Future<dynamic> mostrarSelector(
  BuildContext context, {
  required String title,
  required List<dynamic> options,
  String Function(dynamic option)? textOf,
  bool searchable = true,
  String? searchPlaceholder,
}) {
  return showDialog<dynamic>(
    context: context,
    builder: (_) => ModalSelector(
      title: title,
      options: options,
      textOf: textOf,
      searchable: searchable,
    ),
  );
}