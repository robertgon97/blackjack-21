import 'transaccion.dart';

/// Contrato del historial de créditos. Solo lectura desde el cliente;
/// las escrituras las hace Cloud Functions (Fase 5+).
abstract interface class IWalletRepository {
  /// Stream del saldo actual del usuario autenticado.
  Stream<int> saldoStream(String uid);

  /// Stream de las últimas [limite] transacciones, orden cronológico inverso.
  Stream<List<Transaccion>> transaccionesStream(String uid, {int limite = 50});
}
