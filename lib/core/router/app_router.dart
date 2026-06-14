import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/auth_provider.dart';
import '../telemetria/telemetria_provider.dart';
import 'router_observer.dart';
import '../../features/auth/presentation/pantalla_conversion.dart';
import '../../features/auth/presentation/pantalla_login.dart';
import '../../features/auth/presentation/pantalla_splash.dart';
import '../../features/friends/domain/contacto.dart';
import '../../features/friends/presentation/friends_page.dart';
import '../../features/friends/presentation/transfer_page.dart';
import '../../features/game/presentation/pantalla_juego.dart';
import '../../features/rooms/presentation/lobby_page.dart';
import '../../features/rooms/presentation/room_page.dart';
import '../../features/rooms/presentation/sala_provider.dart';
import '../../features/wallet/presentation/historial_page.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final sesionListenable = _SesionListenable(ref);

  return GoRouter(
    refreshListenable: sesionListenable,
    observers: [TelemetriaRouterObserver(ref.read(servicioTelemetriaProvider))],
    initialLocation: '/',
    redirect: (context, state) {
      // El guard se basa en el ESTADO DE AUTH (token), no en el perfil de
      // Firestore: la sesión persiste aunque la lectura del perfil falle o
      // tarde (issue #49).
      final sesion = ref.read(sesionStreamProvider);
      final enLogin = state.matchedLocation == '/login';
      final enSplash = state.matchedLocation == '/splash';

      // Cold start: mientras Auth restaura el usuario el stream está en
      // AsyncLoading. No confundir «cargando» con «sin sesión» → splash.
      if (sesion.isLoading) {
        return enSplash ? null : '/splash';
      }

      final autenticado = sesion.valueOrNull ?? false;
      // Sin sesión y fuera de login → login (cubre también salir del splash).
      if (!autenticado && !enLogin) return '/login';
      // Con sesión: sacar al usuario del splash o del login hacia el juego.
      if (autenticado && (enLogin || enSplash)) return '/';
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (_, __) => const PantallaSplash(),
      ),
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
          if (ref.read(sesionStreamProvider).valueOrNull != true) {
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

/// Hace que GoRouter reevalúe el guard cuando cambia el estado de sesión
/// (incluida la transición AsyncLoading → AsyncData del cold start).
class _SesionListenable extends ChangeNotifier {
  _SesionListenable(Ref ref) {
    ref.listen(sesionStreamProvider, (_, __) => notifyListeners());
  }
}
