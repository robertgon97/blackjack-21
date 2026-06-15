import '../domain/i_servicio_anuncios.dart';

/// Implementación sin anuncios para Web y escritorio (AdMob solo Android/iOS).
class NoopAdsService implements IServicioAnuncios {
  const NoopAdsService();

  @override
  Future<void> inicializar() async {}

  @override
  bool get disponible => false;

  @override
  Future<bool> mostrarRecompensado(String uid) async => false;
}
