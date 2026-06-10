import '../domain/i_servicio_telemetria.dart';

/// Implementación vacía de [IServicioTelemetria] para Windows y tests.
class NoopTelemetria implements IServicioTelemetria {
  const NoopTelemetria();

  @override
  Future<void> registrarError(
    Object error,
    StackTrace? stackTrace, {
    bool fatal = false,
  }) async {}

  @override
  Future<void> log(String mensaje) async {}

  @override
  Future<void> setClave(String clave, String valor) async {}

  @override
  Future<void> setUid(String? uid) async {}

  @override
  Future<void> evento(String nombre, {Map<String, Object>? params}) async {}

  @override
  Future<void> pantalla(String nombre) async {}

  @override
  Future<void> setPropiedad(String nombre, String? valor) async {}

  @override
  Future<void> setHabilitado(bool habilitado) async {}
}
