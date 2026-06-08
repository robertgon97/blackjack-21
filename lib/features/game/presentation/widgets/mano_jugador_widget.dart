// ============================================================
//  Zona del jugador: una o varias manos (tras dividir)
// ============================================================

import 'package:flutter/material.dart';

import '../../domain/cartas.dart';
import '../../domain/modelos.dart';
import 'carta_widget.dart';

/// Muestra todas las manos del jugador en fila. Resalta la mano activa
/// cuando [resaltarActiva] está activo (turno del jugador).
class ManoJugadorWidget extends StatelessWidget {
  final List<Mano> manos;
  final int indiceMano;
  final bool resaltarActiva;
  final Color acento;

  const ManoJugadorWidget({
    super.key,
    required this.manos,
    required this.indiceMano,
    required this.resaltarActiva,
    required this.acento,
  });

  @override
  Widget build(BuildContext context) {
    if (manos.isEmpty) {
      return SizedBox(height: CartaWidget.altoPara(CartaWidget.anchoDefecto));
    }
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 16,
      runSpacing: 12,
      children: [
        for (var i = 0; i < manos.length; i++)
          _ManoUnica(
            mano: manos[i],
            indice: i,
            multiple: manos.length > 1,
            activa: resaltarActiva && i == indiceMano,
            acento: acento,
          ),
      ],
    );
  }
}

class _ManoUnica extends StatelessWidget {
  final Mano mano;
  final int indice;
  final bool multiple;
  final bool activa;
  final Color acento;

  const _ManoUnica({
    required this.mano,
    required this.indice,
    required this.multiple,
    required this.activa,
    required this.acento,
  });

  @override
  Widget build(BuildContext context) {
    final puntos = calcularPuntos(mano.cartas);
    final pasado = puntos > 21;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: activa ? acento : Colors.transparent,
          width: 2,
        ),
        color:
            activa ? Colors.black.withValues(alpha: 0.18) : Colors.transparent,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: CartaWidget.altoPara(CartaWidget.anchoDefecto),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final carta in mano.cartas)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: CartaWidget(carta: carta),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (multiple)
                _Insignia(texto: 'Mano ${indice + 1}', color: acento),
              _Insignia(
                texto: pasado ? 'Pasó $puntos' : '$puntos',
                color: pasado ? const Color(0xFFD32F2F) : Colors.white,
              ),
              Text(
                '\$${mano.apuesta}',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              if (mano.doblada)
                const _Insignia(texto: 'x2', color: Colors.white),
              if (mano.rendida)
                const _Insignia(texto: 'Rendida', color: Colors.white54),
            ],
          ),
        ],
      ),
    );
  }
}

class _Insignia extends StatelessWidget {
  final String texto;
  final Color color;

  const _Insignia({required this.texto, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        texto,
        style: TextStyle(
          color: color,
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
