import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/firebase_auth_repository.dart';
import '../domain/i_auth_repository.dart';
import '../domain/perfil_usuario.dart';

/// Instancia del repositorio de auth (intercambiable en tests).
final authRepositoryProvider = Provider<IAuthRepository>(
  (_) => FirebaseAuthRepository(),
);

/// Stream del perfil autenticado; emite `null` cuando no hay sesión activa.
final perfilStreamProvider = StreamProvider<PerfilUsuario?>(
  (ref) => ref.watch(authRepositoryProvider).perfilStream,
);
