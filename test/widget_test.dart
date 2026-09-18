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

import 'package:flutter_test/flutter_test.dart'; // El "marco" de tests de Flutter.

import 'package:pedidos_venta/core/formatters.dart'; // Las funciones que probamos.
import 'package:pedidos_venta/models.dart';

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
}