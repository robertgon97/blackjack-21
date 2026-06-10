import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/formato.dart';
import '../../../auth/presentation/auth_provider.dart';
import '../../domain/modelos.dart';
import '../sala_provider.dart';

/// Panel de apuestas para la fase 'betting' de una sala multijugador.
class PanelApuestasSala extends ConsumerStatefulWidget {
  const PanelApuestasSala({
    super.key,
    required this.sala,
  });

  final Sala sala;

  @override
  ConsumerState<PanelApuestasSala> createState() => _PanelApuestasSalaState();
}

class _PanelApuestasSalaState extends ConsumerState<PanelApuestasSala> {
  int _apuesta = 0;
  bool _ocupado = false;

  Sala get sala => widget.sala;

  JugadorEnSala? get _miJugador {
    final uid = ref.read(perfilStreamProvider).valueOrNull?.uid;
    if (uid == null) return null;
    return sala.players[uid];
  }

  @override
  void initState() {
    super.initState();
    final j = _miJugador;
    if (j != null) _apuesta = j.apuesta ?? 0;
  }

  @override
  void didUpdateWidget(covariant PanelApuestasSala old) {
    super.didUpdateWidget(old);
    // Sincroniza si el valor cambió externamente.
    final j = _miJugador;
    if (j != null && !_ocupado) {
      final nueva = j.apuesta ?? 0;
      if (nueva != _apuesta) setState(() => _apuesta = nueva);
    }
  }

  Future<void> _sumar(int valor) async {
    final cfg = sala.config.configJuego;
    final balance = _miJugador?.balance ?? 0;
    final nueva = _apuesta + valor;
    if (nueva > cfg.apuestaMax) {
      _aviso('Máximo: ${dinero(cfg.apuestaMax)}');
      return;
    }
    if (nueva > balance) {
      _aviso('Saldo insuficiente.');
      return;
    }
    setState(() => _apuesta = nueva);
  }

  Future<void> _confirmar() async {
    final cfg = sala.config.configJuego;
    if (_apuesta < cfg.apuestaMin) {
      _aviso('Mínimo: ${dinero(cfg.apuestaMin)}');
      return;
    }
    setState(() => _ocupado = true);
    try {
      final actions = ref.read(salaActionsProvider(sala.id));
      await actions.establecerApuesta(_apuesta);
      await actions.marcarListo(true);
    } catch (e) {
      if (mounted) _aviso(e.toString());
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  void _aviso(String msg) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
      );
  }

  @override
  Widget build(BuildContext context) {
    final cfg = sala.config.configJuego;
    final mj = _miJugador;
    final yaListo = mj?.ready ?? false;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Tu apuesta: ${dinero(_apuesta)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            'Mín ${dinero(cfg.apuestaMin)} · Máx ${dinero(cfg.apuestaMax)}',
            style: const TextStyle(color: Colors.white60, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [10, 25, 50, 100, 200, 500].map((v) {
              return ElevatedButton(
                onPressed: yaListo ? null : () => _sumar(v),
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  backgroundColor: Colors.white.withValues(alpha: 0.12),
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white30),
                ),
                child: Text('+${dinero(v)}'),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: yaListo ? null : () => setState(() => _apuesta = 0),
                child: const Text(
                  'Limpiar',
                  style: TextStyle(color: Colors.white54),
                ),
              ),
              const SizedBox(width: 16),
              FilledButton.icon(
                onPressed: (yaListo || _ocupado) ? null : _confirmar,
                icon: yaListo
                    ? const Icon(Icons.check_circle)
                    : const Icon(Icons.casino),
                label: Text(yaListo ? 'Listo' : 'Confirmar apuesta'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
