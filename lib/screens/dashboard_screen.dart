import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/offline/connection_status_service.dart';
import '../core/offline/offline_outbox_service.dart';
import '../core/offline/offline_sync_service.dart';
import '../core/update/update_service.dart';
import '../state/auth_state.dart';
import '../theme/app_theme.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  DateTime? _lastSyncMasters;
  DateTime? _lastSyncDocs;
  int _syncDays = 30;

  @override
  void initState() {
    super.initState();
    _cargarMetadatosSincronizacion();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        UpdateService.instance.checkUpdate(context, silent: true);
      }
    });
  }

  Future<void> _cargarMetadatosSincronizacion() async {
    final sync = OfflineSyncService.instance;
    final lastM = await sync.getLastSyncMasters();
    final lastD = await sync.getLastSyncDocuments();
    final days = await sync.getSyncDaysHistory();
    if (mounted) {
      setState(() {
        _lastSyncMasters = lastM;
        _lastSyncDocs = lastD;
        _syncDays = days;
      });
    }
  }

  String _formatFechaHora(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$d/$m $h:$min';
  }

  void _sincronizarMaestros() {
    if (!ConnectionStatusService.instance.isOnline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay conexión a internet para sincronizar maestros.')),
      );
      return;
    }
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _SyncProgressModal(
        titulo: 'Sincronizar Maestros',
        icono: Icons.layers_outlined,
        onIniciar: (onProgress) => OfflineSyncService.instance.syncMasters(
          onProgress: onProgress,
        ),
      ),
    ).then((_) => _cargarMetadatosSincronizacion());
  }

  void _sincronizarDocumentos() {
    if (!ConnectionStatusService.instance.isOnline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay conexión a internet para sincronizar documentos.')),
      );
      return;
    }
    final auth = context.read<AuthState>();
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _SyncProgressModal(
        titulo: 'Sincronizar Pedidos y Presupuestos',
        icono: Icons.receipt_long_outlined,
        onIniciar: (onProgress) => OfflineSyncService.instance.syncDocuments(
          days: _syncDays,
          currentUser: auth.currentUser,
          onProgress: onProgress,
        ),
      ),
    ).then((_) => _cargarMetadatosSincronizacion());
  }

  Future<void> _subirPendientesAhora() async {
    if (!ConnectionStatusService.instance.isOnline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay conexión a internet para subir documentos.')),
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
            Text('Sincronizando...'),
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
          content: Text('Se subieron ${res.success} documentos correctamente.'),
          backgroundColor: Colors.green.shade700,
        ),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Subidos: ${res.success}. Fallaron: ${res.failed}. Revisa la conexión.'),
          backgroundColor: Colors.orange.shade800,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    final user = auth.currentUser;
    final userName = user?.name.isNotEmpty == true ? user!.name : 'Comercial';
    final isSyncing = auth.mastersSyncing;
    final colorScheme = Theme.of(context).colorScheme;

    final cards = [
      _DashboardCard(
        icon: Icons.request_quote_outlined,
        title: 'Presupuestos',
        subtitle: 'Consultar y gestionar presupuestos de venta.',
        color: AppColors.primary,
        onTap: () => Navigator.of(context).pushNamed('/presupuestos').then((_) {
          OfflineOutboxService.instance.refreshPendingCount();
          _cargarMetadatosSincronizacion();
        }),
      ),
      _DashboardCard(
        icon: Icons.shopping_bag_outlined,
        title: 'Pedidos',
        subtitle: 'Revisar pedidos activos y su detalle.',
        color: Colors.green.shade700,
        onTap: () => Navigator.of(context).pushNamed('/pedidos').then((_) {
          OfflineOutboxService.instance.refreshPendingCount();
          _cargarMetadatosSincronizacion();
        }),
      ),
      _DashboardCard(
        icon: Icons.inventory_2_outlined,
        title: 'Artículos',
        subtitle: 'Consultar catálogo de artículos.',
        color: Colors.orange.shade700,
        onTap: () => Navigator.of(context).pushNamed('/articulos'),
      ),
      _DashboardCard(
        icon: Icons.people_alt_outlined,
        title: 'Clientes',
        subtitle: 'Consultar cartera de clientes.',
        color: Colors.blue.shade700,
        onTap: () => Navigator.of(context).pushNamed('/clientes'),
      ),
    ];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Inicio'),
        actions: [
          IconButton(
            tooltip: 'Configuración',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).pushNamed('/configuracion').then((_) {
              _cargarMetadatosSincronizacion();
            }),
          ),
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<AuthState>().desconectar(),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bienvenido, $userName',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
             

              // Alerta reactiva de documentos pendientes en Outbox
              ValueListenableBuilder<int>(
                valueListenable: OfflineOutboxService.instance.pendingCount,
                builder: (context, count, _) {
                  if (count <= 0) return const SizedBox.shrink();
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.shade400),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.cloud_upload_outlined, color: Colors.amber.shade900),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '$count documento(s) pendiente(s) de sincronizar',
                            style: TextStyle(
                              color: Colors.amber.shade900,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: _subirPendientesAhora,
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.amber.shade900,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            visualDensity: VisualDensity.compact,
                          ),
                          child: const Text('Subir ahora'),
                        ),
                      ],
                    ),
                  );
                },
              ),

              // PANEL CON LOS 2 BOTONES DE SINCRONIZACIÓN (Solo visible en modo con conexión)
              AnimatedBuilder(
                animation: ConnectionStatusService.instance,
                builder: (context, _) {
                  final isOnline = ConnectionStatusService.instance.isOnline;
                  if (!isOnline) {
                    return const SizedBox.shrink();
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.4)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.sync,
                                size: 16,
                                color: colorScheme.primary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Sincronización para trabajo sin conexión',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final bool esEstrecho = constraints.maxWidth < 480;
                              final btnMaestros = _SyncActionButton(
                                icon: Icons.layers_outlined,
                                title: esEstrecho ? 'Sincronizar Maestros' : 'Sincronizar\nMaestros',
                                subtitle: _lastSyncMasters != null
                                    ? 'Última: ${_formatFechaHora(_lastSyncMasters!)}'
                                    : 'Catálogo y datos generales',
                                color: Colors.indigo,
                                enabled: true,
                                onTap: _sincronizarMaestros,
                              );
                              final btnDocumentos = _SyncActionButton(
                                icon: Icons.receipt_long_outlined,
                                title: esEstrecho ? 'Sincronizar Documentos' : 'Sincronizar\nDocumentos',
                                subtitle: _lastSyncDocs != null
                                    ? 'Última: ${_formatFechaHora(_lastSyncDocs!)} (últ. $_syncDays d)'
                                    : 'Últimos $_syncDays días',
                                color: Colors.teal,
                                enabled: true,
                                onTap: _sincronizarDocumentos,
                              );

                              if (esEstrecho) {
                                return Column(
                                  children: [
                                    btnMaestros,
                                    const SizedBox(height: 8),
                                    btnDocumentos,
                                  ],
                                );
                              }

                              return Row(
                                children: [
                                  Expanded(child: btnMaestros),
                                  const SizedBox(width: 10),
                                  Expanded(child: btnDocumentos),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              if (isSyncing)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Sincronizando sesión en segundo plano...',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.0,
                  children: cards,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SyncActionButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback? onTap;
  final bool enabled;

  const _SyncActionButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveColor = enabled ? color : Colors.grey.shade500;
    final effectiveBgColor = enabled
        ? theme.colorScheme.surface
        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4);

    return Material(
      color: effectiveBgColor,
      borderRadius: BorderRadius.circular(12),
      elevation: enabled ? 1 : 0,
      shadowColor: Colors.black12,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: effectiveColor.withValues(alpha: enabled ? 0.14 : 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: effectiveColor, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                        color: enabled ? null : theme.colorScheme.onSurface.withValues(alpha: 0.45),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 10,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  const _DashboardCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Diálogo de progreso en tiempo real de la sincronización
class _SyncProgressModal extends StatefulWidget {
  final String titulo;
  final IconData icono;
  final Future<void> Function(Function(SyncProgress) onProgress) onIniciar;

  const _SyncProgressModal({
    required this.titulo,
    required this.icono,
    required this.onIniciar,
  });

  @override
  State<_SyncProgressModal> createState() => _SyncProgressModalState();
}

class _SyncProgressModalState extends State<_SyncProgressModal> {
  String _etapa = 'Preparando sincronización...';
  double _progreso = 0.0;
  String _detalle = 'Conectando con el servidor...';
  bool _terminado = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _comenzar();
  }

  Future<void> _comenzar() async {
    try {
      await widget.onIniciar((progress) {
        if (mounted) {
          setState(() {
            _etapa = progress.stage;
            _progreso = progress.progress;
            _detalle = progress.detail;
          });
        }
      });
      if (mounted) {
        setState(() {
          _terminado = true;
          _progreso = 1.0;
          _etapa = '¡Sincronización completada con éxito!';
          _detalle = 'Los datos locales ya están actualizados.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _terminado = true;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(widget.icono, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              widget.titulo,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Fallo en la sincronización: $_error',
                        style: TextStyle(color: Colors.red.shade800, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              const SizedBox(height: 10),
              // Círculo de progreso con porcentaje en el centro
              SizedBox(
                width: 100,
                height: 100,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 100,
                      height: 100,
                      child: CircularProgressIndicator(
                        value: _terminado ? 1.0 : (_progreso > 0 ? _progreso.clamp(0.0, 1.0) : null),
                        strokeWidth: 8,
                        strokeCap: StrokeCap.round,
                        backgroundColor: theme.colorScheme.surfaceContainerHighest,
                        color: _terminado ? Colors.green : theme.colorScheme.primary,
                      ),
                    ),
                    if (_terminado)
                      const Icon(Icons.check_circle_rounded, color: Colors.green, size: 48)
                    else
                      Text(
                        '${(_progreso * 100).clamp(0, 100).toInt()}%',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                _etapa,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
              const SizedBox(height: 6),
              Text(
                _detalle,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 4),
            ],
          ],
        ),
      ),
      actions: [
        if (_terminado)
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Entendido'),
          )
        else
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar ventana'),
          ),
      ],
    );
  }
}
