/// Progresión por niveles (Fase 9 — capa domain, sin Flutter ni Firebase).
///
/// Migrado de `legacy-web/js/stats.js` (`NIVELES`, `nivelActual`), pero el nivel
/// se deriva de la **XP acumulada** (no de la banca, como en el legacy): la XP la
/// otorga la Cloud Function `playerAction` al resolver rondas.
library;

/// Un nivel de progresión: un nombre y la XP mínima para alcanzarlo.
class Nivel {
  const Nivel(this.indice, this.nombre, this.xpMin);

  /// Posición en la escala (0 = primero).
  final int indice;
  final String nombre;

  /// XP mínima para estar en este nivel.
  final int xpMin;
}

/// Escala de niveles, de menor a mayor XP. Nombres conservados del legacy.
const List<Nivel> niveles = [
  Nivel(0, 'Novato', 0),
  Nivel(1, 'Aficionado', 200),
  Nivel(2, 'Jugador', 600),
  Nivel(3, 'Tiburón', 1500),
  Nivel(4, 'Alto Roller', 4000),
  Nivel(5, 'Leyenda', 10000),
];

/// Progreso del jugador derivado de su XP: nivel actual, siguiente nivel (o
/// `null` si ya es el máximo) y el avance fraccional hacia el siguiente [0..1].
class ProgresoNivel {
  const ProgresoNivel({
    required this.xp,
    required this.nivel,
    required this.siguiente,
    required this.fraccion,
  });

  final int xp;
  final Nivel nivel;

  /// Siguiente nivel, o `null` si [nivel] ya es el máximo.
  final Nivel? siguiente;

  /// Avance hacia el siguiente nivel en [0..1]. Es 1.0 en el nivel máximo.
  final double fraccion;

  /// XP que falta para el siguiente nivel; 0 si ya es el máximo.
  int get xpRestante => siguiente == null ? 0 : siguiente!.xpMin - xp;

  /// `true` si está en el nivel máximo de la escala.
  bool get esMaximo => siguiente == null;
}

/// Calcula el [ProgresoNivel] para una cantidad de [xp]. La XP negativa se trata
/// como 0.
ProgresoNivel progresoDeXp(int xp) {
  final xpSegura = xp < 0 ? 0 : xp;

  // El nivel actual es el último cuyo umbral no supera la XP.
  var actual = niveles.first;
  for (final n in niveles) {
    if (xpSegura >= n.xpMin) actual = n;
  }

  final siguiente =
      actual.indice + 1 < niveles.length ? niveles[actual.indice + 1] : null;

  final double fraccion;
  if (siguiente == null) {
    fraccion = 1;
  } else {
    final rango = siguiente.xpMin - actual.xpMin;
    fraccion = ((xpSegura - actual.xpMin) / rango).clamp(0.0, 1.0);
  }

  return ProgresoNivel(
    xp: xpSegura,
    nivel: actual,
    siguiente: siguiente,
    fraccion: fraccion,
  );
}
