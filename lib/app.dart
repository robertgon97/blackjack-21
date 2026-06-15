import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/push/push_provider.dart';
import 'core/router/app_router.dart';
import 'core/telemetria/telemetria_provider.dart';
import 'core/theme/tema_provider.dart';
import 'core/theme/temas.dart';
import 'features/auth/presentation/auth_provider.dart';
import 'features/profile/domain/logros.dart';
import 'features/profile/presentation/profile_provider.dart';

/// Messenger global para mostrar avisos (p. ej. logros) desde cualquier ruta,
/// sin depender del `Scaffold` de la pantalla actual.
final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// Raíz de la aplicación Blackjack 21.
///
/// Observa el tema seleccionado y el router (con guard de auth) para
/// reconstruir el [MaterialApp.router] cuando alguno cambie.
class BlackjackApp extends ConsumerWidget {
  const BlackjackApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tema = ref.watch(temaProvider);
    final router = ref.watch(routerProvider);

    // Sincroniza uid y tipo_cuenta en Crashlytics/Analytics al cambiar el perfil.
    // Se ignoran los estados AsyncLoading/AsyncError para no limpiar el uid
    // durante reconexiones o refrescos del stream.
    ref.listen(perfilStreamProvider, (_, next) {
      if (next is! AsyncData) return;
      final t = ref.read(servicioTelemetriaProvider);
      final perfil = next.valueOrNull;
      t.setUid(perfil?.uid);
      if (perfil != null) {
        final tipo = perfil.isAnonymous ? 'anonimo' : 'permanente';
        t.setPropiedad('tipo_cuenta', tipo);
        t.setClave('tipo_cuenta', tipo);
        // Inicializa el push para este usuario (idempotente; no-op en Windows).
        ref.read(servicioPushProvider).inicializar(perfil.uid);
      }
    });

    // Sincroniza el tema preferido como user property de Analytics.
    ref.listen(temaProvider, (_, nuevoTema) {
      ref.read(servicioTelemetriaProvider).setPropiedad('tema', nuevoTema.name);
    });

    // Avisa con un toast cuando se desbloquea un logro (Fase 9). Se comparan los
    // IDs anteriores con los nuevos para notificar SOLO los recién ganados; en la
    // primera emisión con datos `prev` no tiene valor, así que los logros
    // históricos no disparan avisos al abrir la app.
    ref.listen(logrosProvider, (prev, next) {
      final antes = prev?.valueOrNull;
      final ahora = next.valueOrNull;
      if (antes == null || ahora == null) return;
      final previos = antes.toSet();
      for (final id in ahora.where((id) => !previos.contains(id))) {
        final logro = logroPorId(id);
        if (logro == null) continue;
        _scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content:
                Text('${logro.emoji}  ¡Logro desbloqueado: ${logro.nombre}!'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    });

    return MaterialApp.router(
      title: 'Blackjack 21',
      scaffoldMessengerKey: _scaffoldMessengerKey,
      debugShowCheckedModeBanner: false,
      theme: construirTema(tema),
      routerConfig: router,
    );
  }
}
