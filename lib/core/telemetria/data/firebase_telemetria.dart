import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

import '../domain/i_servicio_telemetria.dart';

/// Implementación de [IServicioTelemetria] sobre Firebase.
///
/// Acepta [crashlytics] nulo: Web y Windows no lo soportan, por lo que
/// [telemetria_provider.dart] lo omite en esas plataformas. Todos los
/// accesos son null-safe; los errores internos de Firebase se capturan
/// para que nunca interrumpan el flujo de la app.
class FirebaseTelemetria implements IServicioTelemetria {
  FirebaseTelemetria({
    FirebaseAnalytics? analytics,
    FirebaseCrashlytics? crashlytics,
  })  : _analytics = analytics,
        _crashlytics = crashlytics;

  final FirebaseAnalytics? _analytics;
  final FirebaseCrashlytics? _crashlytics;

  @override
  Future<void> registrarError(
    Object error,
    StackTrace? stackTrace, {
    bool fatal = false,
  }) async {
    try {
      await _crashlytics?.recordError(error, stackTrace, fatal: fatal);
    } catch (_) {}
  }

  @override
  Future<void> log(String mensaje) async {
    try {
      await _crashlytics?.log(mensaje);
    } catch (_) {}
  }

  @override
  Future<void> setClave(String clave, String valor) async {
    try {
      await _crashlytics?.setCustomKey(clave, valor);
    } catch (_) {}
  }

  @override
  Future<void> setUid(String? uid) async {
    try {
      await _crashlytics?.setUserIdentifier(uid ?? '');
      await _analytics?.setUserId(id: uid);
    } catch (_) {}
  }

  @override
  Future<void> evento(String nombre, {Map<String, Object>? params}) async {
    try {
      await _analytics?.logEvent(name: nombre, parameters: params);
    } catch (_) {}
  }

  @override
  Future<void> pantalla(String nombre) async {
    try {
      await _analytics?.logScreenView(screenName: nombre);
    } catch (_) {}
  }

  @override
  Future<void> setPropiedad(String nombre, String? valor) async {
    try {
      await _analytics?.setUserProperty(name: nombre, value: valor);
    } catch (_) {}
  }

  @override
  Future<void> setHabilitado(bool habilitado) async {
    try {
      await _analytics?.setAnalyticsCollectionEnabled(habilitado);
      await _crashlytics?.setCrashlyticsCollectionEnabled(habilitado);
    } catch (_) {}
  }
}
