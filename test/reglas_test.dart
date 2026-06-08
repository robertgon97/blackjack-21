// Tests de las reglas: empuje en 22, rendición, H17 y pago del blackjack.
// Traducidos de tests/test.js (legacy-web).

import 'package:blackjack_21/features/game/domain/modelos.dart';
import 'package:blackjack_21/features/game/domain/reglas.dart';
import 'package:flutter_test/flutter_test.dart';

Carta c(String valor) => Carta(Palo.picas, valor);

void main() {
  group('Empuje en 22', () {
    final crupier22 = [c('K'), c('7'), c('5')]; // 22
    final mano = const Mano(cartas: [], apuesta: 10)
        .copyWith(cartas: [c('10'), c('10')]);

    test('con empuje22: crupier 22 = empate', () {
      final r = resolverMano(
        mano: mano,
        manoCrupier: crupier22,
        config: const ConfigJuego(empujeEn22: true),
        esUnicaMano: true,
      );
      expect(r.estado, EstadoMano.empate);
    });
    test('sin empuje22: crupier 22 = ganar', () {
      final r = resolverMano(
        mano: mano,
        manoCrupier: crupier22,
        config: const ConfigJuego(empujeEn22: false),
        esUnicaMano: true,
      );
      expect(r.estado, EstadoMano.ganar);
    });
  });

  group('Rendición', () {
    test('rendirse devuelve la mitad de la apuesta', () {
      final mano = Mano(cartas: [c('10'), c('6')], apuesta: 100, rendida: true);
      final r = resolverMano(
        mano: mano,
        manoCrupier: [c('10'), c('7')],
        config: const ConfigJuego(),
        esUnicaMano: true,
      );
      expect(r.ganancia, 50);
    });
  });

  group('Regla del crupier (H17/S17)', () {
    test('H17: el crupier pide con 17 suave', () {
      final pide = debePedirCrupier(
        [c('A'), c('6')],
        const ConfigJuego(crupierPideEn17Suave: true),
      );
      expect(pide, isTrue);
    });
    test('S17: el crupier se planta con 17 suave', () {
      final pide = debePedirCrupier(
        [c('A'), c('6')],
        const ConfigJuego(crupierPideEn17Suave: false),
      );
      expect(pide, isFalse);
    });
    test('el crupier pide con 16 duro', () {
      expect(debePedirCrupier([c('10'), c('6')], const ConfigJuego()), isTrue);
    });
  });

  group('Pago del blackjack', () {
    final manoBJ = Mano(cartas: [c('A'), c('K')], apuesta: 100);
    final crupier16 = [c('9'), c('7')]; // 16, el jugador gana con BJ

    test('BJ 3:2 paga 250 (100 + 150)', () {
      final r = resolverMano(
        mano: manoBJ,
        manoCrupier: crupier16,
        config: const ConfigJuego(pagoBlackjack: 1.5),
        esUnicaMano: true,
      );
      expect(r.esBlackjack, isTrue);
      expect(r.ganancia, 250);
    });
    test('BJ 6:5 paga 220 (100 + 120)', () {
      final r = resolverMano(
        mano: manoBJ,
        manoCrupier: crupier16,
        config: const ConfigJuego(pagoBlackjack: 1.2),
        esUnicaMano: true,
      );
      expect(r.ganancia, 220);
    });
  });
}
