import 'transaccion.dart';

/// Contrato del historial de créditos. Solo lectura desde el cliente;
/// las escrituras las hace Cloud Functions (Fase 5+).
abstract interface class IWalletRepository {
  /// Stream del saldo actual del usuario autenticado.
  Stream<int> saldoStream(String uid);

  /// Stream de las últimas [limite] transacciones, orden cronológico inverso.
  Stream<List<Transaccion>> transaccionesStream(String uid, {int limite = 50});

  /// Reclama el bono diario (una vez cada 24 h) vía Cloud Function. Devuelve el
  /// nuevo saldo. Lanza [Exception] con un mensaje en español si aún está en
  /// cooldown o si falla la red.
  Future<int> reclamarBonoDiario();
}
