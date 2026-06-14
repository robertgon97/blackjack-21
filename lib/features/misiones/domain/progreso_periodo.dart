import 'mision.dart';

/// Progreso del jugador en un periodo (día o semana): contadores acumulados por
/// `playerAction` y misiones ya reclamadas. Documento
/// `users/{uid}/progreso/{periodo}` (capa domain, sin Firebase).
class ProgresoPeriodo {
  const ProgresoPeriodo({required this.contadores, required this.reclamadas});

  /// Contadores por campo de métrica (`manosJugadas`, `ganadas`, …).
  final Map<String, int> contadores;

  /// IDs de misiones ya reclamadas en este periodo.
  final Set<String> reclamadas;

  static const ProgresoPeriodo vacio =
      ProgresoPeriodo(contadores: {}, reclamadas: {});

  /// Valor acumulado de la métrica de [mision] en este periodo.
  int valorDe(Mision mision) => contadores[mision.metrica.campo] ?? 0;

  factory ProgresoPeriodo.fromMap(Map<String, dynamic>? data) {
    if (data == null) return ProgresoPeriodo.vacio;
    const campos = MetricaMision.values;
    final contadores = <String, int>{
      for (final m in campos) m.campo: (data[m.campo] as num?)?.toInt() ?? 0,
    };
    final reclamadas =
        (data['reclamadas'] as List<dynamic>?)?.whereType<String>().toSet() ??
            <String>{};
    return ProgresoPeriodo(contadores: contadores, reclamadas: reclamadas);
  }
}

/// Estado de una misión combinando su definición con el progreso del periodo.
class EstadoMision {
  const EstadoMision({
    required this.mision,
    required this.progreso,
    required this.reclamada,
  });

  final Mision mision;

  /// Progreso actual (acotado a la meta para mostrar la barra).
  final int progreso;
  final bool reclamada;

  bool get completada => progreso >= mision.meta;

  /// Lista para reclamar: completada y aún no reclamada.
  bool get reclamable => completada && !reclamada;

  /// Avance fraccional [0..1] hacia la meta.
  double get fraccion =>
      mision.meta <= 0 ? 1 : (progreso / mision.meta).clamp(0.0, 1.0);

  /// Construye el estado de [mision] a partir del [progreso] de su periodo.
  factory EstadoMision.desde(Mision mision, ProgresoPeriodo progreso) {
    return EstadoMision(
      mision: mision,
      progreso: progreso.valorDe(mision),
      reclamada: progreso.reclamadas.contains(mision.id),
    );
  }
}
