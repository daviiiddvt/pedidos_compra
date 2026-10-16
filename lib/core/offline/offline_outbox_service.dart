import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../models/models.dart';
import '../api_service.dart';
import '../presupuesto_service.dart';
import 'offline_database.dart';
import 'offline_sync_service.dart';

class OutboxSyncResult {
  final int total;
  final int success;
  final int failed;
  final List<String> errors;

  const OutboxSyncResult({
    required this.total,
    required this.success,
    required this.failed,
    this.errors = const [],
  });
}

/// Gestor de la cola de subida (Outbox).
///
/// Monitoriza y sincroniza en segundo plano las ventas (pedidos y presupuestos)
/// creadas mientras el dispositivo no disponía de acceso a la red.
class OfflineOutboxService {
  static final OfflineOutboxService instance = OfflineOutboxService._();
  OfflineOutboxService._();

  final _db = OfflineDatabase.instance;
  Timer? _timer;
  bool _isProcessing = false;

  final ValueNotifier<int> pendingCount = ValueNotifier<int>(0);

  bool get isProcessing => _isProcessing;

  Future<void> init() async {
    await refreshPendingCount();
    _startPeriodicSync();
  }

  void _startPeriodicSync() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 25), (_) {
      triggerBackgroundSync();
    });
  }

  void dispose() {
    _timer?.cancel();
  }

  Future<int> refreshPendingCount() async {
    try {
      final count = await _db.getPendingOutboxCount();
      pendingCount.value = count;
      return count;
    } catch (_) {
      return 0;
    }
  }

  /// Intento de subida en segundo plano: solo procede si hay elementos y el servidor está disponible
  Future<void> triggerBackgroundSync() async {
    if (_isProcessing) return;
    if (pendingCount.value == 0) {
      await refreshPendingCount();
      if (pendingCount.value == 0) return;
    }

    final reachable = await OfflineSyncService.instance.isServerReachable();
    if (!reachable) return;

    await processQueue();
  }

  /// Procesa todos los elementos pendientes de la cola de subida
  Future<OutboxSyncResult> processQueue() async {
    if (_isProcessing) {
      return OutboxSyncResult(total: pendingCount.value, success: 0, failed: 0);
    }

    _isProcessing = true;
    var successCount = 0;
    var failedCount = 0;
    final errorMessages = <String>[];

    try {
      final pendingList = await _db.getPendingOutbox();
      if (pendingList.isEmpty) {
        pendingCount.value = 0;
        return const OutboxSyncResult(total: 0, success: 0, failed: 0);
      }

      for (final item in pendingList) {
        final outboxId = item['id'] as String;
        final tipo = item['tipo'] as String;
        final docId = item['documento_id'] as String;
        final payloadRaw = item['payload_json'] as String;

        try {
          await _db.updateOutboxStatus(outboxId, estado: 'subiendo');
          final payload = jsonDecode(payloadRaw) as Map<String, dynamic>;

          final accion = (item['accion'] ?? 'crear') as String;

          if (tipo == 'pedido') {
            final pedidoMap = payload['pedido'] as Map<String, dynamic>;
            var pedido = Pedido.fromJson(pedidoMap);
            if (pedido.lineas.isEmpty) {
              final dbLineas = await _db.getLineasPedidoOffline(docId);
              if (dbLineas.isNotEmpty) {
                final calcTot = dbLineas.fold<double>(0.0, (s, l) => s + l.getLineTotal());
                pedido = pedido.copyWith(
                  lineas: dbLineas,
                  total: pedido.total > 0.0 ? pedido.total : calcTot,
                );
              }
            }
            final fotoBase64 = payload['fotoBase64'] as String?;
            final fotoBytes = fotoBase64 != null ? base64Decode(fotoBase64) : null;
            final deleteFoto = payload['deleteFoto'] == true;
            final removedLineIds = (payload['removedLineIds'] as List? ?? [])
                .map((e) => int.tryParse('$e') ?? 0)
                .where((e) => e > 0)
                .toSet();

            if (accion == 'editar') {
              final updated = await PedidosService.updateComplete(
                docId,
                pedido,
                removedLineIds,
                fotoBytes: fotoBytes,
                deleteFoto: deleteFoto,
                isSync: true,
              );
              await _db.markOutboxCompleted(
                outboxId: outboxId,
                tempDocId: docId,
                tipo: 'pedido',
                docReal: updated.toJson(),
              );
              successCount++;
            } else {
              // Intentar crear en el servidor
              final created = await PedidosService.createComplete(
                pedido,
                fotoBytes: fotoBytes,
                isSync: true,
              );

              // Si se creó con éxito (id real positivo)
              if (created.id != null && created.id! > 0) {
                await _db.markOutboxCompleted(
                  outboxId: outboxId,
                  tempDocId: docId,
                  tipo: 'pedido',
                  docReal: created.toJson(),
                );
                successCount++;
              } else {
                throw Exception('No se pudo obtener el ID confirmado del servidor.');
              }
            }
          } else if (tipo == 'presupuesto') {
            final preMap = payload['presupuesto'] as Map<String, dynamic>;
            var pre = PresupuestoVenta.fromJson(preMap);
            if (pre.lineas.isEmpty) {
              final dbLineas = await _db.getLineasPresupuestoOffline(docId);
              if (dbLineas.isNotEmpty) {
                final calcTot = dbLineas.fold<double>(0.0, (s, l) => s + l.getLineTotal());
                pre = pre.copyWith(
                  lineas: dbLineas,
                  total: pre.total > 0.0 ? pre.total : calcTot,
                );
              }
            }
            final removedLineIds = (payload['removedLineIds'] as List? ?? [])
                .map((e) => int.tryParse('$e') ?? 0)
                .where((e) => e > 0)
                .toSet();

            if (accion == 'editar') {
              final updated = await PresupuestosService.updateComplete(
                docId,
                pre,
                removedLineIds,
                isSync: true,
              );
              await _db.markOutboxCompleted(
                outboxId: outboxId,
                tempDocId: docId,
                tipo: 'presupuesto',
                docReal: updated.toJson(),
              );
              successCount++;
            } else {
              final created = await PresupuestosService.createComplete(pre, isSync: true);
              if (created.id != null && created.id! > 0) {
                await _db.markOutboxCompleted(
                  outboxId: outboxId,
                  tempDocId: docId,
                  tipo: 'presupuesto',
                  docReal: created.toJson(),
                );
                successCount++;
              } else {
                throw Exception('No se pudo obtener el ID de presupuesto del servidor.');
              }
            }
          }
        } catch (e) {
          failedCount++;
          final errStr = e.toString();
          errorMessages.add(errStr);
          await _db.updateOutboxStatus(
            outboxId,
            estado: 'error',
            errorMsg: errStr,
          );
          debugPrint('[OUTBOX_QUEUE] Error al subir $tipo ($docId): $errStr');
        }
      }

      await refreshPendingCount();
      return OutboxSyncResult(
        total: pendingList.length,
        success: successCount,
        failed: failedCount,
        errors: errorMessages,
      );
    } finally {
      _isProcessing = false;
    }
  }
}

