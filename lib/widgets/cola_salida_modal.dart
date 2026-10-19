import 'dart:convert';
import 'package:flutter/material.dart';
import '../core/formatters.dart';
import '../core/offline/connection_status_service.dart';
import '../core/offline/offline_database.dart';
import '../core/offline/offline_outbox_service.dart';
import '../theme/app_theme.dart';

/// Modal para visualizar, subir individualmente o rechazar/eliminar las
/// subidas pendientes de sincronizar en la cola Outbox.
class ColaSalidaModal extends StatefulWidget {
  const ColaSalidaModal({super.key});

  /// Muestra el modal de gestión de subidas pendientes como un Bottom Sheet
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const ColaSalidaModal(),
    );
  }

  @override
  State<ColaSalidaModal> createState() => _ColaSalidaModalState();
}

class _ColaSalidaModalState extends State<ColaSalidaModal> {
  List<Map<String, dynamic>> _items = [];
  bool _cargando = true;
  String? _itemSubiendoId;
  bool _subiendoTodas = false;

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

  Future<void> _rechazarItem(Map<String, dynamic> item) async {
    final outboxId = (item['id'] ?? '').toString();
    final tipo = (item['tipo'] ?? '').toString().toLowerCase();
    final payloadRaw = item['payload_json'] as String? ?? '{}';

    String docDesc = 'este $tipo';
    try {
      final parsed = jsonDecode(payloadRaw) as Map<String, dynamic>;
      final doc = (parsed['pedido'] ?? parsed['presupuesto'] ?? parsed) as Map<String, dynamic>;
      final clt = doc['clt_nom'] ?? doc['clienteNombre'] ?? '';
      if (clt.toString().trim().isNotEmpty) {
        docDesc = '$tipo de $clt';
      }
    } catch (_) {}

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.delete_outline, color: AppColors.error),
            SizedBox(width: 8),
            Text('Rechazar subida'),
          ],
        ),
        content: Text(
          '¿Estás seguro de que deseas rechazar y eliminar la subida de $docDesc?\n\n'
          'El documento no se enviará al servidor central y se eliminará de las subidas pendientes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Rechazar y eliminar'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    try {
      await OfflineOutboxService.instance.discardItem(outboxId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Subida rechazada y eliminada.'),
          duration: Duration(seconds: 2),
        ),
      );
      await _cargar();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al rechazar subida: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _rechazarTodas() async {
    final total = _items.length;
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.delete_sweep_outlined, color: AppColors.error),
            SizedBox(width: 8),
            Text('Rechazar todas las subidas'),
          ],
        ),
        content: Text(
          '¿Estás seguro de que deseas rechazar las $total subidas pendientes?\n\n'
          'Ninguno de estos documentos se transmitirá al servidor central y esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Rechazar todas'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    try {
      await OfflineOutboxService.instance.discardAll();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Se han descartado $total subidas pendientes.'),
          duration: const Duration(seconds: 2),
        ),
      );
      await _cargar();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al descartar subidas: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _subirItem(String outboxId) async {
    if (!ConnectionStatusService.instance.isOnline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay conexión a internet para sincronizar en este momento.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _itemSubiendoId = outboxId);

    try {
      await OfflineOutboxService.instance.processSingleItem(outboxId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Documento subido correctamente.'),
          backgroundColor: Colors.green.shade700,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al subir: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _itemSubiendoId = null);
        await _cargar();
      }
    }
  }

  Future<void> _subirTodas() async {
    if (!ConnectionStatusService.instance.isOnline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay conexión a internet para sincronizar en este momento.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _subiendoTodas = true);

    try {
      final res = await OfflineOutboxService.instance.processQueue();
      if (!mounted) return;

      if (res.failed == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Se subieron ${res.success} documentos correctamente.'),
            backgroundColor: Colors.green.shade700,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Subidos: ${res.success}. Fallaron: ${res.failed}. Revisa la conexión.'),
            backgroundColor: Colors.orange.shade800,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al procesar subidas: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _subiendoTodas = false);
        await _cargar();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.82,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Barra de agarre superior
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 8, bottom: 4),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.onSurfaceVariant.withAlpha(80),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Encabezado
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 12, 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.cloud_upload_outlined, color: Colors.amber.shade900, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Subidas pendientes',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            if (_items.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade700,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${_items.length}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        Text(
                          'Decide si deseas transmitir o descartar cada documento',
                          style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Contenido principal
            Expanded(
              child: _cargando
                  ? const Center(child: CircularProgressIndicator())
                  : _items.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_circle_outline, size: 64, color: Colors.green.shade600),
                                const SizedBox(height: 16),
                                Text(
                                  'No hay subidas pendientes',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Todos tus pedidos y presupuestos están sincronizados con el servidor.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          itemCount: _items.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (ctx, index) {
                            final item = _items[index];
                            final outboxId = (item['id'] ?? '').toString();
                            final tipo = (item['tipo'] ?? '').toString().toUpperCase();
                            final accion = (item['accion'] ?? 'crear').toString();
                            final estado = (item['estado'] ?? '').toString();
                            final errorMsg = item['error_msg'] as String?;
                            final payloadRaw = item['payload_json'] as String? ?? '{}';
                            final isThisUploading = _itemSubiendoId == outboxId ||
                                (estado == 'subiendo' && _subiendoTodas);

                            String clienteNom = 'Cliente';
                            String fecha = '';
                            double total = 0.0;
                            int lineasCount = 0;
                            String docNum = (item['documento_id'] ?? '').toString();

                            try {
                              final parsed = jsonDecode(payloadRaw) as Map<String, dynamic>;
                              final doc = (parsed['pedido'] ?? parsed['presupuesto'] ?? parsed)
                                  as Map<String, dynamic>;
                              clienteNom = '${doc['clt_nom'] ?? doc['clienteNombre'] ?? 'Cliente #${doc['clt'] ?? doc['clienteId']}'}';
                              fecha = '${doc['fch'] ?? doc['fecha'] ?? ''}';
                              total = (doc['tot_ped'] ?? doc['tot_pre'] ?? doc['total'] ?? 0.0) is num
                                  ? (doc['tot_ped'] ?? doc['tot_pre'] ?? doc['total'] ?? 0.0).toDouble()
                                  : 0.0;
                              final lins = (doc['lineas'] ?? []) as List;
                              lineasCount = lins.length;
                              final nDoc = doc['n_doc'] ?? doc['numero'] ?? doc['numeroPresupuesto'] ?? docNum;
                              if ('$nDoc'.isNotEmpty) docNum = '$nDoc';
                            } catch (_) {}

                            // Etiqueta legible para la acción
                            String accionLabel = 'NUEVO';
                            Color accionColor = Colors.teal;
                            if (accion == 'editar') {
                              accionLabel = 'MODIFICACIÓN';
                              accionColor = Colors.orange.shade800;
                            } else if (accion == 'confirmar') {
                              accionLabel = 'CONFIRMACIÓN';
                              accionColor = Colors.purple.shade700;
                            } else if (accion == 'marcarAceptado') {
                              accionLabel = 'ACEPTADO';
                              accionColor = Colors.indigo.shade700;
                            }

                            return Container(
                              decoration: BoxDecoration(
                                color: colorScheme.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: errorMsg != null
                                      ? AppColors.error.withAlpha(120)
                                      : colorScheme.outlineVariant.withAlpha(80),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withAlpha(8),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Fila superior: Tipo, Acción y Estado
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: tipo == 'PEDIDO' ? Colors.green.shade100 : Colors.blue.shade100,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          tipo,
                                          style: TextStyle(
                                            color: tipo == 'PEDIDO' ? Colors.green.shade900 : Colors.blue.shade900,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: accionColor.withAlpha(30),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          accionLabel,
                                          style: TextStyle(
                                            color: accionColor,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ),
                                      const Spacer(),
                                      if (isThisUploading)
                                        const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            SizedBox(
                                              width: 12,
                                              height: 12,
                                              child: CircularProgressIndicator(strokeWidth: 2),
                                            ),
                                            SizedBox(width: 6),
                                            Text(
                                              'Subiendo...',
                                              style: TextStyle(fontSize: 11, color: Colors.blue),
                                            ),
                                          ],
                                        )
                                      else if (errorMsg != null)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppColors.error.withAlpha(20),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.error_outline, size: 12, color: AppColors.error),
                                              SizedBox(width: 4),
                                              Text(
                                                'Error previo',
                                                style: TextStyle(color: AppColors.error, fontSize: 10, fontWeight: FontWeight.bold),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),

                                  // Datos del cliente y documento
                                  Text(
                                    clienteNom,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    'Doc: $docNum · ${fecha.isNotEmpty ? "Fecha: $fecha · " : ""}$lineasCount línea(s) · Total: ${formatNumber(total, decimals: 2)} €',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),

                                  // Mensaje de error si falló antes
                                  if (errorMsg != null && errorMsg.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade50,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: Colors.red.shade200),
                                      ),
                                      child: Text(
                                        errorMsg,
                                        style: TextStyle(color: Colors.red.shade900, fontSize: 11),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],

                                  const SizedBox(height: 8),
                                  const Divider(height: 1),
                                  const SizedBox(height: 4),

                                  // Acciones individuales: Rechazar vs Subir
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      TextButton.icon(
                                        onPressed: isThisUploading ? null : () => _rechazarItem(item),
                                        style: TextButton.styleFrom(
                                          foregroundColor: AppColors.error,
                                          visualDensity: VisualDensity.compact,
                                          padding: const EdgeInsets.symmetric(horizontal: 10),
                                        ),
                                        icon: const Icon(Icons.delete_outline, size: 16),
                                        label: const Text('Rechazar', style: TextStyle(fontSize: 12)),
                                      ),
                                      const SizedBox(width: 8),
                                      FilledButton.tonalIcon(
                                        onPressed: isThisUploading ? null : () => _subirItem(outboxId),
                                        style: FilledButton.styleFrom(
                                          visualDensity: VisualDensity.compact,
                                          padding: const EdgeInsets.symmetric(horizontal: 12),
                                        ),
                                        icon: const Icon(Icons.cloud_upload_outlined, size: 16),
                                        label: const Text('Subir', style: TextStyle(fontSize: 12)),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),

            // Barra de acciones global (cuando hay elementos)
            if (_items.isNotEmpty) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: OutlinedButton.icon(
                        onPressed: _subiendoTodas ? null : _rechazarTodas,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: const BorderSide(color: AppColors.error),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                        label: const Text('Rechazar todas', style: TextStyle(fontSize: 13)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 5,
                      child: FilledButton.icon(
                        onPressed: _subiendoTodas ? null : _subirTodas,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        icon: _subiendoTodas
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.cloud_upload, size: 18),
                        label: Text(
                          _subiendoTodas ? 'Subiendo...' : 'Subir todas ahora',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

