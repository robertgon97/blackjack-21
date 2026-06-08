// ============================================================
//  Reglas del juego: turno del crupier, resolución de manos y
//  jugadas permitidas.
//
//  Lógica pura traducida de js/juego.js (resolverMano,
//  debePedirCrupier, opcionesActuales, puedeDividir). Sin estado
//  global: todo entra por parámetros.
//  Reglas: docs/reglas-negocio/reglas-del-juego.md
// ============================================================

import 'cartas.dart';
import 'modelos.dart';

/// ¿El crupier debe pedir otra carta? Aplica la regla H17 según [config].
bool debePedirCrupier(List<Carta> manoCrupier, ConfigJuego config) {
  final info = infoMano(manoCrupier);
  if (info.total < 17) return true;
  if (info.total == 17 && info.suave && config.crupierPideEn17Suave) return true;
  return false;
}

/// Resuelve una mano del jugador contra la del crupier y calcula el dinero
/// devuelto a la banca.
///
/// [esUnicaMano] indica que el jugador tiene una sola mano (sin splits), lo
/// cual es requisito para que un 21 cuente como blackjack natural.
ResultadoMano resolverMano({
  required Mano mano,
  required List<Carta> manoCrupier,
  required ConfigJuego config,
  required bool esUnicaMano,
}) {
  final pj = calcularPuntos(mano.cartas);
  final pc = calcularPuntos(manoCrupier);

  // Rendición: recupera la mitad de la apuesta.
  if (mano.rendida) {
    return ResultadoMano(
      estado: EstadoMano.rendir,
      ganancia: mano.apuesta ~/ 2,
      esBlackjack: false,
    );
  }

  final esBlackjack =
      esUnicaMano && mano.cartas.length == 2 && pj == 21 && !mano.doblada;

  final EstadoMano estado;
  if (pj > 21) {
    estado = EstadoMano.perder;
  } else if (config.empujeEn22 && pc == 22) {
    estado = EstadoMano.empate; // variante: crupier 22 empuja
  } else if (pc > 21) {
    estado = EstadoMano.ganar;
  } else if (pj > pc) {
    estado = EstadoMano.ganar;
  } else if (pj < pc) {
    estado = EstadoMano.perder;
  } else {
    estado = EstadoMano.empate;
  }

  var ganancia = 0;
  if (estado == EstadoMano.ganar) {
    ganancia = esBlackjack
        ? mano.apuesta + (mano.apuesta * config.pagoBlackjack).floor()
        : mano.apuesta * 2;
  } else if (estado == EstadoMano.empate) {
    ganancia = mano.apuesta;
  }

  return ResultadoMano(estado: estado, ganancia: ganancia, esBlackjack: esBlackjack);
}

/// ¿Se puede dividir (split) esta mano?
///
/// [cantidadManos] es cuántas manos tiene ya el jugador (límite de 4).
/// [banca] es el saldo disponible para cubrir la apuesta extra.
bool puedeDividir({
  required Mano mano,
  required int cantidadManos,
  required int banca,
}) {
  if (mano.cartas.length != 2) return false;
  if (mano.asPartido) return false;
  if (cantidadManos >= 4) return false;
  if (banca < mano.apuesta) return false;
  return mismoValorSplit(mano.cartas[0], mano.cartas[1]);
}

/// Calcula qué jugadas extra (doblar/dividir/rendirse) están permitidas para
/// la mano activa, según el saldo, la cantidad de manos y la configuración.
OpcionesMano opcionesActuales({
  required Mano mano,
  required int cantidadManos,
  required int banca,
  required ConfigJuego config,
}) {
  return OpcionesMano(
    puedeDoblar:
        mano.cartas.length == 2 && !mano.doblada && banca >= mano.apuesta,
    puedeDividir: puedeDividir(
      mano: mano,
      cantidadManos: cantidadManos,
      banca: banca,
    ),
    puedeRendirse: config.permitirRendirse &&
        mano.cartas.length == 2 &&
        cantidadManos == 1,
  );
}
