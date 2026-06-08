import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/tema_provider.dart';
import 'core/theme/temas.dart';
import 'features/game/presentation/pantalla_juego.dart';

/// Raíz de la aplicación Blackjack 21.
///
/// Observa el tema seleccionado y reconstruye el [MaterialApp] con la paleta
/// correspondiente. La pantalla inicial es el juego solo (Fase 2).
class BlackjackApp extends ConsumerWidget {
  const BlackjackApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tema = ref.watch(temaProvider);
    return MaterialApp(
      title: 'Blackjack 21',
      debugShowCheckedModeBanner: false,
      theme: construirTema(tema),
      home: const PantallaJuego(),
    );
  }
}
