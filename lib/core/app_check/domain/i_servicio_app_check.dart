/// Servicio de App Check: atestigua que las llamadas a Firebase (Firestore,
/// Functions) provienen de la app legítima, no de un cliente falsificado.
///
/// Se abstrae tras una interfaz —igual que la telemetría— para que la elección
/// de proveedor (Play Integrity / App Attest / reCAPTCHA) y la guarda de
/// plataforma (Windows en no-op) queden encapsuladas y la capa de arranque solo
/// llame a [activar].
abstract interface class IServicioAppCheck {
  /// Activa App Check. **Nunca lanza**: un fallo se registra y se ignora para
  /// no bloquear el arranque de la app.
  Future<void> activar();
}
