import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/config.dart';
import '../core/licencia/licencia_service.dart';
import '../core/offline/connection_status_service.dart';
import '../core/offline/offline_outbox_service.dart';
import '../core/offline/offline_sync_service.dart';
import '../core/update/update_service.dart';
import '../state/theme_settings.dart';
import '../widgets/cola_salida_modal.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _syncDays = 30;
  String _appVersion = 'Cargando...';
  bool _buscandoActualizacion = false;

  @override
  void initState() {
    super.initState();
    _cargarConfiguracionOffline();
    _cargarVersionApp();
  }

  Future<void> _cargarVersionApp() async {
    final v = await UpdateService.instance.getCurrentVersion();
    if (mounted) {
      setState(() => _appVersion = v);
    }
  }

  Future<void> _buscarActualizaciones() async {
    if (_buscandoActualizacion) return;
    setState(() => _buscandoActualizacion = true);
    try {
      await UpdateService.instance.checkUpdate(context, silent: false);
    } finally {
      if (mounted) {
        setState(() => _buscandoActualizacion = false);
      }
    }
  }

  Future<void> _cargarConfiguracionOffline() async {
    final days = await OfflineSyncService.instance.getSyncDaysHistory();
    if (mounted) {
      setState(() => _syncDays = days);
    }
  }

  Future<void> _cambiarDiasSync(int? nuevosDias) async {
    if (nuevosDias == null || nuevosDias == _syncDays) return;
    await OfflineSyncService.instance.setSyncDaysHistory(nuevosDias);
    if (mounted) {
      setState(() => _syncDays = nuevosDias);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Historial de sincronización establecido a $nuevosDias días.'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _subirPendientesAhora() async {
    if (!ConnectionStatusService.instance.isOnline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay conexión a internet para transmitir documentos.')),
      );
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            SizedBox(width: 12),
            Text('Transmitiendo documentos pendientes al servidor...'),
          ],
        ),
        duration: Duration(seconds: 2),
      ),
    );

    final res = await OfflineOutboxService.instance.processQueue();
    if (!mounted) return;

    if (res.failed == 0) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('¡Éxito! Se transmitieron ${res.success} documentos al servidor.'),
          backgroundColor: Colors.green.shade700,
        ),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Completados: ${res.success}. Con error: ${res.failed}.'),
          backgroundColor: Colors.orange.shade800,
        ),
      );
    }
  }

  void _mostrarDetallePendientes() {
    ColaSalidaModal.show(context);
  }

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

          // SECCIÓN: MODO SIN CONEXIÓN Y SINCRONIZACIÓN
          const Text(
            'Modo Sin Conexión y Sincronización',
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
                  leading: const Icon(Icons.history_toggle_off),
                  title: const Text('Días de historial a sincronizar'),
                  subtitle: Text('Rango de descarga de pedidos y presupuestos ($_syncDays días)'),
                  trailing: DropdownButton<int>(
                    value: _syncDays,
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(value: 7, child: Text('7 días')),
                      DropdownMenuItem(value: 15, child: Text('15 días')),
                      DropdownMenuItem(value: 30, child: Text('30 días')),
                      DropdownMenuItem(value: 60, child: Text('60 días')),
                      DropdownMenuItem(value: 90, child: Text('90 días')),
                    ],
                    onChanged: _cambiarDiasSync,
                  ),
                ),
                const Divider(height: 1),
                ValueListenableBuilder<int>(
                  valueListenable: OfflineOutboxService.instance.pendingCount,
                  builder: (context, count, _) {
                    return InkWell(
                      onTap: count > 0 ? _mostrarDetallePendientes : null,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  count > 0 ? Icons.cloud_upload : Icons.cloud_done,
                                  color: count > 0 ? Colors.orange.shade800 : Colors.green,
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        count > 0
                                            ? '$count documento(s) pendiente(s) de subir'
                                            : 'Cola de salida sincronizada',
                                        style: TextStyle(
                                          fontWeight: count > 0 ? FontWeight.bold : FontWeight.w600,
                                          fontSize: 15,
                                          color: count > 0 ? Colors.orange.shade900 : null,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        count > 0
                                            ? 'Ventas guardadas sin conexión. Toca para ver el detalle.'
                                            : 'No hay documentos pendientes de transmitir.',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (count > 0)
                                  Icon(Icons.chevron_right, color: Colors.grey.shade400),
                              ],
                            ),
                            if (count > 0) ...[
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.tonalIcon(
                                  icon: const Icon(Icons.upload, size: 18),
                                  label: const Text('Subir pendientes ahora'),
                                  onPressed: ConnectionStatusService.instance.isOnline
                                      ? _subirPendientesAhora
                                      : null,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
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
          const SizedBox(height: 24),
          const Text(
            'Versión y Actualizaciones',
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
                  leading: const Icon(Icons.info_outline),
                  title: const Text('Versión instalada'),
                  subtitle: Text('v$_appVersion'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.system_update_alt),
                  title: const Text('Buscar actualizaciones'),
                  subtitle: const Text('Comprobar si existe una nueva versión en el servidor'),
                  trailing: _buscandoActualizacion
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                  onTap: _buscandoActualizacion ? null : _buscarActualizaciones,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

