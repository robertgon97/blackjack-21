import 'bono_diario.dart';
import 'transaccion.dart';

/// Contrato del historial de créditos. Solo lectura desde el cliente;
/// las escrituras las hace Cloud Functions (Fase 5+).
abstract interface class IWalletRepository {
  /// Stream del saldo actual del usuario autenticado.
  Stream<int> saldoStream(String uid);

  /// Stream de las últimas [limite] transacciones, orden cronológico inverso.
  Stream<List<Transaccion>> transaccionesStream(String uid, {int limite = 50});

  /// Stream del estado del bono diario del usuario [uid] (racha vigente y si ya
  /// puede reclamar hoy), derivado de `users/{uid}` (Fase 10b).
  Stream<EstadoBonoDiario> estadoBonoStream(String uid);

  /// Reclama el bono diario (una vez por día) vía Cloud Function. Devuelve el
  /// nuevo saldo, el monto acreditado y la racha. Lanza [Exception] con un
  /// mensaje en español si ya se reclamó hoy o si falla la red.
  Future<ResultadoBonoDiario> reclamarBonoDiario();
}
