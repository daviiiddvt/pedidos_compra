import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pedidos_venta/core/offline/offline_database.dart';
import 'package:pedidos_venta/models/models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  group('OfflineDatabase Tests', () {
    late OfflineDatabase offlineDb;
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('offline_db_test_');
      offlineDb = OfflineDatabase.instance;
      offlineDb.factoryOverride = databaseFactoryFfi;
      offlineDb.dbPathOverride = p.join(tempDir.path, 'test_offline.db');
      await offlineDb.init();
    });

    tearDown(() async {
      try {
        if (offlineDb.db.isOpen) {
          await offlineDb.db.close();
        }
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      } catch (_) {}
    });

    test('Guarda maestros y filtra artículos con familia', () async {
      final articulos = [
        {
          'id': '101',
          'cod': 'ART101',
          'name': 'Artículo con familia',
          'FAM_M': 'FAM01',
          'baj': 0,
        },
        {
          'id': '102',
          'cod': 'ART102',
          'name': 'Artículo sin familia',
          'FAM_M': '',
          'baj': 0,
        },
      ];

      await offlineDb.saveMaestrosBatch(tabla: 'ART_M', items: articulos, clearBefore: true);

      final resultado = await offlineDb.getArticulosOffline();
      expect(resultado.items.length, equals(1));
      expect(resultado.items.first.id, equals('101'));
      expect(resultado.items.first.nombre, equals('Artículo con familia'));
      expect(resultado.items.first.tieneFamilia, isTrue);
    });

    test('Guarda entidades y distingue comerciales en ENT_M', () async {
      final entidades = [
        {
          'id': '1',
          'name': 'Cliente Normal S.L.',
          'es_clt': 1,
          'es_cmr': 0,
        },
        {
          'id': '2',
          'name': 'Comercial Juan',
          'es_clt': 0,
          'es_cmr': 1,
        },
      ];

      await offlineDb.saveMaestrosBatch(tabla: 'ENT_M', items: entidades, clearBefore: true);

      final clientes = await offlineDb.getClientesOffline();
      expect(clientes.items.length, equals(1));
      expect(clientes.items.first.nombreComercial, equals('Cliente Normal S.L.'));

      final rows = await offlineDb.getMaestrosData('ENT_M');
      final comerciales = rows.where((r) => (r['es_cmr'] ?? 0) == 1).toList();
      expect(comerciales.length, equals(1));
      expect(comerciales.first['name'], equals('Comercial Juan'));
    });

    test('Guarda y recupera pedidos offline con sus líneas', () async {
      const pedido = Pedido(
        id: 501,
        nDocumento: 100501,
        clienteId: 10,
        clienteNombre: 'Construcciones Norte',
        comercial: 'COM01',
        estado: 'PENDIENTE',
        total: 250.0,
        fecha: '2026-10-15',
        lineas: [
          LineaPedido(
            id: 1,
            codigo: 1,
            articulo: 'ART01',
            articuloNombre: 'Ladrillos',
            cantidad: 100,
            precio: 2.5,
            importe: 250.0,
          ),
        ],
      );

      await offlineDb.savePedidosOffline([pedido], clearBefore: true);

      final pedidos = await offlineDb.getPedidosOffline();
      expect(pedidos.length, equals(1));
      expect(pedidos.first.id, equals(501));
      expect(pedidos.first.clienteNombre, equals('Construcciones Norte'));

      final lineas = await offlineDb.getLineasPedidoOffline(501);
      expect(lineas.length, equals(1));
      expect(lineas.first.articuloNombre, equals('Ladrillos'));
      expect(lineas.first.cantidad, equals(100.0));
    });

    test('Cola Outbox: guarda pedido offline y lo marca como completado', () async {
      const pedidoOffline = Pedido(
        id: -999,
        codigo: -999,
        nDocumento: 999,
        clienteId: 20,
        clienteNombre: 'Cliente Offline',
        total: 120.0,
        fecha: '2026-10-15',
        lineas: [
          LineaPedido(
            id: 1,
            articulo: 'ART99',
            articuloNombre: 'Pintura',
            cantidad: 2,
            precio: 60.0,
            importe: 120.0,
          ),
        ],
      );

      await offlineDb.savePedidoOfflineOutbox(pedido: pedidoOffline);

      var count = await offlineDb.getPendingOutboxCount();
      expect(count, equals(1));

      final pending = await offlineDb.getPendingOutbox();
      expect(pending.first['tipo'], equals('pedido'));
      expect(pending.first['documento_id'], equals('-999'));

      // Simular que el servidor respondió con el pedido real #8888
      await offlineDb.markOutboxCompleted(
        outboxId: pending.first['id'] as String,
        tempDocId: '-999',
        tipo: 'pedido',
        docReal: {
          'id': 8888,
          'n_doc': 8888,
          'fch': '2026-10-15',
          'clt': 20,
          'clt_nom': 'Cliente Offline',
          'tot_ped': 120.0,
          'est': 'P',
        },
      );

      count = await offlineDb.getPendingOutboxCount();
      expect(count, equals(0));

      final pedidosActualizados = await offlineDb.getPedidosOffline();
      expect(pedidosActualizados.any((p) => p.id == -999), isFalse);
      expect(pedidosActualizados.any((p) => p.id == 8888), isTrue);
    });

    test('Metadatos de sincronización: guarda y recupera timestamps y días', () async {
      await offlineDb.setMetadata('last_sync_masters', '2026-10-15T12:00:00.000');
      await offlineDb.setMetadata('sync_days_history', '45');

      final mastersMeta = await offlineDb.getMetadata('last_sync_masters');
      final daysMeta = await offlineDb.getMetadata('sync_days_history');

      expect(mastersMeta, equals('2026-10-15T12:00:00.000'));
      expect(daysMeta, equals('45'));
    });

    test('getClientesByIdsOffline mapea por ID numérico y código con ceros a la izquierda', () async {
      final clientesData = [
        {
          'id': '14502',
          'codigo': '000215',
          'name': 'Construcciones Levante S.L.',
          'cif': 'B12345678',
          'tlf': '600123456',
        },
      ];
      await offlineDb.saveMaestrosBatch(tabla: 'ENT_M', items: clientesData, clearBefore: true);

      // Buscar por código numérico 215
      final mapPorCodigo = await offlineDb.getClientesByIdsOffline([215]);
      expect(mapPorCodigo.containsKey(215), isTrue);
      expect(mapPorCodigo[215]!.nombreComercial, equals('Construcciones Levante S.L.'));

      // Buscar por ID interno 14502
      final mapPorId = await offlineDb.getClientesByIdsOffline([14502]);
      expect(mapPorId.containsKey(14502), isTrue);
      expect(mapPorId[14502]!.nombreComercial, equals('Construcciones Levante S.L.'));
    });

    test('Presupuesto offline guarda líneas y calcula total cuando es 0.0', () async {
      final preOffline = PresupuestoVenta(
        id: -888,
        numeroPresupuesto: 'PRE-OFF-1',
        clienteId: 215,
        clienteNombre: 'Cliente Test',
        total: 0.0, // Total no calculado inicialmente en cabecera
        lineas: [
          LineaPresupuestoVenta(
            id: -1,
            articulo: 'ART01',
            articuloNombre: 'Artículo Uno',
            cantidad: 3.0,
            precio: 50.0,
            importe: 150.0,
          ),
        ],
      );

      await offlineDb.savePresupuestoOfflineOutbox(presupuesto: preOffline);

      // Al recuperar presupuestos offline, si el total era 0.0 debe calcularse sumando las líneas
      final presupuestos = await offlineDb.getPresupuestosOffline();
      expect(presupuestos.any((p) => p.id == -888), isTrue);
      final found = presupuestos.firstWhere((p) => p.id == -888);
      expect(found.total, equals(150.0));
      expect(found.lineas.isNotEmpty, isTrue);

      // Editar el presupuesto offline con nuevas líneas: no debe duplicar líneas ni documentos
      final preEditado = found.copyWith(
        total: 200.0,
        lineas: [
          const LineaPresupuestoVenta(
            id: -2,
            articulo: 'ART02',
            articuloNombre: 'Artículo Dos',
            cantidad: 2.0,
            precio: 100.0,
            importe: 200.0,
          ),
        ],
      );
      await offlineDb.savePresupuestoOfflineOutbox(presupuesto: preEditado);

      final lineasActualizadas = await offlineDb.getLineasPresupuestoOffline(-888);
      expect(lineasActualizadas.length, equals(1));
      expect(lineasActualizadas.first.articulo, equals('ART02'));

      final outboxCount = await offlineDb.getPendingOutboxCount();
      expect(outboxCount, equals(1));
    });

    test('Rechazar y eliminar subida pendiente (discardOutboxItem)', () async {
      final pedidoOffline = Pedido(
        id: -999,
        nDocumento: 999,
        numeroPedido: 'OFFLINE-999',
        clienteId: 10,
        clienteNombre: 'Cliente Rechazar',
        comercial: 'COM01',
        estado: 'PENDIENTE',
        total: 120.0,
        lineas: const [
          LineaPedido(
            id: -1,
            articulo: 'ART99',
            articuloNombre: 'Artículo Temporal',
            cantidad: 1,
            precio: 120.0,
            importe: 120.0,
          ),
        ],
      );

      await offlineDb.savePedidoOfflineOutbox(pedido: pedidoOffline, accion: 'crear');
      expect(await offlineDb.getPendingOutboxCount(), equals(1));

      var pedidos = await offlineDb.getPedidosOffline();
      expect(pedidos.any((p) => p.id == -999), isTrue);

      // Descartar la subida
      await offlineDb.discardOutboxItem('-999');

      expect(await offlineDb.getPendingOutboxCount(), equals(0));
      pedidos = await offlineDb.getPedidosOffline();
      expect(pedidos.any((p) => p.id == -999), isFalse);
    });

    test('Rechazar todas las subidas pendientes (discardAllOutboxItems)', () async {
      final pedidoOffline = Pedido(
        id: -1001,
        nDocumento: 1001,
        clienteId: 10,
        clienteNombre: 'Cliente 1',
        total: 50.0,
      );
      final preOffline = PresupuestoVenta(
        id: -1002,
        numeroPresupuesto: 'PRE-OFF-1002',
        clienteId: 20,
        clienteNombre: 'Cliente 2',
        total: 75.0,
      );

      await offlineDb.savePedidoOfflineOutbox(pedido: pedidoOffline, accion: 'crear');
      await offlineDb.savePresupuestoOfflineOutbox(presupuesto: preOffline, accion: 'crear');

      expect(await offlineDb.getPendingOutboxCount(), equals(2));

      await offlineDb.discardAllOutboxItems();

      expect(await offlineDb.getPendingOutboxCount(), equals(0));
      final pedidos = await offlineDb.getPedidosOffline();
      final presupuestos = await offlineDb.getPresupuestosOffline();
      expect(pedidos.any((p) => p.id == -1001), isFalse);
      expect(presupuestos.any((p) => p.id == -1002), isFalse);
    });
  });
}

