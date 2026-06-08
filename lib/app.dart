import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/tema_provider.dart';
import 'core/theme/temas.dart';

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

    return MaterialApp.router(
      title: 'Blackjack 21',
      debugShowCheckedModeBanner: false,
      theme: construirTema(tema),
      routerConfig: router,
    );
  }
}
