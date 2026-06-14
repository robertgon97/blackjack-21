import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/semana.dart';
import '../../auth/presentation/auth_provider.dart';
import '../data/firestore_misiones_repository.dart';
import '../domain/i_misiones_repository.dart';
import '../domain/progreso_periodo.dart';

final misionesRepositoryProvider = Provider<IMisionesRepository>(
  (_) => FirestoreMisionesRepository(),
);

/// Programa la invalidación del provider al inicio del día siguiente (UTC), para
/// que el `periodoId` (fijado al construir el provider) no quede anclado al día
/// anterior si la página se deja abierta cruzando la medianoche.
void _invalidarAlDiaSiguiente<T>(Ref<T> ref, DateTime ahoraUtc) {
  final manana = DateTime.utc(ahoraUtc.year, ahoraUtc.month, ahoraUtc.day + 1);
  final timer = Timer(manana.difference(ahoraUtc), ref.invalidateSelf);
  ref.onDispose(timer.cancel);
}

/// Progreso del usuario autenticado en el día actual (misiones diarias).
final progresoDiarioProvider =
    StreamProvider.autoDispose<ProgresoPeriodo>((ref) {
  final perfil = ref.watch(perfilStreamProvider).valueOrNull;
  if (perfil == null) return const Stream.empty();
  final ahora = DateTime.now().toUtc();
  _invalidarAlDiaSiguiente(ref, ahora);
  return ref
      .watch(misionesRepositoryProvider)
      .progresoStream(perfil.uid, idDiaUtc(ahora));
});

/// Progreso del usuario autenticado en la semana actual (misiones semanales).
final progresoSemanalProvider =
    StreamProvider.autoDispose<ProgresoPeriodo>((ref) {
  final perfil = ref.watch(perfilStreamProvider).valueOrNull;
  if (perfil == null) return const Stream.empty();
  final ahora = DateTime.now().toUtc();
  // Reusar la invalidación diaria: el id de semana solo cambia los lunes, pero
  // reevaluarlo cada día es inofensivo y mantiene el periodo al día.
  _invalidarAlDiaSiguiente(ref, ahora);
  return ref
      .watch(misionesRepositoryProvider)
      .progresoStream(perfil.uid, idSemanaIso(ahora));
});
