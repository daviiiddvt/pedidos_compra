// ============================================================================
//  agenda_form_modal.dart  —  FORMULARIO VISUAL DE UNA VISITA DE AGENDA
// ============================================================================
//
//  Diálogo de escritorio: selectores, fechas/horas, próxima visita y
//  botonera (Eliminar / Aceptar / Enviar / Cancelar).
//
//  El comercial NO se pinta: AgendaFormCubit lo inyecta en el modelo.
//  Los cambios de campo van a AgendaFormCubit.updateField / toggle*.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/crm_repository.dart';
import '../core/search/entity_search_repository.dart';
import '../models/models.dart';
import '../state/agenda_form_cubit.dart';
import '../theme/app_theme.dart';
import 'autocomplete_field.dart';
import 'campo_fecha.dart';
import 'campo_form.dart';
import 'modal_selector.dart';

/// Resultado al cerrar el formulario de agenda.
class AgendaFormResult {
  final AgendaFormAccion accion;
  final VisitaAgenda visita;

  const AgendaFormResult({required this.accion, required this.visita});
}

enum AgendaFormAccion { aceptar, enviar, eliminar, cancelar }

/// Abre el formulario de agenda como diálogo (layout de escritorio).
///
/// Si no se pasa [cubit], se crea uno con [visita] (o una visita vacía).
Future<AgendaFormResult?> mostrarAgendaForm(
  BuildContext context, {
  VisitaAgenda? visita,
  AgendaFormCubit? cubit,
}) {
  return showDialog<AgendaFormResult>(
    context: context,
    barrierDismissible: false,
    builder: (_) {
      final dialog = const AgendaFormModal();
      if (cubit != null) {
        return BlocProvider.value(value: cubit, child: dialog);
      }
      return BlocProvider(
        create: (ctx) => AgendaFormCubit(
          visita: visita,
          crm: ctx.read<CrmRepository>(),
        ),
        child: dialog,
      );
    },
  );
}

/// Formulario de visita de agenda. Requiere un [AgendaFormCubit] en el árbol.
class AgendaFormModal extends StatefulWidget {
  const AgendaFormModal({super.key});

  @override
  State<AgendaFormModal> createState() => _AgendaFormModalState();
}

class _AgendaFormModalState extends State<AgendaFormModal> {
  static const _gap = SizedBox(width: 10, height: 4);

  String _campanaNombre = '';
  String _tipoVisitaNombre = '';
  String _clienteNombre = '';
  String _direccionNombre = '';
  List<OpcionMaestra> _direcciones = const [];
  bool _cargandoDirecciones = false;

  @override
  void initState() {
    super.initState();
    final visita = context.read<AgendaFormCubit>().state.visita;
    _campanaNombre = visita.campanaNombre.isNotEmpty ? visita.campanaNombre : visita.campanaId;
    _tipoVisitaNombre = visita.tipoVisitaNombre.isNotEmpty ? visita.tipoVisitaNombre : visita.tipoVisitaId;
    _clienteNombre = visita.clienteNombre.isNotEmpty ? visita.clienteNombre : visita.clienteId;
    _direccionNombre = visita.direccionId; // The async resolver handles this correctly
    _cubit.cargarMaestros();
    if (visita.clienteId.isNotEmpty) {
      _cargarDirecciones(visita.clienteId);
    }
  }

  String _nombreOpcion(List<OpcionMaestra> opciones, String codigo, String actual) {
    if (codigo.isEmpty) return actual;
    for (final opcion in opciones) {
      if (opcion.codigo == codigo) return opcion.nombre;
    }
    return actual.isNotEmpty ? actual : codigo;
  }

  AgendaFormCubit get _cubit => context.read<AgendaFormCubit>();

  void _update(String campo, dynamic valor) => _cubit.updateField(campo, valor);

  Future<void> _cargarDirecciones(String clienteId) async {
    if (clienteId.trim().isEmpty) {
      setState(() {
        _direcciones = const [];
        _cargandoDirecciones = false;
      });
      return;
    }
    setState(() => _cargandoDirecciones = true);
    try {
      final lista = await _cubit.getDireccionesCliente(clienteId);
      if (!mounted) return;
      setState(() {
        _direcciones = lista;
        _cargandoDirecciones = false;
        if (lista.any((d) => d.codigo == _cubit.state.visita.direccionId)) {
          _direccionNombre =
              lista.firstWhere((d) => d.codigo == _cubit.state.visita.direccionId).nombre;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _direcciones = const [];
        _cargandoDirecciones = false;
      });
    }
  }

  Future<void> _elegirMaestro({
    required String titulo,
    required List<OpcionMaestra> opciones,
    required void Function(OpcionMaestra) onSelected,
  }) async {
    if (opciones.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay opciones disponibles (permisos o configuración).'),
        ),
      );
      return;
    }
    final seleccionado = await mostrarSelector(
      context,
      title: titulo,
      options: opciones,
      textOf: (o) => (o as OpcionMaestra).nombre,
    );
    if (seleccionado != null) onSelected(seleccionado);
  }

  void _cerrar(AgendaFormAccion accion) {
    Navigator.of(context).pop(
      AgendaFormResult(accion: accion, visita: _cubit.state.visita),
    );
  }

  Future<void> _confirmarEliminar() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar visita'),
        content: const Text('¿Seguro que quieres eliminar esta visita de la agenda?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sí, eliminar'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) _cerrar(AgendaFormAccion.eliminar);
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.viewInsetsOf(context);
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1080, maxHeight: 820),
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + viewInsets.bottom),
          child: BlocConsumer<AgendaFormCubit, AgendaFormState>(
            listenWhen: (prev, next) =>
                prev.campanas != next.campanas ||
                prev.tiposVisita != next.tiposVisita,
            listener: (context, state) {
              setState(() {
                _campanaNombre = _nombreOpcion(
                  state.campanas,
                  state.visita.campanaId,
                  _campanaNombre,
                );
                _tipoVisitaNombre = _nombreOpcion(
                  state.tiposVisita,
                  state.visita.tipoVisitaId,
                  _tipoVisitaNombre,
                );
              });
            },
            builder: (context, state) {
              final visita = state.visita;
              final todoElDia = visita.todoElDia;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    visita.id == null ? 'Nueva visita' : 'Editar visita',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _fila([
                            CampoSelect(
                              label: 'Campaña Comercial',
                              value: _campanaNombre.isNotEmpty ? _campanaNombre : visita.campanaId,
                              placeholder: 'Seleccionar campaña...',
                              onTap: () => _elegirMaestro(
                                titulo: 'Seleccionar campaña',
                                opciones: _cubit.state.campanas,
                                onSelected: (o) {
                                  setState(() => _campanaNombre = o.nombre);
                                  _update('campanaId', o.codigo);
                                },
                              ),
                            ),
                            CampoSelect(
                              label: 'Tipo de Visita',
                              value: _tipoVisitaNombre.isNotEmpty ? _tipoVisitaNombre : visita.tipoVisitaId,
                              placeholder: 'Seleccionar tipo...',
                              onTap: () => _elegirMaestro(
                                titulo: 'Seleccionar tipo de visita',
                                opciones: _cubit.state.tiposVisita,
                                onSelected: (o) {
                                  setState(() => _tipoVisitaNombre = o.nombre);
                                  _update('tipoVisitaId', o.codigo);
                                },
                              ),
                            ),
                          ]),
                          _fila([
                            AutocompleteField(
                              label: 'Cliente',
                              required: true,
                              minChars: 3,
                              debounce: const Duration(milliseconds: 400),
                              maxResults: 20,
                              initialValue: _clienteNombre,
                              hint: 'Buscar por nombre o código...',
                              search: (query) => context
                                  .read<EntitySearchRepository>()
                                  .search(EntityKind.cliente, query, limit: 20),
                              onSelected: (cliente) {
                                setState(() {
                                  _clienteNombre = cliente.nombre;
                                  _direccionNombre = '';
                                  _direcciones = const [];
                                });
                                _update('clienteId', cliente.codigo);
                                _update('direccionId', '');
                                _cargarDirecciones(cliente.codigo);
                              },
                              onCleared: () {
                                setState(() {
                                  _clienteNombre = '';
                                  _direccionNombre = '';
                                  _direcciones = const [];
                                });
                                _update('clienteId', '');
                                _update('direccionId', '');
                              },
                            ),
                            CampoSelect(
                              label: 'Dirección completa',
                              value: _direccionNombre.isNotEmpty
                                  ? _direccionNombre
                                  : visita.direccionId,
                              enabled: !_cargandoDirecciones &&
                                  visita.clienteId.isNotEmpty,
                              placeholder: visita.clienteId.isEmpty
                                  ? 'Elige primero un cliente'
                                  : 'Seleccionar dirección...',
                              onTap: () => _elegirMaestro(
                                titulo: 'Seleccionar dirección',
                                opciones: _direcciones,
                                onSelected: (o) {
                                  setState(() => _direccionNombre = o.nombre);
                                  _update('direccionId', o.codigo);
                                },
                              ),
                            ),
                          ]),
                          CampoForm(
                            label: 'Asunto',
                            value: visita.asunto,
                            placeholder: 'Asunto de la visita',
                            onChanged: (v) => _update('asunto', v),
                          ),
                          const SizedBox(height: 12),
                          _fila([
                            _CheckboxAgenda(
                              label: 'Todo el Día',
                              value: todoElDia,
                              onChanged: (v) => _cubit.toggleTodoElDia(v),
                            ),
                            CampoFecha(
                              label: 'Fecha Inicio',
                              value: visita.fechaInicio,
                              required: true,
                              onChanged: (v) => _update('fechaInicio', v),
                            ),
                            _CampoHora(
                              label: 'Hora Inicio',
                              value: visita.horaInicio,
                              enabled: !todoElDia,
                              onChanged: (v) => _update('horaInicio', v),
                            ),
                            CampoFecha(
                              label: 'Fecha Fin',
                              value: visita.fechaFin,
                              enabled: !todoElDia,
                              onChanged: (v) => _update('fechaFin', v),
                            ),
                            _CampoHora(
                              label: 'Hora Fin',
                              value: visita.horaFin,
                              enabled: !todoElDia,
                              onChanged: (v) => _update('horaFin', v),
                            ),
                          ]),
                          const SizedBox(height: 8),
                          const _SeccionAgenda('Próxima visita'),
                          _fila([
                            CampoFecha(
                              label: 'Fecha Próxima Visita',
                              value: visita.fechaProximaVisita,
                              onChanged: (v) => _update('fechaProximaVisita', v),
                            ),
                            _CampoHora(
                              label: 'Hora Próxima Visita',
                              value: visita.horaProximaVisita,
                              onChanged: (v) => _update('horaProximaVisita', v),
                            ),
                            _CheckboxAgenda(
                              label: 'Cerrar',
                              value: visita.cerrar,
                              onChanged: (v) => _cubit.toggleCerrar(v),
                            ),
                          ]),
                          const SizedBox(height: 8),
                          const _SeccionAgenda('Presupuesto'),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: CampoForm(
                                  label: 'Nº Presupuesto',
                                  value: visita.presupuestoId ?? '',
                                  placeholder: 'Número de presupuesto',
                                  onChanged: (v) => _update('presupuestoId', v),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Padding(
                                padding: const EdgeInsets.only(top: 22),
                                child: IconButton(
                                  tooltip: 'Crear presupuesto',
                                  icon: const Icon(Icons.add),
                                  color: AppColors.primary,
                                  onPressed: () {
                                    // TODO: Navegar a crear presupuesto
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          CampoForm(
                            label: 'Descripción',
                            value: visita.descripcion ?? '',
                            placeholder: 'Notas de la visita',
                            multiline: true,
                            onChanged: (v) => _update('descripcion', v),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _BotoneraAgenda(
                    onEliminar: _confirmarEliminar,
                    onAceptar: () => _cerrar(AgendaFormAccion.aceptar),
                    onEnviar: () => _cerrar(AgendaFormAccion.enviar),
                    onCancelar: () => Navigator.of(context).pop(),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _fila(List<Widget> hijos) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < hijos.length; i++) ...[
            if (i > 0) _gap,
            Expanded(child: hijos[i]),
          ],
        ],
      ),
    );
  }
}

class _SeccionAgenda extends StatelessWidget {
  final String texto;
  const _SeccionAgenda(this.texto);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 10),
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

class _CheckboxAgenda extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _CheckboxAgenda({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(8),
        child: Row(
          children: [
            Checkbox(
              value: value,
              onChanged: (v) => onChanged(v ?? false),
            ),
            Flexible(
              child: Text(
                label,
                style: const TextStyle(fontSize: 14, color: AppColors.text),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Campo de hora con [showTimePicker]. Valor persistido como `HH:mm`.
class _CampoHora extends StatelessWidget {
  final String label;
  final String? value;
  final ValueChanged<String> onChanged;
  final bool enabled;

  const _CampoHora({
    required this.label,
    this.value,
    required this.onChanged,
    this.enabled = true,
  });

  TimeOfDay? _parse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final parts = raw.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h.clamp(0, 23), minute: m.clamp(0, 59));
  }

  String _format(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  String _textoVisible() {
    final parsed = _parse(value);
    if (parsed == null) return 'Seleccionar hora';
    return _format(parsed);
  }

  Future<void> _seleccionar(BuildContext context) async {
    if (!enabled) return;
    final picked = await showTimePicker(
      context: context,
      initialTime: _parse(value) ?? TimeOfDay.now(),
    );
    if (picked != null) onChanged(_format(picked));
  }

  @override
  Widget build(BuildContext context) {
    final hayValor = value != null && value!.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: enabled ? () => _seleccionar(context) : null,
          borderRadius: BorderRadius.circular(10),
          child: InputDecorator(
            decoration: InputDecoration(enabled: enabled),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _textoVisible(),
                    style: TextStyle(
                      fontSize: 15,
                      color: !enabled
                          ? AppColors.disabled
                          : (hayValor ? AppColors.text : AppColors.disabled),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  Icons.schedule_outlined,
                  size: 18,
                  color: enabled ? AppColors.textSecondary : AppColors.disabled,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _BotoneraAgenda extends StatelessWidget {
  final VoidCallback onEliminar;
  final VoidCallback onAceptar;
  final VoidCallback onEnviar;
  final VoidCallback onCancelar;

  const _BotoneraAgenda({
    required this.onEliminar,
    required this.onAceptar,
    required this.onEnviar,
    required this.onCancelar,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        OutlinedButton.icon(
          onPressed: onEliminar,
          icon: const Icon(Icons.delete_outline, size: 18),
          label: const Text('ELIMINAR'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.error,
            side: const BorderSide(color: AppColors.error),
          ),
        ),
        const Spacer(),
        OutlinedButton(
          onPressed: onAceptar,
          child: const Text('ACEPTAR'),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: onEnviar,
          child: const Text('ENVIAR'),
        ),
        const SizedBox(width: 8),
        OutlinedButton(
          onPressed: onCancelar,
          child: const Text('CANCELAR'),
        ),
      ],
    );
  }
}
