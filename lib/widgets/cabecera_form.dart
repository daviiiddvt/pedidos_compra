// ============================================================================
//  cabecera_form.dart  —  FORMULARIO EDITABLE DE LA CABECERA DEL PEDIDO DE VENTA
// ============================================================================
//
//  ¿Qué es?
//  --------
//  La pestaña "Cabecera" del FORMULARIO (editar/crear). Aquí el usuario
//  escribe/toca los datos generales del pedido de venta: cliente, serie de
//  ventas, comercial, almacén, fechas, forma de pago...
//
//  ¿Cómo "hace sin guardar" cada cambio?
//  -------------------------------------
//  Cada vez que el usuario cambia algo, construimos un Pedido NUEVO con ese
//  cambio (copyWith) y avisamos con widget.onChanged(nuevo). Así la pantalla
//  madre (PedidoFormScreen) va acumulando los cambios. ¡No se guarda hasta
//  pulsar "Guardar"!
//
//  Los desplegables (cliente, serie ventas, comercial, almacén y formas de
//  pago) se cargan del servidor al nacer (en _cargarMaestros) y se eligen
//  con el ModalSelector (que también permite buscar por nombre).
//
//  CONCEPTO:
//  - Future.wait: lanza varias llamadas al API A LA VEZ (más rápido).
//  - copyWith: método de los modelos para "copiar cambiando algo".
// ============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api_service.dart'; // PedidosService (cargar clientes, series, etc.).
import '../models.dart'; // Pedido, OpcionMaestra.
import '../state/auth_state.dart';
import '../theme/app_theme.dart'; // Colores (para etiqueta de estado).
import 'campo_form.dart'; // CampoForm (texto) y CampoSelect (selector).
import 'campo_fecha.dart'; // CampoFecha (calendario).
import 'modal_selector.dart'; // mostrarSelector (ventana para elegir).

// Los estados posibles de un pedido de venta (fuera de las clases: constante).
const _estados = ['Pendiente', 'Servido', 'Cancelado'];

/// CabeceraForm: el formulario editable de la cabecera del pedido de venta.
class CabeceraForm extends StatefulWidget {
  final Pedido pedido; // El pedido actual (para mostrar los valores).
  final ValueChanged<Pedido> onChanged; // Avisamos del pedido modificado.

  const CabeceraForm({super.key, required this.pedido, required this.onChanged});

  @override
  State<CabeceraForm> createState() => _CabeceraFormState();
}

class _CabeceraFormState extends State<CabeceraForm> {
  // Las listas "maestras" que bajamos del servidor para los desplegables.
  List<OpcionMaestra> _clientes = [];
  List<OpcionMaestra> _series = [];
  List<OpcionMaestra> _comerciales = [];
  List<OpcionMaestra> _almacenes = [];
  List<OpcionMaestra> _formasPago = [];
  List<OpcionMaestra> _direccionesCliente = [];
  bool _cargandoCliente = false;

  @override
  void initState() {
    super.initState();
    _cargarMaestros(); // Al nacer, bajamos todas las listas.
  }

  /// _cargarMaestros: pide las listas al servidor A LA VEZ.
  Future<void> _cargarMaestros() async {
    Future<List<OpcionMaestra>> cargar(
      String nombre,
      Future<List<OpcionMaestra>> Function() solicitud,
    ) async {
      try {
        return await solicitud();
      } catch (e) {
        debugPrint('No se pudo cargar $nombre: $e');
        return [];
      }
    }

    final resultados = await Future.wait([
      cargar('clientes', PedidosService.getClientes),
      cargar('series', PedidosService.getSeries),
      cargar('comerciales', PedidosService.getComerciales),
      cargar('almacenes', PedidosService.getAlmacenes),
      cargar('formas de pago', PedidosService.getFormasPago),
    ]);
    if (!mounted) return;
    setState(() {
      _clientes = resultados[0];
      _series = resultados[1];
      _comerciales = resultados[2];
      _almacenes = resultados[3];
      _formasPago = resultados[4];
    });
  }

  /// _actualizar: aplica un cambio al pedido y avisa a la pantalla madre.
  /// "transform" es una función que recibe el pedido y devuelve la copia cambiada.
  Pedido _actualizar(Pedido Function(Pedido) transform) {
    final nuevo = transform(widget.pedido);
    widget.onChanged(nuevo); // Avisamos: "el pedido ahora es así".
    return nuevo;
  }

  Future<void> _cargarDatosCliente(int clienteId) async {
    if (clienteId <= 0) {
      setState(() {
        _direccionesCliente = [];
        _cargandoCliente = false;
      });
      return;
    }

    setState(() => _cargandoCliente = true);
    try {
      final defaults = await PedidosService.getClienteDefaults(clienteId);
      final direcciones = await PedidosService.getDireccionesCliente(clienteId);
      if (!mounted) return;

      setState(() {
        _direccionesCliente = direcciones;
        _cargandoCliente = false;
      });

      final serieDefault = defaults['serie'];
      if (serieDefault is String && serieDefault.isNotEmpty &&
          (widget.pedido.serie.isEmpty || !_series.any((s) => s.codigo == widget.pedido.serie))) {
        final serieOpcion = _series.firstWhere(
          (s) => s.codigo == serieDefault,
          orElse: () => OpcionMaestra(codigo: serieDefault, nombre: serieDefault),
        );
        widget.onChanged(widget.pedido.copyWith(
          serie: serieOpcion.codigo,
          serieNombre: serieOpcion.nombre,
        ));
      }

      final direccionDefault = defaults['direccion'];
      if (direccionDefault is String &&
          direccionDefault.isNotEmpty &&
          widget.pedido.direccionEnvio.isEmpty) {
        widget.onChanged(widget.pedido.copyWith(direccionEnvio: direccionDefault));
      }

      final emailDefault = defaults['email'];
      if (emailDefault is String &&
          emailDefault.isNotEmpty &&
          widget.pedido.email.isEmpty) {
        widget.onChanged(widget.pedido.copyWith(email: emailDefault));
      }

      final almacenDefault = defaults['almacen'];
      if (almacenDefault is String &&
          almacenDefault.isNotEmpty &&
          widget.pedido.almacen.isEmpty) {
        widget.onChanged(widget.pedido.copyWith(almacen: almacenDefault));
      }

      if (_direccionesCliente.length > 1 && widget.pedido.direccionEnvio.isEmpty) {
        final direccionElegida = _direccionesCliente.first;
        widget.onChanged(widget.pedido.copyWith(direccionEnvio: direccionElegida.codigo));
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _cargandoCliente = false);
    }
  }

  /// _elegir: abre el selector de una lista maestro y guarda la elección.
  Future<void> _elegir(
    String title, // Título de la ventana.
    List<OpcionMaestra> opciones, // Lista con la que elegir.
    void Function(OpcionMaestra) onSelected, // Qué hacer con la elegida.
  ) async {
    // Si la lista está vacía (sin permisos del API Key o sin configurar),
    // avisamos y salimos.
    if (opciones.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay opciones disponibles (permisos o configuración).'),
        ),
      );
      return;
    }
    // Abrimos el modal y esperamos la opción elegida.
    final seleccionado = await mostrarSelector(
      context,
      title: title,
      options: opciones,
      textOf: (o) => (o as OpcionMaestra).nombre, // Mostramos el nombre bonito.
    );
    if (seleccionado != null) onSelected(seleccionado);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.pedido; // Atajo: "p" = pedido actual.
    final currentUser = context.watch<AuthState>().currentUser;
    final esComercial = currentUser?.role.toLowerCase() == 'comercial';
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ================= DATOS GENERALES =================
        const _Seccion('Datos generales'),

        if (p.id != null) ...[
          // Velneo genera estos valores al crear el pedido.
          CampoForm(
            label: 'N° pedido',
            value: p.nPedido,
            enabled: false,
            placeholder: 'Se genera automáticamente',
          ),
          CampoForm(
            label: 'N° documento',
            value: p.nDocumento.toString(),
            enabled: false,
            placeholder: 'Número de documento',
          ),
        ],

        // Cliente (selector; obligatorio).
        CampoSelect(
          label: 'Cliente',
          value: p.clienteNombre.isNotEmpty ? p.clienteNombre : p.cliente,
          required: true, // Obligatorio.
          onTap: () => _elegir(
            'Seleccionar cliente',
            _clientes,
            (o) async {
              final clienteId = int.tryParse(o.codigo) ?? 0;
              final nuevoPedido = _actualizar(
                (x) => x.copyWith(
                  clienteId: clienteId,
                  cliente: o.codigo,
                  clienteNombre: o.nombre,
                ),
              );
              if (clienteId > 0) {
                await _cargarDatosCliente(clienteId);
                        if (mounted) {
                  widget.onChanged(
                    nuevoPedido.copyWith(
                      serie: widget.pedido.serie,
                      direccionEnvio: widget.pedido.direccionEnvio,
                      email: widget.pedido.email,
                      almacen: widget.pedido.almacen,
                    ),
                  );
                }
              }
            },
          ),
        ),
        if (_cargandoCliente)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              'Cargando datos del cliente...',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ),

        // Serie de ventas (selector).
        CampoSelect(
          label: 'Serie ventas',
          value: p.serieNombre.isNotEmpty ? p.serieNombre : p.serie,
          onTap: () => _elegir(
            'Seleccionar serie',
            _series,
            (o) => _actualizar(
              (x) => x.copyWith(serie: o.codigo, serieNombre: o.nombre),
            ),
          ),
        ),

        if (!esComercial)
          CampoSelect(
            label: 'Comercial',
            value: p.comercialNombre.isNotEmpty ? p.comercialNombre : p.comercial,
            onTap: () => _elegir(
              'Seleccionar comercial',
              _comerciales,
              (o) => _actualizar(
                (x) => x.copyWith(comercial: o.codigo, comercialNombre: o.nombre),
              ),
            ),
          ),

        // Almacén (selector).
        CampoSelect(
          label: 'Almacén',
          value: p.almacenNombre.isNotEmpty ? p.almacenNombre : p.almacen,
          onTap: () => _elegir(
            'Seleccionar almacén',
            _almacenes,
            (o) => _actualizar(
              (x) => x.copyWith(almacen: o.codigo, almacenNombre: o.nombre),
            ),
          ),
        ),

        // Fecha y entrega prevista, lado a lado.
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: CampoFecha(
                label: 'Fecha',
                value: p.fecha,
                required: true, // Obligatoria.
                onChanged: (v) => _actualizar((x) => x.copyWith(fecha: v)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: CampoFecha(
                label: 'Entregar el',
                value: p.previstoPara,
                onChanged: (v) => _actualizar((x) => x.copyWith(previstoPara: v)),
              ),
            ),
          ],
        ),

        // Forma de pago (selector).
        CampoSelect(
          label: 'Forma de pago',
          value: p.formaPagoNombre.isNotEmpty ? p.formaPagoNombre : p.formaPago,
          onTap: () => _elegir(
            'Seleccionar forma de pago',
            _formasPago,
            (o) => _actualizar(
              (x) => x.copyWith(formaPago: o.codigo, formaPagoNombre: o.nombre),
            ),
          ),
        ),

        // Estado (selector de los 3 estados fijos de venta).
        CampoSelect(
          label: 'Estado',
          value: AppColors.estadoLabel(p.estado), // Texto bonito ("Pendiente").
          onTap: () async {
            final seleccionado = await mostrarSelector(
              context,
              title: 'Seleccionar estado',
              options: _estados, // ['Pendiente', 'Servido', 'Cancelado']
              searchable: false, // Son pocos: sin buscador.
            );
            if (seleccionado != null) {
              // Guardamos el CÓDIGO VELNEO (P/S/C), que es lo que entiende el API.
              _actualizar((x) => x.copyWith(estado: AppColors.estadoCodigo(seleccionado)));
            }
          },
        ),

        // ================= ENVÍO =================
        const _Seccion('Envío'),

        // Dirección de envío (multilínea; se guarda como dir_env_man).
        CampoForm(
          label: 'Dirección de envío',
          value: p.direccionEnvio,
          onChanged: (v) => _actualizar((x) => x.copyWith(direccionEnvio: v)),
          placeholder: 'Dirección de entrega',
          multiline: true,
        ),

        // Email: Velneo lo devuelve, pero esta API no permite modificarlo.
        CampoForm(
          label: 'Email',
          value: p.email,
          placeholder: 'correo@empresa.com',
          keyboardType: TextInputType.emailAddress,
          enabled: false,
        ),

        // ================= OTROS =================
        const _Seccion('Otros'),

        // Observaciones (multilínea).
        CampoForm(
          label: 'Observaciones',
          value: p.observaciones,
          onChanged: (v) => _actualizar((x) => x.copyWith(observaciones: v)),
          placeholder: 'Notas del pedido',
          multiline: true,
        ),
      ],
    );
  }
}

/// _Seccion: título de sección en mayúsculas (igual que en cabecera_view).
class _Seccion extends StatelessWidget {
  final String texto;

  const _Seccion(this.texto);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 10),
      child: Text(
        texto.toUpperCase(),
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}