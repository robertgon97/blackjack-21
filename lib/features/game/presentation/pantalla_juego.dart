// ============================================================
//  Pantalla principal del juego solo (jugador vs crupier)
//
//  Ensambla el tapete: barra superior, zona del crupier, manos
//  del jugador, ayudas y el panel de control según la fase.
// ============================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/temas.dart';
import '../../../core/utils/formato.dart';
import '../../auth/presentation/widgets/banner_conversion.dart';
import 'controlador_juego.dart';
import 'estado_juego.dart';
import 'widgets/barra_estado.dart';
import 'widgets/botones_accion.dart';
import 'widgets/mano_jugador_widget.dart';
import 'widgets/panel_apuestas.dart';
import 'widgets/zona_crupier_widget.dart';

class PantallaJuego extends ConsumerWidget {
  const PantallaJuego({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(controladorJuegoProvider);
    final tapete = context.tapete;

    // Avisos transitorios (toasts) emitidos por el controlador.
    ref.listen<int>(
      controladorJuegoProvider.select((e) => e.avisoSeq),
      (anterior, actual) {
        final aviso = ref.read(controladorJuegoProvider).aviso;
        if (aviso == null) return;
        final messenger = ScaffoldMessenger.of(context);
        messenger
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: Text(aviso),
              duration: const Duration(seconds: 2),
            ),
          );
      },
    );

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.0,
            colors: [tapete.tapete1, tapete.tapete2],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const BarraEstado(),
                const BannerConversion(),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        const SizedBox(height: 16),
                        ZonaCrupierWidget(
                          cartas: estado.manoCrupier,
                          oculto: estado.crupierOculto,
                        ),
                        const SizedBox(height: 20),
                        _Mensaje(estado: estado),
                        const SizedBox(height: 20),
                        ManoJugadorWidget(
                          manos: estado.manos,
                          indiceMano: estado.indiceMano,
                          resaltarActiva: estado.fase == FaseJuego.jugando,
                          acento: tapete.acento,
                        ),
                        const SizedBox(height: 12),
                        _Ayudas(estado: estado),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _PanelControl(estado: estado),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Mensaje guía + monto del resultado (cuando la ronda terminó).
class _Mensaje extends StatelessWidget {
  final EstadoJuego estado;

  const _Mensaje({required this.estado});

  @override
  Widget build(BuildContext context) {
    final colorResultado = switch (estado.signoResultado) {
      SignoResultado.positivo => const Color(0xFF81C784),
      SignoResultado.negativo => const Color(0xFFE57373),
      SignoResultado.neutro => Colors.white,
    };
    return Column(
      children: [
        Text(
          estado.mensaje,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        if (estado.resultadoNeto != null) ...[
          const SizedBox(height: 6),
          Text(
            dineroConSigno(estado.resultadoNeto!),
            style: TextStyle(
              color: colorResultado,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ],
    );
  }
}

/// Consejo de estrategia y probabilidad de pasarse.
class _Ayudas extends StatelessWidget {
  final EstadoJuego estado;

  const _Ayudas({required this.estado});

  @override
  Widget build(BuildContext context) {
    if (estado.consejo.isEmpty && estado.probabilidad.isEmpty) {
      return const SizedBox.shrink();
    }
    final acento = context.tapete.acento;
    return Column(
      children: [
        if (estado.consejo.isNotEmpty)
          Text(
            estado.consejo,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: acento,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        if (estado.probabilidad.isNotEmpty)
          Text(
            estado.probabilidad,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
      ],
    );
  }
}

/// Zona inferior de controles, que cambia según la fase del juego.
class _PanelControl extends ConsumerWidget {
  final EstadoJuego estado;

  const _PanelControl({required this.estado});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctrl = ref.read(controladorJuegoProvider.notifier);
    final acento = context.tapete.acento;

    switch (estado.fase) {
      case FaseJuego.apuestas:
        return const PanelApuestas();
      case FaseJuego.jugando:
        return const BotonesAccion();
      case FaseJuego.seguro:
        return Wrap(
          spacing: 12,
          alignment: WrapAlignment.center,
          children: [
            FilledButton(
              onPressed: () => unawaited(ctrl.tomarSeguro(true)),
              child: const Text('Tomar seguro'),
            ),
            OutlinedButton(
              onPressed: () => unawaited(ctrl.tomarSeguro(false)),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
              child: const Text('No, gracias'),
            ),
          ],
        );
      case FaseJuego.resultado:
        if (estado.sinDinero) {
          return FilledButton.icon(
            onPressed: ctrl.pedirPrestamo,
            style: FilledButton.styleFrom(
              backgroundColor: acento,
              foregroundColor: Colors.black,
            ),
            icon: const Icon(Icons.savings),
            label: const Text('Pedir préstamo (\$500)'),
          );
        }
        return FilledButton.icon(
          onPressed: ctrl.nuevaRonda,
          style: FilledButton.styleFrom(
            backgroundColor: acento,
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
            textStyle:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          icon: const Icon(Icons.refresh),
          label: const Text('NUEVA MANO'),
        );
    }
  }
}
