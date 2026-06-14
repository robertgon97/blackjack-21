/// Bono diario con racha (Fase 10b — capa domain, sin Flutter ni Firebase).
library;

/// Recompensa del día 1 de la racha.
const int montoBaseBono = 500;

/// Incremento por cada día consecutivo.
const int incrementoBono = 100;

/// Día de la racha a partir del cual la recompensa deja de crecer.
const int topeRachaBono = 7;

/// Recompensa del día [racha] de la racha (creciente, con tope). Espejo de
/// `montoPorRacha` en `functions/src/dailyBonus.ts`.
int montoPorRacha(int racha) {
  final dia = racha.clamp(1, topeRachaBono);
  return montoBaseBono + (dia - 1) * incrementoBono;
}

/// Resultado de reclamar el bono diario: saldo nuevo, monto acreditado y racha.
class ResultadoBonoDiario {
  const ResultadoBonoDiario({
    required this.balance,
    required this.monto,
    required this.racha,
  });

  final int balance;
  final int monto;
  final int racha;
}

/// Estado del bono diario para la UI (antes de reclamar).
class EstadoBonoDiario {
  const EstadoBonoDiario({required this.racha, required this.disponibleHoy});

  /// Racha vigente de días consecutivos (0 si se rompió y aún no se reclamó).
  final int racha;

  /// `true` si el usuario aún no ha reclamado hoy.
  final bool disponibleHoy;

  /// Recompensa que recibiría al reclamar ahora (día siguiente de la racha
  /// vigente, o día 1 si está rota o vacía).
  int get montoAlReclamar => montoPorRacha(disponibleHoy ? racha + 1 : racha);

  static const EstadoBonoDiario inicial =
      EstadoBonoDiario(racha: 0, disponibleHoy: true);
}
