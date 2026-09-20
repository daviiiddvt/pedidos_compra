// ============================================================================
//  search_test.dart  —  TESTS DEL FLUJO DE BÚSQUEDA (debounce + caché local)
// ============================================================================
//
//  Cubre las 3 piezas nuevas de la arquitectura:
//    1. RemoteSearchCubit        → estados y respuestas fuera de orden.
//    2. LocalCacheDb (memoria)   → guardar, buscar, contar, limpiar.
//    3. EntitySearchRepository   → local-first (caché antes que API).
//    4. MasterSyncService        → sincronización diferida por lotes.
//    5. AutocompleteField        → debounce y mínimo de caracteres (widget).
// ============================================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pedidos_venta/core/search/entity_search_repository.dart';
import 'package:pedidos_venta/core/search/local_cache_db.dart';
// LocalCacheDbMemory está en la implementación "stub" (memoria, web). Aquí la
// importamos directamente para poder usarla también en los tests de escritorio.
import 'package:pedidos_venta/core/search/local_cache_db_stub.dart'
    show LocalCacheDbMemory;
import 'package:pedidos_venta/core/search/master_sync_service.dart';
import 'package:pedidos_venta/models.dart';
import 'package:pedidos_venta/state/remote_search_cubit.dart';
import 'package:pedidos_venta/widgets/autocomplete_field.dart';

// ---------------------------------------------------------------------------
// RemoteSearchCubit
// ---------------------------------------------------------------------------

void main() {
  group('RemoteSearchCubit', () {
    test('con menos caracteres de los mínimos emite idle sin llamar a la red',
        () {
      var calls = 0;
      final cubit = RemoteSearchCubit(
        minChars: 3,
        searchFn: (_) async {
          calls++;
          return const [];
        },
      );

      cubit.search('ab'); // 2 caracteres < 3.
      expect(cubit.state, isA<RemoteSearchIdle>());
      expect(calls, 0);
      cubit.close();
    });

    test('emite loading y luego success con los resultados', () async {
      final cubit = RemoteSearchCubit(
        minChars: 3,
        searchFn: (_) async => [
          const OpcionMaestra(codigo: 'A1', nombre: 'Artículo uno'),
        ],
      );

      final future = cubit.search('abc');
      expect(cubit.state, isA<RemoteSearchLoading>());
      await future;
      final state = cubit.state;
      expect(state, isA<RemoteSearchSuccess>());
      expect((state as RemoteSearchSuccess).results.single.codigo, 'A1');
      await cubit.close();
    });

    test('descarta respuestas fuera de orden (peticiones rápidas y lentas)',
        () async {
      final completers = <String, Completer<List<OpcionMaestra>>>{};
      final cubit = RemoteSearchCubit(
        minChars: 3,
        searchFn: (q) =>
            completers.putIfAbsent(q, Completer<List<OpcionMaestra>>.new).future,
      );

      cubit.search('abc'); // Petición 1 (será la lenta).
      cubit.search('abcd'); // Petición 2 (la más reciente).
      expect(cubit.state, isA<RemoteSearchLoading>());

      // La más reciente termina primero -> es la que debe mandar.
      completers['abcd']!.complete(const [
        OpcionMaestra(codigo: '2', nombre: 'Segunda'),
      ]);
      // La antigua termina después -> debe DESCARTARSE.
      completers['abc']!.complete(const [
        OpcionMaestra(codigo: '1', nombre: 'Primera'),
      ]);

      await Future<void>.delayed(const Duration(milliseconds: 5));
      final state = cubit.state;
      expect(state, isA<RemoteSearchSuccess>());
      expect((state as RemoteSearchSuccess).results.single.codigo, '2');
      await cubit.close();
    });

    test('ante un error de red emite failure', () async {
      final cubit = RemoteSearchCubit(
        minChars: 3,
        searchFn: (_) async => throw Exception('timeout'),
      );

      await cubit.search('abc');
      expect(cubit.state, isA<RemoteSearchFailure>());
      await cubit.close();
    });
  });

  // -------------------------------------------------------------------------
  // LocalCacheDb (memoria → misma interfaz que SQLite)
  // -------------------------------------------------------------------------

  group('LocalCacheDb (memoria)', () {
    test('guarda, busca por nombre y por código y ordena por uso', () async {
      final db = LocalCacheDbMemory();
      await db.upsertMany('cliente', const [
        OpcionMaestra(codigo: '10', nombre: 'Alfa Distribuciones'),
        OpcionMaestra(codigo: '11', nombre: 'Beta S.L.'),
      ]);

      final porNombre = await db.search('cliente', 'alfa');
      expect(porNombre.map((o) => o.codigo), ['10']);

      final porCodigo = await db.search('cliente', '11');
      expect(porCodigo.map((o) => o.codigo), ['11']);

      expect(await db.count('cliente'), 2);
      expect(await db.listRecent('cliente'), hasLength(2));

      await db.clear('cliente');
      expect(await db.count('cliente'), 0);
    });
  });

  // -------------------------------------------------------------------------
  // EntitySearchRepository (local-first)
  // -------------------------------------------------------------------------

  group('EntitySearchRepository', () {
    test('con coincidencia en caché local NO llama al API', () async {
      final db = LocalCacheDbMemory();
      await db.upsertMany('cliente', const [
        OpcionMaestra(codigo: '10', nombre: 'Alfa Distribuciones'),
      ]);
      var remoteCalls = 0;
      final repo = EntitySearchRepository(
        db: db,
        remoteSearch: (kind, q, {required limit}) async {
          remoteCalls++;
          return const [OpcionMaestra(codigo: '99', nombre: 'Remoto S.A.')];
        },
      );

      final hits = await repo.search(EntityKind.cliente, 'alfa');
      expect(hits.map((o) => o.codigo), ['10']);
      expect(remoteCalls, 0);
    });

    test('sin coincidencia local llama al API y persiste el resultado',
        () async {
      final db = LocalCacheDbMemory();
      await db.upsertMany('cliente', const [
        OpcionMaestra(codigo: '10', nombre: 'Alfa Distribuciones'),
      ]);
      var remoteCalls = 0;
      final repo = EntitySearchRepository(
        db: db,
        remoteSearch: (kind, q, {required limit}) async {
          remoteCalls++;
          return const [OpcionMaestra(codigo: '99', nombre: 'Remoto S.A.')];
        },
      );

      final miss = await repo.search(EntityKind.cliente, 'remoto');
      expect(miss.map((o) => o.codigo), ['99']);
      expect(remoteCalls, 1);

      // El resultado remoto quedó en caché: la siguiente búsqueda es local.
      final cached = await db.search('cliente', 'remoto');
      expect(cached, isNotEmpty);
      expect(remoteCalls, 1);
    });
  });

  // -------------------------------------------------------------------------
  // MasterSyncService (sincronización diferida, inyectado sin red)
  // -------------------------------------------------------------------------

  group('MasterSyncService', () {
    test('descarga páginas por lotes y las persiste en la caché local',
        () async {
      final db = LocalCacheDbMemory();
      final repo = EntitySearchRepository(db: db);
      var pageCalls = 0;
      final service = MasterSyncService(repository: repo);

      await service.syncHeavy(fetchPage: (kind, page) async {
        pageCalls++;
        if (page > 1) return const <OpcionMaestra>[]; // Solo 1 página llena.
        return [
          OpcionMaestra(codigo: '$page', nombre: 'Registro página $page'),
        ];
      });

      // clientes y artículos, cada uno con 1 página llena + 1 vacía (break).
      expect(pageCalls, 4);
      expect(await db.count('cliente'), 1);
      expect(await db.count('articulo'), 1);
    });
  });

  // -------------------------------------------------------------------------
  // AutocompleteField (widget: debounce y mínimo de caracteres)
  // -------------------------------------------------------------------------

  group('AutocompleteField', () {
    testWidgets('no busca con <3 caracteres', (tester) async {
      final calls = <String>[];
      await tester.pumpWidget(_wrap(AutocompleteField(
        label: 'Artículo',
        minChars: 3,
        search: (q) async {
          calls.add(q);
          return const <OpcionMaestra>[];
        },
        onSelected: (_) {},
      )));

      await tester.enterText(find.byType(TextField), 'ab');
      await tester.pump(const Duration(milliseconds: 600));
      expect(calls, isEmpty);
    });

    testWidgets('respeta el debounce (no llama mientras se sigue tecleando)',
        (tester) async {
      final calls = <String>[];
      await tester.pumpWidget(_wrap(AutocompleteField(
        label: 'Artículo',
        debounce: const Duration(milliseconds: 400),
        search: (q) async {
          calls.add(q);
          return const [OpcionMaestra(codigo: 'A1', nombre: 'Artículo uno')];
        },
        onSelected: (_) {},
      )));

      final field = find.byType(TextField);

      await tester.enterText(field, 'ab');
      await tester.enterText(field, 'abc'); // resetea el debounce
      await tester.enterText(field, 'abcd'); // y de nuevo
      await tester.pump(const Duration(milliseconds: 200));
      expect(calls, isEmpty); // 200ms < 400ms de debounce

      await tester.pump(const Duration(milliseconds: 250)); // 450ms total
      expect(calls, ['abcd']); // una única llamada con el texto final
      // Dejar que el estado pase de loading a success.
      await tester.pump(const Duration(milliseconds: 10));
      expect(find.text('Artículo uno'), findsOneWidget);
    });

    testWidgets('al tocar una sugerencia la selecciona y avisa a onSelected',
        (tester) async {
      OpcionMaestra? selected;
      await tester.pumpWidget(_wrap(AutocompleteField(
        label: 'Artículo',
        minChars: 3,
        debounce: const Duration(milliseconds: 300),
        search: (q) async => const [
          OpcionMaestra(codigo: 'A1', nombre: 'Artículo uno'),
          OpcionMaestra(codigo: 'A2', nombre: 'Artículo dos'),
        ],
        onSelected: (o) => selected = o,
      )));

      await tester.enterText(find.byType(TextField), 'art');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump(const Duration(milliseconds: 10));

      await tester.tap(find.text('Artículo uno'));
      await tester.pump();
      expect(selected?.codigo, 'A1');
      expect(selected?.nombre, 'Artículo uno');
    });
  });
}

Widget _wrap(Widget child) {
  return MaterialApp(
    home: Scaffold(body: Padding(padding: const EdgeInsets.all(16), child: child)),
  );
}