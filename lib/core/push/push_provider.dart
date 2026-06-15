import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/firebase_push_service.dart';
import 'data/noop_push_service.dart';
import 'domain/i_servicio_push.dart';

/// Crea la implementación de push según la plataforma, con la misma guarda que
/// telemetría y App Check: Windows/Linux no soportan Cloud Messaging → no-op; el
/// resto (Android/iOS/Web) usa Firebase Messaging.
IServicioPush crearServicioPush() {
  const sinSoporte = {TargetPlatform.windows, TargetPlatform.linux};
  if (!kIsWeb && sinSoporte.contains(defaultTargetPlatform)) {
    return const NoopPushService();
  }
  return FirebasePushService();
}

final servicioPushProvider =
    Provider<IServicioPush>((ref) => crearServicioPush());
