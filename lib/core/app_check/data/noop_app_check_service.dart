import '../domain/i_servicio_app_check.dart';

/// Implementación no-op de App Check para plataformas sin soporte
/// (Windows/Linux) y para tests. No hace nada al activarse.
class NoopAppCheckService implements IServicioAppCheck {
  const NoopAppCheckService();

  @override
  Future<void> activar() async {}
}
