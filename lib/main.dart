import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/app_check/app_check_provider.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // App Check: atestigua que las llamadas a Firebase vienen de la app legítima.
  // Se activa SIN await (fire-and-forget): la atestación (p. ej. Play Integrity)
  // puede tardar o colgarse, y bloquear `runApp` dejaría la app en pantalla
  // negra. En modo monitor las llamadas no requieren el token todavía, así que
  // activar en segundo plano es seguro. `activar()` captura sus propios errores.
  unawaited(crearServicioAppCheck().activar());

  // Engancha los errores de Flutter y de Dart a Crashlytics.
  // Solo en plataformas soportadas: no funciona en Web, Windows ni Linux.
  if (!kIsWeb &&
      defaultTargetPlatform != TargetPlatform.windows &&
      defaultTargetPlatform != TargetPlatform.linux) {
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  }

  runApp(const ProviderScope(child: BlackjackApp()));
}
