import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/firebase_telemetria.dart';
import 'data/noop_telemetria.dart';
import 'domain/i_servicio_telemetria.dart';

export 'domain/i_servicio_telemetria.dart';

/// Provider global del servicio de telemetría.
///
/// - Android / iOS / macOS / Linux: Crashlytics + Analytics.
/// - Web: solo Analytics (Crashlytics no soporta Web).
/// - Windows: no-op (ningún servicio Firebase soporta Windows).
final servicioTelemetriaProvider = Provider<IServicioTelemetria>((ref) {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
    return const NoopTelemetria();
  }
  if (kIsWeb) {
    return FirebaseTelemetria(analytics: FirebaseAnalytics.instance);
  }
  return FirebaseTelemetria(
    analytics: FirebaseAnalytics.instance,
    crashlytics: FirebaseCrashlytics.instance,
  );
});

/// Estado del toggle «Compartir datos de uso» en el panel de ajustes.
/// Por defecto habilitado; sin persistencia entre sesiones (mejora futura).
final compartirDatosProvider = StateProvider<bool>((ref) => true);
