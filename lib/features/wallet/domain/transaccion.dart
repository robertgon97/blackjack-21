/// Tipos de movimiento de créditos definidos en las reglas de negocio.
enum TipoTransaccion {
  win,
  loss,
  push,
  transferIn,
  transferOut,
  adReward,
  bonusRegistro,
  bonusInvitacion,
  bonusConversion,
}

/// Un movimiento de créditos del historial del usuario.
class Transaccion {
  const Transaccion({
    required this.id,
    required this.tipo,
    required this.monto,
    required this.balanceAfter,
    required this.descripcion,
    required this.fecha,
    this.gameId,
    this.fromUid,
    this.toUid,
  });

  final String id;
  final TipoTransaccion tipo;

  /// Monto del movimiento (siempre positivo; el tipo indica dirección).
  final int monto;
  final int balanceAfter;
  final String descripcion;
  final DateTime fecha;
  final String? gameId;
  final String? fromUid;
  final String? toUid;

  bool get esIngreso => switch (tipo) {
        TipoTransaccion.win ||
        TipoTransaccion.push ||
        TipoTransaccion.transferIn ||
        TipoTransaccion.adReward ||
        TipoTransaccion.bonusRegistro ||
        TipoTransaccion.bonusInvitacion ||
        TipoTransaccion.bonusConversion =>
          true,
        _ => false,
      };
}
