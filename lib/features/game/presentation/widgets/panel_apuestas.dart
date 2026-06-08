// ============================================================
//  Panel de apuestas: fichas y botón de repartir
// ============================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/temas.dart';
import '../controlador_juego.dart';

/// Fichas para apostar y controles de la fase de apuestas.
class PanelApuestas extends ConsumerWidget {
  const PanelApuestas({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(controladorJuegoProvider);
    final ctrl = ref.read(controladorJuegoProvider.notifier);
    final acento = context.tapete.acento;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Apuesta: \$${estado.apuesta}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: WrapAlignment.center,
          children: [
            for (final valor in denominacionesFicha)
              _Ficha(
                valor: valor,
                acento: acento,
                onTap: () => ctrl.sumarFicha(valor),
              ),
          ],
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            _BotonChico(texto: 'Limpiar', onTap: ctrl.limpiarApuesta),
            _BotonChico(texto: 'Repetir', onTap: ctrl.repetirApuesta),
            _BotonChico(texto: 'x2', onTap: ctrl.doblarApuestaPendiente),
          ],
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: estado.apuesta >= estado.config.apuestaMin
              ? () => unawaited(ctrl.repartir())
              : null,
          style: FilledButton.styleFrom(
            backgroundColor: acento,
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
            textStyle:
                const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          icon: const Icon(Icons.style),
          label: const Text('REPARTIR'),
        ),
      ],
    );
  }
}

class _Ficha extends StatelessWidget {
  final int valor;
  final Color acento;
  final VoidCallback onTap;

  const _Ficha({
    required this.valor,
    required this.acento,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF1A1A1A),
          border: Border.all(color: acento, width: 3),
          boxShadow: const [
            BoxShadow(
              color: Colors.black54,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          '\$$valor',
          style: TextStyle(
            color: acento,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}

class _BotonChico extends StatelessWidget {
  final String texto;
  final VoidCallback onTap;

  const _BotonChico({required this.texto, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: const BorderSide(color: Colors.white38),
      ),
      child: Text(texto),
    );
  }
}
