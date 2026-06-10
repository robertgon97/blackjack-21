import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/telemetria/telemetria_provider.dart';
import '../../auth/presentation/auth_provider.dart';
import '../data/firestore_friends_repository.dart';
import '../domain/contacto.dart';
import '../domain/i_friends_repository.dart';

final friendsRepositoryProvider = Provider<IFriendsRepository>((ref) {
  return FirestoreFriendsRepository(
    telemetria: ref.read(servicioTelemetriaProvider),
  );
});

/// Stream de todos los contactos del usuario autenticado (pendientes + aceptados).
final contactosProvider = StreamProvider<List<Contacto>>((ref) {
  final perfil = ref.watch(perfilStreamProvider).valueOrNull;
  if (perfil == null) return const Stream.empty();
  return ref.watch(friendsRepositoryProvider).contactosStream(perfil.uid);
});
