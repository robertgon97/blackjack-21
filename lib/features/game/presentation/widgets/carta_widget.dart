// ============================================================
//  Widget de una carta (cara visible o reverso boca abajo)
// ============================================================

import 'package:flutter/material.dart';

import '../../domain/modelos.dart';

/// Pinta una [Carta] del juego. Si [carta] es null, muestra el reverso
/// (carta boca abajo del crupier).
class CartaWidget extends StatelessWidget {
  final Carta? carta;

  /// Ancho de la carta; el alto se calcula con proporción de naipe (~1.4).
  final double ancho;

  const CartaWidget({super.key, required this.carta, this.ancho = 64});

  @override
  Widget build(BuildContext context) {
    final alto = ancho * 1.42;
    if (carta == null) return _reverso(alto);
    return _cara(context, alto);
  }

  bool get _esRoja =>
      carta!.palo == Palo.corazones || carta!.palo == Palo.diamantes;

  Widget _cara(BuildContext context, double alto) {
    final color = _esRoja ? const Color(0xFFD32F2F) : const Color(0xFF1A1A1A);
    return Container(
      width: ancho,
      height: alto,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ancho * 0.12),
        boxShadow: const [
          BoxShadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      padding: EdgeInsets.all(ancho * 0.08),
      child: Stack(
        children: [
          // Esquina superior izquierda: valor + palo.
          Align(
            alignment: Alignment.topLeft,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  carta!.valor,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: ancho * 0.26,
                    height: 1,
                  ),
                ),
                Text(
                  carta!.palo.simbolo,
                  style: TextStyle(
                    color: color,
                    fontSize: ancho * 0.22,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
          // Palo grande centrado.
          Center(
            child: Text(
              carta!.palo.simbolo,
              style: TextStyle(color: color, fontSize: ancho * 0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _reverso(double alto) {
    return Container(
      width: ancho,
      height: alto,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(ancho * 0.12),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3949AB), Color(0xFF1A237E)],
        ),
        border: Border.all(color: Colors.white70, width: 2),
        boxShadow: const [
          BoxShadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Center(
        child: Text(
          '♠',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.35),
            fontSize: ancho * 0.5,
          ),
        ),
      ),
    );
  }
}
