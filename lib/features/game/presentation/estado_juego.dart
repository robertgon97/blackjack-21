// ============================================================
//  Estado inmutable de una partida solo (jugador vs crupier)
//
//  Es un snapshot que la UI pinta. La lógica que lo produce vive
//  en `controlador_juego.dart`; las reglas puras, en `domain/`.
// ============================================================

import '../domain/cartas.dart';
import '../domain/modelos.dart';
import '../domain/reglas.dart';

/// Fase del flujo de juego: decide qué panel muestra la pantalla.
enum FaseJuego {
  /// Eligiendo apuesta con las fichas.
  apuestas,

  /// El jugador decide (pedir/plantarse/doblar/dividir/rendirse).
  jugando,

  /// El crupier muestra un As: se ofrece seguro.
  seguro,

  /// Ronda terminada: se muestra el resultado y "nueva mano".
  resultado,
}

/// Signo del resultado neto de la ronda, para colorear el monto.
enum SignoResultado { positivo, negativo, neutro }

/// Snapshot inmutable de la partida. Inmutable y con [copyWith].
class EstadoJuego {
  final ConfigJuego config;
  final FaseJuego fase;

  /// Saldo disponible del jugador.
  final int banca;

  /// Apuesta acumulada en la fase de apuestas (antes de repartir).
  final int apuesta;

  /// Última apuesta jugada, para el botón "repetir".
  final int ultimaApuesta;

  /// Manos del jugador (más de una tras dividir).
  final List<Mano> manos;

  /// Índice de la mano activa dentro de [manos].
  final int indiceMano;

  /// Cartas del crupier (la primera está oculta mientras [crupierOculto]).
  final List<Carta> manoCrupier;

  /// `true` mientras la primera carta del crupier sigue boca abajo.
  final bool crupierOculto;

  /// `true` mientras corre una animación/reparto: bloquea los botones.
  final bool animando;

  /// Monto apostado al seguro (0 si no se tomó).
  final int seguro;

  /// Mensaje guía mostrado al jugador.
  final String mensaje;

  /// Consejo de estrategia óptima (vacío si no aplica).
  final String consejo;

  /// Texto de probabilidad de pasarse (vacío si está desactivada).
  final String probabilidad;

  /// Resultado neto de la ronda (ganancia − apostado). Null durante el juego.
  final int? resultadoNeto;

  // --- Información del shoe (copiada para que la UI reaccione) ---
  final int conteoCorrido;
  final double conteoVerdadero;
  final int cartasRestantes;
  final double barajasRestantes;

  /// Último aviso transitorio (toast). La UI lo muestra cuando cambia [avisoSeq].
  final String? aviso;

  /// Secuencia que crece con cada aviso, para que la UI lo muestre una vez.
  final int avisoSeq;

  const EstadoJuego({
    required this.config,
    required this.fase,
    required this.banca,
    required this.apuesta,
    required this.ultimaApuesta,
    required this.manos,
    required this.indiceMano,
    required this.manoCrupier,
    required this.crupierOculto,
    required this.animando,
    required this.seguro,
    required this.mensaje,
    required this.consejo,
    required this.probabilidad,
    required this.resultadoNeto,
    required this.conteoCorrido,
    required this.conteoVerdadero,
    required this.cartasRestantes,
    required this.barajasRestantes,
    this.aviso,
    this.avisoSeq = 0,
  });

  /// Estado inicial en fase de apuestas, con la banca de [config].
  factory EstadoJuego.inicial(ConfigJuego config) {
    return EstadoJuego(
      config: config,
      fase: FaseJuego.apuestas,
      banca: config.bancaInicial,
      apuesta: 0,
      ultimaApuesta: 0,
      manos: const [],
      indiceMano: 0,
      manoCrupier: const [],
      crupierOculto: true,
      animando: false,
      seguro: 0,
      mensaje: 'Elige tu apuesta para empezar.',
      consejo: '',
      probabilidad: '',
      resultadoNeto: null,
      conteoCorrido: 0,
      conteoVerdadero: 0,
      cartasRestantes: 0,
      barajasRestantes: 0,
      aviso: null,
      avisoSeq: 0,
    );
  }

  /// La mano que el jugador está jugando ahora mismo (o null en apuestas).
  Mano? get manoActiva => (manos.isNotEmpty && indiceMano < manos.length)
      ? manos[indiceMano]
      : null;

  /// `true` si el jugador se quedó sin saldo (ofrecer préstamo).
  bool get sinDinero => banca <= 0;

  /// Signo del resultado neto de la ronda, para colorear el monto.
  SignoResultado get signoResultado {
    final neto = resultadoNeto;
    if (neto == null || neto == 0) return SignoResultado.neutro;
    return neto > 0 ? SignoResultado.positivo : SignoResultado.negativo;
  }

  /// Puntos de la mano activa (0 si no hay).
  int get puntosJugador {
    final m = manoActiva;
    return m == null ? 0 : calcularPuntos(m.cartas);
  }

  /// Total apostado actualmente en juego (suma de manos + seguro).
  int get totalEnJuego {
    if (fase == FaseJuego.apuestas) return apuesta;
    return manos.fold(0, (s, m) => s + m.apuesta) + seguro;
  }

  /// Jugadas extra disponibles para la mano activa.
  OpcionesMano get opcionesActivas {
    final m = manoActiva;
    if (m == null) {
      return const OpcionesMano(
        puedeDoblar: false,
        puedeDividir: false,
        puedeRendirse: false,
      );
    }
    return opcionesActuales(
      mano: m,
      cantidadManos: manos.length,
      banca: banca,
      config: config,
    );
  }

  EstadoJuego copyWith({
    ConfigJuego? config,
    FaseJuego? fase,
    int? banca,
    int? apuesta,
    int? ultimaApuesta,
    List<Mano>? manos,
    int? indiceMano,
    List<Carta>? manoCrupier,
    bool? crupierOculto,
    bool? animando,
    int? seguro,
    String? mensaje,
    String? consejo,
    String? probabilidad,
    int? resultadoNeto,
    bool limpiarResultadoNeto = false,
    int? conteoCorrido,
    double? conteoVerdadero,
    int? cartasRestantes,
    double? barajasRestantes,
    String? aviso,
    int? avisoSeq,
  }) {
    return EstadoJuego(
      config: config ?? this.config,
      fase: fase ?? this.fase,
      banca: banca ?? this.banca,
      apuesta: apuesta ?? this.apuesta,
      ultimaApuesta: ultimaApuesta ?? this.ultimaApuesta,
      manos: manos ?? this.manos,
      indiceMano: indiceMano ?? this.indiceMano,
      manoCrupier: manoCrupier ?? this.manoCrupier,
      crupierOculto: crupierOculto ?? this.crupierOculto,
      animando: animando ?? this.animando,
      seguro: seguro ?? this.seguro,
      mensaje: mensaje ?? this.mensaje,
      consejo: consejo ?? this.consejo,
      probabilidad: probabilidad ?? this.probabilidad,
      resultadoNeto:
          limpiarResultadoNeto ? null : (resultadoNeto ?? this.resultadoNeto),
      conteoCorrido: conteoCorrido ?? this.conteoCorrido,
      conteoVerdadero: conteoVerdadero ?? this.conteoVerdadero,
      cartasRestantes: cartasRestantes ?? this.cartasRestantes,
      barajasRestantes: barajasRestantes ?? this.barajasRestantes,
      aviso: aviso ?? this.aviso,
      avisoSeq: avisoSeq ?? this.avisoSeq,
    );
  }
}
