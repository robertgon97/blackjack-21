import 'progreso_periodo.dart';

/// Contrato de las misiones. La capa data lo implementa sobre Firestore +
/// Cloud Functions; presentación solo conoce esta abstracción.
abstract interface class IMisionesRepository {
  /// Stream del progreso del usuario [uid] en el periodo [periodoId] (día UTC o
  /// semana ISO). Emite [ProgresoPeriodo.vacio] si aún no hay documento.
  Stream<ProgresoPeriodo> progresoStream(String uid, String periodoId);

  /// Reclama la recompensa de la misión [missionId] vía Cloud Function. Devuelve
  /// el nuevo saldo. Lanza [Exception] con un mensaje en español si la misión no
  /// está completada, ya se reclamó, o falla la red.
  Future<int> reclamarMision(String missionId);
}
