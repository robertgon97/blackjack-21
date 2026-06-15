/// Servicio de notificaciones push (FCM). Se abstrae tras una interfaz —igual
/// que telemetría y App Check— para encapsular el proveedor (Firebase Messaging)
/// y la guarda de plataforma (Windows/Linux en no-op).
abstract interface class IServicioPush {
  /// Inicializa el push para el usuario [uid]: pide permiso, obtiene el token
  /// FCM, lo guarda en `users/{uid}.fcmTokens` y configura los listeners.
  ///
  /// **Nunca lanza** (un fallo se registra y se ignora) y es **idempotente**:
  /// llamarlo varias veces para el mismo `uid` no repite el trabajo.
  Future<void> inicializar(String uid);
}
