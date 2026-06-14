import 'datos_usuario.dart';

/// Contrato de lectura del perfil de juego. La capa data lo implementa sobre
/// Firestore; presentación y domain solo conocen esta abstracción.
abstract interface class IProfileRepository {
  /// Stream en tiempo real de los datos de progresión del usuario [uid]
  /// (estadísticas + logros).
  ///
  /// Un solo listener del documento `users/{uid}` alimenta ambos, en vez de
  /// abrir dos suscripciones al mismo documento.
  Stream<DatosUsuario> datosStream(String uid);
}
