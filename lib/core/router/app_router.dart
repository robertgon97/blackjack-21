import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/domain/perfil_usuario.dart';
import '../../features/auth/presentation/auth_provider.dart';
import '../../features/auth/presentation/pantalla_login.dart';
import '../../features/game/presentation/pantalla_juego.dart';
import '../../features/wallet/presentation/historial_page.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final perfilListenable = _PerfilListenable(ref);

  return GoRouter(
    refreshListenable: perfilListenable,
    initialLocation: '/',
    redirect: (context, state) {
      final perfil = ref.read(perfilStreamProvider).valueOrNull;
      final enLogin = state.matchedLocation == '/login';
      if (perfil == null && !enLogin) return '/login';
      if (perfil != null && enLogin) return '/';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (_, __) => const PantallaLogin(),
      ),
      GoRoute(
        path: '/',
        builder: (_, __) => const PantallaJuego(),
        routes: [
          GoRoute(
            path: 'historial',
            builder: (_, __) => const HistorialPage(),
          ),
        ],
      ),
    ],
  );
});

/// Hace que GoRouter se refresque cuando cambia el estado de auth.
class _PerfilListenable extends ChangeNotifier {
  _PerfilListenable(ProviderRef ref) {
    ref.listen(perfilStreamProvider, (_, __) => notifyListeners());
  }
}
