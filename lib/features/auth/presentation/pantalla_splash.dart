import 'package:flutter/material.dart';

/// Pantalla de arranque en frío: se muestra mientras Firebase Auth restaura la
/// sesión desde disco (estado `AsyncLoading` de `sesionStreamProvider`).
///
/// Evita el parpadeo a la pantalla de login del issue #49: hasta que se sepa si
/// hay o no sesión, el router deja al usuario aquí en vez de rebotar a `/login`.
class PantallaSplash extends StatelessWidget {
  const PantallaSplash({super.key});

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colores.surface,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Los emojis los renderiza el motor del SO, no Flutter: aplicar
            // `color` aquí no tendría efecto, así que solo se fija el tamaño.
            const Text('🃏', style: TextStyle(fontSize: 72)),
            const SizedBox(height: 24),
            Text(
              'Blackjack 21',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: colores.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 32),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
