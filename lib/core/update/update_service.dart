import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

/// Servicio de control de versiones y actualizaciones para dispositivos móviles (Android).
///
/// Consulta periódicamente o bajo demanda el archivo de versiones en el servidor:
/// https://solucionestecmicro.es/version/TecERP_KYRO_version.json
///
/// Si hay una versión superior para Android, muestra un diálogo informativo con el mensaje
/// del servidor para actualizar la aplicación.
class UpdateService {
  static final UpdateService instance = UpdateService._internal();

  UpdateService._internal();

  static const String versionUrl =
      'https://solucionestecmicro.es/version/TecERP_KYRO_version.json';
  static const Duration requestTimeout = Duration(seconds: 15);

  /// Obtiene la versión actual de la aplicación desde pubspec (vía package_info_plus).
  Future<String> getCurrentVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return info.version;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[UpdateService] Error al obtener PackageInfo: $e');
      }
      return '1.0.0';
    }
  }

  /// Compara dos cadenas de versión semántica (ej. "2.0.0" vs "1.0.0").
  /// Retorna true si [remote] es estrictamente mayor que [current].
  static bool isNewer(String remote, String current) {
    try {
      final cleanRemote = remote.split('+').first.split('-').first.trim();
      final cleanCurrent = current.split('+').first.split('-').first.trim();

      final rParts =
          cleanRemote.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final cParts =
          cleanCurrent.split('.').map((e) => int.tryParse(e) ?? 0).toList();

      final maxLen = rParts.length > cParts.length ? rParts.length : cParts.length;
      while (rParts.length < maxLen) {
        rParts.add(0);
      }
      while (cParts.length < maxLen) {
        cParts.add(0);
      }

      for (int i = 0; i < maxLen; i++) {
        if (rParts[i] > cParts[i]) return true;
        if (rParts[i] < cParts[i]) return false;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Extrae la sección de Android del JSON devuelto por el servidor.
  static Map<String, dynamic>? extractAndroidSection(Map<String, dynamic> root) {
    if (root['android'] is Map<String, dynamic>) {
      return root['android'] as Map<String, dynamic>;
    }
    if (root['TecERP_KYRO'] is Map<String, dynamic>) {
      final sub = root['TecERP_KYRO'] as Map<String, dynamic>;
      if (sub['android'] is Map<String, dynamic>) {
        return sub['android'] as Map<String, dynamic>;
      }
    }
    return null;
  }

  /// Comprueba si existe una actualización en el servidor.
  ///
  /// - Si [silent] es true (ej. al iniciar la app):
  ///   Solo muestra diálogo si HAY una actualización real disponible.
  ///   Si está actualizado o hay fallo de red, no interrumpe al usuario.
  /// - Si [silent] es false (ej. pulsado por el usuario en Configuración):
  ///   Muestra mensajes informativos en caso de estar al día o si hay errores.
  Future<void> checkUpdate(
    BuildContext context, {
    bool silent = false,
    http.Client? httpClient,
  }) async {
    if (kIsWeb) return;

    final client = httpClient ?? http.Client();
    try {
      final currentVersion = await getCurrentVersion();

      // Esta aplicación es exclusivamente para móviles (Android).
      if (!Platform.isAndroid) {
        if (!silent && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Las actualizaciones automáticas están destinadas a la versión móvil (Android). Versión actual: v$currentVersion',
              ),
            ),
          );
        }
        return;
      }

      if (kDebugMode) {
        debugPrint('[UpdateService] Comprobando versión en: $versionUrl');
      }

      final uri = Uri.parse(versionUrl);
      final response = await client.get(uri).timeout(requestTimeout);

      if (response.statusCode != 200) {
        if (kDebugMode) {
          debugPrint(
              '[UpdateService] HTTP ${response.statusCode} al consultar versión.');
        }
        if (!silent && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Error al consultar el servidor de actualizaciones (HTTP ${response.statusCode}).'),
            ),
          );
        }
        return;
      }

      final dynamic decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic>) {
        if (!silent && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Respuesta inesperada del servidor de versiones.'),
            ),
          );
        }
        return;
      }

      final androidSection = extractAndroidSection(decoded);
      if (androidSection == null) {
        if (kDebugMode) {
          debugPrint(
              '[UpdateService] No hay sección "android" en $versionUrl');
        }
        if (!silent && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('La aplicación está al día (v$currentVersion).'),
            ),
          );
        }
        return;
      }

      if (!context.mounted) return;

      await _handleAndroidUpdate(
        context,
        androidSection,
        currentVersion,
        silent: silent,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[UpdateService] Error comprobando actualizaciones: $e');
      }
      if (!silent && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo comprobar actualizaciones: $e'),
          ),
        );
      }
    } finally {
      if (httpClient == null) {
        client.close();
      }
    }
  }

  Future<void> _handleAndroidUpdate(
    BuildContext context,
    Map<String, dynamic>? data,
    String currentVersion, {
    required bool silent,
  }) async {
    if (data == null) {
      if (!silent && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('La aplicación está al día (v$currentVersion).')),
        );
      }
      return;
    }

    final remoteVersion = data['version']?.toString() ?? '0.0.0';
    final message = data['message']?.toString();

    if (!isNewer(remoteVersion, currentVersion)) {
      if (!silent && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('La aplicación está al día (v$currentVersion).')),
        );
      }
      return;
    }

    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.system_update_alt, color: Color(0xFF07134D)),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Actualización disponible',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('Versión actual: '),
                  Text(
                    currentVersion,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Text('Nueva versión: '),
                  Text(
                    remoteVersion,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                message != null && message.isNotEmpty
                    ? message
                    : 'Hay una nueva versión disponible. Por favor, póngase en contacto con soporte técnico para actualizar la aplicación.',
                softWrap: true,
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF07134D),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }
}
