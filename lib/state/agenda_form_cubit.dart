// ============================================================================
//  agenda_form_cubit.dart  —  ESTADO Y LÓGICA DEL FORMULARIO DE AGENDA
// ============================================================================

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../core/crm_repository.dart';
import '../models/models.dart';

part 'agenda_form_cubit.freezed.dart';

/// Estado del formulario de la visita de agenda.
@freezed
abstract class AgendaFormState with _$AgendaFormState {
  const factory AgendaFormState({
    required VisitaAgenda visita,
    @Default(<OpcionMaestra>[]) List<OpcionMaestra> campanas,
    @Default(<OpcionMaestra>[]) List<OpcionMaestra> tiposVisita,
  }) = _AgendaFormState;
}

/// Lógica del formulario de agenda: muta la `VisitaAgenda` vía copyWith.
class AgendaFormCubit extends Cubit<AgendaFormState> {
  AgendaFormCubit({
    CrmRepository? crm,
    VisitaAgenda? visita,
  })  : _crm = crm ?? CrmRepository(),
        super(AgendaFormState(visita: visita ?? const VisitaAgenda()));

  final CrmRepository _crm;

  /// Reemplaza la visita (edición / carga inicial).
  void init(VisitaAgenda visita) => emit(state.copyWith(visita: visita));

  /// Inicializa una visita vacía para una visita nueva, asignando el comercial
  /// logueado e inyectando los campos multi-empresa obligatorios en "1".
  void initNewVisita(String comercialLogueadoId) {
    emit(state.copyWith(
      visita: VisitaAgenda(
        comercialId: comercialLogueadoId,
        emp: '1',
        empDiv: '1',
      ),
    ));
  }

  /// Búsqueda remota de campañas (índice `PARTS` de Velneo).
  Future<List<OpcionMaestra>> buscarCampanas(String query) =>
      _crm.searchCampanas(query);

  /// Búsqueda remota de tipos de visita (índice `PARTS` de Velneo).
  Future<List<OpcionMaestra>> buscarTiposVisita(String query) =>
      _crm.searchTiposVisita(query);

  /// Direcciones del cliente para el selector (muestra `DIR_COM`).
  Future<List<OpcionMaestra>> getDireccionesCliente(String clienteId) =>
      _crm.getDireccionesCliente(clienteId);

  Future<void> cargarMaestros() async {
    final resultados = await Future.wait([
      _cargarLista(_crm.getCampanas),
      _cargarLista(_crm.getTiposVisita),
    ]);
    if (isClosed) return;
    emit(state.copyWith(
      campanas: resultados[0],
      tiposVisita: resultados[1],
    ));
  }

  Future<List<OpcionMaestra>> _cargarLista(
    Future<List<OpcionMaestra>> Function() loader,
  ) async {
    try {
      return await loader();
    } catch (_) {
      return const [];
    }
  }

  /// Alterna "todo el día". Si se activa, se limpian hora de inicio,
  /// fecha de fin y hora de fin.
  void toggleTodoElDia(bool value) {
    emit(state.copyWith(
      visita: value
          ? state.visita.copyWith(
              todoElDia: true,
              horaInicio: null,
              fechaFin: null,
              horaFin: null,
            )
          : state.visita.copyWith(todoElDia: false),
    ));
  }

  /// Alterna el campo `cerrar` (NO_GEN_PRO_VIS).
  void toggleCerrar(bool value) {
    emit(state.copyWith(visita: state.visita.copyWith(cerrar: value)));
  }

  /// Actualiza genéricamente un campo de la visita (maestros: cliente,
  /// campaña, tipo de visita, dirección, asunto, descripción, fechas, horas...).
  void updateField(String name, dynamic value) {
    final visita = state.visita;
    final stringValue = (value ?? '').toString();
    final trimmed = stringValue.isNotEmpty ? stringValue : null;
    final newVisita = switch (name) {
      'clienteId' => visita.copyWith(clienteId: stringValue),
      'campanaId' => visita.copyWith(campanaId: stringValue),
      'tipoVisitaId' => visita.copyWith(tipoVisitaId: stringValue),
      'direccionId' => visita.copyWith(direccionId: stringValue),
      'asunto' => visita.copyWith(asunto: stringValue),
      'descripcion' => visita.copyWith(descripcion: trimmed),
      'fechaInicio' => visita.copyWith(fechaInicio: stringValue),
      'horaInicio' => visita.copyWith(horaInicio: trimmed),
      'fechaFin' => visita.copyWith(fechaFin: trimmed),
      'horaFin' => visita.copyWith(horaFin: trimmed),
      'presupuestoId' => visita.copyWith(presupuestoId: trimmed),
      'fechaProximaVisita' => visita.copyWith(fechaProximaVisita: trimmed),
      'horaProximaVisita' => visita.copyWith(horaProximaVisita: trimmed),
      _ => visita,
    };
    emit(state.copyWith(visita: newVisita));
  }
}
