import 'estadisticas.dart';

/// Contrato de lectura del perfil de juego. La capa data lo implementa sobre
/// Firestore; presentación y domain solo conocen esta abstracción.
abstract interface class IProfileRepository {
  /// Stream en tiempo real de las estadísticas del usuario [uid].
  ///
  /// Emite [Estadisticas.vacias] mientras el usuario no tenga el sub-mapa
  /// `stats` (cuentas anteriores a la Fase 8 o sin partidas multijugador).
  Stream<Estadisticas> estadisticasStream(String uid);
}
