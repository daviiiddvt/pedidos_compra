import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:pedidos_venta/core/licencia/licencia.dart';
import 'package:pedidos_venta/core/licencia/licencia_service.dart';
import 'package:pedidos_venta/core/licencia/licencia_navigation_observer.dart';
import 'package:pedidos_venta/core/offline/offline_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  group('Licencia Model Tests', () {
    test('Calcula identificador correctamente según fórmula: LicenciaCodigo - 3259', () {
      expect(Licencia.calcularIdentificador('3314'), '55');
      expect(Licencia.calcularIdentificador('3312'), '53');
      expect(Licencia.calcularIdentificador('3259'), '0');
      expect(Licencia.calcularIdentificador('texto'), 'texto');
    });

    test('buildValidateUrl genera la URL según la especificación de Velneo', () {
      final lic = Licencia(
        licenciaCodigo: '3314',
        identificador: '53',
        serverApi: 'https://servidor.cliente.com:8443',
        version: 'v1',
        apiKey: '2xQmwUXpt8i',
      );
      final url = lic.buildValidateUrl();
      expect(
        url,
        'https://servidor.cliente.com:8443/tecmicro/TecERPv7_dat_dat/v1/app_ent/53?api_key=2xQmwUXpt8i',
      );
    });

    test('buildValidateUrl no duplica instancia cuando se especifica TECMICRO_PRUEBAS_AD_AVANZADO', () {
      final lic = Licencia(
        serverHost: 'https://servidor.cliente.com:8443',
        serverApi: 'TECMICRO_PRUEBAS_AD_AVANZADO',
        identificador: '45',
        version: 'v1',
        apiKey: '80IF1kwMQZTknj3BirIz',
      );
      final url = lic.buildValidateUrl();
      expect(
        url,
        'https://servidor.cliente.com:8443/TECMICRO_PRUEBAS_AD_AVANZADO/TecERPv7_dat_dat/v1/app_ent/45?api_key=80IF1kwMQZTknj3BirIz',
      );
    });

    test('toDbMap y fromDbMap serializan y deserializan correctamente para SQLite', () {
      final lic = Licencia(
        tecnico: 'Técnico de pruebas',
        id: '8597',
        identificador: '53',
        licenciaCodigo: '3314',
        uuid: 'UUID-TEST-1234',
        serverApi: 'TECMICRO_PRUEBAS_AD_AVANZADO',
        version: 'v1',
        validada: true,
        entM: '8597',
        contraclave: '1243003940',
        offlineIntentos: 0,
        apiKey: 'clave_api_123',
      );

      final dbMap = lic.toDbMap();
      expect(dbMap['id'], 1);
      expect(dbMap['tecnico'], 'Técnico de pruebas');
      expect(dbMap['id_licencia'], '8597');
      expect(dbMap['identificador'], '53');
      expect(dbMap['validada'], 1);

      final deserialized = Licencia.fromDbMap(dbMap);
      expect(deserialized.tecnico, lic.tecnico);
      expect(deserialized.id, lic.id);
      expect(deserialized.identificador, lic.identificador);
      expect(deserialized.validada, true);
      expect(deserialized.contraclave, '1243003940');
      expect(deserialized.entM, '8597');
      expect(deserialized.serverApi, 'TECMICRO_PRUEBAS_AD_AVANZADO');
    });

    test('serverApi y serverHost aparecen vacíos por defecto y preservan el servidor configurado por el usuario', () {
      final defaultLic = Licencia();
      expect(defaultLic.serverApi, '');
      expect(defaultLic.serverHost, '');

      final fromMapWithHost = Licencia.fromDbMap({'server_host': 'https://tecerp.nunsys.com:4331', 'server_api': 'TECMICRO'});
      expect(fromMapWithHost.serverHost, 'https://tecerp.nunsys.com:4331');
      expect(fromMapWithHost.serverApi, 'TECMICRO');

      final fromJsonWithHost = Licencia.fromJson({'serverHost': 'https://tecerp.nunsys.com:4331', 'serverApi': 'TECMICRO'});
      expect(fromJsonWithHost.serverHost, 'https://tecerp.nunsys.com:4331');
      expect(fromJsonWithHost.serverApi, 'TECMICRO');
    });
  });

  group('SQLite Licencia Table Tests', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('licencia_db_test_');
      OfflineDatabase.instance.factoryOverride = databaseFactoryFfi;
      OfflineDatabase.instance.dbPathOverride = '${tempDir.path}/test_offline.db';
      await OfflineDatabase.instance.init();
    });

    tearDown(() async {
      try {
        await OfflineDatabase.instance.db.close();
      } catch (_) {}
      try {
        await tempDir.delete(recursive: true);
      } catch (_) {}
      OfflineDatabase.instance.dbPathOverride = null;
      OfflineDatabase.instance.factoryOverride = null;
    });

    test('Guarda y recupera licencia en tabla SQLite con id = 1', () async {
      final lic = Licencia(
        tecnico: 'Empresa Test',
        id: '8597',
        identificador: '53',
        licenciaCodigo: '3314',
        uuid: 'UUID-PRUEBA',
        serverApi: 'TECMICRO_PRUEBAS_AD_AVANZADO',
        version: 'v1',
        validada: true,
        entM: '8597',
        contraclave: '1243003940',
        offlineIntentos: 1,
        apiKey: 'key_abc',
      );

      await OfflineDatabase.instance.saveLicencia(lic.toDbMap());

      final row = await OfflineDatabase.instance.getLicencia();
      expect(row, isNotNull);
      expect(row!['id'], 1);
      expect(row['tecnico'], 'Empresa Test');
      expect(row['id_licencia'], '8597');
      expect(row['identificador'], '53');
      expect(row['licencia_codigo'], '3314');
      expect(row['validada'], 1);
      expect(row['contraclave'], '1243003940');
      expect(row['ent_m'], '8597');
      expect(row['offline_intentos'], 1);
      expect(row['api_key'], 'key_abc');
    });

    test('resetLicencia restablece los valores por defecto manteniendo UUID y servidor configurado', () async {
      final lic = Licencia(
        tecnico: 'Empresa Test',
        id: '8597',
        identificador: '53',
        licenciaCodigo: '3314',
        uuid: 'UUID-CONSERVADO',
        serverHost: 'https://servidor-personalizado.com:8443',
        serverApi: 'INSTANCIA_CLIENTE',
        validada: true,
      );
      await OfflineDatabase.instance.saveLicencia(lic.toDbMap());

      await OfflineDatabase.instance.resetLicencia(uuid: 'UUID-CONSERVADO');

      final row = await OfflineDatabase.instance.getLicencia();
      expect(row, isNotNull);
      expect(row!['validada'], 0);
      expect(row['licencia_codigo'], '');
      expect(row['id_licencia'], '');
      expect(row['uuid'], 'UUID-CONSERVADO');
      expect(row['server_host'], 'https://servidor-personalizado.com:8443');
      expect(row['server_api'], 'INSTANCIA_CLIENTE');
    });

    test('LicenciaService.validate preserva el id (7665) y no lo sobrescribe con apiId (45)', () async {
      final fakeClient = _FakeHttpClient((req) async {
        return http.Response('''
{
  "count": 1,
  "total_count": 1,
  "app_ent": [
    {
      "id": 45,
      "name": "DAVID",
      "ent_m": 7665,
      "baj": false,
      "lic": "3304",
      "contraclave": "F762B466-4130-4A2D-8E80-5BC5A79AC83E"
    }
  ]
}
''', 200, headers: {'content-type': 'application/json'});
      });

      final service = LicenciaService(httpClient: fakeClient);
      final lic = Licencia(
        licenciaCodigo: '3304',
        id: '7665',
        identificador: '45',
        serverHost: 'https://servidor.cliente.com:8443',
        serverApi: 'TECMICRO_PRUEBAS_AD_AVANZADO',
      );

      final result = await service.validate(lic, saveOnSuccess: false);
      expect(result.ok, isTrue);
      expect(lic.id, '7665', reason: 'El ID (app_ent) configurado no debe sobreescribirse con 45');
      expect(lic.identificador, '45');
      expect(lic.entM, '7665');
    });

    test('comprobarBajaSiProcede detecta baja y notifica onLicenciaRevocada', () async {
      final fakeClient = _FakeHttpClient((request) async {
        return http.Response('''
{
  "app_ent": [
    {
      "id": 45,
      "licencia": 3304,
      "ent_m": 7665,
      "contraclave": "CLAVE-123",
      "baj": true
    }
  ]
}
''', 200, headers: {'content-type': 'application/json'});
      });

      final service = LicenciaService(httpClient: fakeClient);
      final lic = Licencia(
        licenciaCodigo: '3304',
        id: '7665',
        identificador: '45',
        serverHost: 'https://servidor.cliente.com:8443',
        serverApi: 'API_TEST',
        validada: true,
      );
      await service.save(lic);
      expect(service.isValida, isTrue);

      String? motivoRevocacion;
      service.onLicenciaRevocada = (motivo) {
        motivoRevocacion = motivo;
      };

      await service.comprobarBajaSiProcede();

      expect(service.isValida, isFalse);
      expect(motivoRevocacion, contains('baja'));
    });

    test('LicenciaNavigationObserver dispara comprobarBajaSiProcede en didPush y didPop', () async {
      var llamadas = 0;
      final fakeClient = _FakeHttpClient((request) async {
        llamadas++;
        return http.Response('''
{
  "app_ent": [
    {
      "id": 45,
      "licencia": 3304,
      "ent_m": 7665,
      "contraclave": "CLAVE-123",
      "baj": false
    }
  ]
}
''', 200, headers: {'content-type': 'application/json'});
      });

      final service = LicenciaService(httpClient: fakeClient);
      final lic = Licencia(
        licenciaCodigo: '3304',
        id: '7665',
        identificador: '45',
        serverHost: 'https://servidor.cliente.com:8443',
        serverApi: 'API_TEST',
        validada: true,
      );
      await service.save(lic);

      final observer = LicenciaNavigationObserver(service);
      final routePresupuestos = MaterialPageRoute(
        settings: const RouteSettings(name: '/presupuestos'),
        builder: (_) => const SizedBox(),
      );
      final routeHome = MaterialPageRoute(
        settings: const RouteSettings(name: '/home'),
        builder: (_) => const SizedBox(),
      );

      // 1. didPush a presupuestos
      observer.didPush(routePresupuestos, routeHome);
      await Future.delayed(const Duration(milliseconds: 50));
      expect(llamadas, 1);

      // 2. didPop saliendo de presupuestos
      // Reiniciamos throttle para simular el paso del tiempo
      await Future.delayed(const Duration(milliseconds: 1600));
      observer.didPop(routePresupuestos, routeHome);
      await Future.delayed(const Duration(milliseconds: 50));
      expect(llamadas, 2);
    });
  });
}

class _FakeHttpClient extends http.BaseClient {
  final Future<http.Response> Function(http.BaseRequest request) handler;
  _FakeHttpClient(this.handler);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await handler(request);
    return http.StreamedResponse(
      Stream.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
    );
  }
}