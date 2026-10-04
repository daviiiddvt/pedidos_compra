import 'package:freezed_annotation/freezed_annotation.dart';

part 'visita_agenda.freezed.dart';
part 'visita_agenda.g.dart';

/// Visita de la agenda (tabla `CRM_AGE` en Velneo).
@freezed
abstract class VisitaAgenda with _$VisitaAgenda {
  const VisitaAgenda._();

  const factory VisitaAgenda({
    @JsonKey(name: 'ID') int? id,
    @JsonKey(name: 'CLI') @Default('') String clienteId,
    @JsonKey(includeFromJson: false, includeToJson: false) @Default('') String clienteNombre,
    @JsonKey(name: 'CRM_CAM_COM') @Default('') String campanaId,
    @JsonKey(includeFromJson: false, includeToJson: false) @Default('') String campanaNombre,
    @JsonKey(name: 'TIP_VIS') @Default('') String tipoVisitaId,
    @JsonKey(includeFromJson: false, includeToJson: false) @Default('') String tipoVisitaNombre,
    @JsonKey(name: 'COM') @Default('') String comercialId,
    @JsonKey(includeFromJson: false, includeToJson: false) @Default('') String comercialNombre,
    @JsonKey(name: 'DIR_M') @Default('') String direccionId,
    @JsonKey(includeFromJson: false, includeToJson: false) @Default('') String direccionNombre,
    @JsonKey(name: 'ASU') @Default('') String asunto,
    @JsonKey(name: 'TOD_DIA') @Default(false) bool todoElDia,
    @JsonKey(name: 'FCH_INI') @Default('') String fechaInicio,
    @JsonKey(name: 'HOR_INI') String? horaInicio,
    @JsonKey(name: 'FCH_FIN') String? fechaFin,
    @JsonKey(name: 'HOR_FIN') String? horaFin,
    @JsonKey(name: 'VTA_PRE_G') String? presupuestoId,
    @JsonKey(name: 'FCH_PRO_VIS') String? fechaProximaVisita,
    @JsonKey(name: 'HOR_PRO_VIS') String? horaProximaVisita,
    @JsonKey(name: 'NO_GEN_PRO_VIS') @Default(false) bool cerrar,
    @JsonKey(name: 'DSC') String? descripcion,
    @JsonKey(name: 'emp') @Default('1') String emp,
    @JsonKey(name: 'emp_div') @Default('1') String empDiv,
  }) = _VisitaAgenda;

  factory VisitaAgenda.fromJson(Map<String, dynamic> json) =>
      _$VisitaAgendaFromJson(json);
}