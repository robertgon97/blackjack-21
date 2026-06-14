// Tests del bono diario con racha (wallet/domain/bono_diario.dart). Lógica pura;
// espejo de la fórmula de functions/src/dailyBonus.ts.

import 'package:blackjack_21/features/wallet/domain/bono_diario.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('montoPorRacha', () {
    test('día 1 es el monto base', () {
      expect(montoPorRacha(1), montoBaseBono);
    });

    test('crece de forma lineal por día', () {
      expect(montoPorRacha(2), montoBaseBono + incrementoBono);
      expect(montoPorRacha(3), montoBaseBono + 2 * incrementoBono);
    });

    test('se topa en el día tope y no crece más', () {
      final maximo = montoPorRacha(topeRachaBono);
      expect(montoPorRacha(topeRachaBono + 1), maximo);
      expect(montoPorRacha(99), maximo);
    });

    test('rachas <= 0 se tratan como día 1', () {
      expect(montoPorRacha(0), montoBaseBono);
      expect(montoPorRacha(-5), montoBaseBono);
    });
  });

  group('EstadoBonoDiario.montoAlReclamar', () {
    test('disponible: cuenta el día siguiente de la racha vigente', () {
      const e = EstadoBonoDiario(racha: 3, disponibleHoy: true);
      expect(e.montoAlReclamar, montoPorRacha(4));
    });

    test('disponible con racha 0: cuenta como día 1', () {
      const e = EstadoBonoDiario(racha: 0, disponibleHoy: true);
      expect(e.montoAlReclamar, montoPorRacha(1));
    });

    test('no disponible: refleja el día ya reclamado', () {
      const e = EstadoBonoDiario(racha: 3, disponibleHoy: false);
      expect(e.montoAlReclamar, montoPorRacha(3));
    });
  });
}
