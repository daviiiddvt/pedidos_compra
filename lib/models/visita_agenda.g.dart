// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'visita_agenda.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_VisitaAgenda _$VisitaAgendaFromJson(Map<String, dynamic> json) =>
    _VisitaAgenda(
      id: (json['ID'] as num?)?.toInt(),
      clienteId: json['CLI'] as String? ?? '',
      campanaId: json['CRM_CAM_COM'] as String? ?? '',
      tipoVisitaId: json['TIP_VIS'] as String? ?? '',
      comercialId: json['COM'] as String? ?? '',
      direccionId: json['DIR_M'] as String? ?? '',
      asunto: json['ASU'] as String? ?? '',
      todoElDia: json['TOD_DIA'] as bool? ?? false,
      fechaInicio: json['FCH_INI'] as String? ?? '',
      horaInicio: json['HOR_INI'] as String?,
      fechaFin: json['FCH_FIN'] as String?,
      horaFin: json['HOR_FIN'] as String?,
      presupuestoId: json['VTA_PRE_G'] as String?,
      fechaProximaVisita: json['FCH_PRO_VIS'] as String?,
      horaProximaVisita: json['HOR_PRO_VIS'] as String?,
      cerrar: json['NO_GEN_PRO_VIS'] as bool? ?? false,
      descripcion: json['DSC'] as String?,
      emp: json['emp'] as String? ?? '1',
      empDiv: json['emp_div'] as String? ?? '1',
    );

Map<String, dynamic> _$VisitaAgendaToJson(_VisitaAgenda instance) =>
    <String, dynamic>{
      'ID': instance.id,
      'CLI': instance.clienteId,
      'CRM_CAM_COM': instance.campanaId,
      'TIP_VIS': instance.tipoVisitaId,
      'COM': instance.comercialId,
      'DIR_M': instance.direccionId,
      'ASU': instance.asunto,
      'TOD_DIA': instance.todoElDia,
      'FCH_INI': instance.fechaInicio,
      'HOR_INI': instance.horaInicio,
      'FCH_FIN': instance.fechaFin,
      'HOR_FIN': instance.horaFin,
      'VTA_PRE_G': instance.presupuestoId,
      'FCH_PRO_VIS': instance.fechaProximaVisita,
      'HOR_PRO_VIS': instance.horaProximaVisita,
      'NO_GEN_PRO_VIS': instance.cerrar,
      'DSC': instance.descripcion,
      'emp': instance.emp,
      'emp_div': instance.empDiv,
    };
