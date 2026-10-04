// ============================================================================
//  agenda_list_cubit.dart  —  LISTA DE VISITAS DE AGENDA (CALENDARIO)
// ============================================================================

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../core/api_client.dart';
import '../core/crm_repository.dart';
import '../models/visita_agenda.dart';

part 'agenda_list_cubit.freezed.dart';

/// Estado de la lista de visitas mostrada en el calendario.
@freezed
abstract class AgendaListState with _$AgendaListState {
  const factory AgendaListState({
    @Default(<VisitaAgenda>[]) List<VisitaAgenda> visitas,
    @Default(false) bool cargando,
    String? error,
  }) = _AgendaListState;
}

/// Carga y filtra las visitas de `CRM_AGE` por día.
class AgendaListCubit extends Cubit<AgendaListState> {
  AgendaListCubit(this._crm) : super(const AgendaListState());

  final CrmRepository _crm;

  /// Descarga las visitas del comercial desde Velneo.
  Future<void> loadVisitas(String comercialId) async {
    emit(state.copyWith(cargando: true, error: null));
    try {
      final visitas = await _crm.getVisitasAgenda(comercialId);
      emit(AgendaListState(visitas: visitas));
    } catch (e) {
      final mensaje = e is ApiException ? e.message : '$e';
      emit(state.copyWith(cargando: false, error: mensaje));
    }
  }

  /// Visitas cuyo `fechaInicio` cae en [dia] (compara año/mes/día, sin hora).
  List<VisitaAgenda> getVisitasParaDia(DateTime dia) {
    return state.visitas.where((visita) {
      final fecha = _parseFecha(visita.fechaInicio);
      if (fecha == null) return false;
      return fecha.year == dia.year &&
          fecha.month == dia.month &&
          fecha.day == dia.day;
    }).toList();
  }

  DateTime? _parseFecha(String raw) {
    if (raw.isEmpty) return null;
    return DateTime.tryParse(raw.contains('T') ? raw : '${raw}T00:00:00');
  }
}
