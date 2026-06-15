import 'data/mobile_ads_service.dart';
import 'domain/i_servicio_anuncios.dart';

/// Fábrica para plataformas con `dart:io` (móvil/escritorio). En escritorio el
/// propio servicio queda inerte por su guard de runtime; solo Android/iOS usan
/// el SDK.
IServicioAnuncios crearServicioAnuncios() => MobileAdsService();
