import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../state/theme_settings.dart';
import '../core/config.dart';
import '../core/licencia/licencia_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeSettings = context.watch<ThemeSettings>();
    final licService = context.watch<LicenciaService>();
    final lic = licService.licencia;

    return Scaffold(
      appBar: AppBar(title: const Text('Configuración')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Licencia del Dispositivo',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(
                    licService.isValida ? Icons.verified : Icons.warning_amber_rounded,
                    color: licService.isValida ? Colors.green : Colors.orange,
                  ),
                  title: Text(
                    licService.isValida ? 'Licencia Activa' : 'Licencia Sin Validar',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: licService.isValida ? Colors.green.shade700 : Colors.orange.shade800,
                    ),
                  ),
                  subtitle: Text(
                    lic?.tecnico.isNotEmpty == true
                        ? 'Titular: ${lic!.tecnico}'
                        : (licService.isValida ? 'Dispositivo validado' : 'Requiere activación'),
                  ),
                  trailing: FilledButton.tonal(
                    onPressed: () => Navigator.of(context).pushNamed('/licencia'),
                    child: const Text('Gestionar'),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.fingerprint),
                  title: const Text('UUID del Dispositivo'),
                  subtitle: Text(
                    lic?.uuid.isNotEmpty == true ? lic!.uuid : 'Cargando...',
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.copy, size: 20),
                    tooltip: 'Copiar UUID',
                    onPressed: () {
                      final uuid = lic?.uuid ?? '';
                      if (uuid.isNotEmpty) {
                        Clipboard.setData(ClipboardData(text: uuid));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('UUID copiado al portapapeles'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.dns_outlined),
                  title: const Text('Servidor de Licencia'),
                  subtitle: Text(
                    '${lic?.serverApi ?? 'TECERPV7_TECPASS'} (${lic?.version ?? 'v1'}) · ${lic?.serverHost ?? ''}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                if (lic != null && (lic.esAdmin || lic.esSoloLec)) ...[
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(
                      children: [
                        const Text('Permisos:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(width: 8),
                        if (lic.esAdmin)
                          const Padding(
                            padding: EdgeInsets.only(right: 6),
                            child: Chip(
                              avatar: Icon(Icons.shield, size: 16),
                              label: Text('Administrador', style: TextStyle(fontSize: 12)),
                              padding: EdgeInsets.zero,
                            ),
                          ),
                        if (lic.esSoloLec)
                          const Chip(
                            avatar: Icon(Icons.visibility, size: 16),
                            label: Text('Solo lectura', style: TextStyle(fontSize: 12)),
                            padding: EdgeInsets.zero,
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Apariencia',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: SwitchListTile.adaptive(
              title: const Text('Modo oscuro'),
              subtitle: const Text('Usar una apariencia oscura en la aplicación'),
              secondary: Icon(
                themeSettings.isDarkMode
                    ? Icons.dark_mode_outlined
                    : Icons.light_mode_outlined,
              ),
              value: themeSettings.isDarkMode,
              onChanged: themeSettings.setDarkMode,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Red',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.dns_outlined),
                  title: const Text('Servidor (Host)'),
                  subtitle: Text(AppConfig.serverHost),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.layers_outlined),
                  title: const Text('Instancia de Datos'),
                  subtitle: Text(
                    AppConfig.serverInstance.isNotEmpty
                        ? AppConfig.serverInstance
                        : '(No especificada)',
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.numbers_outlined),
                  title: const Text('Versión de API'),
                  subtitle: Text(AppConfig.serverVersion),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.cloud_outlined),
                  title: const Text('URL Base Completa'),
                  subtitle: Text(
                    AppConfig.baseUrl,
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.copy, size: 20),
                    tooltip: 'Copiar URL',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: AppConfig.baseUrl));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('URL copiada al portapapeles'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.vpn_key_outlined),
                  title: const Text('API Key'),
                  subtitle: Text(AppConfig.apiKey.isNotEmpty && AppConfig.apiKey.length > 4 
                    ? '••••••••${AppConfig.apiKey.substring(AppConfig.apiKey.length - 4)}'
                    : AppConfig.apiKey),
                  trailing: AppConfig.apiKey.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.copy, size: 20),
                          tooltip: 'Copiar API Key',
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: AppConfig.apiKey));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('API Key copiada al portapapeles'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                        )
                      : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
