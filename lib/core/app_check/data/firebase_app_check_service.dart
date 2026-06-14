import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

import '../domain/i_servicio_app_check.dart';

/// Site key de reCAPTCHA v3 para App Check en **Web**. Se inyecta al compilar
/// con `--dart-define=RECAPTCHA_SITE_KEY=...`. En móvil no se usa (queda vacía).
const _recaptchaSiteKey = String.fromEnvironment('RECAPTCHA_SITE_KEY');

/// Implementación real de App Check sobre Firebase.
///
/// - **Android:** Play Integrity (release) / Debug provider (desarrollo).
/// - **Apple:** App Attest (release) / Debug provider (desarrollo).
/// - **Web:** reCAPTCHA v3 (requiere la site key vía `--dart-define`).
///
/// En **debug** se usan los proveedores *debug*, que requieren registrar el
/// token de depuración en la consola de Firebase (App Check → Apps → Manage
/// debug token). El token se imprime en el log la primera vez.
class FirebaseAppCheckService implements IServicioAppCheck {
  const FirebaseAppCheckService();

  @override
  Future<void> activar() async {
    try {
      await FirebaseAppCheck.instance.activate(
        providerAndroid: kReleaseMode
            ? const AndroidPlayIntegrityProvider()
            : const AndroidDebugProvider(),
        providerApple: kReleaseMode
            ? const AppleAppAttestProvider()
            : const AppleDebugProvider(),
        providerWeb: _recaptchaSiteKey.isEmpty
            ? null
            : ReCaptchaV3Provider(_recaptchaSiteKey),
      );
    } catch (e) {
      // App Check NUNCA debe impedir el arranque (lección de la pantalla
      // negra): si la activación falla, se registra y la app continúa.
      debugPrint('App Check: no se pudo activar: $e');
    }
  }
}
