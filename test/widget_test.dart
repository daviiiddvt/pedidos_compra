// ============================================================================
//  widget_test.dart  —  LOS TESTS AUTOMÁTICOS DE LA APP
// ============================================================================
//
//  ¿Qué es esto?
//  -------------
//  Pequeñas "comprobaciones automáticas" que verifican que nuestras funciones
//  de formato se portan bien. Es como un examen: le decimos "entrada X debe
//  darnos salida Y" y, si no coincide, el test falla en rojo.
//
//  ¿Cómo se ejecutan? (desde la carpeta del proyecto)
//      flutter test
//
//  Cobertura actual: las 3 funciones de formatters.dart (formatters_funciones:
//  formatNumber, parseNumber y formatDate). Si tocamos esas funciones y los
//  tests siguen pasando, la lógica sigue bien.
//
//  CONCEPTO:
//  - test('nombre', () { expect(real, esperado); }):
//        "Comprueba que REAL es IGUAL a ESPERADO". Si no lo es → falla.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart'; // El "marco" de tests de Flutter.

import 'package:pedidos_venta/api_service.dart';
import 'package:pedidos_venta/core/formatters.dart'; // Las funciones que probamos.
import 'package:pedidos_venta/core/master_cache_service.dart';
import 'package:pedidos_venta/models.dart';
import 'package:pedidos_venta/widgets/campo_form.dart';

void main() {
  // ------ Test 1: formatNumber -------
  test('formatNumber con miles y decimales', () {
    // Puntos para los miles y coma para los decimales (formato español).
    expect(formatNumber(1234567.89), '1.234.567,89'); // Número con miles.
    expect(formatNumber(0), '0,00'); // Cero → "0,00".
    expect(formatNumber(-42.5), '-42,50'); // Negativo conserva el signo.
  });

  // ------ Test 2: parseNumber -------
  test('parseNumber normaliza formato español', () {
    // De texto con formato español pasa a número de verdad.
    expect(parseNumber('1.234,56'), 1234.56); // Acepta puntos (miles).
    expect(parseNumber('12,5'), 12.5); // Acepta coma decimal.
    expect(parseNumber('abc'), 0); // Texto basura → 0 (no rompe).
  });

  // ------ Test 3: formatDate -------
  test('dateFormato convierte ISO a dd/mm/yyyy', () {
    expect(formatDate('2026-09-09'), '09/09/2026'); // ISO → formato español.
  });

  test('Pedido mapea los campos publicados por VTA_PED_G', () {
    final pedido = Pedido.fromJson({
      'num_ped': 'PV-10',
      'clt': 25,
      'est': 'P',
      'tot_ped': 121.0,
      'n_doc': 100,
      'ser': 'V',
      'fch': '2026-09-18',
      'fch_ent': '2026-09-20',
      'fpg': 'CONT',
      'dir_env': 'Calle Mayor 1',
      'email': 'cliente@example.com',
      'obs': 'Entregar por la manana',
      'cmr': {'id': 7},
    });

    expect(pedido.numeroPedido, 'PV-10');
    expect(pedido.clienteId, 25);
    expect(pedido.nDocumento, 100);
    expect(pedido.comercial, '7');
    expect(pedido.direccionEnvio, 'Calle Mayor 1');
    expect(pedido.observaciones, 'Entregar por la manana');
  });

  test('LineaPedido mapea VTA_PED_LIN_G y calcula su importe', () {
    final linea = LineaPedido.fromJson({
      'art': {'id': 30},
      'dsc': 'Articulo de prueba',
      'can_ped': 2,
      'pre': 50,
      'por_dto': 10,
      'reg_iva_vta': 'G',
      'est': 'P',
    });

    expect(linea.articulo, '30');
    expect(linea.descripcion, 'Articulo de prueba');
    expect(linea.tipoIva, 21);
    expect(linea.getLineTotal(), 90);
  });

  test('buildArticleNameMap agrupa nombres por artículo sin consultar uno a uno', () {
    final recordMap = [
      {'id': 10, 'name': 'Tornillo M5'},
      {'id': 20, 'descripcion': 'Tuerca hexagonal'},
      {'id': 99, 'name': 'No solicitado'},
    ];

    final map = PedidosService.buildArticleNameMap(recordMap, {'10', '20', '999'});

    expect(map['10'], 'Tornillo M5');
    expect(map['20'], 'Tuerca hexagonal');
    expect(map.containsKey('999'), isFalse);
  });

  testWidgets('CampoSelect no dispara onTap cuando está deshabilitado', (tester) async {
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CampoSelect(
            label: 'Cliente',
            enabled: false,
            onTap: () => tapped = true,
          ),
        ),
      ),
    );

    await tester.tap(find.byType(InkWell));
    await tester.pump();

    expect(tapped, isFalse);
  });

  test('buildPedidoPayload omite el email porque la API no lo admite en cabecera', () {
    final pedido = Pedido(
      clienteId: 25,
      estado: 'P',
      serie: 'V',
      comercial: '7',
      almacen: 'A1',
      fecha: '2026-09-18',
      previstoPara: '2026-09-20',
      formaPago: 'CONT',
      direccionEnvio: 'DIR-1',
      email: 'cliente@example.com',
      observaciones: 'Pedido de prueba',
    );

    final payload = PedidosService.buildPedidoPayload(pedido);

    expect(payload['clt'], 25);
    expect(payload['email'], isNull);
    expect(payload['dir_env'], 'DIR-1');
    expect(payload['fpg'], 'CONT');
  });

  test('shouldRequestNextPage sigue paginando hasta cubrir total_count', () {
    expect(
      PedidosService.shouldRequestNextPage(
        loadedRecords: 1000,
        totalRecords: 6298,
        pageSize: 1000,
        pageRecords: 1000,
      ),
      isTrue,
    );

    expect(
      PedidosService.shouldRequestNextPage(
        loadedRecords: 6298,
        totalRecords: 6298,
        pageSize: 1000,
        pageRecords: 298,
      ),
      isFalse,
    );
  });

  test('resolveDefaultValue acepta valores anidados de Velneo', () {
    final record = {
      'ser_vta': {'value': 'V'},
      'fpg': {'id': 'CONT'},
      'DIR_M_VTA_PED_ENV': {'id': 42},
      'EML': {'value': 'cliente@empresa.com'},
      'ALM': {'value': 'A1'},
    };

    expect(PedidosService.resolveDefaultValue(record, ['ser_vta', 'SER_VTA']), 'V');
    expect(PedidosService.resolveDefaultValue(record, ['fpg', 'FPG']), 'CONT');
    expect(PedidosService.resolveDefaultValue(record, ['DIR_M_VTA_PED_ENV', 'dir_env']), '42');
    expect(PedidosService.resolveDefaultValue(record, ['EML', 'email']), 'cliente@empresa.com');
    expect(PedidosService.resolveDefaultValue(record, ['ALM', 'alm']), 'A1');
  });

  test('findMatchingOption acepta tanto el código como el nombre del maestro', () {
    final opciones = [
      const OpcionMaestra(codigo: 'CONT', nombre: 'Contado'),
      const OpcionMaestra(codigo: 'A1', nombre: 'Almacén principal'),
    ];

    expect(PedidosService.findMatchingOption(opciones, 'Contado')?.codigo, 'CONT');
    expect(PedidosService.findMatchingOption(opciones, 'Almacén principal')?.codigo, 'A1');
    expect(PedidosService.findMatchingOption(opciones, 'A1')?.codigo, 'A1');
  });

  test('isClienteEntity solo acepta entidades con ES_CLT marcado como cliente', () {
    expect(PedidosService.isClienteEntity({'ES_CLT': true}), isTrue);
    expect(PedidosService.isClienteEntity({'es_clt': 'true'}), isTrue);
    expect(PedidosService.isClienteEntity({'ES_CLT': false}), isFalse);
    expect(PedidosService.isClienteEntity({'name': 'Proveedor'}), isFalse);
  });

  test('searchClientes genera una petición paginada y filtrada por cliente', () {
    final params = PedidosService.buildClienteSearchParams('alfa', limit: 25, page: 2);
    final records = [
      {'id': '10', 'nom_com': 'Alfa Distribuciones', 'ES_CLT': true},
      {'id': '11', 'nom_com': 'Beta S.L.', 'ES_CLT': true},
      {'id': '12', 'nom_com': 'Alfabeta', 'ES_CLT': false},
    ];

    expect(params['page[size]'], 25);
    expect(params['page[number]'], 2);
    // El filtro obligatorio de Velneo recibe el texto entre comillas dobles.
    expect(params['filter[TRO_ES_CLT]'], '"alfa"');
    // No se envían los filtros especulativos que el API ignora.
    expect(params.containsKey('search'), isFalse);
    expect(params.containsKey('filter[nom_com]'), isFalse);
    expect(
      PedidosService.filterClienteRecords(records, 'alfa').map((r) => r['id']).toList(),
      ['10'],
    );
  });

  test('MasterCacheService reutiliza la misma respuesta en la misma sesión', () async {
    final cache = MasterCacheService();
    var calls = 0;

    final first = await cache.getOrLoad<String>(
      key: 'clientes',
      loader: () async {
        calls++;
        return 'clientes-v1';
      },
      ttl: const Duration(minutes: 10),
    );

    final second = await cache.getOrLoad<String>(
      key: 'clientes',
      loader: () async {
        calls++;
        return 'clientes-v2';
      },
      ttl: const Duration(minutes: 10),
    );

    expect(first, 'clientes-v1');
    expect(second, 'clientes-v1');
    expect(calls, 1);
  });

  test('MasterCacheService deduplica peticiones concurrentes del mismo maestro', () async {
    final cache = MasterCacheService();
    cache.invalidate('clientes');
    var calls = 0;

    final future1 = cache.getOrLoad<String>(
      key: 'clientes',
      loader: () async {
        calls++;
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return 'clientes-v1';
      },
      ttl: const Duration(minutes: 10),
    );

    final future2 = cache.getOrLoad<String>(
      key: 'clientes',
      loader: () async {
        calls++;
        return 'clientes-v2';
      },
      ttl: const Duration(minutes: 10),
    );

    final results = await Future.wait([future1, future2]);

    expect(results, ['clientes-v1', 'clientes-v1']);
    expect(calls, 1);
  });
}