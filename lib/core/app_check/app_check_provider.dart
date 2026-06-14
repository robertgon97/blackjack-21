import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/firebase_app_check_service.dart';
import 'data/noop_app_check_service.dart';
import 'domain/i_servicio_app_check.dart';

/// Crea la implementación de App Check según la plataforma, con la **misma
/// guarda** que la telemetría (Fase 6): Windows/Linux no soportan App Check, así
/// que reciben un no-op; el resto (Android/iOS/Web) usa la implementación real.
///
/// Es una función top-level (no solo un provider) porque la activación ocurre en
/// `main()` —antes de montar el `ProviderScope`— donde no hay `ref` disponible.
IServicioAppCheck crearServicioAppCheck() {
  const sinSoporte = {TargetPlatform.windows, TargetPlatform.linux};
  if (!kIsWeb && sinSoporte.contains(defaultTargetPlatform)) {
    return const NoopAppCheckService();
  }
  return const FirebaseAppCheckService();
}

/// Expone el servicio a la capa de presentación/tests si llegara a necesitarse.
final servicioAppCheckProvider =
    Provider<IServicioAppCheck>((ref) => crearServicioAppCheck());
