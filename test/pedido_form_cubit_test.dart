import 'package:flutter_test/flutter_test.dart';

import 'package:pedidos_venta/core/formatters.dart';
import 'package:pedidos_venta/models.dart';
import 'package:pedidos_venta/state/pedido_form_cubit.dart';

void main() {
  group('PedidoFormCubit', () {
    test('init y update reflejan el pedido en el estado', () {
      final cubit = PedidoFormCubit(Pedido(fecha: todayIso()));

      cubit.init(const Pedido(clienteId: 7, clienteNombre: 'Cliente A'));
      expect(cubit.state.pedido.clienteId, 7);

      cubit.update(
        const Pedido(clienteId: 7, clienteNombre: 'Cliente A', serie: 'V1'),
      );
      expect(cubit.state.pedido.serie, 'V1');
    });

    test('selectCliente sin id fija cliente y almacén central 1', () {
      final cubit = PedidoFormCubit(Pedido(fecha: todayIso()));

      cubit.selectCliente(
        const OpcionMaestra(codigo: '', nombre: 'Sin código'),
        almacenes: const [OpcionMaestra(codigo: '1', nombre: 'Almacén central')],
      );

      final estado = cubit.state;
      expect(estado.pedido.clienteId, 0);
      expect(estado.pedido.almacen, '1');
      expect(estado.pedido.almacenNombre, 'Almacén central');
      expect(estado.cargandoDatosCliente, isFalse);
    });

    test('clearCliente limpia cliente y direcciones', () {
      final cubit = PedidoFormCubit(
        const Pedido(
          clienteId: 7,
          cliente: '7',
          clienteNombre: 'Cliente A',
          direccionEnvio: 'D1',
        ),
      );

      cubit.clearCliente();

      final pedido = cubit.state.pedido;
      expect(pedido.clienteId, 0);
      expect(pedido.cliente, '');
      expect(pedido.clienteNombre, '');
      expect(pedido.direccionEnvio, '');
      expect(cubit.state.direccionesCliente, isEmpty);
    });
  });
}