import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/telemetria/telemetria_provider.dart';
import 'core/theme/tema_provider.dart';
import 'core/theme/temas.dart';
import 'features/auth/presentation/auth_provider.dart';

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
      }
    });

    // Sincroniza el tema preferido como user property de Analytics.
    ref.listen(temaProvider, (_, nuevoTema) {
      ref.read(servicioTelemetriaProvider).setPropiedad('tema', nuevoTema.name);
    });

    return MaterialApp.router(
      title: 'Blackjack 21',
      debugShowCheckedModeBanner: false,
      theme: construirTema(tema),
      routerConfig: router,
    );
  }
}
