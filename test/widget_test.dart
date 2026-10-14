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

import 'package:diacritic/diacritic.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart'; // El "marco" de tests de Flutter.

import 'package:pedidos_venta/core/api_client.dart';
import 'package:pedidos_venta/core/api_service.dart';
import 'package:pedidos_venta/core/config.dart';
import 'package:pedidos_venta/core/formatters.dart'; // Las funciones que probamos.
import 'package:pedidos_venta/core/master_cache_service.dart';
import 'package:pedidos_venta/core/repositorio_pedidos.dart';
import 'package:pedidos_venta/core/licencia/licencia.dart';
import 'package:pedidos_venta/core/licencia/licencia_service.dart';
import 'package:pedidos_venta/models/articulo.dart';
import 'package:pedidos_venta/models/models.dart';
import 'package:pedidos_venta/theme/app_theme.dart';
import 'package:pedidos_venta/widgets/campo_form.dart';

void main() {
  // ------ Test 1: formatNumber -------
  test('formatNumber con miles y decimales', () {
    // Puntos para los miles y coma para los decimales (formato español con 3 decimales).
    expect(formatNumber(1234567.89), '1.234.567,890'); // Número con miles y 3 decimales.
    expect(formatNumber(0), '0,000'); // Cero → "0,000".
    expect(formatNumber(-42.5), '-42,500'); // Negativo conserva el signo y 3 decimales.
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

  test('LineaPedido mapea por_dto, DTO1, DTO2, DTO3 y aplica los 4 descuentos concatenados al importe', () {
    final linea = LineaPedido.fromJson({
      'art': 30,
      'dsc': 'Articulo con 4 descuentos concatenados',
      'can_ped': 2,
      'pre': 100,    // bruto = 200
      'por_dto': 10, // 200 - 10% = 180 (principal)
      'DTO1': 10,    // 180 - 10% = 162
      'DTO2': 5,     // 162 - 5% = 153.90
      'DTO3': 2,     // 153.90 - 2% = 150.822
    });

    expect(linea.dto, 10);
    expect(linea.dto1, 10);
    expect(linea.dto2, 5);
    expect(linea.dto3, 2);
    expect(linea.getLineTotal(), closeTo(150.822, 0.001));
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
    expect(payload['emp'], '1');
    expect(payload['emp_div'], '1');
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
      {'id': '10', 'nom_fis': 'Alfa Distribuciones', 'ES_CLT': true},
      {'id': '11', 'nom_fis': 'Beta S.L.', 'ES_CLT': true},
      {'id': '12', 'nom_fis': 'Alfabeta', 'ES_CLT': false},
    ];

    expect(params['page[size]'], 25);
    expect(params['page[number]'], 2);
    // El filtro obligatorio de Velneo recibe el texto entre comillas dobles.
    expect(params['filter[TRO_ES_CLT]'], '"alfa"');
    // No se envían los filtros especulativos que el API ignora.
    expect(params.containsKey('search'), isFalse);
    expect(params.containsKey('filter[nom_fis]'), isFalse);
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

  test('Filtro de estado PARCIALMENTE SERVIDO filtra correctamente en RepositorioPedidos', () {
    expect(AppColors.estadoCodigo('PARCIALMENTE SERVIDO'), 'Q');
    expect(AppColors.estadoLabel('Q'), 'PARCIALMENTE SERVIDO');

    final repo = RepositorioPedidos();
    final p1 = Pedido(id: 1, clienteId: 10, estado: 'P', numeroPedido: 'PV-1');
    final p2 = Pedido(id: 2, clienteId: 10, estado: 'Q', numeroPedido: 'PV-2');
    final p3 = Pedido(id: 3, clienteId: 10, estado: 'S', numeroPedido: 'PV-3');

    repo.setOrders([p1, p2, p3]);

    const admin = User(id: '1', name: 'Admin', role: 'admin');

    final filtrados = repo.filtrarPedidos(
      query: '',
      statusFilter: 'PARCIALMENTE SERVIDO',
      currentUser: admin,
    );

    expect(filtrados.length, 1);
    expect(filtrados.first.id, 2);
    expect(filtrados.first.estado, 'Q');
  });

  test('JsonHelpers.b evalúa correctamente campos booleanos en varios formatos y mayúsculas', () {
    final record1 = {'ES_CMR': '1'};
    final record2 = {'es_cmr': 'true'};
    final record3 = {'es_cmr': true};
    final record4 = {'es_cmr': '0'};
    final record5 = {'ES_CMR': false};
    final record6 = <String, dynamic>{};

    expect(record1.b('es_cmr'), isTrue);
    expect(record1.b('ES_CMR'), isTrue);
    expect(record2.b('es_cmr'), isTrue);
    expect(record3.b('es_cmr'), isTrue);
    expect(record4.b('es_cmr'), isFalse);
    expect(record5.b('es_cmr'), isFalse);
    expect(record6.b('es_cmr'), isFalse);
  });

  test('Articulo mapea correctamente los campos REF, NAME, FAM, PRV, COD_BAR, PVP e IMG', () {
    final json = {
      'id': 123,
      'REF': 'REF-A99',
      'NAME': 'Taladro Percutor 750W',
      'FAM': {'id': 5, 'name': 'Herramientas Eléctricas'},
      'PRV': {'id': 10, 'name': 'Bosch Ibérica'},
      'COD_BAR': '8412345678901',
      'PVP': 89.95,
      'IMG': 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
    };

    final art = Articulo.fromJson(json);

    expect(art.id, '123');
    expect(art.referencia, 'REF-A99');
    expect(art.nombre, 'Taladro Percutor 750W');
    expect(art.familiaId, '5');
    expect(art.familiaNombre, 'Herramientas Eléctricas');
    expect(art.proveedorId, '10');
    expect(art.proveedorNombre, 'Bosch Ibérica');
    expect(art.codigoBarras, '8412345678901');
    expect(art.precio, 89.95);
    expect(art.imagen.isNotEmpty, isTrue);
  });

  test('Búsqueda de artículos filtra correctamente por nombre o por referencia', () {
    final articulos = [
      const Articulo(id: '1', nombre: 'Martillo de bola', referencia: 'REF-MART-01', codigo: 'ART1'),
      const Articulo(id: '2', nombre: 'Destornillador Phillips', referencia: 'REF-DEST-02', codigo: 'ART2'),
      const Articulo(id: '3', nombre: 'Taladro eléctrico', referencia: 'REF-TAL-03', codigo: 'ART3'),
    ];

    List<Articulo> filtrar(String query) {
      final q = removeDiacritics(query.trim().toLowerCase());
      if (q.isEmpty) return articulos;
      final tokens = q.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
      return articulos.where((art) {
        final nombre = removeDiacritics(art.nombre.toLowerCase());
        final ref = removeDiacritics(art.referencia.toLowerCase());
        final cod = removeDiacritics(art.codigo.toLowerCase());
        final searchable = '$nombre $ref $cod';
        return tokens.every((token) => searchable.contains(token));
      }).toList();
    }

    // Por nombre
    expect(filtrar('martillo').map((a) => a.id), ['1']);
    expect(filtrar('MÁRTILLO').map((a) => a.id), ['1']);
    expect(filtrar('eléctrico').map((a) => a.id), ['3']);

    // Por referencia
    expect(filtrar('REF-DEST').map((a) => a.id), ['2']);
    expect(filtrar('tal-03').map((a) => a.id), ['3']);

    // Búsqueda vacía devuelve todos
    expect(filtrar('').length, 3);
  });

  test('Articulo.fromJson mapea el campo OFF (desactivado) correctamente', () {
    expect(Articulo.fromJson({'OFF': 1}).desactivado, isTrue);
    expect(Articulo.fromJson({'OFF': '1'}).desactivado, isTrue);
    expect(Articulo.fromJson({'OFF': true}).desactivado, isTrue);
    expect(Articulo.fromJson({'off': 'true'}).desactivado, isTrue);
    expect(Articulo.fromJson({}).desactivado, isFalse);
  });

  test('AppConfig tiene configurado el endpoint descuentosPorFamilia apuntando a DTO_POR_FAM', () {
    expect(AppConfig.endpoint('descuentosPorFamilia'), 'DTO_POR_FAM');
  });

  test('PedidosService extrae DTO1, DTO2 y DTO3 de registros DTO_POR_FAM en formatos numéricos o texto', () {
    final registro = {
      'id': 1,
      'ENT_M': 100,
      'FAM_M': 25,
      'DTO1': 12.5,
      'DTO2': '5,00',
      'DTO3': {'value': 2.0},
    };

    final dtos = PedidosService.extraerDescuentosFamilia(registro);
    expect(dtos['dto1'], 12.5);
    expect(dtos['dto2'], 5.0);
    expect(dtos['dto3'], 2.0);
  });

  test('payloadLista y extraerDescuentosFamilia procesan la respuesta real de Velneo dto_por_fam', () {
    final responseJson = {
      'count': 1,
      'total_count': 1,
      'dto_por_fam': [
        {
          'id': 1,
          'name': '',
          'ent_m': 4,
          'fam_m': '00200002',
          'dto1': 63,
          'dto2': 10,
          'dto3': 5,
        }
      ],
    };

    final lista = payloadLista(responseJson);
    expect(lista.length, 1);
    expect(lista.first['fam_m'], '00200002');
    expect(lista.first['ent_m'], 4);

    final dtos = PedidosService.extraerDescuentosFamilia(lista.first);
    expect(dtos['dto1'], 63.0);
    expect(dtos['dto2'], 10.0);
    expect(dtos['dto3'], 5.0);
  });

  // ------ Tests de Licencia UUID ------
  test('Licencia.calcularIdentificador calcula (codigo - 3259) correctamente', () {
    expect(Licencia.calcularIdentificador('3314'), '55');
    expect(Licencia.calcularIdentificador('3259'), '0');
    expect(Licencia.calcularIdentificador('10000'), '6741');
    expect(Licencia.calcularIdentificador('no_es_numero'), 'no_es_numero');
    expect(Licencia.calcularIdentificador('   3314   '), '55');
  });

  test('Licencia.buildValidateUrl construye la URL correcta según especificación', () {
    final lic = Licencia(
      serverHost: 'https://tecerp.nunsys.com:4331',
      serverApi: 'TECERPV7_TECPASS',
      version: 'v1',
      identificador: '55',
      apiKey: 'test-api-key',
    );

    final url = lic.buildValidateUrl();
    expect(
      url,
      'https://tecerp.nunsys.com:4331/TECERPV7_TECPASS/TecERPv7_dat_dat/v1/app_ent/55?api_key=test-api-key',
    );
  });

  test('Licencia serializa y deserializa en JSON preservando todos los campos', () {
    final original = Licencia(
      tecnico: 'Juan Perez',
      id: '55',
      identificador: '55',
      licenciaCodigo: '3314',
      uuid: 'A1B2C3D4-E5F6-7890-ABCD-EF1234567890',
      serverHost: 'https://custom-server.com:443',
      serverApi: 'TECERPV7_PROD',
      version: 'v1',
      validada: true,
      entM: '12',
      contraclave: 'A1B2C3D4-E5F6-7890-ABCD-EF1234567890',
      offlineIntentos: 0,
      configIntentos: 2,
      apiKey: 'secret_key',
      mainLicenseAppEntId: '10',
      esAdmin: true,
      esSoloLec: false,
      equipo: 'Movil 1',
    );

    final json = original.toJson();
    final reconstruida = Licencia.fromJson(json);

    expect(reconstruida.tecnico, 'Juan Perez');
    expect(reconstruida.id, '55');
    expect(reconstruida.identificador, '55');
    expect(reconstruida.licenciaCodigo, '3314');
    expect(reconstruida.uuid, 'A1B2C3D4-E5F6-7890-ABCD-EF1234567890');
    expect(reconstruida.serverHost, 'https://custom-server.com:443');
    expect(reconstruida.serverApi, 'TECERPV7_PROD');
    expect(reconstruida.validada, isTrue);
    expect(reconstruida.configIntentos, 2);
    expect(reconstruida.esAdmin, isTrue);
    expect(reconstruida.esSoloLec, isFalse);
    expect(reconstruida.equipo, 'Movil 1');
  });

  test('LicenciaResult reporta estado ok únicamente cuando es valida', () {
    const valida = LicenciaResult(
      estado: LicenciaEstado.valida,
      mensaje: 'Licencia validada',
    );
    expect(valida.ok, isTrue);

    const denegada = LicenciaResult(
      estado: LicenciaEstado.denegada,
      mensaje: 'UUID no coincide',
    );
    expect(denegada.ok, isFalse);

    const errorConexion = LicenciaResult(
      estado: LicenciaEstado.errorConexion,
      mensaje: 'Sin conexión',
    );
    expect(errorConexion.ok, isFalse);
  });

  // ------ Tests de AppConfig Parametrizada ------
  test('AppConfig.buildBaseUrl construye URL con DAT fijo TecERPv7_dat_dat', () {
    final url = AppConfig.buildBaseUrl(
      host: 'https://tecerp.nunsys.com:4331',
      instance: 'TECMICRO_PRUEBAS_AD_AVANZADO',
      version: 'v1',
    );

    expect(
      url,
      'https://tecerp.nunsys.com:4331/TECMICRO_PRUEBAS_AD_AVANZADO/TecERPv7_dat_dat/v1',
    );
    expect(AppConfig.datName, 'TecERPv7_dat_dat');
  });

  test('AppConfig.parseAndSetBaseUrl descompone correctamente la URL completa', () {
    AppConfig.parseAndSetBaseUrl(
      'https://custom.server.es:8080/MI_INSTANCIA/TecERPv7_dat_dat/v2/',
    );

    expect(AppConfig.serverHost, 'https://custom.server.es:8080');
    expect(AppConfig.serverInstance, 'MI_INSTANCIA');
    expect(AppConfig.serverVersion, 'v2');
    expect(AppConfig.baseUrl, 'https://custom.server.es:8080/MI_INSTANCIA/TecERPv7_dat_dat/v2');
  });
}