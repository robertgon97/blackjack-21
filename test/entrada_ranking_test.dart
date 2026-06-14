// Tests del modelo del ranking semanal (leaderboards/domain). Parsing tolerante
// y selección de la métrica. Lógica pura.

import 'package:blackjack_21/features/leaderboards/domain/entrada_ranking.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EntradaRanking.fromMap', () {
    test('lee los campos presentes', () {
      final e = EntradaRanking.fromMap('u1', {
        'displayName': 'Ana',
        'avatar': '😎',
        'gananciaNeta': 1200,
        'manosGanadas': 9,
        'mejorRacha': 4,
      });
      expect(e.uid, 'u1');
      expect(e.displayName, 'Ana');
      expect(e.avatar, '😎');
      expect(e.gananciaNeta, 1200);
      expect(e.manosGanadas, 9);
      expect(e.mejorRacha, 4);
    });

    test('aplica defaults a campos ausentes', () {
      final e = EntradaRanking.fromMap('u2', <String, dynamic>{});
      expect(e.displayName, 'Jugador');
      expect(e.avatar, '🃏');
      expect(e.gananciaNeta, 0);
      expect(e.manosGanadas, 0);
      expect(e.mejorRacha, 0);
    });

    test('acepta ganancia neta negativa', () {
      final e = EntradaRanking.fromMap('u3', {'gananciaNeta': -300});
      expect(e.gananciaNeta, -300);
    });
  });

  group('valor', () {
    test('devuelve el campo correspondiente a cada métrica', () {
      const e = EntradaRanking(
        uid: 'u',
        displayName: 'x',
        avatar: '🃏',
        gananciaNeta: 500,
        manosGanadas: 7,
        mejorRacha: 3,
      );
      expect(e.valor(MetricaRanking.gananciaNeta), 500);
      expect(e.valor(MetricaRanking.manosGanadas), 7);
      expect(e.valor(MetricaRanking.mejorRacha), 3);
    });
  });
}
