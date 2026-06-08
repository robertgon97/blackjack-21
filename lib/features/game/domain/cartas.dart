// ============================================================
//  Cartas, mazo múltiple (Shoe), puntos, conteo y probabilidades
//
//  Lógica pura traducida de la versión web (js/cartas.js). No
//  toca UI ni red. Reglas: docs/reglas-negocio/reglas-del-juego.md
// ============================================================

import 'dart:math';

import 'modelos.dart';

const List<String> _figuras = ['J', 'Q', 'K'];

/// Calcula los puntos de una mano. El As vale 11, pero baja a 1 las veces
/// necesarias para no pasarse de 21.
int calcularPuntos(List<Carta> cartas) {
  var total = 0;
  var ases = 0;
  for (final carta in cartas) {
    if (carta.valor == 'A') {
      ases++;
      total += 11;
    } else if (_figuras.contains(carta.valor)) {
      total += 10;
    } else {
      total += int.parse(carta.valor);
    }
  }
  while (total > 21 && ases > 0) {
    total -= 10;
    ases--;
  }
  return total;
}

/// Devuelve el total de la mano y si es "suave" (tiene un As contando como 11).
InfoMano infoMano(List<Carta> cartas) {
  var total = 0;
  var ases = 0;
  for (final carta in cartas) {
    if (carta.valor == 'A') {
      ases++;
      total += 11;
    } else if (_figuras.contains(carta.valor)) {
      total += 10;
    } else {
      total += int.parse(carta.valor);
    }
  }
  while (total > 21 && ases > 0) {
    total -= 10;
    ases--;
  }
  return InfoMano(total, ases > 0);
}

/// Valor a efectos de división: las figuras y el 10 cuentan igual ('10').
String valorSplit(Carta carta) {
  if (carta.valor == 'A') return 'A';
  if (carta.valor == '10' || _figuras.contains(carta.valor)) return '10';
  return carta.valor;
}

/// ¿Dos cartas tienen el mismo valor de división (se pueden partir)?
bool mismoValorSplit(Carta a, Carta b) => valorSplit(a) == valorSplit(b);

/// Valor Hi-Lo de una carta: 2–6 = +1, 7–9 = 0, 10/figuras/As = −1.
int valorConteo(Carta carta) {
  const bajas = ['2', '3', '4', '5', '6'];
  const neutras = ['7', '8', '9'];
  if (bajas.contains(carta.valor)) return 1;
  if (neutras.contains(carta.valor)) return 0;
  return -1; // 10, J, Q, K, A
}

/// Probabilidad de pasarse de 21 si se pide una carta más, dadas las cartas
/// que aún quedan disponibles ([restantes]).
double probabilidadPasarse(List<Carta> mano, List<Carta> restantes) {
  final total = calcularPuntos(mano);
  if (total >= 21) return total > 21 ? 1.0 : 0.0;
  if (restantes.isEmpty) return 0.0;
  var pasan = 0;
  for (final c in restantes) {
    if (calcularPuntos([...mano, c]) > 21) pasan++;
  }
  return pasan / restantes.length;
}

/// El "zapato": varias barajas mezcladas de las que se reparten cartas.
///
/// Mantiene el conteo Hi-Lo corrido. El barajado usa [Random], que se puede
/// inyectar (semilla fija) para tests deterministas.
class Shoe {
  final List<Carta> _cartas = [];
  final Random _random;

  int _totalInicial = 0;
  int _conteoCorrido = 0;

  /// Crea y baraja un shoe con [numBarajas] barajas.
  ///
  /// [random] permite fijar la semilla en tests; por defecto usa una aleatoria.
  Shoe(int numBarajas, {Random? random}) : _random = random ?? Random() {
    rebarajar(numBarajas);
  }

  /// Cartas que quedan por repartir.
  int get cartasRestantes => _cartas.length;

  /// Barajas que quedan (cartas restantes / 52).
  double get barajasRestantes => _cartas.length / 52;

  /// Conteo Hi-Lo corrido (running count).
  int get conteoCorrido => _conteoCorrido;

  /// Conteo "verdadero" = corrido / barajas restantes.
  double get conteoVerdadero {
    final baraj = barajasRestantes;
    if (baraj < 0.1) return _conteoCorrido.toDouble();
    return _conteoCorrido / baraj;
  }

  /// Vista de solo lectura de las cartas restantes (para cálculos como
  /// [probabilidadPasarse]).
  List<Carta> get restantes => List.unmodifiable(_cartas);

  /// ¿Conviene rebarajar? (penetración del 25%, como en los casinos).
  bool get necesitaBarajar => _cartas.length < _totalInicial * 0.25;

  /// Llena el shoe con [numBarajas] barajas y lo mezcla (Fisher-Yates).
  void rebarajar(int numBarajas) {
    _cartas.clear();
    for (var b = 0; b < numBarajas; b++) {
      for (final palo in Palo.values) {
        for (final valor in valoresBaraja) {
          _cartas.add(Carta(palo, valor));
        }
      }
    }
    _barajar();
    _totalInicial = _cartas.length;
    _conteoCorrido = 0;
  }

  /// Saca la carta de arriba del shoe. Si se acaba, lo regenera con el mismo
  /// número de barajas con el que se creó.
  Carta sacarCarta() {
    if (_cartas.isEmpty) {
      rebarajar(_totalInicial ~/ 52);
    }
    return _cartas.removeLast();
  }

  /// Suma una carta al conteo Hi-Lo (se llama al hacerla visible).
  void contar(Carta carta) {
    _conteoCorrido += valorConteo(carta);
  }

  void _barajar() {
    for (var i = _cartas.length - 1; i > 0; i--) {
      final j = _random.nextInt(i + 1);
      final tmp = _cartas[i];
      _cartas[i] = _cartas[j];
      _cartas[j] = tmp;
    }
  }
}
