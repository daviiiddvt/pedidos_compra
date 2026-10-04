import 'package:flutter_test/flutter_test.dart';
import 'package:pedidos_venta/core/api_client.dart';
import 'package:pedidos_venta/core/config.dart';
import 'dart:convert';

void main() {
  test('Test PEDIDO', () async {
    final api = ApiClient.instance;
    api.setApiKey(AppConfig.apiKey);
    
    final json = await api.get('TecERPv7_dat_dat/v1/VTA_PED_G', params: {'page[size]': '1'});
    // ignore: avoid_print
    print('PEDIDO: \n${jsonEncode(json)}');
  });
}
