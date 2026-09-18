// ============================================================================
//  campo_form.dart  —  CAMPO DE TEXTO REUTILIZABLE (+ CampoSelect)
// ============================================================================
//
//  ¿Qué contiene este archivo?
//  ---------------------------
//  1) CampoForm     → el campo de texto de toda la app (con etiqueta encima,
//                     placeholder, opción de obligatorio, error, multilínea...).
//  2) CampoSelect   → el "campo falso" que parece un selector: al tocarlo abre
//                     un selector (no es un campo de escritura).
//
//  ¿Por qué reutilizarlos?
//  -----------------------
//  Así TODOS los campos se ven igual y, si cambiamos algo (colores, bordes),
//  se cambia una sola vez. Se usan en el login, la cabecera y el modal de línea.
//
//  CONCEPTO:
//  - typedef: crear un "alias" para un tipo de función. CampoValidator es una
//    función que recibe un texto y devuelve un error o null (si va bien).
//  - widget.xxx: en un State, "widget" da acceso a los parámetros que se pasaron.
// ============================================================================

import 'package:flutter/material.dart';

import '../theme/app_theme.dart'; // Colores.

/// Alias de tipo: una "función de validación" recibe lo escrito y devuelve
/// un String de error si algo va mal, o null si todo es correcto.
typedef CampoValidator = String? Function(String? value);

/// CampoForm: campo de texto con etiqueta, listo para cualquier pantalla.
class CampoForm extends StatefulWidget {
  // --- Parámetros configurables (todos con valor por defecto) ---
  final String label; // Texto de la etiqueta (ej. "URL del servidor").
  final TextEditingController? controller; // Si lo pasamos, controlamos el valor desde fuera.
  final String? value; // Valor inicial si NO pasamos controller.
  final ValueChanged<String>? onChanged; // Avisa cuando el texto cambia.
  final String? placeholder; // Texto gris de "ayuda" dentro del campo vacío.
  final TextInputType keyboardType; // Qué teclado sale (texto, número, URL...).
  final bool enabled; // false = campo bloqueado (no se puede escribir).
  final bool multiline; // true = campo de varias líneas (textarea).
  final bool obscureText;
  final bool required; // true = muestra un "*" rojo al lado de la etiqueta.
  final String? error; // Mensaje de error a mostrar bajo el campo.
  final int? maxLength; // Máximo de caracteres.
  final CampoValidator? validator; // Función de validación (si va con Form).

  const CampoForm({
    super.key,
    required this.label,
    this.controller,
    this.value,
    this.onChanged,
    this.placeholder,
    this.keyboardType = TextInputType.text,
    this.enabled = true,
    this.multiline = false,
    this.obscureText = false,
    this.required = false,
    this.error,
    this.maxLength,
    this.validator,
  });

  @override
  State<CampoForm> createState() => _CampoFormState();
}

/// _CampoFormState: la "memoria" del campo.
class _CampoFormState extends State<CampoForm> {
  late final TextEditingController _controller; // Quién guarda el texto.
  late final bool _propioController; // ¿Creamos nosotros el controller o nos lo pasaron?

  @override
  void initState() {
    super.initState();
    // Si no nos pasaron controller, creamos uno propio con el valor inicial.
    _propioController = widget.controller == null;
    _controller = widget.controller ?? TextEditingController(text: widget.value ?? '');
  }

  @override
  void dispose() {
    // Solo liberamos el controller si es nuestro (si es de fuera, otro lo limpia).
    if (_propioController) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant CampoForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_propioController && widget.value != oldWidget.value &&
        widget.value != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.value ?? '',
        selection: TextSelection.collapsed(
          offset: (widget.value ?? '').length,
        ),
      );
    }
  }

  /// Puente: cuando el usuario escribe, avisamos al onChanged externo (si existe).
  void _onChanged(String value) {
    widget.onChanged?.call(value);
  }

  @override
  Widget build(BuildContext context) {
    // ---- La etiqueta (con el "*" si es obligatorio) ----
    final info = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        if (widget.required)
          const Text(
            ' *',
            style: TextStyle(fontSize: 13, color: AppColors.error),
          ),
      ],
    );

    // ---- Decoración común (placeholder, error, disabled) ----
    final decoration = InputDecoration(
      hintText: widget.placeholder, // Texto de ayuda.
      hintStyle: const TextStyle(color: AppColors.disabled),
      errorText: widget.error, // Mensaje rojo bajo el campo.
      enabled: widget.enabled, // Bloquear/desbloquear.
    );

    // Elegimos el tipo de campo:
    Widget campo;
    if (widget.validator != null) {
      // Con validación dentro de un Form: TextFormField.
      campo = TextFormField(
        controller: _controller,
        onChanged: _onChanged,
        decoration: decoration,
        keyboardType: widget.keyboardType,
        obscureText: widget.obscureText,
        maxLines: widget.multiline ? null : 1, // null = líneas infinitas.
        minLines: widget.multiline ? 3 : 1,
        maxLength: widget.maxLength,
        validator: widget.validator,
      );
    } else {
      // Campo normal: TextField.
      campo = TextField(
        controller: _controller,
        onChanged: _onChanged,
        decoration: decoration,
        keyboardType: widget.keyboardType,
        obscureText: widget.obscureText,
        maxLines: widget.multiline ? null : 1,
        minLines: widget.multiline ? 3 : 1,
        maxLength: widget.maxLength,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        info, // Etiqueta.
        const SizedBox(height: 6),
        campo, // El campo.
      ],
    );
  }
}

/// CampoSelect: parece un campo pero al tocarlo abre un selector (modal).
/// Se usa en el formulario para proveedor, serie, almacén, estado, IVA...
class CampoSelect extends StatelessWidget {
  final String label; // Etiqueta ("Proveedor", "Estado"...).
  final String? value; // El texto que se muestra (lo ya elegido).
  final VoidCallback? onTap; // Qué pasa al tocarlo (abrir el modal).
  final String placeholder; // Texto por defecto si no hay valor ("Seleccionar...").
  final bool required; // Muestra el "*" rojo.
  final String? error; // Mensaje de error.

  const CampoSelect({
    super.key,
    required this.label,
    this.value,
    this.onTap,
    this.placeholder = 'Seleccionar...',
    this.required = false,
    this.error,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Etiqueta (misma pinta que la de CampoForm).
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
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
          onTap: onTap, // Al pulsar → abre el selector (lo define quien lo usa).
          borderRadius: BorderRadius.circular(10),
          child: InputDecorator(
            decoration: InputDecoration(
              errorText: error,
              enabled: true,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween, // Texto ✓ flecha.
              children: [
                Expanded(
                  child: Text(
                    // Si hay valor lo mostramos; si no, el placeholder gris.
                    value != null && value!.isNotEmpty ? value! : placeholder,
                    style: TextStyle(
                      fontSize: 15,
                      color: (value != null && value!.isNotEmpty)
                          ? AppColors.text
                          : AppColors.disabled,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // La "flecha" de desplegable.
                const Icon(Icons.expand_more, color: AppColors.textSecondary, size: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }
}