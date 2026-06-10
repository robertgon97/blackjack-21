import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/telemetria/telemetria_provider.dart';
import '../data/firebase_auth_repository.dart';
import '../domain/i_auth_repository.dart';
import '../domain/perfil_usuario.dart';

/// Instancia del repositorio de auth (intercambiable en tests).
final authRepositoryProvider = Provider<IAuthRepository>((ref) {
  return FirebaseAuthRepository(
    telemetria: ref.read(servicioTelemetriaProvider),
  );
});

/// Stream del perfil autenticado; emite `null` cuando no hay sesión activa.
final perfilStreamProvider = StreamProvider<PerfilUsuario?>(
  (ref) => ref.watch(authRepositoryProvider).perfilStream,
);

/// Si el usuario descartó el banner de conversión en esta sesión. Vive a nivel
/// de app (no del widget) para que no reaparezca al recrear `BannerConversion`
/// —p. ej. al volver de `/convertir`—.
final bannerConversionDescartadoProvider = StateProvider<bool>((_) => false);
