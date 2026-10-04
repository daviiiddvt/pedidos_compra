// ============================================================================
//  pedido_form_cubit.dart  —  ESTADO Y LÓGICA DEL FORMULARIO (CABECERA)
// ============================================================================
//
//  ¿Qué es?
//  --------
//  El Cubit compartido por PedidoFormScreen y PresupuestoFormScreen. Ambas
//  pantallas editan un mismo documento (Pedido) aunque alimenten tablas
//  distintas en Velneo; por eso comparten este mismo estado/lógica.
//
//  ¿Qué guarda?
//  ------------
//  - El `Pedido` que se está construyendo/editando (la cabecera).
//  - Las direcciones de envío del cliente elegido (para el selector).
//  - Flags de UI: cargandoDetalle (modo edición) y cargandoDatosCliente
//    (mientras se descargan los valores por defecto del cliente).
//
//  REGLA DE NEGOCIO (selectCliente):
//  - almacen     → SIEMPRE '1' (almacén central de la empresa).
//  - formaPago   → la que trae el cliente (getClienteDefaults) → 'formaPago'.
//  - serie       → la que trae el cliente (getClienteDefaults) → 'serie'.
//  - Además se propaga email y dirección de envío por defecto del cliente.
// ============================================================================

import 'package:flutter/foundation.dart' show debugPrint; // Logging.
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../core/api_service.dart';
import '../models/models.dart';

part 'pedido_form_cubit.freezed.dart';

/// Estado del formulario de pedido/presupuesto.
@freezed
abstract class PedidoFormState with _$PedidoFormState {
  const factory PedidoFormState({
    required Pedido pedido,
    @Default(<OpcionMaestra>[]) List<OpcionMaestra> direccionesCliente,
    @Default(false) bool cargandoDetalle,
    @Default(false) bool cargandoDatosCliente,
  }) = _PedidoFormState;
}

/// Lógica del formulario: muta el `Pedido` de la cabecera vía copyWith.
class PedidoFormCubit extends Cubit<PedidoFormState> {
  PedidoFormCubit(Pedido pedido)
      : super(PedidoFormState(pedido: pedido));

  /// Reemplaza el documento (carga inicial / detalle cargado en edición).
  Future<void> init(Pedido pedido) async {
    emit(state.copyWith(pedido: pedido, cargandoDatosCliente: true));
    try {
      final direcciones = await PedidosService.getDireccionesCliente(pedido.clienteId);
      if (!isClosed) emit(state.copyWith(direccionesCliente: direcciones.toList(), cargandoDatosCliente: false));
    } catch (_) {
      if (!isClosed) emit(state.copyWith(cargandoDatosCliente: false));
    }
  }

  /// Aplica un cambio genérico de cabecera (campos individuales).
  void update(Pedido pedido) => emit(state.copyWith(pedido: pedido));

  /// Selecciona un cliente desde el buscador y aplica los valores por defecto
  /// de la cabecera que trae de Velneo (almacén, forma de pago, serie, etc.).
  Future<void> selectCliente(
    OpcionMaestra cliente, {
    List<OpcionMaestra> series = const [],
    List<OpcionMaestra> formasPago = const [],
    List<OpcionMaestra> almacenes = const [],
  }) async {
    debugPrint('🚀🚀🚀 CUBIT RECIBIÓ EL CLIENTE: $cliente');
    final clienteId = int.tryParse(cliente.codigo) ?? 0;

    debugPrint('\n[selectCliente] Recibido del AutocompleteField: ${cliente.codigo}'
        ' | ${cliente.nombre} (id=$clienteId)');

    // Almacén central fijo: siempre el código '1', con su nombre real (si la
    // lista de almacenes ya está cargada). Comparación segura: ambos lados a
    // String y sin espacios.
    final almacenOpcion = _opcionPorCodigo(almacenes, '1') ??
        const OpcionMaestra(codigo: '1', nombre: '1');

    // 1º: fijamos el cliente y el almacén central de inmediato.
    emit(state.copyWith(
      pedido: state.pedido.copyWith(
        clienteId: clienteId,
        cliente: cliente.codigo,
        clienteNombre: cliente.nombre,
        almacen: almacenOpcion.codigo,
        almacenNombre: almacenOpcion.nombre,
      ),
      direccionesCliente: const [],
      cargandoDatosCliente: clienteId > 0,
    ));
    debugPrint('[selectCliente] Paso 1 aplicado → clienteId=$clienteId,'
        ' cliente=${cliente.codigo}, clienteNombre=${cliente.nombre},'
        " almacen='${almacenOpcion.codigo}', almacenNombre=${almacenOpcion.nombre}");
    if (clienteId <= 0) return;

    try {
      // 2º: formato de pago, serie, email y dirección por defecto del cliente.
      final resultados = await Future.wait([
        PedidosService.getClienteDefaults(clienteId),
        PedidosService.getDireccionesCliente(clienteId),
      ]);
      if (isClosed) return;

      final defaults = resultados[0] as Map<String, dynamic>;
      final direcciones = resultados[1] as List<OpcionMaestra>;

      debugPrint('[selectCliente] Defaults de Velneo recibidos → $defaults');
      var pedido = state.pedido;

      // ── Mapeo explícito de campos del cliente al Pedido ────────────────
      // Forma de pago: la del cliente. Traducimos el código numérico a su
      // nombre descriptivo buscándolo en la lista de formas de pago.
      final formaPagoDefault = defaults['formaPago'];
      if (formaPagoDefault is String && formaPagoDefault.isNotEmpty) {
        final opcion = _opcionPorCodigo(formasPago, formaPagoDefault) ??
            OpcionMaestra(codigo: formaPagoDefault, nombre: formaPagoDefault);
        pedido = pedido.copyWith(
          formaPago: opcion.codigo,
          formaPagoNombre: opcion.nombre,
        );
        debugPrint('[selectCliente] formaPago <- ${opcion.codigo}'
            ' (${opcion.nombre}) desde default="$formaPagoDefault"');
      }

      // Serie: la del cliente. Traducimos el código numérico a su nombre
      // descriptivo buscándolo en la lista de series.
      final serieDefault = defaults['serie'];
      if (serieDefault is String && serieDefault.isNotEmpty) {
        final opcion = _opcionPorCodigo(series, serieDefault) ??
            OpcionMaestra(codigo: serieDefault, nombre: serieDefault);
        pedido = pedido.copyWith(
          serie: opcion.codigo,
          serieNombre: opcion.nombre,
        );
        debugPrint('[selectCliente] serie <- ${opcion.codigo}'
            ' (${opcion.nombre}) desde default="$serieDefault"');
      }

      final emailDefault = defaults['email'];
      if (emailDefault is String &&
          emailDefault.isNotEmpty &&
          emailDefault != pedido.email) {
        pedido = pedido.copyWith(email: emailDefault);
      }

      // Dirección de envío: la por defecto, o la primera disponible.
      final direccionDefault = defaults['direccion'];
      final direccionesDisponibles = [...direcciones];
      if (direccionesDisponibles.isEmpty &&
          direccionDefault is String &&
          direccionDefault.isNotEmpty) {
        direccionesDisponibles.add(
          OpcionMaestra(codigo: direccionDefault, nombre: direccionDefault),
        );
      }
      final direccionElegida = (direccionDefault is String && direccionDefault.isNotEmpty)
          ? direccionDefault
          : (direccionesDisponibles.isNotEmpty ? direccionesDisponibles.first.codigo : null);
      if (direccionElegida != null &&
          direccionElegida.isNotEmpty &&
          direccionElegida != pedido.direccionEnvio) {
        pedido = pedido.copyWith(direccionEnvio: direccionElegida);
      }

      emit(state.copyWith(
        pedido: pedido,
        direccionesCliente: direccionesDisponibles,
        cargandoDatosCliente: false,
      ));
      debugPrint('[selectCliente] PASO 2 FINAL →'
          ' almacen=${pedido.almacen} (${pedido.almacenNombre}),'
          ' serie=${pedido.serie} (${pedido.serieNombre}),'
          ' formaPago=${pedido.formaPago} (${pedido.formaPagoNombre}),'
          ' direccionEnvio=${pedido.direccionEnvio}');
    } catch (e) {
      debugPrint('[selectCliente] Error al aplicar defaults del cliente: $e');
      if (!isClosed) emit(state.copyWith(cargandoDatosCliente: false));
    }
  }

  /// Busca en [opciones] la opción cuyo código coincida EXACTAMENTE con
  /// [codigo] (comparando ambos lados como String y sin espacios ni
  /// mayúsculas). Devuelve null si no hay coincidencia.
  ///
  /// Es la forma segura de traducir los códigos numéricos de Velneo
  /// (ej. formaPago '2', serie '14', almacen '1') a su nombre descriptivo.
  OpcionMaestra? _opcionPorCodigo(List<OpcionMaestra> opciones, String? codigo) {
    final buscado = (codigo ?? '').toString().trim().toLowerCase();
    if (buscado.isEmpty) return null;
    for (final opcion in opciones) {
      if (opcion.codigo.toString().trim().toLowerCase() == buscado) {
        return opcion;
      }
    }
    return null;
  }

  /// Limpia el cliente elegido (botón "quitar selección" del buscador).
  void clearCliente() {
    emit(state.copyWith(
      pedido: state.pedido.copyWith(
        clienteId: 0,
        cliente: '',
        clienteNombre: '',
        direccionEnvio: '',
      ),
      direccionesCliente: const [],
    ));
  }

  /// Fija la dirección de envío elegida por el usuario.
  void selectDireccion(OpcionMaestra direccion) {
    emit(state.copyWith(
      pedido: state.pedido.copyWith(direccionEnvio: direccion.codigo),
    ));
  }

  void setCargandoDetalle(bool value) =>
      emit(state.copyWith(cargandoDetalle: value));
}