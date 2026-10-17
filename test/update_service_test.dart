import 'package:flutter_test/flutter_test.dart';
import 'package:pedidos_venta/core/update/update_service.dart';

void main() {
  group('UpdateService.isNewer', () {
    test('detecta versión mayor remota', () {
      expect(UpdateService.isNewer('2.0.0', '1.0.0'), isTrue);
      expect(UpdateService.isNewer('1.1.0', '1.0.0'), isTrue);
      expect(UpdateService.isNewer('1.0.1', '1.0.0'), isTrue);
      expect(UpdateService.isNewer('1.0.0.1', '1.0.0'), isTrue);
    });

    test('retorna false si remota es menor o igual', () {
      expect(UpdateService.isNewer('1.0.0', '1.0.0'), isFalse);
      expect(UpdateService.isNewer('0.9.9', '1.0.0'), isFalse);
      expect(UpdateService.isNewer('1.0.0', '2.0.0'), isFalse);
    });

    test('ignora sufijos de compilación (+1, -beta)', () {
      expect(UpdateService.isNewer('1.0.1+2', '1.0.0+1'), isTrue);
      expect(UpdateService.isNewer('1.0.0+5', '1.0.0+1'), isFalse);
    });
  });

  group('UpdateService.extractAndroidSection', () {
    test('extrae la clave android directamente de la raíz (TecERP_KYRO_version.json)', () {
      final json = {
        'android': {
          'version': '2.0.0',
          'message': 'Hay una nueva versión disponible.'
        }
      };
      final section = UpdateService.extractAndroidSection(json);
      expect(section, isNotNull);
      expect(section!['version'], '2.0.0');
      expect(section['message'], 'Hay una nueva versión disponible.');
    });

    test('extrae la clave android dentro de TecERP_KYRO si estuviera anidada', () {
      final json = {
        'TecERP_KYRO': {
          'android': {
            'version': '2.1.0',
            'message': 'Actualización disponible.'
          }
        }
      };
      final section = UpdateService.extractAndroidSection(json);
      expect(section, isNotNull);
      expect(section!['version'], '2.1.0');
    });

    test('retorna null si no existe clave android', () {
      final json = {
        'windows': {
          'version': '2.0.0',
        }
      };
      final section = UpdateService.extractAndroidSection(json);
      expect(section, isNull);
    });
  });
}
