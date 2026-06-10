import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/auth_provider.dart';
import '../../features/auth/presentation/pantalla_conversion.dart';
import '../../features/auth/presentation/pantalla_login.dart';
import '../../features/friends/domain/contacto.dart';
import '../../features/friends/presentation/friends_page.dart';
import '../../features/friends/presentation/transfer_page.dart';
import '../../features/game/presentation/pantalla_juego.dart';
import '../../features/rooms/presentation/lobby_page.dart';
import '../../features/rooms/presentation/room_page.dart';
import '../../features/rooms/presentation/sala_provider.dart';
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
        path: '/convertir',
        builder: (_, __) => const PantallaConversion(),
      ),
      // Deep link de invitación: busca la sala por código y redirige.
      GoRoute(
        path: '/join/:code',
        redirect: (context, state) async {
          // Sin sesión, la query a Firestore la denegarían las reglas (excepción
          // no capturada que rompe el router). Verificar auth antes del await.
          if (ref.read(perfilStreamProvider).valueOrNull == null) {
            return '/login';
          }
          final code = state.pathParameters['code'] ?? '';
          final repo = ref.read(salaRepositoryProvider);
          try {
            final sala = await repo.buscarPorCodigo(code);
            if (sala == null) return '/lobby';
            return '/room/${sala.id}';
          } catch (_) {
            return '/lobby';
          }
        },
      ),
      GoRoute(
        path: '/',
        builder: (_, __) => const PantallaJuego(),
        routes: [
          GoRoute(
            path: 'historial',
            builder: (_, __) => const HistorialPage(),
          ),
          GoRoute(
            path: 'friends',
            builder: (_, __) => const FriendsPage(),
            routes: [
              GoRoute(
                path: 'transfer',
                builder: (_, state) =>
                    TransferPage(contacto: state.extra! as Contacto),
              ),
            ],
          ),
          GoRoute(
            path: 'lobby',
            builder: (_, __) => const LobbyPage(),
          ),
          GoRoute(
            path: 'room/:id',
            builder: (_, state) =>
                RoomPage(roomId: state.pathParameters['id']!),
          ),
        ],
      ),
    ],
  );
});

/// Hace que GoRouter se refresque cuando cambia el estado de auth.
class _PerfilListenable extends ChangeNotifier {
  _PerfilListenable(Ref ref) {
    ref.listen(perfilStreamProvider, (_, __) => notifyListeners());
  }
}
