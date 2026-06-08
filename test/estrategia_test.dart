// Tests de la estrategia básica. Traducidos de tests/test.js (legacy-web).

import 'package:blackjack_21/features/game/domain/estrategia.dart';
import 'package:blackjack_21/features/game/domain/modelos.dart';
import 'package:flutter_test/flutter_test.dart';

Carta c(String valor) => Carta(Palo.picas, valor);

const opcSi = OpcionesMano(
  puedeDoblar: true,
  puedeDividir: true,
  puedeRendirse: true,
);
const opcNoR = OpcionesMano(
  puedeDoblar: true,
  puedeDividir: true,
  puedeRendirse: false,
);
const opcNada = OpcionesMano(
  puedeDoblar: false,
  puedeDividir: false,
  puedeRendirse: false,
);

void main() {
  group('Estrategia básica', () {
    test('8,8 -> dividir', () {
      expect(
        consejoEstrategia([c('8'), c('8')], c('6'), opcSi),
        Jugada.dividir,
      );
    });
    test('10,10 -> plantarse', () {
      expect(
        consejoEstrategia([c('10'), c('Q')], c('6'), opcSi),
        Jugada.plantarse,
      );
    });
    test('A,A -> dividir', () {
      expect(
        consejoEstrategia([c('A'), c('A')], c('6'), opcSi),
        Jugada.dividir,
      );
    });
    test('11 vs 6 -> doblar', () {
      expect(consejoEstrategia([c('5'), c('6')], c('6'), opcSi), Jugada.doblar);
    });
    test('16 vs 10 sin rendir -> pedir', () {
      expect(
        consejoEstrategia([c('10'), c('6')], c('10'), opcNoR),
        Jugada.pedir,
      );
    });
    test('16 vs 10 con rendir -> rendirse', () {
      expect(
        consejoEstrategia([c('10'), c('6')], c('10'), opcSi),
        Jugada.rendirse,
      );
    });
    test('A,7 vs 9 -> pedir', () {
      expect(consejoEstrategia([c('A'), c('7')], c('9'), opcSi), Jugada.pedir);
    });
    test('A,7 vs 6 -> doblar', () {
      expect(consejoEstrategia([c('A'), c('7')], c('6'), opcSi), Jugada.doblar);
    });
    test('20 duro -> plantarse', () {
      expect(
        consejoEstrategia([c('10'), c('K')], c('5'), opcNada),
        Jugada.plantarse,
      );
    });
  });
}
