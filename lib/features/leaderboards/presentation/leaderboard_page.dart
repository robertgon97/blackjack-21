// ============================================================
//  Ranking semanal (Fase 10): top global y entre amigos por tres
//  métricas (ganancia neta, manos ganadas, mejor racha), con la
//  posición del usuario.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formato.dart';
import '../../auth/presentation/auth_provider.dart';
import '../domain/entrada_ranking.dart';
import 'leaderboard_provider.dart';

class LeaderboardPage extends ConsumerStatefulWidget {
  const LeaderboardPage({super.key});

  @override
  ConsumerState<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends ConsumerState<LeaderboardPage> {
  /// false = global, true = solo amigos.
  bool _amigos = false;

  @override
  Widget build(BuildContext context) {
    const metricas = MetricaRanking.values;
    return DefaultTabController(
      length: metricas.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Ranking semanal'),
          bottom: TabBar(
            isScrollable: true,
            tabs: [for (final m in metricas) Tab(text: m.etiqueta)],
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Global')),
                  ButtonSegment(value: true, label: Text('Amigos')),
                ],
                selected: {_amigos},
                onSelectionChanged: (s) => setState(() => _amigos = s.first),
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  for (final m in metricas)
                    _ListaRanking(metrica: m, amigos: _amigos),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ListaRanking extends ConsumerWidget {
  const _ListaRanking({required this.metrica, required this.amigos});

  final MetricaRanking metrica;
  final bool amigos;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final miUid = ref.watch(perfilStreamProvider).valueOrNull?.uid;
    final async = amigos
        ? ref.watch(topAmigosProvider(metrica))
        : ref.watch(topGlobalProvider(metrica));

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('No se pudo cargar el ranking: $e')),
      data: (lista) {
        if (lista.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                amigos
                    ? 'Ni tú ni tus amigos han jugado esta semana.'
                    : 'Nadie ha jugado multijugador esta semana. ¡Sé el primero!',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        return Column(
          children: [
            if (!amigos) _BannerPosicion(metrica: metrica),
            Expanded(
              child: ListView.separated(
                itemCount: lista.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) => _Fila(
                  posicion: i + 1,
                  entrada: lista[i],
                  metrica: metrica,
                  esYo: lista[i].uid == miUid,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _BannerPosicion extends ConsumerWidget {
  const _BannerPosicion({required this.metrica});

  final MetricaRanking metrica;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pos = ref.watch(miPosicionProvider(metrica)).valueOrNull;
    if (pos == null) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      color: Theme.of(context).colorScheme.primaryContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Text(
        'Estás en el puesto #$pos esta semana',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _Fila extends StatelessWidget {
  const _Fila({
    required this.posicion,
    required this.entrada,
    required this.metrica,
    required this.esYo,
  });

  final int posicion;
  final EntradaRanking entrada;
  final MetricaRanking metrica;
  final bool esYo;

  String get _medalla => switch (posicion) {
        1 => '🥇',
        2 => '🥈',
        3 => '🥉',
        _ => '#$posicion',
      };

  String get _valor => metrica == MetricaRanking.gananciaNeta
      ? dineroConSigno(entrada.gananciaNeta)
      : '${entrada.valor(metrica)}';

  @override
  Widget build(BuildContext context) {
    return Container(
      color: esYo
          ? Theme.of(context)
              .colorScheme
              .secondaryContainer
              .withValues(alpha: 0.5)
          : null,
      child: ListTile(
        leading: SizedBox(
          width: 36,
          child: Center(
            child: Text(_medalla, style: const TextStyle(fontSize: 18)),
          ),
        ),
        title: Row(
          children: [
            Text(entrada.avatar, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                esYo ? '${entrada.displayName} (tú)' : entrada.displayName,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: esYo ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
        trailing: Text(
          _valor,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
