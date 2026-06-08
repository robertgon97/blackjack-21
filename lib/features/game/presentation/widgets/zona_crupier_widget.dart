// ============================================================
//  Zona del crupier: sus cartas y su puntaje
// ============================================================

import 'package:flutter/material.dart';

import '../../domain/cartas.dart';
import '../../domain/modelos.dart';
import 'carta_widget.dart';

/// Muestra la mano del crupier. Si [oculto], la primera carta va boca abajo
/// y el puntaje aparece como "?".
class ZonaCrupierWidget extends StatelessWidget {
  final List<Carta> cartas;
  final bool oculto;

  const ZonaCrupierWidget({
    super.key,
    required this.cartas,
    required this.oculto,
  });

  @override
  Widget build(BuildContext context) {
    final puntosTexto =
        cartas.isEmpty ? '0' : (oculto ? '?' : '${calcularPuntos(cartas)}');

    return Column(
      children: [
        _Etiqueta(texto: 'Crupier', puntos: puntosTexto),
        const SizedBox(height: 8),
        SizedBox(
          height: CartaWidget.altoPara(CartaWidget.anchoDefecto),
          child: cartas.isEmpty
              ? const SizedBox.shrink()
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < cartas.length; i++)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        // La primera carta va oculta mientras [oculto].
                        child: CartaWidget(
                          carta: (i == 0 && oculto) ? null : cartas[i],
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _Etiqueta extends StatelessWidget {
  final String texto;
  final String puntos;

  const _Etiqueta({required this.texto, required this.puntos});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          texto,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            puntos,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
