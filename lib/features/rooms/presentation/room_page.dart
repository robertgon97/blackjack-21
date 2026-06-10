import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/temas.dart';
import '../../../core/utils/formato.dart';
import '../../auth/presentation/auth_provider.dart';
import '../domain/modelos.dart';
import 'sala_provider.dart';
import 'widgets/panel_apuestas_sala.dart';
import 'widgets/tapete_multijugador.dart';

/// Página de sala multijugador. Cambia de vista según la fase.
class RoomPage extends ConsumerStatefulWidget {
  const RoomPage({super.key, required this.roomId});
  final String roomId;

  @override
  ConsumerState<RoomPage> createState() => _RoomPageState();
}

class _RoomPageState extends ConsumerState<RoomPage> {
  int _timerSeg = 45;
  Timer? _timer;
  String? _errorAccion;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _iniciarTimer(int seg) {
    _timer?.cancel();
    setState(() => _timerSeg = seg);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _timerSeg--;
        if (_timerSeg <= 0) {
          t.cancel();
          _accion('plantarse');
        }
      });
    });
  }

  Future<void> _accion(String accion, {int? manoIdx}) async {
    _timer?.cancel();
    setState(() => _errorAccion = null);
    try {
      await ref
          .read(salaActionsProvider(widget.roomId))
          .accion(accion, manoIdx: manoIdx);
    } catch (e) {
      if (mounted) setState(() => _errorAccion = e.toString());
    }
  }

  Future<void> _salir() async {
    try {
      await ref.read(salaActionsProvider(widget.roomId)).salir();
      _timer?.cancel();
      if (mounted) context.pop();
    } catch (_) {
      // Durante 'playing' las reglas impiden que un miembro borre su entrada.
      // No salimos en falso (eso dejaría un jugador fantasma ocupando asiento):
      // avisamos y dejamos que lo intente al terminar la ronda.
      if (mounted) {
        setState(() {
          _errorAccion =
              'No puedes salir durante la partida. Inténtalo al terminar la ronda.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Arrancar el temporizador en la transición a 'playing'. Se gestiona como
    // efecto secundario con ref.listen (no mutando estado dentro de build).
    ref.listen(salaProvider(widget.roomId), (prev, next) {
      final antes = prev?.valueOrNull?.status;
      final ahora = next.valueOrNull?.status;
      if (ahora == EstadoSala.playing && antes != EstadoSala.playing) {
        _iniciarTimer(next.valueOrNull!.config.timerSeg);
      }
    });

    final salaAsync = ref.watch(salaProvider(widget.roomId));
    final tapete = context.tapete;
    final uid = ref.watch(perfilStreamProvider).valueOrNull?.uid ?? '';

    return salaAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Error: $e')),
      ),
      data: (sala) {
        if (sala == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Sala')),
            body: const Center(child: Text('La sala ya no existe.')),
          );
        }

        return Scaffold(
          body: Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.topCenter,
                radius: 1.2,
                colors: [tapete.tapete1, tapete.tapete2],
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  _BarraSala(sala: sala, miUid: uid, onSalir: _salir),
                  if (_errorAccion != null)
                    _BannerError(
                      mensaje: _errorAccion!,
                      onDismiss: () => setState(() => _errorAccion = null),
                    ),
                  Expanded(
                    child: _Cuerpo(
                      sala: sala,
                      miUid: uid,
                      timerSeg: _timerSeg,
                      onAccion: _accion,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Barra superior ─────────────────────────────────────────────────────────────

class _BarraSala extends ConsumerWidget {
  const _BarraSala({
    required this.sala,
    required this.miUid,
    required this.onSalir,
  });

  final Sala sala;
  final String miUid;
  final VoidCallback onSalir;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final esHost = sala.hostUid == miUid;
    final activos = sala.jugadoresActivos.length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: Colors.black.withValues(alpha: 0.3),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: onSalir,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sala.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '$activos/${sala.maxPlayers} jugadores · ${sala.status.etiqueta}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          if (esHost && sala.status == EstadoSala.waiting)
            FilledButton.icon(
              onPressed: () => ref
                  .read(salaActionsProvider(sala.id))
                  .cambiarEstado(EstadoSala.betting),
              icon: const Icon(Icons.play_arrow, size: 18),
              label: const Text('Iniciar apuestas'),
              style: FilledButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                textStyle: const TextStyle(fontSize: 13),
              ),
            )
          else
            _CodigoInvitacion(code: sala.inviteCode),
        ],
      ),
    );
  }
}

class _CodigoInvitacion extends StatelessWidget {
  const _CodigoInvitacion({required this.code});
  final String code;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Código: $code'),
            duration: const Duration(seconds: 3),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Código',
              style: TextStyle(color: Colors.white54, fontSize: 10),
            ),
            Text(
              code,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BannerError extends StatelessWidget {
  const _BannerError({required this.mensaje, required this.onDismiss});
  final String mensaje;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.red.shade700,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              mensaje,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white, size: 16),
            onPressed: onDismiss,
          ),
        ],
      ),
    );
  }
}

// ── Cuerpo (cambia según la fase) ─────────────────────────────────────────────

class _Cuerpo extends StatelessWidget {
  const _Cuerpo({
    required this.sala,
    required this.miUid,
    required this.timerSeg,
    required this.onAccion,
  });

  final Sala sala;
  final String miUid;
  final int timerSeg;
  final Future<void> Function(String accion, {int? manoIdx}) onAccion;

  @override
  Widget build(BuildContext context) {
    return switch (sala.status) {
      EstadoSala.waiting => _FaseEspera(sala: sala, miUid: miUid),
      EstadoSala.betting => _FaseApuestas(sala: sala, miUid: miUid),
      EstadoSala.playing => _FaseJuego(
          sala: sala,
          miUid: miUid,
          timerSeg: timerSeg,
          onAccion: onAccion,
        ),
      EstadoSala.finished => _FaseResultados(sala: sala, miUid: miUid),
    };
  }
}

// ── Fase: waiting ─────────────────────────────────────────────────────────────

class _FaseEspera extends ConsumerWidget {
  const _FaseEspera({required this.sala, required this.miUid});
  final Sala sala;
  final String miUid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jugadores = sala.jugadoresActivos;
    final esHost = sala.hostUid == miUid;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Esperando jugadores...',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          ...jugadores.map((j) => _FilaJugador(jugador: j)),
          ...List.generate(sala.asientosLibres, (_) => const _AsientoVacio()),
          const Spacer(),
          if (esHost)
            FilledButton.icon(
              onPressed: jugadores.isNotEmpty
                  ? () => ref
                      .read(salaActionsProvider(sala.id))
                      .cambiarEstado(EstadoSala.betting)
                  : null,
              icon: const Icon(Icons.casino),
              label: const Text('Iniciar fase de apuestas'),
            ),
        ],
      ),
    );
  }
}

class _FilaJugador extends StatelessWidget {
  const _FilaJugador({required this.jugador});
  final JugadorEnSala jugador;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Text(jugador.avatar, style: const TextStyle(fontSize: 28)),
      title: Text(
        jugador.displayName,
        style: const TextStyle(color: Colors.white),
      ),
      subtitle: Text(
        dinero(jugador.balance),
        style: const TextStyle(color: Colors.white60),
      ),
      trailing: Icon(
        jugador.connected ? Icons.wifi : Icons.wifi_off,
        color: jugador.connected ? Colors.green : Colors.grey,
        size: 20,
      ),
    );
  }
}

class _AsientoVacio extends StatelessWidget {
  const _AsientoVacio();

  @override
  Widget build(BuildContext context) {
    return const ListTile(
      leading: Icon(Icons.chair, color: Colors.white24, size: 28),
      title: Text(
        'Asiento libre',
        style: TextStyle(
          color: Colors.white30,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}

// ── Fase: betting ─────────────────────────────────────────────────────────────

class _FaseApuestas extends ConsumerWidget {
  const _FaseApuestas({required this.sala, required this.miUid});
  final Sala sala;
  final String miUid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final esHost = sala.hostUid == miUid;
    final jugadores = sala.jugadoresActivos;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Fase de apuestas',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                ...jugadores.map((j) => _FilaApuesta(jugador: j)),
                if (esHost && sala.todosListos)
                  Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: FilledButton.icon(
                      onPressed: () =>
                          ref.read(salaActionsProvider(sala.id)).iniciarRonda(),
                      icon: const Icon(Icons.play_circle),
                      label: const Text('Iniciar ronda'),
                    ),
                  ),
              ],
            ),
          ),
        ),
        PanelApuestasSala(sala: sala),
      ],
    );
  }
}

class _FilaApuesta extends StatelessWidget {
  const _FilaApuesta({required this.jugador});
  final JugadorEnSala jugador;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Text(jugador.avatar, style: const TextStyle(fontSize: 26)),
      title: Text(
        jugador.displayName,
        style: const TextStyle(color: Colors.white),
      ),
      subtitle: jugador.apuesta != null
          ? Text(
              'Apuesta: ${dinero(jugador.apuesta!)}',
              style: const TextStyle(color: Colors.amber),
            )
          : const Text(
              'Sin apuesta',
              style: TextStyle(color: Colors.white38),
            ),
      trailing: Icon(
        jugador.ready ? Icons.check_circle : Icons.radio_button_unchecked,
        color: jugador.ready ? Colors.green : Colors.white30,
        size: 24,
      ),
    );
  }
}

// ── Fase: playing ─────────────────────────────────────────────────────────────

class _FaseJuego extends ConsumerWidget {
  const _FaseJuego({
    required this.sala,
    required this.miUid,
    required this.timerSeg,
    required this.onAccion,
  });

  final Sala sala;
  final String miUid;
  final int timerSeg;
  final Future<void> Function(String, {int? manoIdx}) onAccion;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gameId = sala.currentGameId;
    if (gameId == null) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text(
              'Iniciando ronda...',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      );
    }

    final partidaAsync = ref.watch(partidaProvider(gameId));

    return partidaAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(color: Colors.white)),
      error: (e, _) => Center(
        child: Text('Error: $e', style: const TextStyle(color: Colors.white)),
      ),
      data: (partida) {
        if (partida == null) {
          return const Center(
            child: Text(
              'Cargando partida...',
              style: TextStyle(color: Colors.white70),
            ),
          );
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: TapeteMultijugador(
            sala: sala,
            partida: partida,
            miUid: miUid,
            timerSeg: timerSeg,
            onAccion: (a) => onAccion(a),
          ),
        );
      },
    );
  }
}

// ── Fase: finished ────────────────────────────────────────────────────────────

class _FaseResultados extends ConsumerWidget {
  const _FaseResultados({required this.sala, required this.miUid});
  final Sala sala;
  final String miUid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final esHost = sala.hostUid == miUid;
    final gameId = sala.currentGameId;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Ronda finalizada',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          if (gameId != null)
            Consumer(
              builder: (_, ref, __) {
                final async = ref.watch(partidaProvider(gameId));
                return async.maybeWhen(
                  data: (p) => p != null
                      ? _TablaResultados(partida: p, sala: sala)
                      : const SizedBox.shrink(),
                  orElse: SizedBox.shrink,
                );
              },
            ),
          const Spacer(),
          if (esHost)
            FilledButton.icon(
              onPressed: () => ref
                  .read(salaActionsProvider(sala.id))
                  .cambiarEstado(EstadoSala.betting),
              icon: const Icon(Icons.refresh),
              label: const Text('Nueva ronda'),
            ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () async {
              await ref.read(salaActionsProvider(sala.id)).salir();
              if (context.mounted) context.pop();
            },
            style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
            child: const Text('Salir de la sala'),
          ),
        ],
      ),
    );
  }
}

class _TablaResultados extends StatelessWidget {
  const _TablaResultados({required this.partida, required this.sala});
  final EstadoPartida partida;
  final Sala sala;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: partida.players.entries.map((e) {
        final jugador = sala.players[e.key];
        final datos = e.value;
        final (color, texto) = switch (datos.result) {
          'win' => (Colors.green, 'GANÓ'),
          'blackjack' => (Colors.amber, '¡BLACKJACK!'),
          'lose' => (Colors.red, 'PERDIÓ'),
          'push' => (Colors.orange, 'EMPATE'),
          'surrender' => (Colors.grey, 'SE RINDIÓ'),
          _ => (Colors.white54, '—'),
        };
        return ListTile(
          leading: Text(
            jugador?.avatar ?? '🃏',
            style: const TextStyle(fontSize: 26),
          ),
          title: Text(
            jugador?.displayName ?? e.key,
            style: const TextStyle(color: Colors.white),
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color),
            ),
            child: Text(
              texto,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
