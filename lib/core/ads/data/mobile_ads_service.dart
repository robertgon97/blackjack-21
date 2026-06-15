import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../domain/i_servicio_anuncios.dart';

/// Implementación de [IServicioAnuncios] con AdMob (google_mobile_ads).
///
/// Solo Android/iOS: aunque este archivo se compile en escritorio (vía
/// `dart.library.io`), un guard de runtime evita tocar el SDK fuera de móvil.
/// En **debug** usa el Ad Unit de **prueba** de Google para no arriesgar el baneo
/// por clics inválidos sobre los anuncios reales.
class MobileAdsService implements IServicioAnuncios {
  bool _inicializado = false;

  bool get _esMovil =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  /// Ad Unit recompensado: prueba en debug, real en release.
  static String get _adUnitId {
    if (kDebugMode) {
      // IDs de prueba oficiales de Google (no generan ingresos ni baneo).
      return defaultTargetPlatform == TargetPlatform.iOS
          ? 'ca-app-pub-3940256099942544/1712485313'
          : 'ca-app-pub-3940256099942544/5224354917';
    }
    // Producción (Android). El de iOS se añadirá con su cuenta/firma.
    return 'ca-app-pub-4615188161032989/7079919403';
  }

  @override
  bool get disponible => _esMovil;

  @override
  Future<void> inicializar() async {
    if (_inicializado || !_esMovil) return;
    try {
      await MobileAds.instance.initialize();
      _inicializado = true;
    } catch (e) {
      debugPrint('ads: inicialización falló (no fatal): $e');
    }
  }

  @override
  Future<bool> mostrarRecompensado(String uid) async {
    if (!_esMovil) return false;
    final completer = Completer<bool>();
    try {
      await RewardedAd.load(
        adUnitId: _adUnitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            // El uid viaja como userId del SSV: AdMob lo enviará firmado a la
            // Function admobSsv, que acredita la recompensa server-side.
            ad.setServerSideOptions(ServerSideVerificationOptions(userId: uid));
            var gano = false;
            ad.fullScreenContentCallback = FullScreenContentCallback(
              onAdDismissedFullScreenContent: (ad) {
                ad.dispose();
                if (!completer.isCompleted) completer.complete(gano);
              },
              onAdFailedToShowFullScreenContent: (ad, error) {
                ad.dispose();
                if (!completer.isCompleted) completer.complete(false);
              },
            );
            ad.show(onUserEarnedReward: (_, __) => gano = true);
          },
          onAdFailedToLoad: (error) {
            if (!completer.isCompleted) completer.complete(false);
          },
        ),
      );
    } catch (e) {
      debugPrint('ads: error al mostrar recompensado: $e');
      if (!completer.isCompleted) completer.complete(false);
    }
    return completer.future;
  }
}
