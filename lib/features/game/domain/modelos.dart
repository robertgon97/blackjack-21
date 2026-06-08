// ============================================================
//  Modelos del dominio del juego (Blackjack 21)
//
//  Clases y enums inmutables, sin dependencias de Flutter ni
//  Firebase. Son la base de la lógica pura del juego.
//  Reglas de negocio: docs/reglas-negocio/reglas-del-juego.md
// ============================================================

/// Palo de una carta, con su símbolo para mostrar.
enum Palo {
  picas('♠'),
  corazones('♥'),
  diamantes('♦'),
  treboles('♣');

  /// Símbolo Unicode del palo.
  final String simbolo;
  const Palo(this.simbolo);
}

/// Valores posibles de una carta, en el orden de una baraja.
///
/// Se modelan como `String` (igual que en la versión original) para
/// distinguir figuras ('J', 'Q', 'K') del 10 sin ambigüedad.
const List<String> valoresBaraja = [
  'A',
  '2',
  '3',
  '4',
  '5',
  '6',
  '7',
  '8',
  '9',
  '10',
  'J',
  'Q',
  'K',
];

/// Una carta de la baraja: un palo y un valor.
class Carta {
  final Palo palo;

  /// Uno de [valoresBaraja]: 'A', '2'..'10', 'J', 'Q', 'K'.
  final String valor;

  const Carta(this.palo, this.valor);

  @override
  bool operator ==(Object other) =>
      other is Carta && other.palo == palo && other.valor == valor;

  @override
  int get hashCode => Object.hash(palo, valor);

  @override
  String toString() => '$valor${palo.simbolo}';
}

/// Resultado de evaluar una mano: total de puntos y si es "suave".
///
/// Una mano es "suave" cuando tiene un As contando como 11 (p. ej. A+6 = 17
/// suave), lo que permite pedir sin riesgo de pasarse.
class InfoMano {
  final int total;
  final bool suave;

  const InfoMano(this.total, this.suave);
}

/// Una mano del jugador. Con los splits, un jugador puede tener varias.
class Mano {
  final List<Carta> cartas;

  /// Apuesta asociada a esta mano (cada mano de un split tiene la suya).
  final int apuesta;

  /// `true` si el jugador dobló en esta mano.
  final bool doblada;

  /// `true` si la mano proviene de partir un par de ases (recibe 1 sola carta).
  final bool asPartido;

  /// `true` si el jugador se rindió en esta mano.
  final bool rendida;

  const Mano({
    required this.cartas,
    required this.apuesta,
    this.doblada = false,
    this.asPartido = false,
    this.rendida = false,
  });

  Mano copyWith({
    List<Carta>? cartas,
    int? apuesta,
    bool? doblada,
    bool? asPartido,
    bool? rendida,
  }) {
    return Mano(
      cartas: cartas ?? this.cartas,
      apuesta: apuesta ?? this.apuesta,
      doblada: doblada ?? this.doblada,
      asPartido: asPartido ?? this.asPartido,
      rendida: rendida ?? this.rendida,
    );
  }
}

/// Jugada que puede hacer el jugador en su turno.
enum Jugada {
  pedir('PEDIR carta'),
  plantarse('PLANTARSE'),
  doblar('DOBLAR'),
  dividir('DIVIDIR'),
  rendirse('RENDIRSE');

  /// Texto legible para mostrar al usuario.
  final String etiqueta;
  const Jugada(this.etiqueta);
}

/// Qué jugadas extra están permitidas para una mano en un momento dado.
class OpcionesMano {
  final bool puedeDoblar;
  final bool puedeDividir;
  final bool puedeRendirse;

  const OpcionesMano({
    required this.puedeDoblar,
    required this.puedeDividir,
    required this.puedeRendirse,
  });
}

/// Estado final de una mano tras compararla con el crupier.
enum EstadoMano { ganar, perder, empate, rendir }

/// Resultado de resolver una mano: estado, dinero devuelto a la banca y si
/// fue un blackjack natural (que paga distinto).
class ResultadoMano {
  final EstadoMano estado;

  /// Dinero devuelto a la banca del jugador (incluye la apuesta cuando gana
  /// o empata; 0 cuando pierde).
  final int ganancia;

  final bool esBlackjack;

  const ResultadoMano({
    required this.estado,
    required this.ganancia,
    required this.esBlackjack,
  });
}

/// Configuración de reglas de la mesa. Inmutable; equivalente al objeto
/// `config` de la versión original.
/// Detalle: docs/reglas-negocio/reglas-del-juego.md
class ConfigJuego {
  /// Cuántas barajas hay en el shoe (1–8).
  final int numBarajas;

  /// Pago del blackjack: 1.5 = 3:2 ; 1.2 = 6:5.
  final double pagoBlackjack;

  /// H17: el crupier pide con 17 suave (As+6).
  final bool crupierPideEn17Suave;

  /// Variante: si el crupier llega a 22, es empate.
  final bool empujeEn22;

  final int apuestaMin;
  final int apuestaMax;

  /// Permitir la jugada "Rendirse".
  final bool permitirRendirse;

  /// Avisa cuando el jugador se desvía de la estrategia óptima.
  final bool modoEntrenamiento;

  /// Muestra el conteo Hi-Lo.
  final bool mostrarConteo;

  /// Muestra la probabilidad de pasarse.
  final bool mostrarProbabilidad;

  /// Saldo inicial (en multijugador lo gobierna la economía de créditos).
  final int bancaInicial;

  const ConfigJuego({
    this.numBarajas = 6,
    this.pagoBlackjack = 1.5,
    this.crupierPideEn17Suave = false,
    this.empujeEn22 = false,
    this.apuestaMin = 10,
    this.apuestaMax = 500,
    this.permitirRendirse = true,
    this.modoEntrenamiento = false,
    this.mostrarConteo = false,
    this.mostrarProbabilidad = true,
    this.bancaInicial = 1000,
  });

  ConfigJuego copyWith({
    int? numBarajas,
    double? pagoBlackjack,
    bool? crupierPideEn17Suave,
    bool? empujeEn22,
    int? apuestaMin,
    int? apuestaMax,
    bool? permitirRendirse,
    bool? modoEntrenamiento,
    bool? mostrarConteo,
    bool? mostrarProbabilidad,
    int? bancaInicial,
  }) {
    return ConfigJuego(
      numBarajas: numBarajas ?? this.numBarajas,
      pagoBlackjack: pagoBlackjack ?? this.pagoBlackjack,
      crupierPideEn17Suave: crupierPideEn17Suave ?? this.crupierPideEn17Suave,
      empujeEn22: empujeEn22 ?? this.empujeEn22,
      apuestaMin: apuestaMin ?? this.apuestaMin,
      apuestaMax: apuestaMax ?? this.apuestaMax,
      permitirRendirse: permitirRendirse ?? this.permitirRendirse,
      modoEntrenamiento: modoEntrenamiento ?? this.modoEntrenamiento,
      mostrarConteo: mostrarConteo ?? this.mostrarConteo,
      mostrarProbabilidad: mostrarProbabilidad ?? this.mostrarProbabilidad,
      bancaInicial: bancaInicial ?? this.bancaInicial,
    );
  }
}
