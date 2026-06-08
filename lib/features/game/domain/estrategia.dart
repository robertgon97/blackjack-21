// ============================================================
//  Estrategia básica de Blackjack
//
//  Tablas matemáticamente óptimas (multi-baraja). Recomienda la
//  jugada para enseñar y para el "modo entrenamiento".
//  Traducción pura de js/estrategia.js.
//
//  Códigos internos:
//    H  = pedir            S  = plantarse
//    D  = doblar (si no se puede, pedir)
//    Ds = doblar (si no se puede, plantarse)
//    P  = dividir          R  = rendirse (si no se puede, pedir)
// ============================================================

import 'cartas.dart';
import 'modelos.dart';

/// Valor de la carta visible del crupier (As = 11; figuras y 10 = 10).
int valorCarta(Carta carta) {
  if (carta.valor == 'A') return 11;
  if (carta.valor == '10' ||
      carta.valor == 'J' ||
      carta.valor == 'Q' ||
      carta.valor == 'K') {
    return 10;
  }
  return int.parse(carta.valor);
}

/// Recomienda la jugada óptima dada la mano, la carta visible del crupier y
/// las jugadas permitidas en ese momento.
Jugada consejoEstrategia(
  List<Carta> cartas,
  Carta cartaCrupier,
  OpcionesMano opc,
) {
  final up = valorCarta(cartaCrupier); // 2..11
  final info = infoMano(cartas);
  final total = info.total;
  final suave = info.suave;

  // 1) PAREJAS (solo con 2 cartas del mismo valor)
  if (cartas.length == 2 && mismoValorSplit(cartas[0], cartas[1])) {
    final codigo = _consejoPareja(valorSplit(cartas[0]), up);
    if (codigo == 'P') return _traducir('P', opc, total, suave);
    // Si la tabla dice que NO se divide, seguimos con total duro/blando.
  }

  // 2) RENDIRSE (late surrender, solo con 2 cartas)
  if (opc.puedeRendirse && cartas.length == 2 && !suave) {
    if (total == 16 && (up == 9 || up == 10 || up == 11)) {
      return _traducir('R', opc, total, suave);
    }
    if (total == 15 && up == 10) return _traducir('R', opc, total, suave);
  }

  // 3) MANO BLANDA (con As de 11)
  if (suave) return _traducir(_consejoBlanda(total, up), opc, total, suave);

  // 4) MANO DURA
  return _traducir(_consejoDura(total, up), opc, total, suave);
}

/// Tabla de parejas. [valor] es el valor de split ('A', '10', '2'..'9').
String _consejoPareja(String valor, int up) {
  switch (valor) {
    case 'A':
      return 'P'; // Ases: siempre dividir
    case '10':
      return 'S'; // 10/figuras: nunca dividir
    case '9':
      return (up == 7 || up == 10 || up == 11)
          ? 'S'
          : 'P'; // se planta vs 7,10,A
    case '8':
      return 'P'; // Ochos: siempre dividir
    case '7':
      return up <= 7 ? 'P' : 'H';
    case '6':
      return up <= 6 ? 'P' : 'H';
    case '5':
      return up <= 9 ? 'D' : 'H'; // como un 10 duro
    case '4':
      return (up == 5 || up == 6) ? 'P' : 'H';
    case '3':
    case '2':
      return up <= 7 ? 'P' : 'H';
    default:
      return 'H';
  }
}

/// Tabla de manos blandas (el total incluye el As como 11).
String _consejoBlanda(int total, int up) {
  switch (total) {
    case 20:
      return 'S'; // A,9
    case 19:
      return up == 6 ? 'Ds' : 'S'; // A,8
    case 18: // A,7
      if (up >= 3 && up <= 6) return 'Ds';
      if (up == 2 || up == 7 || up == 8) return 'S';
      return 'H'; // vs 9,10,A
    case 17:
      return (up >= 3 && up <= 6) ? 'D' : 'H'; // A,6
    case 16:
    case 15:
      return (up >= 4 && up <= 6) ? 'D' : 'H'; // A,5 / A,4
    case 14:
    case 13:
      return (up == 5 || up == 6) ? 'D' : 'H'; // A,3 / A,2
    default:
      return 'S';
  }
}

/// Tabla de manos duras.
String _consejoDura(int total, int up) {
  if (total >= 17) return 'S';
  if (total >= 13 && total <= 16) return up <= 6 ? 'S' : 'H';
  if (total == 12) return (up >= 4 && up <= 6) ? 'S' : 'H';
  if (total == 11) return 'D';
  if (total == 10) return up <= 9 ? 'D' : 'H';
  if (total == 9) return (up >= 3 && up <= 6) ? 'D' : 'H';
  return 'H'; // 5-8
}

/// Convierte el código interno en una [Jugada] real según lo permitido.
Jugada _traducir(String codigo, OpcionesMano opc, int total, bool suave) {
  switch (codigo) {
    case 'P':
      if (opc.puedeDividir) return Jugada.dividir;
      if (suave) return Jugada.pedir;
      return total >= 17 ? Jugada.plantarse : Jugada.pedir;
    case 'D':
      return opc.puedeDoblar ? Jugada.doblar : Jugada.pedir;
    case 'Ds':
      return opc.puedeDoblar ? Jugada.doblar : Jugada.plantarse;
    case 'R':
      return opc.puedeRendirse ? Jugada.rendirse : Jugada.pedir;
    case 'S':
      return Jugada.plantarse;
    case 'H':
      return Jugada.pedir;
    default:
      return Jugada.pedir;
  }
}
