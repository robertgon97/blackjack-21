import '../domain/i_servicio_push.dart';

/// Implementación no-op para plataformas sin Cloud Messaging (Windows/Linux).
class NoopPushService implements IServicioPush {
  const NoopPushService();

  @override
  Future<void> inicializar(String uid) async {}
}
