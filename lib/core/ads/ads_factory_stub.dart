import 'data/noop_ads_service.dart';
import 'domain/i_servicio_anuncios.dart';

/// Fábrica para Web/plataformas sin `dart:io`: nunca importa google_mobile_ads.
IServicioAnuncios crearServicioAnuncios() => const NoopAdsService();
