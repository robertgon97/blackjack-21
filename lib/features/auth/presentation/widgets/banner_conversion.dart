import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth_provider.dart';

/// Banner descartable que incita a convertir la cuenta demo en permanente.
/// Solo se muestra mientras `perfil.isAnonymous == true` y el usuario no lo
/// haya descartado en esta sesión. Nunca bloquea el juego.
class BannerConversion extends ConsumerStatefulWidget {
  const BannerConversion({super.key});

  @override
  ConsumerState<BannerConversion> createState() => _BannerConversionState();
}

class _BannerConversionState extends ConsumerState<BannerConversion> {
  bool _descartado = false;

  @override
  Widget build(BuildContext context) {
    final perfil = ref.watch(perfilStreamProvider).valueOrNull;
    if (_descartado || perfil == null || !perfil.isAnonymous) {
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
          onPressed: () => setState(() => _descartado = true),
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
