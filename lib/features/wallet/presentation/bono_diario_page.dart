// ============================================================
//  Bono diario con racha (Fase 10b): muestra la racha de días
//  consecutivos y permite reclamar la recompensa del día.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formato.dart';
import '../domain/bono_diario.dart';
import 'wallet_provider.dart';

class BonoDiarioPage extends ConsumerStatefulWidget {
  const BonoDiarioPage({super.key});

  @override
  ConsumerState<BonoDiarioPage> createState() => _BonoDiarioPageState();
}

class _BonoDiarioPageState extends ConsumerState<BonoDiarioPage> {
  bool _reclamando = false;

  Future<void> _reclamar() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _reclamando = true);
    try {
      final bono =
          await ref.read(walletRepositoryProvider).reclamarBonoDiario();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '¡+${dinero(bono.monto)}! Racha: ${bono.racha} '
            '${bono.racha == 1 ? "día" : "días"}',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _reclamando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final estadoAsync = ref.watch(estadoBonoProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Bono diario')),
      body: estadoAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('No se pudo cargar el bono: $e')),
        data: (estado) => _Contenido(
          estado: estado,
          reclamando: _reclamando,
          onReclamar: _reclamar,
        ),
      ),
    );
  }
}

class _Contenido extends StatelessWidget {
  const _Contenido({
    required this.estado,
    required this.reclamando,
    required this.onReclamar,
  });

  final EstadoBonoDiario estado;
  final bool reclamando;
  final Future<void> Function() onReclamar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          Text(
            '🔥',
            style: theme.textTheme.displayMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Racha de ${estado.racha} ${estado.racha == 1 ? "día" : "días"}',
            style: theme.textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var dia = 1; dia <= topeRachaBono; dia++)
                _DiaChip(
                  dia: dia,
                  monto: montoPorRacha(dia),
                  conseguido: dia <= estado.racha,
                  // clamp: con racha máxima (≥ tope) el "hoy" sería el día tope.
                  esHoy: estado.disponibleHoy &&
                      dia == (estado.racha + 1).clamp(1, topeRachaBono),
                ),
            ],
          ),
          const Spacer(),
          if (estado.disponibleHoy)
            FilledButton.icon(
              icon: const Icon(Icons.card_giftcard),
              label: Text('Reclamar ${dinero(estado.montoAlReclamar)}'),
              onPressed: reclamando ? null : () => onReclamar(),
            )
          else
            const Text(
              'Ya reclamaste tu bono de hoy. ¡Vuelve mañana para no perder la racha!',
              textAlign: TextAlign.center,
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _DiaChip extends StatelessWidget {
  const _DiaChip({
    required this.dia,
    required this.monto,
    required this.conseguido,
    required this.esHoy,
  });

  final int dia;
  final int monto;
  final bool conseguido;
  final bool esHoy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = esHoy
        ? theme.colorScheme.primaryContainer
        : conseguido
            ? theme.colorScheme.secondaryContainer
            : theme.colorScheme.surfaceContainerHighest;
    return Container(
      width: 84,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
        border: esHoy
            ? Border.all(color: theme.colorScheme.primary, width: 2)
            : null,
      ),
      child: Column(
        children: [
          Text('Día $dia', style: theme.textTheme.labelMedium),
          const SizedBox(height: 2),
          Text(
            dia == topeRachaBono ? '${dinero(monto)}+' : dinero(monto),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          if (conseguido)
            const Icon(Icons.check_circle, size: 16)
          else
            const SizedBox(height: 16),
        ],
      ),
    );
  }
}
