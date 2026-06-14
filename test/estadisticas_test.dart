// Tests del modelo de estadísticas (profile/domain): parsing tolerante y
// porcentaje de victoria. Sin Firebase ni Flutter: modelo puro.

import 'package:blackjack_21/features/profile/domain/estadisticas.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Estadisticas.fromMap', () {
    test('mapa null devuelve estadísticas en cero', () {
      final stats = Estadisticas.fromMap(null);
      expect(stats.manosJugadas, 0);
      expect(stats.ganadas, 0);
      expect(stats.totalGanado, 0);
    });

    test('mapa vacío devuelve estadísticas en cero (cuenta pre-Fase 8)', () {
      final stats = Estadisticas.fromMap(<String, dynamic>{});
      expect(stats.manosJugadas, 0);
      expect(stats.blackjacks, 0);
    });

    test('lee todos los campos presentes', () {
      final stats = Estadisticas.fromMap(<String, dynamic>{
        'manosJugadas': 10,
        'ganadas': 6,
        'perdidas': 3,
        'empates': 1,
        'blackjacks': 2,
        'mayorGanancia': 300,
        'rachaActual': 2,
        'mejorRacha': 4,
        'totalApostado': 1000,
        'totalGanado': 450,
        'xp': 320,
      });
      expect(stats.manosJugadas, 10);
      expect(stats.ganadas, 6);
      expect(stats.perdidas, 3);
      expect(stats.empates, 1);
      expect(stats.blackjacks, 2);
      expect(stats.mayorGanancia, 300);
      expect(stats.rachaActual, 2);
      expect(stats.mejorRacha, 4);
      expect(stats.totalApostado, 1000);
      expect(stats.totalGanado, 450);
      expect(stats.xp, 320);
    });

    test('xp ausente queda en 0', () {
      expect(Estadisticas.fromMap(<String, dynamic>{'ganadas': 1}).xp, 0);
    });

    test('claves faltantes quedan en 0 sin lanzar', () {
      final stats = Estadisticas.fromMap(<String, dynamic>{'ganadas': 5});
      expect(stats.ganadas, 5);
      expect(stats.perdidas, 0);
    });

    test('acepta números enteros llegados como double (Firestore num)', () {
      final stats =
          Estadisticas.fromMap(<String, dynamic>{'manosJugadas': 7.0});
      expect(stats.manosJugadas, 7);
    });
  });

  group('porcentajeVictoria', () {
    test('es 0 cuando no se ha jugado ninguna mano', () {
      expect(Estadisticas.vacias.porcentajeVictoria, 0);
    });

    test('calcula el porcentaje sobre las manos jugadas', () {
      const stats = Estadisticas(manosJugadas: 4, ganadas: 1);
      expect(stats.porcentajeVictoria, 25);
    });
  });
}
