// ============================================================================
//  agenda_calendar_screen.dart  —  CALENDARIO CRM DEL COMERCIAL
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:table_calendar/table_calendar.dart';

import '../core/formatters.dart';
import '../core/crm_repository.dart';
import '../models/visita_agenda.dart';
import '../state/agenda_list_cubit.dart';
import '../state/auth_state.dart';
import '../theme/app_theme.dart';
import '../widgets/agenda_form_modal.dart';

/// Calendario mensual de visitas. Crea/edita con [mostrarAgendaForm].
class AgendaCalendarScreen extends StatefulWidget {
  const AgendaCalendarScreen({super.key});

  @override
  State<AgendaCalendarScreen> createState() => _AgendaCalendarScreenState();
}

class _AgendaCalendarScreenState extends State<AgendaCalendarScreen> {
  late final AgendaListCubit _cubit;
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('es');
    _cubit = AgendaListCubit(context.read<CrmRepository>());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _cargarVisitas();
    });
  }

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  String get _comercialId =>
      context.read<AuthState>().currentUser?.contactId ?? '';

  Future<void> _cargarVisitas() {
    return _cubit.loadVisitas(_comercialId);
  }

  String _isoDia(DateTime dia) =>
      '${dia.year}-${dia.month.toString().padLeft(2, '0')}-${dia.day.toString().padLeft(2, '0')}';

  Future<void> _abrirVisita([VisitaAgenda? visita]) async {
    final resultado = await mostrarAgendaForm(context, visita: visita);
    if (!mounted) return;

    if (resultado?.accion == AgendaFormAccion.aceptar) {
      final visitaGuardada = resultado!.visita;
      final crmRepository = context.read<CrmRepository>();

      await crmRepository.guardarVisita(visitaGuardada);

      final esEdicion = visitaGuardada.id != null;

      if (visitaGuardada.cerrar) {
        final currentFecha = DateTime.tryParse(visitaGuardada.fechaInicio);
        if (currentFecha != null) {
          final relVisits = _cubit.state.visitas.where((v) =>
              v.id != visitaGuardada.id &&
              v.clienteId == visitaGuardada.clienteId &&
              v.comercialId == visitaGuardada.comercialId &&
              v.asunto == visitaGuardada.asunto &&
              v.campanaId == visitaGuardada.campanaId
          ).toList();

          for (final v in relVisits) {
            final vDate = DateTime.tryParse(v.fechaInicio);
            if (vDate != null) {
              if (vDate.isBefore(currentFecha)) {
                if (!v.cerrar) {
                  try {
                    await crmRepository.guardarVisita(v.copyWith(cerrar: true));
                  } catch (_) {}
                }
              } else if (vDate.isAfter(currentFecha)) {
                if (v.id != null) {
                  try {
                    await crmRepository.eliminarVisita(v.id!);
                  } catch (_) {}
                }
              }
            }
          }
        }
      } else if (esEdicion && !visitaGuardada.cerrar) {
        String nuevaFecha = '';
        if (visitaGuardada.fechaProximaVisita != null && visitaGuardada.fechaProximaVisita!.isNotEmpty) {
          nuevaFecha = visitaGuardada.fechaProximaVisita!;
        } else {
          final hoy = DateTime.now();
          final target = hoy.add(const Duration(days: 60));
          nuevaFecha = '${target.year}-${target.month.toString().padLeft(2, '0')}-${target.day.toString().padLeft(2, '0')}';
        }

        final existe = _cubit.state.visitas.any((v) =>
            v.clienteId == visitaGuardada.clienteId &&
            v.comercialId == visitaGuardada.comercialId &&
            v.asunto == visitaGuardada.asunto &&
            v.campanaId == visitaGuardada.campanaId &&
            v.fechaInicio == nuevaFecha);

        debugPrint('--- CLONING VISITA ---');
        debugPrint('esEdicion: $esEdicion, cerrar: ${visitaGuardada.cerrar}');
        debugPrint('nuevaFecha: $nuevaFecha');
        debugPrint('existe duplicado: $existe');

        if (!existe) {
          final proximaVisita = visitaGuardada.copyWith(
            id: null,
            fechaInicio: nuevaFecha,
            horaInicio: visitaGuardada.horaProximaVisita,
            fechaProximaVisita: null,
            horaProximaVisita: null,
            cerrar: false,
            descripcion: null, // descripción vacía
          );
          
          debugPrint('Intentando POST nueva visita con fechaInicio: ${proximaVisita.fechaInicio}');
          try {
            await crmRepository.guardarVisita(proximaVisita);
            debugPrint('Visita clonada guardada correctamente.');
          } catch(e) {
            debugPrint('ERROR guardando visita clonada: $e');
          }
        }
      }
    } else if (resultado?.accion == AgendaFormAccion.eliminar) {
      if (resultado!.visita.id != null) {
        try {
          await context.read<CrmRepository>().eliminarVisita(resultado.visita.id!);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Visita eliminada correctamente.')),
          );
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al eliminar la visita: $e'), backgroundColor: AppColors.error),
          );
        }
      }
    }

    await _cargarVisitas();
  }

  Future<void> _nuevaVisita() {
    return _abrirVisita(
      VisitaAgenda(
        comercialId: _comercialId,
        fechaInicio: _isoDia(_selectedDay),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _cubit,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Agenda')),
        floatingActionButton: FloatingActionButton(
          tooltip: 'Nueva visita',
          onPressed: _nuevaVisita,
          child: const Icon(Icons.add),
        ),
        body: BlocBuilder<AgendaListCubit, AgendaListState>(
          builder: (context, state) {
            final visitasDelDia = _cubit.getVisitasParaDia(_selectedDay);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (state.cargando) const LinearProgressIndicator(minHeight: 2),
                if (state.error != null)
                  Material(
                    color: AppColors.error.withValues(alpha: 0.08),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 18,
                            color: AppColors.error,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              state.error!,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.error,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: _cargarVisitas,
                            child: const Text('Reintentar'),
                          ),
                        ],
                      ),
                    ),
                  ),
                Card(
                  margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                  child: TableCalendar<VisitaAgenda>(
                    locale: 'es',
                    firstDay: DateTime.utc(2020, 1, 1),
                    lastDay: DateTime.utc(2100, 12, 31),
                    focusedDay: _focusedDay,
                    selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                    calendarFormat: CalendarFormat.month,
                    availableCalendarFormats: const {
                      CalendarFormat.month: 'Mes',
                    },
                    startingDayOfWeek: StartingDayOfWeek.monday,
                    eventLoader: _cubit.getVisitasParaDia,
                    onDaySelected: (selected, focused) {
                      setState(() {
                        _selectedDay = selected;
                        _focusedDay = focused;
                      });
                    },
                    onPageChanged: (focused) => _focusedDay = focused,
                    headerStyle: const HeaderStyle(
                      titleCentered: true,
                      formatButtonVisible: false,
                      titleTextStyle: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                    calendarStyle: CalendarStyle(
                      todayDecoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.35),
                        shape: BoxShape.circle,
                      ),
                      selectedDecoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      markerDecoration: const BoxDecoration(
                        color: AppColors.primaryDark,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    'Visitas del ${formatDate(_isoDia(_selectedDay))}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Expanded(
                  child: visitasDelDia.isEmpty
                      ? Center(
                          child: Text(
                            state.cargando
                                ? 'Cargando visitas...'
                                : 'No hay visitas este día.',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 88),
                          itemCount: visitasDelDia.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final visita = visitasDelDia[index];
                            final titulo = visita.asunto.trim().isEmpty
                                ? 'Sin asunto'
                                : visita.asunto;
                            final hora = (visita.horaInicio ?? '').trim();
                            final cliente = visita.clienteNombre.trim();
                            final subtitulo = [
                              if (hora.isNotEmpty) hora,
                              if (cliente.isNotEmpty) cliente,
                            ].join(' · ');
                            return Material(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(12),
                              child: ListTile(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                leading: CircleAvatar(
                                  backgroundColor: AppColors.primary.withValues(
                                    alpha: 0.12,
                                  ),
                                  foregroundColor: AppColors.primary,
                                  child: const Icon(Icons.event_outlined),
                                ),
                                title: Text(
                                  titulo,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: subtitulo.isEmpty
                                    ? null
                                    : Text(subtitulo),
                                trailing: const Icon(
                                  Icons.chevron_right,
                                  color: AppColors.textSecondary,
                                ),
                                onTap: () => _abrirVisita(visita),
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
