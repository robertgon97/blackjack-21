import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_provider.dart';
import '../../friends/domain/contacto.dart';
import '../../friends/presentation/friends_provider.dart';
import '../data/firestore_leaderboard_repository.dart';
import '../domain/entrada_ranking.dart';
import '../domain/i_leaderboard_repository.dart';

final leaderboardRepositoryProvider = Provider<ILeaderboardRepository>(
  (_) => FirestoreLeaderboardRepository(),
);

// Todos los providers son `.autoDispose`: se descartan al salir de la página de
// ranking y se recargan al volver, para que los datos no queden congelados (y se
// libere el listener de Firestore del top global).

/// Top global de la semana actual por [metrica] (tiempo real).
final topGlobalProvider =
    StreamProvider.autoDispose.family<List<EntradaRanking>, MetricaRanking>(
  (ref, metrica) => ref.watch(leaderboardRepositoryProvider).topGlobal(metrica),
);

/// Top de amigos aceptados (+ uno mismo) por [metrica].
final topAmigosProvider =
    FutureProvider.autoDispose.family<List<EntradaRanking>, MetricaRanking>(
  (ref, metrica) async {
    final perfil = ref.watch(perfilStreamProvider).valueOrNull;
    if (perfil == null) return const [];
    final contactos =
        ref.watch(contactosProvider).valueOrNull ?? const <Contacto>[];
    final uids = <String>{
      perfil.uid,
      for (final c in contactos)
        if (c.estado == EstadoAmistad.aceptada) c.uid,
    }.toList();
    return ref.watch(leaderboardRepositoryProvider).topAmigos(uids, metrica);
  },
);

/// Mi entrada de la semana actual (o `null` si no jugué multijugador esta semana).
final miEntradaProvider =
    FutureProvider.autoDispose<EntradaRanking?>((ref) async {
  final perfil = ref.watch(perfilStreamProvider).valueOrNull;
  if (perfil == null) return null;
  return ref.watch(leaderboardRepositoryProvider).entradaDe(perfil.uid);
});

/// Mi posición global por [metrica], o `null` si no tengo entrada esta semana.
final miPosicionProvider = FutureProvider.autoDispose
    .family<int?, MetricaRanking>((ref, metrica) async {
  final entrada = await ref.watch(miEntradaProvider.future);
  if (entrada == null) return null;
  return ref
      .watch(leaderboardRepositoryProvider)
      .posicionGlobal(metrica, entrada.valor(metrica));
});
