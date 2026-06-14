// Tests del identificador de semana ISO-8601 (core/utils/semana.dart). Casos
// borde de fin/inicio de año, donde la semana ISO no coincide con el año natural.

import 'package:blackjack_21/core/utils/semana.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('idSemanaIso', () {
    test('todos los días de una misma semana dan el mismo id', () {
      // 2026-06-08 (lunes) … 2026-06-14 (domingo) son la misma semana ISO.
      final id = idSemanaIso(DateTime.utc(2026, 6, 8));
      for (var dia = 8; dia <= 14; dia++) {
        expect(idSemanaIso(DateTime.utc(2026, 6, dia)), id);
      }
    });

    test('la semana 1 es la que contiene el primer jueves del año', () {
      // 2026-01-01 es jueves → W01.
      expect(idSemanaIso(DateTime.utc(2026, 1, 1)), '2026-W01');
      // 2025-12-29 (lunes) pertenece a esa misma semana ISO → también 2026-W01.
      expect(idSemanaIso(DateTime.utc(2025, 12, 29)), '2026-W01');
    });

    test('fin de año puede caer en la semana del año contiguo', () {
      // 2027-01-01 (viernes): su jueves cae en 2026 → 2026-W53.
      expect(idSemanaIso(DateTime.utc(2027, 1, 1)), '2026-W53');
      // 2024-01-01 (lunes): su jueves es 2024-01-04 → 2024-W01.
      expect(idSemanaIso(DateTime.utc(2024, 1, 1)), '2024-W01');
    });

    test('el número de semana se rellena a dos dígitos', () {
      expect(idSemanaIso(DateTime.utc(2026, 1, 5)), '2026-W02');
    });
  });
}
