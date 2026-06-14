import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_provider.dart';
import '../data/firestore_profile_repository.dart';
import '../domain/estadisticas.dart';
import '../domain/i_profile_repository.dart';

final profileRepositoryProvider = Provider<IProfileRepository>(
  (_) => FirestoreProfileRepository(),
);

/// Documento `users/{uid}` del usuario autenticado en tiempo real. Es la **fuente
/// única** del listener: `estadisticasProvider` y `logrosProvider` derivan de
/// aquí para no abrir dos suscripciones Firestore al mismo documento.
final usuarioDocProvider = StreamProvider<Map<String, dynamic>>((ref) {
  final perfil = ref.watch(perfilStreamProvider).valueOrNull;
  if (perfil == null) return const Stream.empty();
  return ref.watch(profileRepositoryProvider).usuarioDocStream(perfil.uid);
});

/// Estadísticas de juego del usuario autenticado, derivadas del doc compartido.
final estadisticasProvider = Provider<AsyncValue<Estadisticas>>((ref) {
  return ref.watch(usuarioDocProvider).whenData(
        (data) => Estadisticas.fromMap(data['stats'] as Map<String, dynamic>?),
      );
});

/// IDs de logros desbloqueados del usuario autenticado (Fase 9), derivados del
/// doc compartido.
final logrosProvider = Provider<AsyncValue<List<String>>>((ref) {
  return ref.watch(usuarioDocProvider).whenData(
        (data) =>
            (data['logros'] as List<dynamic>?)?.cast<String>() ??
            const <String>[],
      );
});
