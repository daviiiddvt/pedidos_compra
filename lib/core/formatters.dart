// ============================================================================
//  formatters.dart  —  AYUDAS PARA FORMAR FECHAS Y NÚMEROS
// ============================================================================
//
//  ¿Para qué sirve?
//  ----------------
//  VELNEO nos manda fechas como "2026-09-10" y precios como 1234.5.
//  Pero en pantalla queremos ver "10/09/2026" y "1.234,50" (formato español).
//  Estas cuatro funciones hacen esas conversiones. Se usan en toda la app.
// ============================================================================

// Devuelve un número de 0 a 9 con un cero delante: 5 → "05". Así las fechas
// quedan siempre con dos dígitos: "09/05" en vez de "9/5".
String _diaConCero(int n) => n.toString().padLeft(2, '0');

/// formatDate: convierte una fecha del API a formato español "día/mes/año".
/// - Entrada típica VELNEO:  "2026-09-10"  o  "2026-09-10T12:30:00"
/// - Salida:                 "10/09/2026"
/// Si no puede entender la fecha, devuelve el texto original (no rompe).
String formatDate(dynamic iso) {
  if (iso == null || '$iso'.isEmpty) return '—'; // Sin fecha → guion largo.

  final text = '$iso';
  // Si la fecha no trae hora, le añadimos "T00:00:00" para que DateTime la
  // entienda (DateTime.tryParse espera un formato casi ISO completo).
  final date = DateTime.tryParse(text.contains('T') ? text : '${text}T00:00:00');

  if (date == null) return text; // No se pudo parsear → devolvemos el texto tal cual.

  // Montamos "día/mes/año" con ceros a la izquierda.
  return '${_diaConCero(date.day)}/'
      '${_diaConCero(date.month)}/'
      '${date.year}';
}

/// parseNumber: convierte texto escrito por el usuario a número decimal.
/// - Entrada:  "1.234,56"  o "1234,56"  o "12.34"
/// - Salida:   1234.56 (número de verdad)
///
/// Permite que el usuario escriba cantidades "a la española" (puntos como
/// separador de miles y coma como decimal) sin que falle.
double parseNumber(String text) {
  // 1) Quitamos todos los puntos (separador de miles): "1.234" → "1234".
  // 2) Cambiamos la coma por punto: "1234,56" → "1234.56".
  // 3) Eliminamos cualquier carácter raro que no sea dígito, punto o signo menos.
  final normalized = text
      .replaceAll('.', '')
      .replaceAll(',', '.')
      .replaceAll(RegExp(r'[^\d.\-]'), '');
  return double.tryParse(normalized) ?? 0; // Si no es número → 0.
}

/// formatNumber: convierte un número a texto CON formato español.
/// - Entrada:  1234.5  →  Salida: "1.234,50"
/// - Entrada:  -50     →  Salida: "-50"
/// Esto es: puntos para los miles y coma como separador decimal.
String formatNumber(num value, {int decimals = 2}) {
  // "1234.5" con 2 decimales → "1234.50".
  final fixed = value.toStringAsFixed(decimals);

  // Dividimos en parte entera y parte decimal.
  final parts = fixed.split('.');
  final intPart = parts[0]; // "1234"
  final decimalPart = parts.length > 1 ? parts[1] : ''; // "50"

  // Añadimos puntos de miles a la parte entera, sin contar el signo menos.
  final buffer = StringBuffer();
  final digits = intPart.replaceFirst('-', ''); // "1234"
  for (var i = 0; i < digits.length; i++) {
    final remaining = digits.length - i; // Cuántos dígitos quedan.
    buffer.write(digits[i]);
    // Cada 3 dígitos (desde la derecha) ponemos un punto.
    if (remaining > 1 && remaining % 3 == 1) {
      buffer.write('.');
    }
  }

  // Recomponemos el signo si era negativo.
  final sign = intPart.startsWith('-') ? '-' : '';
  // Resultado: "1.234,50" o "1.234" (si no hay decimales).
  return decimalPart.isNotEmpty ? '$sign$buffer,$decimalPart' : '$sign$buffer';
}

/// todayIso: fecha de HOY en formato ISO "2026-09-10" (la que entiende VELNEO).
/// Se usa como valor por defecto en los campos de fecha del formulario.
String todayIso() {
  final now = DateTime.now();
  return '${now.year}-${_diaConCero(now.month)}-${_diaConCero(now.day)}';
}