import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Servicio responsable de obtener un identificador único y persistente para el dispositivo.
class DeviceIdService {
  static const String uuidStorageKey = 'persistent_device_uuid';

  /// Obtiene el identificador único guardado o lo genera a partir del hardware del dispositivo.
  static Future<String> getOrCreateUuid() async {
    // 1. Intentar leer de almacenamiento persistente
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(uuidStorageKey);
      if (cached != null && cached.trim().isNotEmpty) {
        return cached.trim();
      }
    } catch (e) {
      debugPrint('⚠️ Error leyendo UUID de almacenamiento: $e');
    }

    // 2. Resolver según la plataforma
    String uuid = '';
    if (!kIsWeb && Platform.isAndroid) {
      uuid = await _getAndroidId();
    } else if (!kIsWeb && Platform.isWindows) {
      uuid = await _getWindowsIdentifier();
    }

    // 3. Fallback a UUID v4 aleatorio si el hardware no devolvió nada
    if (uuid.trim().isEmpty) {
      uuid = const Uuid().v4();
    }

    uuid = uuid.trim();

    // 4. Guardar en almacenamiento persistente
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(uuidStorageKey, uuid);
    } catch (e) {
      debugPrint('⚠️ Error guardando UUID en almacenamiento: $e');
    }

    debugPrint('🔑 UUID del dispositivo obtenido: $uuid');
    return uuid;
  }

  /// Obtiene el ANDROID_ID mediante MethodChannel nativo.
  static Future<String> _getAndroidId() async {
    const channels = [
      MethodChannel('com.tecapppedvta/device_info'),
      MethodChannel('com.tecpass/device_info'),
    ];

    for (final channel in channels) {
      try {
        final id = await channel.invokeMethod<String>('getAndroidId');
        if (id != null && id.trim().isNotEmpty) {
          debugPrint('📱 ANDROID_ID obtenido con éxito: $id');
          return id.trim();
        }
      } catch (e) {
        debugPrint('⚠️ Canal ${channel.name} no disponible: $e');
      }
    }
    return '';
  }

  /// Obtiene identificador en Windows (soporte para pruebas y desarrollo).
  static Future<String> _getWindowsIdentifier() async {
    // 1. PowerShell Win32_ComputerSystemProduct (moderno y compatible con Windows 10/11)
    try {
      final result = await Process.run('powershell', [
        '-NoProfile',
        '-Command',
        '& {(Get-CimInstance -ClassName Win32_ComputerSystemProduct).UUID}',
      ]);
      if (result.exitCode == 0) {
        final sn = (result.stdout as String).trim();
        if (sn.isNotEmpty && sn != '0') return sn;
      }
    } catch (_) {}

    // 2. wmic csproduct get uuid (método tradicional)
    try {
      final result = await Process.run('wmic', ['csproduct', 'get', 'uuid'], runInShell: true);
      if (result.exitCode == 0) {
        final lines = (result.stdout as String)
            .trim()
            .split('\n')
            .map((l) => l.trim())
            .where((l) => l.isNotEmpty)
            .toList();
        if (lines.length > 1 && lines[1] != '0') return lines[1];
      }
    } catch (_) {}

    // 3. Fallback determinista con hostname
    try {
      final host = Platform.localHostname;
      if (host.isNotEmpty) {
        return const Uuid().v5(Namespace.dns.value, host);
      }
    } catch (_) {}

    return '';
  }
}
