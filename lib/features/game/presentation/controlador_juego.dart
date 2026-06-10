// ============================================================
//  Controlador del juego solo (jugador vs crupier)
//
//  Orquesta la lógica pura de `domain/` (cartas, reglas,
//  estrategia) con el dinero, el shoe y las animaciones, y
//  publica un [EstadoJuego] inmutable que la UI pinta.
//
//  Traducción del flujo de `legacy-web/js/juego.js` a un
//  `Notifier` de Riverpod (sin estado global ni DOM).
// ============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/telemetria/telemetria_provider.dart';
import '../domain/cartas.dart';
import '../domain/estrategia.dart';
import '../domain/modelos.dart';
import '../domain/reglas.dart';
import 'estado_juego.dart';

/// Provider del estado de la partida solo.
final controladorJuegoProvider =
    NotifierProvider<ControladorJuego, EstadoJuego>(ControladorJuego.new);

/// Denominaciones de fichas disponibles para apostar.
const List<int> denominacionesFicha = [10, 25, 50, 100];

/// Pausas (ms) entre repartos para dar sensación de animación.
const int _pausaReparto = 360;
const int _pausaCrupier = 620;

class ControladorJuego extends Notifier<EstadoJuego> {
  late Shoe _shoe;
  late IServicioTelemetria _telemetria;

  @override
  EstadoJuego build() {
    _telemetria = ref.read(servicioTelemetriaProvider);
    const config = ConfigJuego();
    _shoe = Shoe(config.numBarajas);
    final estado = EstadoJuego.inicial(config);
    return _conInfoShoe(estado);
  }

  // ----------------------------------------------------------
  //  Utilidades de estado
  // ----------------------------------------------------------

  /// Copia la información del shoe (conteo, restantes) dentro del estado.
  EstadoJuego _conInfoShoe(EstadoJuego e) {
    return e.copyWith(
      conteoCorrido: _shoe.conteoCorrido,
      conteoVerdadero: _shoe.conteoVerdadero,
      cartasRestantes: _shoe.cartasRestantes,
      barajasRestantes: _shoe.barajasRestantes,
    );
  }

  Future<void> _pausa(int ms) =>
      Future<void>.delayed(Duration(milliseconds: ms));

  /// Emite un aviso transitorio (toast) hacia la UI.
  void _avisar(String mensaje) {
    state = state.copyWith(aviso: mensaje, avisoSeq: state.avisoSeq + 1);
  }

  // ----------------------------------------------------------
  //  Configuración y temas de mesa
  // ----------------------------------------------------------

  /// Aplica una nueva configuración de reglas. Si cambia el número de barajas,
  /// regenera el shoe (solo permitido fuera de una ronda).
  void aplicarConfig(ConfigJuego nueva) {
    if (state.fase == FaseJuego.jugando || state.fase == FaseJuego.seguro) {
      _avisar('Termina la ronda para cambiar las reglas.');
      return;
    }
    if (nueva.numBarajas != state.config.numBarajas) {
      _shoe = Shoe(nueva.numBarajas);
    }
    // La banca solo se reinicia si el jugador aún no ha jugado nada.
    state = _conInfoShoe(state.copyWith(config: nueva));
  }

  // ----------------------------------------------------------
  //  Fase de apuestas
  // ----------------------------------------------------------

  void sumarFicha(int valor) {
    if (state.fase != FaseJuego.apuestas) return;
    final nueva = state.apuesta + valor;
    if (nueva > state.banca) {
      _avisar('No te alcanza la banca.');
      return;
    }
    if (nueva > state.config.apuestaMax) {
      _avisar('Apuesta máxima: \$${state.config.apuestaMax}.');
      return;
    }
    state = state.copyWith(
      apuesta: nueva,
      mensaje:
          'Apuesta: \$$nueva (mín \$${state.config.apuestaMin} · máx \$${state.config.apuestaMax}).',
    );
  }

  void limpiarApuesta() {
    if (state.fase != FaseJuego.apuestas) return;
    state = state.copyWith(apuesta: 0, mensaje: 'Apuesta reiniciada.');
  }

  void repetirApuesta() {
    if (state.fase != FaseJuego.apuestas) return;
    final base = state.ultimaApuesta == 0
        ? state.config.apuestaMin
        : state.ultimaApuesta;
    final valor = _limitarApuesta(base);
    state =
        state.copyWith(apuesta: valor, mensaje: 'Apuesta repetida: \$$valor');
  }

  void doblarApuestaPendiente() {
    if (state.fase != FaseJuego.apuestas) return;
    final base = state.apuesta == 0 ? state.config.apuestaMin : state.apuesta;
    final valor = _limitarApuesta(base * 2);
    state = state.copyWith(apuesta: valor, mensaje: 'Apuesta: \$$valor');
  }

  int _limitarApuesta(int v) {
    final tope = state.banca < state.config.apuestaMax
        ? state.banca
        : state.config.apuestaMax;
    if (v < 0) return 0;
    return v > tope ? tope : v;
  }

  // ----------------------------------------------------------
  //  Reparto inicial
  // ----------------------------------------------------------

  Future<void> repartir() async {
    if (state.animando || state.fase != FaseJuego.apuestas) return;
    if (state.apuesta < state.config.apuestaMin) {
      _avisar('Apuesta mínima: \$${state.config.apuestaMin}.');
      return;
    }
    if (state.apuesta > state.banca) {
      _avisar('No te alcanza la banca.');
      return;
    }

    if (_shoe.cartasRestantes == 0 || _shoe.necesitaBarajar) {
      _shoe.rebarajar(state.config.numBarajas);
      _avisar('Barajando ${state.config.numBarajas} barajas...');
    }

    final apuesta = state.apuesta;
    await _telemetria.evento('apuesta_realizada', params: {'monto': apuesta});
    await _telemetria.evento('ronda_iniciada');
    state = state.copyWith(
      fase: FaseJuego.jugando,
      animando: true,
      ultimaApuesta: apuesta,
      banca: state.banca - apuesta,
      manos: [Mano(cartas: const [], apuesta: apuesta)],
      indiceMano: 0,
      manoCrupier: const [],
      crupierOculto: true,
      seguro: 0,
      limpiarResultadoNeto: true,
      consejo: '',
      probabilidad: '',
      mensaje: 'Repartiendo...',
    );

    await _darCartaJugador(0);
    await _darCartaCrupierOculta();
    await _darCartaJugador(0);
    await _darCartaCrupierVisible();

    state = state.copyWith(animando: false);

    // Seguro si el crupier muestra un As.
    final crupierMuestraAs = state.manoCrupier[1].valor == 'A';
    final mitad = apuesta ~/ 2;
    if (crupierMuestraAs && state.banca >= mitad) {
      state = state.copyWith(
        fase: FaseJuego.seguro,
        mensaje: 'El crupier muestra un As. ¿Tomas seguro?',
      );
    } else {
      await _iniciarTurnoJugador();
    }
  }

  Future<void> tomarSeguro(bool quiere) async {
    if (state.fase != FaseJuego.seguro) return;
    if (quiere) {
      final seguro = state.apuesta ~/ 2;
      state = state.copyWith(
        seguro: seguro,
        banca: state.banca - seguro,
        fase: FaseJuego.jugando,
        mensaje: 'Seguro tomado por \$$seguro.',
      );
    } else {
      state = state.copyWith(fase: FaseJuego.jugando);
    }
    await _iniciarTurnoJugador();
  }

  // ----------------------------------------------------------
  //  Reparto de cartas individuales
  // ----------------------------------------------------------

  Future<void> _darCartaJugador(int i, {int pausaMs = _pausaReparto}) async {
    final carta = _shoe.sacarCarta();
    _shoe.contar(carta);
    final manos = [...state.manos];
    manos[i] = manos[i].copyWith(cartas: [...manos[i].cartas, carta]);
    state = _conInfoShoe(state.copyWith(manos: manos));
    await _pausa(pausaMs);
  }

  Future<void> _darCartaCrupierVisible({int pausaMs = _pausaReparto}) async {
    final carta = _shoe.sacarCarta();
    _shoe.contar(carta);
    state = _conInfoShoe(
      state.copyWith(manoCrupier: [...state.manoCrupier, carta]),
    );
    await _pausa(pausaMs);
  }

  Future<void> _darCartaCrupierOculta({int pausaMs = _pausaReparto}) async {
    // No se cuenta todavía: está boca abajo.
    final carta = _shoe.sacarCarta();
    state = state.copyWith(manoCrupier: [...state.manoCrupier, carta]);
    await _pausa(pausaMs);
  }

  void _revelarCrupier() {
    final ocultaCuenta =
        state.manoCrupier.isNotEmpty ? state.manoCrupier[0] : null;
    if (ocultaCuenta != null) _shoe.contar(ocultaCuenta);
    state = _conInfoShoe(state.copyWith(crupierOculto: false));
  }

  // ----------------------------------------------------------
  //  Turno del jugador
  // ----------------------------------------------------------

  Future<void> _iniciarTurnoJugador() async {
    // Bloquea los botones de acción durante la pausa de resolución: un 21
    // natural (jugador o crupier) cierra la ronda sin turno del jugador, y la
    // fase sigue siendo `jugando` mientras tanto.
    final hayBlackjack = calcularPuntos(state.manoCrupier) == 21 ||
        calcularPuntos(state.manos[0].cartas) == 21;
    if (hayBlackjack) {
      await _telemetria.evento('blackjack');
      state = state.copyWith(animando: true);
      _revelarCrupier();
      await _pausa(600);
      _finalizarRonda();
      return;
    }
    await _jugarManoActiva();
  }

  Future<void> _jugarManoActiva() async {
    state = state.copyWith(animando: true, consejo: '', probabilidad: '');
    var mano = state.manos[state.indiceMano];

    // Tras dividir, la mano queda con una sola carta: completar a dos.
    if (mano.cartas.length < 2) {
      await _darCartaJugador(state.indiceMano);
      mano = state.manos[state.indiceMano];
    }

    if (mano.asPartido) {
      state = state.copyWith(
        mensaje: 'As dividido (mano ${state.indiceMano + 1}): una sola carta.',
      );
      await _pausa(700);
      await _avanzarMano();
      return;
    }

    if (calcularPuntos(mano.cartas) == 21) {
      await _pausa(400);
      await _avanzarMano();
      return;
    }

    // Turno normal: habilitar acciones.
    var texto = state.manos.length > 1
        ? 'Juega la mano ${state.indiceMano + 1}.'
        : 'Tu turno.';
    if (state.opcionesActivas.puedeDividir) texto += ' ¡Par! Puedes DIVIDIR 🟢';
    state = state.copyWith(animando: false, mensaje: texto);
    _actualizarAyudas();
  }

  Future<void> _avanzarMano() async {
    if (state.indiceMano < state.manos.length - 1) {
      state = state.copyWith(indiceMano: state.indiceMano + 1);
      await _jugarManoActiva();
    } else {
      await _jugarCrupier();
    }
  }

  void _actualizarAyudas() {
    final mano = state.manoActiva;
    if (mano == null || state.fase != FaseJuego.jugando) {
      state = state.copyWith(consejo: '', probabilidad: '');
      return;
    }
    final rec = consejoEstrategia(
      mano.cartas,
      state.manoCrupier[1],
      state.opcionesActivas,
    );
    final consejo = '💡 Estrategia óptima: ${_nombreJugada(rec)}';

    String prob = '';
    if (state.config.mostrarProbabilidad) {
      final p = probabilidadPasarse(mano.cartas, _shoe.restantes);
      prob = 'Si pides: ${(p * 100).round()}% de pasarte';
    }
    state = state.copyWith(consejo: consejo, probabilidad: prob);
  }

  /// En modo entrenamiento, avisa si la jugada elegida no es la óptima.
  void _chequearEntrenamiento(Jugada jugada) {
    if (!state.config.modoEntrenamiento) return;
    final mano = state.manoActiva;
    if (mano == null) return;
    final rec = consejoEstrategia(
      mano.cartas,
      state.manoCrupier[1],
      state.opcionesActivas,
    );
    if (rec != jugada) {
      _avisar(
        '❌ Lo óptimo era ${_nombreJugada(rec)}, no ${_nombreJugada(jugada)}.',
      );
    }
  }

  String _nombreJugada(Jugada j) => switch (j) {
        Jugada.pedir => 'Pedir',
        Jugada.plantarse => 'Plantarse',
        Jugada.doblar => 'Doblar',
        Jugada.dividir => 'Dividir',
        Jugada.rendirse => 'Rendirse',
      };

  // ----------------------------------------------------------
  //  Acciones del jugador
  // ----------------------------------------------------------

  Future<void> pedir() async {
    if (state.fase != FaseJuego.jugando || state.animando) return;
    _chequearEntrenamiento(Jugada.pedir);
    await _telemetria.evento('accion_jugador', params: {'accion': 'pedir'});
    state = state.copyWith(animando: true, consejo: '', probabilidad: '');

    await _darCartaJugador(state.indiceMano);
    final puntos = calcularPuntos(state.manos[state.indiceMano].cartas);

    if (puntos > 21) {
      final etq =
          state.manos.length > 1 ? 'Mano ${state.indiceMano + 1}: ' : '';
      state = state.copyWith(mensaje: '${etq}te pasaste con $puntos.');
      await _pausa(700);
      await _avanzarMano();
    } else if (puntos == 21) {
      await _avanzarMano();
    } else {
      state = state.copyWith(animando: false);
      _actualizarAyudas();
    }
  }

  Future<void> doblar() async {
    if (state.fase != FaseJuego.jugando || state.animando) return;
    if (!state.opcionesActivas.puedeDoblar) return;
    _chequearEntrenamiento(Jugada.doblar);
    await _telemetria.evento('accion_jugador', params: {'accion': 'doblar'});

    final i = state.indiceMano;
    final mano = state.manos[i];
    final manos = [...state.manos];
    manos[i] = mano.copyWith(apuesta: mano.apuesta * 2, doblada: true);
    state = state.copyWith(
      animando: true,
      consejo: '',
      probabilidad: '',
      banca: state.banca - mano.apuesta,
      manos: manos,
      mensaje: '¡Doblaste! Una sola carta.',
    );

    await _darCartaJugador(i, pausaMs: 560);
    final puntos = calcularPuntos(state.manos[i].cartas);
    if (puntos > 21) {
      state = state.copyWith(mensaje: 'Doblaste y te pasaste con $puntos.');
      await _pausa(700);
    }
    await _avanzarMano();
  }

  Future<void> dividir() async {
    if (state.fase != FaseJuego.jugando || state.animando) return;
    if (!state.opcionesActivas.puedeDividir) return;
    _chequearEntrenamiento(Jugada.dividir);
    await _telemetria.evento('accion_jugador', params: {'accion': 'dividir'});

    final i = state.indiceMano;
    final mano = state.manos[i];
    final cartaMovida = mano.cartas[1];
    final esAs = cartaMovida.valor == 'A';

    final nueva = Mano(
      cartas: [cartaMovida],
      apuesta: mano.apuesta,
      asPartido: esAs,
    );
    final actualizada = mano.copyWith(
      cartas: [mano.cartas[0]],
      asPartido: esAs,
    );

    final manos = [...state.manos];
    manos[i] = actualizada;
    manos.insert(i + 1, nueva);

    state = state.copyWith(
      animando: true,
      consejo: '',
      probabilidad: '',
      banca: state.banca - mano.apuesta,
      manos: manos,
      mensaje: 'Dividiste tu mano en dos.',
    );
    await _pausa(500);
    await _jugarManoActiva();
  }

  Future<void> rendirse() async {
    if (state.fase != FaseJuego.jugando || state.animando) return;
    if (!state.opcionesActivas.puedeRendirse) return;
    _chequearEntrenamiento(Jugada.rendirse);
    await _telemetria.evento('accion_jugador', params: {'accion': 'rendirse'});

    final i = state.indiceMano;
    final manos = [...state.manos];
    manos[i] = manos[i].copyWith(rendida: true);
    state = state.copyWith(
      animando: true,
      consejo: '',
      probabilidad: '',
      manos: manos,
      mensaje: 'Te rendiste: recuperas la mitad de la apuesta.',
    );
    await _pausa(600);
    await _avanzarMano();
  }

  Future<void> plantarse() async {
    if (state.fase != FaseJuego.jugando || state.animando) return;
    _chequearEntrenamiento(Jugada.plantarse);
    await _telemetria.evento('accion_jugador', params: {'accion': 'plantarse'});
    state = state.copyWith(animando: true, consejo: '', probabilidad: '');
    await _avanzarMano();
  }

  // ----------------------------------------------------------
  //  Turno del crupier
  // ----------------------------------------------------------

  Future<void> _jugarCrupier() async {
    state = state.copyWith(animando: true, consejo: '', probabilidad: '');
    _revelarCrupier();
    await _pausa(700);

    final algunaViva = state.manos.any(
      (m) => !m.rendida && calcularPuntos(m.cartas) <= 21,
    );
    if (algunaViva) {
      while (debePedirCrupier(state.manoCrupier, state.config)) {
        state = state.copyWith(mensaje: 'El crupier pide carta...');
        await _darCartaCrupierVisible(pausaMs: _pausaCrupier);
      }
    }
    _finalizarRonda();
  }

  // ----------------------------------------------------------
  //  Resolución de la ronda
  // ----------------------------------------------------------

  void _finalizarRonda() {
    var banca = state.banca;
    var netoTotal = 0;
    final partes = <String>[];
    final esUnica = state.manos.length == 1;

    // Seguro: paga 2:1 si el crupier tiene blackjack.
    if (state.seguro > 0) {
      final crupierBlackjack = state.manoCrupier.length == 2 &&
          calcularPuntos(state.manoCrupier) == 21;
      if (crupierBlackjack) {
        banca += state.seguro * 3;
        netoTotal += state.seguro * 2;
        partes.add('Seguro +\$${state.seguro * 2}');
      } else {
        netoTotal -= state.seguro;
        partes.add('Seguro -\$${state.seguro}');
      }
    }

    // Resolver cada mano.
    for (var idx = 0; idx < state.manos.length; idx++) {
      final mano = state.manos[idx];
      final r = resolverMano(
        mano: mano,
        manoCrupier: state.manoCrupier,
        config: state.config,
        esUnicaMano: esUnica,
      );
      banca += r.ganancia;
      final neto = r.ganancia - mano.apuesta;
      netoTotal += neto;

      final etq = state.manos.length > 1 ? 'Mano ${idx + 1}: ' : '';
      switch (r.estado) {
        case EstadoMano.ganar:
          partes.add(
            r.esBlackjack ? '$etq¡BLACKJACK! +\$$neto' : '${etq}ganas +\$$neto',
          );
        case EstadoMano.empate:
          partes.add('${etq}empate');
        case EstadoMano.rendir:
          partes.add('${etq}rendido -\$${mano.apuesta - r.ganancia}');
        case EstadoMano.perder:
          partes.add('${etq}pierdes -\$${mano.apuesta}');
      }
    }

    final pc = calcularPuntos(state.manoCrupier);
    final textoCrupier = pc > 21 ? 'se pasó ($pc)' : '$pc';
    final mensaje = 'Crupier: $textoCrupier. ${partes.join(' · ')}';

    _telemetria.evento(
      'mano_resuelta',
      params: {
        'resultado':
            netoTotal > 0 ? 'ganar' : (netoTotal < 0 ? 'perder' : 'empate'),
        'neto': netoTotal,
      },
    );
    if (banca == 0) _telemetria.evento('saldo_agotado');

    state = _conInfoShoe(
      state.copyWith(
        fase: FaseJuego.resultado,
        animando: false,
        banca: banca,
        apuesta: 0,
        seguro: 0,
        mensaje: mensaje,
        resultadoNeto: netoTotal,
        consejo: '',
        probabilidad: '',
      ),
    );
  }

  // ----------------------------------------------------------
  //  Nueva ronda y préstamo
  // ----------------------------------------------------------

  void nuevaRonda() {
    if (state.animando || state.fase != FaseJuego.resultado) return;
    state = state.copyWith(
      fase: FaseJuego.apuestas,
      manos: const [],
      indiceMano: 0,
      manoCrupier: const [],
      crupierOculto: true,
      apuesta: 0,
      seguro: 0,
      limpiarResultadoNeto: true,
      consejo: '',
      probabilidad: '',
      mensaje: 'Elige tu apuesta para la siguiente mano.',
    );
  }

  /// Préstamo de emergencia cuando la banca llega a cero.
  void pedirPrestamo() {
    if (state.animando || state.fase != FaseJuego.resultado) return;
    state = state.copyWith(banca: state.banca + 500);
    _avisar('Préstamo de \$500 concedido.');
    nuevaRonda();
  }
}
