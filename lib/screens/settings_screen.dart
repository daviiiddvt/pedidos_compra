import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/config.dart';
import '../core/formatters.dart';
import '../core/licencia/licencia_service.dart';
import '../core/offline/offline_database.dart';
import '../core/offline/offline_outbox_service.dart';
import '../core/offline/offline_sync_service.dart';
import '../state/theme_settings.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _syncDays = 30;

  @override
  void initState() {
    super.initState();
    _cargarConfiguracionOffline();
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
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _DetallePendientesModal(
        onSubir: () {
          Navigator.of(ctx).pop();
          _subirPendientesAhora();
        },
      ),
    );
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
                    return ListTile(
                      leading: Icon(
                        count > 0 ? Icons.cloud_upload : Icons.cloud_done,
                        color: count > 0 ? Colors.orange.shade800 : Colors.green,
                      ),
                      title: Text(
                        count > 0
                            ? '$count documento(s) pendiente(s) de subir'
                            : 'Cola de salida sincronizada',
                        style: TextStyle(
                          fontWeight: count > 0 ? FontWeight.bold : FontWeight.normal,
                          color: count > 0 ? Colors.orange.shade900 : null,
                        ),
                      ),
                      subtitle: Text(
                        count > 0
                            ? 'Ventas guardadas sin conexión. Toca para ver el detalle.'
                            : 'No hay documentos pendientes de transmitir.',
                      ),
                      trailing: count > 0
                          ? FilledButton.tonal(
                              onPressed: _subirPendientesAhora,
                              child: const Text('Subir ahora'),
                            )
                          : null,
                      onTap: count > 0 ? _mostrarDetallePendientes : null,
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
        ],
      ),
    );
  }
}

/// Modal inferior para ver el detalle de los documentos pendientes de la cola de salida
class _DetallePendientesModal extends StatefulWidget {
  final VoidCallback onSubir;

  const _DetallePendientesModal({required this.onSubir});

  @override
  State<_DetallePendientesModal> createState() => _DetallePendientesModalState();
}

class _DetallePendientesModalState extends State<_DetallePendientesModal> {
  List<Map<String, dynamic>> _items = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final list = await OfflineDatabase.instance.getPendingOutbox();
    if (mounted) {
      setState(() {
        _items = list;
        _cargando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(20),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.outbox, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Documentos Pendientes de Transmitir',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_cargando)
              const Center(child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ))
            else if (_items.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('No hay documentos en la cola de salida.'),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _items.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (ctx, index) {
                    final item = _items[index];
                    final tipo = (item['tipo'] ?? '').toString().toUpperCase();
                    final estado = (item['estado'] ?? '').toString();
                    final errorMsg = item['error_msg'] as String?;
                    final payloadRaw = item['payload_json'] as String? ?? '{}';

                    String clienteNom = 'Cliente desconocido';
                    String fecha = '';
                    double total = 0.0;
                    int lineasCount = 0;

                    try {
                      final parsed = jsonDecode(payloadRaw) as Map<String, dynamic>;
                      final doc = (parsed['pedido'] ?? parsed['presupuesto'] ?? parsed) as Map<String, dynamic>;
                      clienteNom = '${doc['clt_nom'] ?? doc['clienteNombre'] ?? 'Cliente #${doc['clt'] ?? doc['clienteId']}'}';
                      fecha = '${doc['fch'] ?? doc['fecha'] ?? ''}';
                      total = (doc['tot_ped'] ?? doc['tot_pre'] ?? doc['total'] ?? 0.0) is num
                          ? (doc['tot_ped'] ?? doc['tot_pre'] ?? doc['total'] ?? 0.0).toDouble()
                          : 0.0;
                      final lins = (doc['lineas'] ?? []) as List;
                      lineasCount = lins.length;
                    } catch (_) {}

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
                      leading: Chip(
                        label: Text(tipo, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                        backgroundColor: tipo == 'PEDIDO'
                            ? Colors.green.shade100
                            : Colors.blue.shade100,
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                      ),
                      title: Text(
                        clienteNom,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Fecha: $fecha · $lineasCount línea(s) · Total: ${formatNumber(total, decimals: 2)} €',
                            style: const TextStyle(fontSize: 12),
                          ),
                          if (errorMsg != null && errorMsg.isNotEmpty)
                            Text(
                              'Error: $errorMsg',
                              style: TextStyle(color: Colors.red.shade700, fontSize: 11),
                            )
                          else if (estado == 'subiendo')
                            Text(
                              'Transmitiendo ahora...',
                              style: TextStyle(color: Colors.blue.shade700, fontSize: 11),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 16),
            if (_items.isNotEmpty)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: widget.onSubir,
                  icon: const Icon(Icons.cloud_upload),
                  label: const Text('Subir todos los pendientes ahora'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
