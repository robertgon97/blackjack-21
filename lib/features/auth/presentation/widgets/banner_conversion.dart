import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth_provider.dart';

/// Banner descartable que incita a convertir la cuenta demo en permanente.
/// Solo se muestra mientras `perfil.isAnonymous == true` y el usuario no lo
/// haya descartado en esta sesión. Nunca bloquea el juego.
class BannerConversion extends ConsumerWidget {
  const BannerConversion({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perfil = ref.watch(perfilStreamProvider).valueOrNull;
    final descartado = ref.watch(bannerConversionDescartadoProvider);
    if (descartado || perfil == null || !perfil.isAnonymous) {
      return const SizedBox.shrink();
    }

    final cs = Theme.of(context).colorScheme;
    return MaterialBanner(
      backgroundColor: cs.secondaryContainer,
      content: const Text(
        'Crea tu cuenta para no perder tu progreso (+500 créditos de regalo).',
      ),
      leading: Icon(Icons.account_circle, color: cs.onSecondaryContainer),
      actions: [
        TextButton(
          onPressed: () => ref
              .read(bannerConversionDescartadoProvider.notifier)
              .state = true,
          child: const Text('Ahora no'),
        ),
        FilledButton(
          onPressed: () => context.go('/convertir'),
          child: const Text('Crear cuenta'),
        ),
      ],
    );
  }
}
