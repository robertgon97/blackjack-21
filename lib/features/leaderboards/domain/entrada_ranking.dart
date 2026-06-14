/// Modelo del ranking semanal (Fase 10 — capa domain, sin Flutter ni Firebase).
library;

/// Métrica por la que se ordena un leaderboard. `campo` es el nombre del campo
/// en `leaderboards/{periodo}/entries/{uid}` que escribe `playerAction`.
enum MetricaRanking {
  gananciaNeta('gananciaNeta', 'Ganancia'),
  manosGanadas('manosGanadas', 'Manos ganadas'),
  mejorRacha('mejorRacha', 'Mejor racha');

  const MetricaRanking(this.campo, this.etiqueta);

  final String campo;
  final String etiqueta;
}

/// Una entrada del leaderboard semanal: los datos denormalizados del jugador y
/// sus métricas acumuladas en la semana.
class EntradaRanking {
  const EntradaRanking({
    required this.uid,
    required this.displayName,
    required this.avatar,
    required this.gananciaNeta,
    required this.manosGanadas,
    required this.mejorRacha,
  });

  final String uid;
  final String displayName;
  final String avatar;

  /// Créditos netos ganados en la semana (puede ser negativo).
  final int gananciaNeta;

  /// Manos ganadas en la semana (acumulado).
  final int manosGanadas;

  /// Mayor racha de victorias consecutivas alcanzada en la semana.
  final int mejorRacha;

  /// Valor de la [metrica] indicada (para ordenar y mostrar).
  int valor(MetricaRanking metrica) => switch (metrica) {
        MetricaRanking.gananciaNeta => gananciaNeta,
        MetricaRanking.manosGanadas => manosGanadas,
        MetricaRanking.mejorRacha => mejorRacha,
      };

  factory EntradaRanking.fromMap(String uid, Map<String, dynamic> d) {
    int leer(String k) => (d[k] as num?)?.toInt() ?? 0;
    return EntradaRanking(
      uid: uid,
      displayName: d['displayName'] as String? ?? 'Jugador',
      avatar: d['avatar'] as String? ?? '🃏',
      gananciaNeta: leer('gananciaNeta'),
      manosGanadas: leer('manosGanadas'),
      mejorRacha: leer('mejorRacha'),
    );
  }
}
