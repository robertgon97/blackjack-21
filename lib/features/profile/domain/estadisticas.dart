/// Estadísticas de juego del usuario (capa domain — sin Firebase ni Flutter).
///
/// Las escribe la Cloud Function `playerAction` server-side en `users/{uid}.stats`
/// (anti-trampa); el cliente solo las lee. Espejo del modelo TS en
/// `functions/src/blackjack.ts` (`EstadisticasJugador`). Solo el multijugador
/// alimenta estas stats: el modo solo es client-side y no cuenta.
class Estadisticas {
  const Estadisticas({
    this.manosJugadas = 0,
    this.ganadas = 0,
    this.perdidas = 0,
    this.empates = 0,
    this.blackjacks = 0,
    this.mayorGanancia = 0,
    this.rachaActual = 0,
    this.mejorRacha = 0,
    this.totalApostado = 0,
    this.totalGanado = 0,
    this.xp = 0,
  });

  /// Manos jugadas en total (cada mano de un split cuenta por separado).
  final int manosJugadas;

  /// Manos ganadas (incluye los blackjacks).
  final int ganadas;

  /// Manos perdidas (incluye las rendiciones/surrender).
  final int perdidas;

  /// Manos que terminaron en empate (push).
  final int empates;

  /// Blackjacks logrados (también contabilizados en [ganadas]).
  final int blackjacks;

  /// Mayor ganancia neta en una sola ronda.
  final int mayorGanancia;

  /// Racha actual de rondas ganadas. Se calcula por ronda, no por mano.
  final int rachaActual;

  /// Mejor racha histórica de rondas ganadas consecutivas.
  final int mejorRacha;

  /// Total de créditos apostados en partidas multijugador.
  final int totalApostado;

  /// Total de créditos ganados (suma de los deltas positivos de las rondas).
  final int totalGanado;

  /// XP acumulada (Fase 9). El nivel se deriva de esta XP (ver `niveles.dart`).
  final int xp;

  /// Estadísticas en cero (usuario que aún no ha jugado multijugador).
  static const Estadisticas vacias = Estadisticas();

  /// Porcentaje de victorias sobre el total de manos (0–100). Devuelve 0 si no
  /// se ha jugado ninguna mano (evita la división por cero).
  double get porcentajeVictoria {
    if (manosJugadas == 0) return 0;
    return ganadas / manosJugadas * 100;
  }

  /// Construye las estadísticas desde el sub-mapa `stats` de `users/{uid}`.
  /// Tolerante a documentos sin el campo o con claves faltantes (todo a 0),
  /// para usuarios anteriores a la Fase 8.
  factory Estadisticas.fromMap(Map<String, dynamic>? data) {
    if (data == null) return Estadisticas.vacias;
    int leer(String clave) => (data[clave] as num?)?.toInt() ?? 0;
    return Estadisticas(
      manosJugadas: leer('manosJugadas'),
      ganadas: leer('ganadas'),
      perdidas: leer('perdidas'),
      empates: leer('empates'),
      blackjacks: leer('blackjacks'),
      mayorGanancia: leer('mayorGanancia'),
      rachaActual: leer('rachaActual'),
      mejorRacha: leer('mejorRacha'),
      totalApostado: leer('totalApostado'),
      totalGanado: leer('totalGanado'),
      xp: leer('xp'),
    );
  }
}
