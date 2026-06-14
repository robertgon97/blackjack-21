/// Contrato de lectura del perfil de juego. La capa data lo implementa sobre
/// Firestore; presentación y domain solo conocen esta abstracción.
abstract interface class IProfileRepository {
  /// Stream en tiempo real del documento `users/{uid}` completo (mapa crudo).
  ///
  /// Las estadísticas (`stats`) y los logros (`logros`) se derivan de aquí en la
  /// capa de presentación, de modo que un solo listener de Firestore alimente
  /// ambos en vez de abrir dos suscripciones al mismo documento.
  Stream<Map<String, dynamic>> usuarioDocStream(String uid);
}
