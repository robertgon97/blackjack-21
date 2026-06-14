// Tests de la progresión por niveles (profile/domain/niveles.dart): derivación
// del nivel desde la XP y avance hacia el siguiente. Lógica pura.

import 'package:blackjack_21/features/profile/domain/niveles.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('progresoDeXp', () {
    test('XP 0 → Novato, sin avance, siguiente Aficionado', () {
      final p = progresoDeXp(0);
      expect(p.nivel.nombre, 'Novato');
      expect(p.nivel.indice, 0);
      expect(p.siguiente?.nombre, 'Aficionado');
      expect(p.fraccion, 0);
      expect(p.esMaximo, isFalse);
    });

    test('XP negativa se trata como 0', () {
      final p = progresoDeXp(-50);
      expect(p.nivel.nombre, 'Novato');
      expect(p.xp, 0);
    });

    test('a mitad de camino del primer rango → fracción 0.5', () {
      // Novato [0..200): a 100 XP, mitad del rango.
      final p = progresoDeXp(100);
      expect(p.nivel.nombre, 'Novato');
      expect(p.fraccion, closeTo(0.5, 1e-9));
      expect(p.xpRestante, 100);
    });

    test('justo en el umbral sube de nivel', () {
      expect(progresoDeXp(200).nivel.nombre, 'Aficionado');
      expect(progresoDeXp(600).nivel.nombre, 'Jugador');
    });

    test('nivel intermedio calcula la fracción dentro de su rango', () {
      // Jugador [600..1500): a 700 → (700-600)/(1500-600) = 100/900.
      final p = progresoDeXp(700);
      expect(p.nivel.nombre, 'Jugador');
      expect(p.siguiente?.nombre, 'Tiburón');
      expect(p.fraccion, closeTo(100 / 900, 1e-9));
    });

    test('nivel máximo: sin siguiente, fracción 1, sin XP restante', () {
      final p = progresoDeXp(999999);
      expect(p.nivel.nombre, 'Leyenda');
      expect(p.esMaximo, isTrue);
      expect(p.siguiente, isNull);
      expect(p.fraccion, 1);
      expect(p.xpRestante, 0);
    });
  });
}
