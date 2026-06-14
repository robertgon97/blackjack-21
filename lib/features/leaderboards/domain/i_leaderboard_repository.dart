import 'entrada_ranking.dart';

/// Contrato de lectura del leaderboard semanal. La capa data lo implementa sobre
/// Firestore (periodo = semana ISO actual); presentación solo conoce esta
/// abstracción.
abstract interface class ILeaderboardRepository {
  /// Top global de la semana actual por [metrica], de mayor a menor.
  Stream<List<EntradaRanking>> topGlobal(MetricaRanking metrica, {int limite});

  /// Entradas de la semana actual de los jugadores [uids] (amigos + uno mismo),
  /// ya ordenadas por [metrica] de mayor a menor. Omite a quienes no tengan
  /// entrada esta semana.
  Future<List<EntradaRanking>> topAmigos(
    List<String> uids,
    MetricaRanking metrica,
  );

  /// Entrada del usuario [uid] en la semana actual, o `null` si no jugó esta
  /// semana.
  Future<EntradaRanking?> entradaDe(String uid);

  /// Posición global (1-based) en [metrica] de quien tiene el valor [miValor]:
  /// cuántas entradas lo superan, más uno.
  Future<int> posicionGlobal(MetricaRanking metrica, int miValor);
}
