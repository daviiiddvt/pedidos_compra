// ============================================================================
//  cabecera_view.dart  —  VISTA DE LA CABECERA DEL PEDIDO (SOLO LECTURA)
// ============================================================================
//
//  ¿Qué es?
//  --------
//  La pestaña "Cabecera" del DETALLE del pedido. Muestra TODOS los datos
//  generales en forma de lista: proveedor, serie, fechas, envío, etc.
//  Es de solo lectura (no se puede editar aquí; para eso está cabecera_form).
//
//  CONCEPTO:
//  - _Campo : mini-widget "etiqueta gris + valor" (privado a este archivo).
//  - _Seccion: el título de una sección ("DATOS GENERALES", "ENVÍO...").
// ============================================================================

import 'package:flutter/material.dart';

import '../core/api_service.dart';
import '../core/master_cache_service.dart';
import '../core/offline/offline_database.dart';
import '../models/models.dart'; // Pedido + calcularTotales.
 // Colores.
import '../core/formatters.dart'; // formatDate y formatNumber.
import 'estado_badge.dart'; // Píldora del estado.

/// CabeceraView: lista de datos generales del pedido (solo lectura).
class CabeceraView extends StatefulWidget {
  final Pedido pedido; // El pedido cuyos datos mostrar.
  final bool mostrarAlmacen;
  final bool mostrarFechaEntrega;
  final bool mostrarEmail;
  final bool mostrarFechaValidez;
  final bool mostrarNumeroPresupuesto;

  const CabeceraView({
    super.key,
    required this.pedido,
    this.mostrarAlmacen = true,
    this.mostrarFechaEntrega = true,
    this.mostrarEmail = false,
    this.mostrarFechaValidez = false,
    this.mostrarNumeroPresupuesto = false,
  });

  @override
  State<CabeceraView> createState() => _CabeceraViewState();
}

class _CabeceraViewState extends State<CabeceraView> {
  String _serieNombre = '';
  String _almacenNombre = '';
  String _formaPagoNombre = '';
  String _comercialNombre = '';
  String _direccionEnvioNombre = '';

  @override
  void initState() {
    super.initState();
    final cache = MasterCacheService();
    final cachedSeries = cache.getSync<List<OpcionMaestra>>('series');
    final cachedFpg = cache.getSync<List<OpcionMaestra>>('formas_pago');
    final cachedAlm = cache.getSync<List<OpcionMaestra>>('almacenes');

    final s = PedidosService.findMatchingOption(cachedSeries ?? [], widget.pedido.serie);
    final f = PedidosService.findMatchingOption(cachedFpg ?? [], widget.pedido.formaPago);
    final a = PedidosService.findMatchingOption(cachedAlm ?? [], widget.pedido.almacen);

    _serieNombre = s?.nombre ?? widget.pedido.serieNombre;
    _formaPagoNombre = f?.nombre ?? widget.pedido.formaPagoNombre;
    _almacenNombre = a?.nombre ?? widget.pedido.almacenNombre;
    _comercialNombre = widget.pedido.comercialNombre;
    if (_comercialNombre.isEmpty && widget.pedido.comercial.isNotEmpty) {
      OfflineDatabase.instance.getNombreComercialOffline(widget.pedido.comercial).then((nom) {
        if (mounted && nom.isNotEmpty) {
          setState(() => _comercialNombre = nom);
        }
      });
    }

    _direccionEnvioNombre = widget.pedido.direccionEnvio;
    if (_direccionEnvioNombre.isNotEmpty && int.tryParse(_direccionEnvioNombre) != null) {
      OfflineDatabase.instance.getNombreMaestroOffline('DIR_M', _direccionEnvioNombre).then((nom) {
        if (mounted && nom.isNotEmpty) {
          setState(() => _direccionEnvioNombre = nom);
        }
      });
    }

    _loadMaestros();
  }

  Future<void> _loadMaestros() async {
    final cache = MasterCacheService();
    try {
      final reqs = await Future.wait([
        cache.getOrLoad(key: 'series', loader: PedidosService.getSeries, ttl: const Duration(minutes: 10)),
        if (widget.mostrarAlmacen)
          cache.getOrLoad(key: 'almacenes', loader: PedidosService.getAlmacenes, ttl: const Duration(minutes: 10))
        else
          Future.value(<OpcionMaestra>[]),
        cache.getOrLoad(key: 'formas_pago', loader: PedidosService.getFormasPago, ttl: const Duration(minutes: 10)),
        PedidosService.getDireccionesCliente(widget.pedido.clienteId),
        if (_comercialNombre.isEmpty && widget.pedido.comercial.isNotEmpty)
          PedidosService.getContactName(widget.pedido.comercial)
        else
          Future.value(_comercialNombre),
      ]);

      if (!mounted) return;

      final series = reqs[0] as List<OpcionMaestra>;
      final almacenes = reqs[1] as List<OpcionMaestra>;
      final formasPago = reqs[2] as List<OpcionMaestra>;
      final direcciones = reqs[3] as List<OpcionMaestra>;
      final cmrNombre = reqs[4] as String;

      final s = PedidosService.findMatchingOption(series, widget.pedido.serie);
      final a = PedidosService.findMatchingOption(almacenes, widget.pedido.almacen);
      final f = PedidosService.findMatchingOption(formasPago, widget.pedido.formaPago);
      final d = PedidosService.findMatchingOption(direcciones, widget.pedido.direccionEnvio);

      var dirNombre = d?.nombre;
      if (dirNombre == null || dirNombre.isEmpty) {
        if (widget.pedido.direccionEnvio.isNotEmpty && int.tryParse(widget.pedido.direccionEnvio) != null) {
          final res = await PedidosService.getDireccionNombre(widget.pedido.direccionEnvio);
          if (res.isNotEmpty && res != widget.pedido.direccionEnvio) {
            dirNombre = res;
          }
        }
      }

      setState(() {
        if (s != null) _serieNombre = s.nombre;
        if (a != null) _almacenNombre = a.nombre;
        if (f != null) _formaPagoNombre = f.nombre;
        if (dirNombre != null && dirNombre.isNotEmpty) _direccionEnvioNombre = dirNombre;
        if (cmrNombre.isNotEmpty) _comercialNombre = cmrNombre;
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final pedido = widget.pedido;
    // Total del pedido: si tiene líneas las suma; si no, usamos el total de
    // la cabecera que manda el servidor (tot_ped).
    final total = pedido.lineas.isNotEmpty
        ? calcularTotales(pedido.lineas).total
        : pedido.total;

    return ListView(
      // Toda la información en scroll vertical.
      padding: const EdgeInsets.all(16),
      children: [
        // ---- Fila superior: código (si lo hay) + estado ----
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (pedido.codigo != 0)
              Text(
                'Código: ${pedido.codigo}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            if (pedido.codigo != 0) const SizedBox(height: 8),
            EstadoBadge(estado: pedido.estado),
          ],
        ),

        // ---- Sección 1: DATOS GENERALES ----
        const _Seccion('Datos generales'),
        
        _Campo(
          'Cliente',
          pedido.clienteNombre.isNotEmpty
              ? pedido.clienteNombre
              : pedido.cliente,
        ),
        _Campo(
          'Serie ventas',
          _serieNombre.isNotEmpty ? _serieNombre : pedido.serie,
        ),
        _Campo(
          'Comercial',
          _comercialNombre.isNotEmpty
              ? _comercialNombre
              : (pedido.comercialNombre.isNotEmpty
                  ? pedido.comercialNombre
                  : pedido.comercial),
        ),
        if (widget.mostrarAlmacen)
          _Campo(
            'Almacén',
            _almacenNombre.isNotEmpty
                ? _almacenNombre
                : pedido.almacen,
          ),
        _Campo('Fecha', formatDate(pedido.fecha)), // Formato "10/09/2026".
        if (widget.mostrarFechaValidez)
          _Campo('Válida hasta', formatDate(pedido.fechaValidez)),
        if (widget.mostrarFechaEntrega)
          _Campo('Entregar el', formatDate(pedido.previstoPara)),
        _Campo(
          'Forma de pago',
          _formaPagoNombre.isNotEmpty
              ? _formaPagoNombre
              : pedido.formaPago,
        ),

        // ---- Sección 2: ENVÍO ----
        const _Seccion('Envío'),
        _Campo('Dirección de envío', _direccionEnvioNombre.isNotEmpty ? _direccionEnvioNombre : pedido.direccionEnvio),
        if (widget.mostrarEmail) _Campo('Email', pedido.email),

        // ---- Sección 3: OTROS ----
        const _Seccion('Otros'),
        _Campo('Observaciones', pedido.observaciones),
        const SizedBox(height: 8),

        // ---- Total al final ----
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              widget.mostrarNumeroPresupuesto ? 'Total presupuesto' : 'Total pedido',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              '${formatNumber(total)} €',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// _Campo: "etiqueta gris pequeña + valor grande" (privado a este archivo).
class _Campo extends StatelessWidget {
  final String label; // "Proveedor"
  final String? valor; // "Ferretería SL" (si está vacío, se muestra "—").

  const _Campo(this.label, this.valor);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            (valor == null || valor!.isEmpty)
                ? '—'
                : valor!, // Guion si está vacío.
            style: TextStyle(
              fontSize: 15,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

/// _Seccion: título de una sección (en MAYÚSCULAS y en azul).
class _Seccion extends StatelessWidget {
  final String texto;

  const _Seccion(this.texto);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 12),
      child: Text(
        texto.toUpperCase(), // Lo ponemos todo en mayúsculas.
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 0.5, // Un pelín de espacio entre letras.
        ),
      ),
    );
  }
}
