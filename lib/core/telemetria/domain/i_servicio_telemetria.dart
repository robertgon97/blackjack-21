/// Contrato de telemetría: Crashlytics (errores) + Analytics (eventos/pantallas).
///
/// - [FirebaseTelemetria] es la implementación real (Android/iOS/Web parcial).
/// - [NoopTelemetria] es la implementación vacía para Windows y tests.
abstract interface class IServicioTelemetria {
  // ── Crashlytics ──────────────────────────────────────────────────────────

  /// Registra un error fatal o no fatal con su traza de pila.
  Future<void> registrarError(
    Object error,
    StackTrace? stackTrace, {
    bool fatal = false,
  });

  /// Añade una línea de breadcrumb para reconstruir el camino al crash.
  Future<void> log(String mensaje);

  /// Establece una clave personalizada de sesión (uid, sala_actual, tema…).
  Future<void> setClave(String clave, String valor);

  /// Actualiza el identificador de usuario en Crashlytics y Analytics.
  Future<void> setUid(String? uid);

  // ── Analytics ────────────────────────────────────────────────────────────

  /// Registra un evento con parámetros opcionales.
  Future<void> evento(String nombre, {Map<String, Object>? params});

  /// Registra una vista de pantalla.
  Future<void> pantalla(String nombre);

  /// Establece una propiedad de usuario (nivel, tema, tipo_cuenta…).
  Future<void> setPropiedad(String nombre, String? valor);

  /// Activa o desactiva toda la recolección de datos (Crashlytics + Analytics).
  Future<void> setHabilitado(bool habilitado);
}
