// ============================================================================
//  app_log.dart  —  LOGS A FICHERO (imprescindible en Windows)
// ============================================================================
//
//  En Windows el ejecutable de Flutter es una aplicación GUI, no de consola:
//  aunque se abra desde un terminal, no tiene stdout conectado, por lo que
//  `debugPrint`/`print` se pierden sin dejar rastro.
//
//  Este helper sobrescribe `debugPrint` para que, además de comportarse como
//  siempre (visible con `flutter run -d windows`), escriba cada línea en un
//  fichero de log accesible:
//
//      Windows → %APPDATA%\pedidos_venta\pedidos_venta.log
//      Otros   → carpeta temporal + pedidos_venta.log
//
//  El fichero se crea bajo demanda (no hace falta precrearlo) y se añade una
//  fecha/hora a cada línea para poder correlacionar eventos.
// ============================================================================

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

File? _logFile;

/// Ruta donde se guardará el log (se resuelve una vez).
File _resolverRutaLog() {
  final appData = Platform.environment['APPDATA'];
  final dir = appData != null && appData.isNotEmpty
      ? Directory(p.join(appData, 'pedidos_venta'))
      : Directory(p.join(Directory.systemTemp.path, 'pedidos_venta'));
  if (!dir.existsSync()) {
    try {
      dir.createSync(recursive: true);
    } catch (_) {
      // Si no se puede crear la carpeta, se deja en el fichero base siguiente.
      return File(p.join(Directory.systemTemp.path, 'pedidos_venta.log'));
    }
  }
  return File(p.join(dir.path, 'pedidos_venta.log'));
}

void _escribir(File file, String stamp, String line) {
  try {
    file.writeAsStringSync('$stamp $line\n', mode: FileMode.append, flush: true);
  } catch (_) {
    // Nunca romper la app por un fallo de logging.
  }
}

/// Instala el volcado de `debugPrint` a fichero. Llamar UNA vez en `main()`
/// antes de `runApp(...)`.
void setupFileLogging() {
  // Resolvemos la ruta antes de sobrescribir para no depender de Platform
  // después de que dart:io quede "contaminado" por la bandera.
  final ruta = _resolverRutaLog();
  debugPrint(ruta.path); // Se registrará también en la consola, si existe.

  debugPrint = (String? message, {int? wrapWidth}) {
    final line = message ?? '';
    if (line.isEmpty) return;
    final stamp = DateTime.now().toIso8601String();
    _escribir(ruta, stamp, line);
    debugPrintSynchronously(line, wrapWidth: wrapWidth);
  };
}

/// Da acceso al fichero de log (para abrirlo con el bloc de notas, etc.).
String rutaLog() => (_logFile ??= _resolverRutaLog()).path;