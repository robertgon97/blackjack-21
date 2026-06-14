// ============================================================
//  Misiones diarias/semanales (Fase 10c): progreso por misión y
//  reclamo de la recompensa.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formato.dart';
import '../domain/mision.dart';
import '../domain/progreso_periodo.dart';
import 'misiones_provider.dart';

class MisionesPage extends ConsumerStatefulWidget {
  const MisionesPage({super.key});

  @override
  ConsumerState<MisionesPage> createState() => _MisionesPageState();
}

class _MisionesPageState extends ConsumerState<MisionesPage> {
  /// IDs de misiones cuyo reclamo está en curso (para deshabilitar el botón).
  final Set<String> _reclamando = {};

  Future<void> _reclamar(Mision mision) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _reclamando.add(mision.id));
    try {
      await ref.read(misionesRepositoryProvider).reclamarMision(mision.id);
      messenger.showSnackBar(
        SnackBar(
          content: Text('¡Misión completada! +${dinero(mision.recompensa)}'),
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
      if (mounted) setState(() => _reclamando.remove(mision.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Misiones')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Seccion(
            tipo: TipoMision.diaria,
            progreso: ref.watch(progresoDiarioProvider),
            reclamando: _reclamando,
            onReclamar: _reclamar,
          ),
          const SizedBox(height: 24),
          _Seccion(
            tipo: TipoMision.semanal,
            progreso: ref.watch(progresoSemanalProvider),
            reclamando: _reclamando,
            onReclamar: _reclamar,
          ),
        ],
      ),
    );
  }
}

class _Seccion extends StatelessWidget {
  const _Seccion({
    required this.tipo,
    required this.progreso,
    required this.reclamando,
    required this.onReclamar,
  });

  final TipoMision tipo;
  final AsyncValue<ProgresoPeriodo> progreso;
  final Set<String> reclamando;
  final Future<void> Function(Mision) onReclamar;

  @override
  Widget build(BuildContext context) {
    final misiones = catalogoMisiones.where((m) => m.tipo == tipo).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tipo.etiqueta, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        progreso.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (e, _) => Text('No se pudieron cargar las misiones: $e'),
          data: (prog) => Column(
            children: [
              for (final m in misiones)
                _TarjetaMision(
                  estado: EstadoMision.desde(m, prog),
                  reclamando: reclamando.contains(m.id),
                  onReclamar: () => onReclamar(m),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TarjetaMision extends StatelessWidget {
  const _TarjetaMision({
    required this.estado,
    required this.reclamando,
    required this.onReclamar,
  });

  final EstadoMision estado;
  final bool reclamando;
  final VoidCallback onReclamar;

  @override
  Widget build(BuildContext context) {
    final m = estado.mision;
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    m.descripcion,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Text('+${dinero(m.recompensa)}'),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child:
                  LinearProgressIndicator(value: estado.fraccion, minHeight: 8),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${estado.progreso.clamp(0, m.meta)} / ${m.meta}',
                  style: theme.textTheme.bodySmall,
                ),
                if (estado.reclamada)
                  const Text('Reclamada ✓')
                else if (estado.reclamable)
                  FilledButton(
                    onPressed: reclamando ? null : onReclamar,
                    child: const Text('Reclamar'),
                  )
                else
                  Text('En progreso', style: theme.textTheme.bodySmall),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
