// ============================================================================
//  remote_search_cubit.dart  —  ESTADOS DE UNA BÚSQUEDA REMOTA (Autocomplete)
// ============================================================================
//
//  ¿Qué es?
//  --------
//  El "cerebro" del buscador con autocompletado. Gestiona los estados de
//  carga, error y datos vacíos de cada búsqueda contra Velneo, sin bloquear la
//  interfaz. Un widget (AutocompleteField) crea un cubit por campo e inyecta
//  la función de búsqueda (normalmente el repositorio local-first).
//
//  ESTADOS (UI)                                QUÉ SIGNIFICAN
//  -------------                               ----------------------------
//  RemoteSearchIdle                            Aún no hay búsqueda (o texto corto).
//  RemoteSearchLoading                         Petición en curso.
//  RemoteSearchSuccess(results)                Resultados para pintar.
//  RemoteSearchFailure(message)                Algo falló (red / permisos).
//
//  CONCEPTO:
//  - Cubit: clase de flutter_bloc que emite estados y permite SUSCRIBIRSE
//    con BlocBuilder. El número de secuencia (_sequence) descarta respuestas
//    antiguas si el usuario sigue tecleando (respuestas fuera de orden).
// ============================================================================

import 'package:flutter_bloc/flutter_bloc.dart';

import '../models.dart'; // OpcionMaestra (resultado de la búsqueda).

/// Estado base del buscador remoto.
sealed class RemoteSearchState {
  const RemoteSearchState();
}

/// Sin búsqueda activa (campo vacío o con menos caracteres de los mínimos).
class RemoteSearchIdle extends RemoteSearchState {
  const RemoteSearchIdle();
}

/// Petición contra el API en curso.
class RemoteSearchLoading extends RemoteSearchState {
  const RemoteSearchLoading();
}

/// Búsqueda terminada con resultados (vacía si no hubo coincidencias).
class RemoteSearchSuccess extends RemoteSearchState {
  final List<OpcionMaestra> results;
  const RemoteSearchSuccess(this.results);
}

/// La búsqueda falló (error de red, API, permisos...).
class RemoteSearchFailure extends RemoteSearchState {
  final String message;
  const RemoteSearchFailure(this.message);
}

/// Cubit que ejecuta una búsqueda remota por consulta, descartando respuestas
/// fuera de orden. [search] es la función que resuelve la consulta (repositorio).
class RemoteSearchCubit extends Cubit<RemoteSearchState> {
  /// Función de búsqueda inyectada (repositorio local-first o PedidosService).
  final Future<List<OpcionMaestra>> Function(String query) searchFn;

  /// Número mínimo de caracteres para disparar la búsqueda.
  final int minChars;

  /// Secuencia interna: solo la última petición puede actualizar el estado.
  int _sequence = 0;

  RemoteSearchCubit({
    required this.searchFn,
    this.minChars = 3,
  }) : super(const RemoteSearchIdle());

  /// Lanza una búsqueda para [query]. Peticiones con menos de [minChars]
  /// caracteres resetean a idle (no golpean la red).
  Future<void> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.length < minChars) {
      _sequence++; // Invalidamos cualquier petición aún en vuelo.
      if (state is! RemoteSearchIdle) emit(const RemoteSearchIdle());
      return;
    }

    emit(const RemoteSearchLoading());
    final seq = ++_sequence;
    try {
      final results = await searchFn(trimmed);
      if (seq == _sequence && !isClosed) {
        emit(RemoteSearchSuccess(results));
      }
    } catch (e) {
      if (seq == _sequence && !isClosed) {
        emit(RemoteSearchFailure('No se pudo buscar. Inténtalo de nuevo.'));
      }
    }
  }

  /// Cancela cualquier búsqueda pendiente y vuelve a idle.
  void cancel() {
    _sequence++;
    if (!isClosed && state is! RemoteSearchIdle) emit(const RemoteSearchIdle());
  }

  @override
  Future<void> close() async {
    _sequence++; // Evitamos emitir después del cierre.
    return super.close();
  }
}