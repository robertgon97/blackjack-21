import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/semana.dart';
import '../../auth/presentation/auth_provider.dart';
import '../data/firestore_misiones_repository.dart';
import '../domain/i_misiones_repository.dart';
import '../domain/progreso_periodo.dart';

final misionesRepositoryProvider = Provider<IMisionesRepository>(
  (_) => FirestoreMisionesRepository(),
);

/// Progreso del usuario autenticado en el día actual (misiones diarias).
final progresoDiarioProvider =
    StreamProvider.autoDispose<ProgresoPeriodo>((ref) {
  final perfil = ref.watch(perfilStreamProvider).valueOrNull;
  if (perfil == null) return const Stream.empty();
  return ref
      .watch(misionesRepositoryProvider)
      .progresoStream(perfil.uid, idDiaUtc(DateTime.now()));
});

/// Progreso del usuario autenticado en la semana actual (misiones semanales).
final progresoSemanalProvider =
    StreamProvider.autoDispose<ProgresoPeriodo>((ref) {
  final perfil = ref.watch(perfilStreamProvider).valueOrNull;
  if (perfil == null) return const Stream.empty();
  return ref
      .watch(misionesRepositoryProvider)
      .progresoStream(perfil.uid, idSemanaIso(DateTime.now()));
});
