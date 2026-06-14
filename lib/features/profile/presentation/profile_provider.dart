import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_provider.dart';
import '../data/firestore_profile_repository.dart';
import '../domain/estadisticas.dart';
import '../domain/i_profile_repository.dart';

final profileRepositoryProvider = Provider<IProfileRepository>(
  (_) => FirestoreProfileRepository(),
);

/// Estadísticas de juego en tiempo real del usuario autenticado.
final estadisticasProvider = StreamProvider<Estadisticas>((ref) {
  final perfil = ref.watch(perfilStreamProvider).valueOrNull;
  if (perfil == null) return const Stream.empty();
  return ref.watch(profileRepositoryProvider).estadisticasStream(perfil.uid);
});
