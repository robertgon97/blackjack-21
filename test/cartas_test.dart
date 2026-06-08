// Tests de la lógica de cartas: puntos, manos suaves, split, conteo Hi-Lo,
// shoe y probabilidad de pasarse. Traducidos de tests/test.js (legacy-web).

import 'dart:math';

import 'package:blackjack_21/features/game/domain/cartas.dart';
import 'package:blackjack_21/features/game/domain/modelos.dart';
import 'package:flutter_test/flutter_test.dart';

/// Atajo para crear una carta (el palo no afecta a los puntos).
Carta c(String valor) => Carta(Palo.picas, valor);

void main() {
  group('Puntos', () {
    test('As+K = 21', () {
      expect(calcularPuntos([c('A'), c('K')]), 21);
    });
    test('A+A+9 = 21', () {
      expect(calcularPuntos([c('A'), c('A'), c('9')]), 21);
    });
    test('K+Q+5 = 25 (pasado)', () {
      expect(calcularPuntos([c('K'), c('Q'), c('5')]), 25);
    });
    test('A+6 es suave 17', () {
      final info = infoMano([c('A'), c('6')]);
      expect(info.suave, isTrue);
      expect(info.total, 17);
    });
    test('A+6+10 NO es suave', () {
      expect(infoMano([c('A'), c('6'), c('10')]).suave, isFalse);
    });
  });

  group('Split', () {
    test('10 y K se dividen', () {
      expect(mismoValorSplit(c('10'), c('K')), isTrue);
    });
    test('8 y 9 NO se dividen', () {
      expect(mismoValorSplit(c('8'), c('9')), isFalse);
    });
  });

  group('Conteo Hi-Lo', () {
    test('conteo 5 = +1', () => expect(valorConteo(c('5')), 1));
    test('conteo K = -1', () => expect(valorConteo(c('K')), -1));
    test('conteo 8 = 0', () => expect(valorConteo(c('8')), 0));
  });

  group('Shoe', () {
    test('shoe de 6 barajas = 312 cartas', () {
      final shoe = Shoe(6, random: Random(1));
      expect(shoe.cartasRestantes, 312);
    });
    test('shoe recién creado no necesita barajar', () {
      final shoe = Shoe(6, random: Random(1));
      expect(shoe.necesitaBarajar, isFalse);
    });
    test('sacarCarta reduce las cartas restantes', () {
      final shoe = Shoe(1, random: Random(1));
      final antes = shoe.cartasRestantes;
      shoe.sacarCarta();
      expect(shoe.cartasRestantes, antes - 1);
    });
  });

  group('Probabilidad de pasarse', () {
    final restantes = Shoe(6, random: Random(1)).restantes;
    test('12 tiene menos riesgo que 20', () {
      final p12 = probabilidadPasarse([c('10'), c('2')], restantes);
      final p20 = probabilidadPasarse([c('10'), c('10')], restantes);
      expect(p12 < p20, isTrue);
    });
    test('20 tiene alto riesgo (>0.6)', () {
      final p20 = probabilidadPasarse([c('10'), c('10')], restantes);
      expect(p20 > 0.6, isTrue);
    });
  });
}
