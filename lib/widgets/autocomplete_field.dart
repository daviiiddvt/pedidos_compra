// ============================================================================
//  autocomplete_field.dart  —  CAMPO DE TEXTO CON AUTOCOMPLETADO REMOTO
// ============================================================================
//
//  ¿Qué es?
//  --------
//  El sustituto de los desplegables masivos (DropdownButton). Es un campo de
//  texto en el que el usuario escribe y, al superar 3 caracteres, se consulta
//  al API de VELNEO (solo entonces) devolviendo hasta 20 resultados para
//  elegir. Incluye un "debounce" de 400 ms: si el usuario sigue tecleando, se
//  espera a que se detenga antes de llamar a la red.
//
//  ¿Cómo se usa?
//  -------------
//  AutocompleteField(
//    label: 'Cliente',
//    required: true,
//    search: (query) => repositorio.search(EntityKind.cliente, query),
//    onSelected: (opcion) { ... },   // Al elegir una opción.
//  )
//
//  REGLAS DE BUENAS PRÁCTICAS:
//  - Debounce 300-500 ms → 400 ms por defecto.
//  - Mínimo 3 caracteres antes de disparar la búsqueda.
//  - Top 20 resultados (configurable con maxResults).
//  - Estados de carga / error / vacío gestionados por RemoteSearchCubit (BLoC).
// ============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../state/remote_search_cubit.dart';
import '../theme/app_theme.dart';
import '../models.dart'; // OpcionMaestra.

/// Campo de texto con sugerencias de autocompletado remotas.
class AutocompleteField extends StatefulWidget {
  final String label; // Etiqueta sobre el campo.
  final bool required; // Muestra el "*" rojo.
  final bool enabled; // false = bloquea escritura.
  final String? initialValue; // Texto inicial (ej. nombre ya elegido).
  final String hint; // Placeholder ("Escribir para buscar...").
  final int minChars; // Caracteres mínimos para buscar (3 por defecto).
  final Duration debounce; // Espera antes de llamar a la red (400 ms).
  final int maxResults; // Máximo de sugerencias (20 por defecto).
  final Future<List<OpcionMaestra>> Function(String query) search; // Búsqueda remota.
  final ValueChanged<OpcionMaestra> onSelected; // Al elegir una sugerencia.
  final VoidCallback? onCleared; // Al borrar el texto (opcional).

  const AutocompleteField({
    super.key,
    required this.label,
    required this.search,
    required this.onSelected,
    this.required = false,
    this.enabled = true,
    this.initialValue,
    this.hint = 'Escribir para buscar...',
    this.minChars = 3,
    this.debounce = const Duration(milliseconds: 400),
    this.maxResults = 20,
    this.onCleared,
  });

  @override
  State<AutocompleteField> createState() => _AutocompleteFieldState();
}

class _AutocompleteFieldState extends State<AutocompleteField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  late final RemoteSearchCubit _cubit;

  /// Opción actualmente elegida (para no volver a buscar si no cambia el texto).
  OpcionMaestra? _selected;

  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue ?? '');
    _focusNode = FocusNode()..addListener(_onFocusChanged);
    // Cada campo tiene su propio cubit con la función de búsqueda inyectada.
    _cubit = RemoteSearchCubit(
      searchFn: widget.search,
      minChars: widget.minChars,
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _cubit.close();
    _focusNode
      ..removeListener(_onFocusChanged)
      ..dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant AutocompleteField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Si desde fuera cambian el valor mostrado (ej. reset del formulario),
    // sincronizamos el texto solo si el usuario NO está tecleando (focus) ni
    // ya coincide con lo aprendido; así no pisamos lo recién escrito.
    if (widget.initialValue != oldWidget.initialValue &&
        widget.initialValue != null &&
        widget.initialValue != _controller.text &&
        !_focusNode.hasFocus) {
      _controller.text = widget.initialValue!;
      _selected = null;
    }
  }

  void _onFocusChanged() {
    // Al perder el foco, ocultamos las sugerencias.
    if (!_focusNode.hasFocus) {
      _debounce?.cancel();
      _cubit.cancel();
    }
  }

  /// Debounce: cada tecla reinicia el temporizador. Solo cuando el usuario
  /// se detiene 400 ms (y hay ≥ minChars) se llama a la red.
  void _onChanged(String value) {
    _debounce?.cancel();
    if (value.trim().length < widget.minChars) {
      _cubit.cancel();
      if (_selected != null) {
        setState(() => _selected = null);
        widget.onCleared?.call();
      }
      return;
    }
    _debounce = Timer(widget.debounce, () {
      _cubit.search(value);
    });
  }

  void _select(OpcionMaestra option) {
    _debounce?.cancel();
    setState(() {
      _selected = option;
      _controller.text = option.nombre;
      // Cursor al final del texto.
      _controller.selection = TextSelection.collapsed(offset: option.nombre.length);
    });
    _cubit.cancel();
    _focusNode.unfocus();
    widget.onSelected(option);
  }

  String _hintText() {
    if (widget.minChars <= 1) return widget.hint;
    return '${widget.hint} (mín. ${widget.minChars} caracteres)';
  }

  @override
  Widget build(BuildContext context) {
    final label = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        if (widget.required)
          const Text(' *', style: TextStyle(fontSize: 13, color: AppColors.error)),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        label,
        const SizedBox(height: 6),
        TextField(
          controller: _controller,
          focusNode: _focusNode,
          enabled: widget.enabled,
          onChanged: _onChanged,
          decoration: InputDecoration(
            hintText: _hintText(),
            hintStyle: const TextStyle(color: AppColors.disabled),
            suffixIcon: _selected != null
                ? IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    tooltip: 'Quitar selección',
                    onPressed: widget.enabled
                        ? () {
                            _debounce?.cancel();
                            _cubit.cancel();
                            setState(() {
                              _selected = null;
                              _controller.clear();
                            });
                            widget.onCleared?.call();
                          }
                        : null,
                  )
                : const Icon(Icons.search, size: 20, color: AppColors.textSecondary),
          ),
        ),

        // Sugerencias de autocompletado (solo mientras el campo tiene foco).
        BlocBuilder<RemoteSearchCubit, RemoteSearchState>(
          bloc: _cubit,
          builder: (context, state) {
            if (!_focusNode.hasFocus) return const SizedBox.shrink();
            switch (state) {
              case RemoteSearchIdle():
                return const SizedBox.shrink();
              case RemoteSearchLoading():
                return const _SuggestionsCard(
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      height: 16,
                      child: LinearProgressIndicator(minHeight: 2),
                    ),
                  ),
                );
              case RemoteSearchFailure():
                return _SuggestionsCard(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, size: 18, color: AppColors.error),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'No se pudo buscar. Inténtalo de nuevo.',
                            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                          ),
                        ),
                        TextButton(
                          onPressed: () => _cubit.search(_controller.text),
                          child: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  ),
                );
              case RemoteSearchSuccess():
                final results = state.results;
                if (results.isEmpty) {
                  return const _SuggestionsCard(
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                        'Sin resultados',
                        style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ),
                  );
                }
                return _SuggestionsCard(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 260),
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: results.length,
                      itemBuilder: (context, index) {
                        final option = results[index];
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.sell_outlined, size: 18,
                              color: AppColors.textSecondary),
                          title: Text(option.nombre, style: const TextStyle(fontSize: 14)),
                          subtitle: option.codigo.isNotEmpty
                              ? Text('Código: ${option.codigo}', style: const TextStyle(fontSize: 11))
                              : null,
                          onTap: () => _select(option),
                        );
                      },
                    ),
                  ),
                );
            }
          },
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

/// Pequeña tarjeta con borde que envuelve las sugerencias bajo el campo.
/// Usa [Material] como ancestro material de los ListTile (tinta/ripples).
class _SuggestionsCard extends StatelessWidget {
  final Widget child;
  const _SuggestionsCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      child: Material(
        color: Colors.white,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: AppColors.primary.withValues(alpha: 0.35)),
        ),
        child: child,
      ),
    );
  }
}