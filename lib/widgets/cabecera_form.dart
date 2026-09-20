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
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';

import '../api_service.dart'; // PedidosService (cargar clientes, series, etc.).
import '../core/master_cache_service.dart';
import '../core/search/entity_search_repository.dart'; // Repositorio local-first.
import '../models.dart'; // Pedido, OpcionMaestra.
import '../state/auth_state.dart';
import '../state/pedido_form_cubit.dart'; // selectCliente (valores por defecto).
import '../theme/app_theme.dart'; // Colores (para etiqueta de estado).
import 'autocomplete_field.dart'; // Buscador de cliente con autocompletado.
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
  // Nota: clientes y artículos NO se cargan completos; se buscan bajo demanda
  // a través del repositorio local-first (AutocompleteField).
  List<OpcionMaestra> _series = [];
  List<OpcionMaestra> _comerciales = [];
  List<OpcionMaestra> _almacenes = [];
  List<OpcionMaestra> _formasPago = [];
  bool _cargandoMaestros = true;

  @override
  void initState() {
    super.initState();
    _cargarMaestros(); // Al nacer, bajamos todas las listas.
    _cargarEmpresaDefaults();
  }

  Future<void> _cargarEmpresaDefaults() async {
    try {
      final currentUser = context.read<AuthState>().currentUser;
      final defaults = await PedidosService.getEmpresaDefaults(
        contactId: currentUser?.contactId,
      );
      if (!mounted) return;
      final almacenDefault = defaults['almacen'];
      if (almacenDefault is String &&
          almacenDefault.isNotEmpty &&
          widget.pedido.almacen.isEmpty) {
        final almacenOpcion = PedidosService.findMatchingOption(_almacenes, almacenDefault) ??
            OpcionMaestra(codigo: almacenDefault, nombre: almacenDefault);
        widget.onChanged(widget.pedido.copyWith(
          almacen: almacenOpcion.codigo,
          almacenNombre: almacenOpcion.nombre,
        ));
      }
    } catch (_) {
      // Silencio: si la empresa no expone ese valor, el usuario puede elegirlo.
    }
  }

  /// _cargarMaestros: usa caché por sesión para reutilizar las listas maestra.
  Future<void> _cargarMaestros() async {
    final cache = MasterCacheService();

    Future<List<OpcionMaestra>> cargar(
      String nombre,
      String cacheKey,
      Future<List<OpcionMaestra>> Function() solicitud,
    ) async {
      try {
        return await cache.getOrLoad<List<OpcionMaestra>>(
          key: cacheKey,
          loader: solicitud,
          ttl: const Duration(minutes: 10),
        );
      } catch (e) {
        debugPrint('No se pudo cargar $nombre: $e');
        return [];
      }
    }

    final resultados = await Future.wait([
      cargar('series', 'series', PedidosService.getSeries),
      cargar('comerciales', 'comerciales', PedidosService.getComerciales),
      cargar('almacenes', 'almacenes', PedidosService.getAlmacenes),
      cargar('formas de pago', 'formas_pago', PedidosService.getFormasPago),
    ]);
    if (!mounted) return;
    setState(() {
      _series = resultados[0];
      _comerciales = resultados[1];
      _almacenes = resultados[2];
      _formasPago = resultados[3];
      _cargandoMaestros = false;
    });
    await _cargarEmpresaDefaults();
  }

  /// _actualizar: aplica un cambio al pedido y avisa a la pantalla madre.
  /// "transform" es una función que recibe el pedido y devuelve la copia cambiada.
  Pedido _actualizar(Pedido Function(Pedido) transform) {
    final nuevo = transform(widget.pedido);
    widget.onChanged(nuevo); // Avisamos: "el pedido ahora es así".
    return nuevo;
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

        // Cliente (buscador con autocompletado; obligatorio).
        // Se consulta a Velneo bajo demanda (debounce 400 ms, mín. 3 letras)
        // y se apoya en la caché local para devolver resultados al instante.
        // Al elegir, el PedidoFormCubit aplica los valores por defecto del
        // cliente (almacén central '1', forma de pago y serie).
        AutocompleteField(
          label: 'Cliente',
          required: true,
          minChars: 3,
          debounce: const Duration(milliseconds: 400),
          maxResults: 20,
          initialValue: p.clienteNombre.isNotEmpty ? p.clienteNombre : p.cliente,
          hint: 'Buscar por nombre o código...',
          search: (query) => context
              .read<EntitySearchRepository>()
              .search(EntityKind.cliente, query, limit: 20),
          onSelected: (cliente) {
            context.read<PedidoFormCubit>().selectCliente(
                  cliente,
                  series: _series,
                  formasPago: _formasPago,
                  almacenes: _almacenes,
                );
          },
          onCleared: () {
            context.read<PedidoFormCubit>().clearCliente();
          },
        ),
        if (context.watch<PedidoFormCubit>().state.cargandoDatosCliente)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              'Aplicando datos del cliente...',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ),

        // Serie de ventas (selector).
        CampoSelect(
          label: 'Serie ventas',
          value: p.serieNombre.isNotEmpty ? p.serieNombre : p.serie,
          enabled: !_cargandoMaestros,
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
            enabled: !_cargandoMaestros,
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
          enabled: !_cargandoMaestros,
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
          enabled: !_cargandoMaestros,
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
          enabled: !_cargandoMaestros,
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

        // Dirección de envío: siempre se muestra como selector. Las
        // direcciones del cliente elegido viven en el PedidoFormCubit.
        Builder(builder: (context) {
          final direcciones = context.watch<PedidoFormCubit>().state.direccionesCliente;
          return CampoSelect(
            label: 'Dirección de envío',
            value: direcciones.any((d) => d.codigo == p.direccionEnvio)
                ? direcciones
                    .firstWhere((d) => d.codigo == p.direccionEnvio)
                    .nombre
                : p.direccionEnvio,
            enabled: !_cargandoMaestros,
            onTap: () => _elegir(
              'Seleccionar dirección de envío',
              direcciones,
              (o) => context.read<PedidoFormCubit>().selectDireccion(o),
            ),
          );
        }),

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