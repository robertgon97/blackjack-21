import 'modelos.dart';

/// Persiste el resultado de una ronda del **juego solo** llamando a la Cloud
/// Function que valida y actualiza el saldo (el cliente no puede escribir el
/// `balance` directamente: está protegido por las reglas anti-trampa).
abstract interface class IResultadoSoloRepository {
  /// Envía la ronda terminada al servidor, que **recalcula** el resultado con
  /// las reglas y actualiza el balance. Devuelve el nuevo balance autoritativo.
  ///
  /// Lanza [Exception] con un mensaje en español si la validación o la red
  /// fallan (la presentación no debe depender de los tipos de Firebase).
  Future<int> registrarRonda({
    required List<Mano> manos,
    required List<Carta> manoCrupier,
    required int seguro,
    required ConfigJuego config,
  });
}
